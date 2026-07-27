// =============================================================================
//  main.cu · Phase-0 driver — "does it come alive and hold at the edge?"
//  Usage:  ./brain_phase0 [seed]
//  Outputs (CSV, for tools/analyze.py):
//     activity.csv    step, A_t              (network activity per step)
//     avalanches.csv  size, duration         (for MLE power-law + KS offline)
//     neurons.csv     x,y,z,is_inh,rate_hz   (3D point cloud snapshot)
// =============================================================================
#include "brain.h"
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cmath>
#include <vector>
#include <fstream>
#include <algorithm>

#define CUDA_CHECK(x) do { cudaError_t e=(x); if(e!=cudaSuccess){ \
    fprintf(stderr,"CUDA error %s:%d: %s\n",__FILE__,__LINE__,cudaGetErrorString(e)); \
    exit(1);} } while(0)

template <class T> static T* dmalloc(long n){ T* p; CUDA_CHECK(cudaMalloc(&p,n*sizeof(T))); return p; }
template <class T> static T* dcopy(const std::vector<T>& h){
    T* p = dmalloc<T>((long)h.size());
    CUDA_CHECK(cudaMemcpy(p, h.data(), h.size()*sizeof(T), cudaMemcpyHostToDevice));
    return p;
}

// host splitmix for Izhikevich parameter heterogeneity
static inline uint64_t hsm(uint64_t& x){ x+=0x9E3779B97F4A7C15ULL; uint64_t z=x;
    z=(z^(z>>30))*0xBF58476D1CE4E5B9ULL; z=(z^(z>>27))*0x94D049BB133111EBULL; return z^(z>>31);}
static inline float hrand(uint64_t& s){ return (float)((hsm(s)>>40)*(1.0/16777216.0)); }

// =============================================================================
//  CONTROLLER-AUTHORITY PROBE (Session 4)
// =============================================================================
// Reports whether the two homeostats still have AUTHORITY or have railed, and the
// E/I current balance the network actually runs at. Motivation: the Session-3 E/I
// null (W_INH_INIT 4->10->16 => same operating point) was attributed to iSTDP
// "slaving inhibitory weight to the rate target and washing out W_INH_INIT" -- but
// k_scatter updates an edge once per PRESYNAPTIC spike, so at the t4 corner
// (inh rate ~19 Hz, x_trace ~0.22, alpha 0.06, eta 0.005) the total excursion over
// a 20 s run is dw ~ 0.3. It cannot wash out a 4->16 difference. Either the weights
// move far more than that arithmetic predicts, or inhibition is inert for some other
// reason -- and nothing in the run output could distinguish those. This does.
//
// Everything is derived on the host from a few D2H copies (~5 calls/run); no new
// kernel and no change to the brain.h contract surface.
//
// Units: g_syn obeys  g <- g*exp(-dt/tau) + sum(w),  and  dv = dt*I, so I is mV/ms.
// A source i firing at nu_i Hz with efficacy D_i contributes  w*D_i*nu_i*tau  to the
// mean g of each of its targets; summing rows and dividing by N gives the mean over
// POSTsynaptic neurons (in-degree == out-degree on average).
static void probe_controllers(const char* tag, int step,
                              const Connectome& c, const NeuronState& s, int N,
                              const std::vector<int>& row_ptr,
                              const std::vector<uint8_t>& is_inh, float dt)
{
    static std::vector<float> w, gain, Dstd, rate;
    w.resize(c.M); gain.resize(N); Dstd.resize(N); rate.resize(N);
    CUDA_CHECK(cudaMemcpy(w.data(),    c.weight, c.M*sizeof(float), cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaMemcpy(gain.data(), s.gain,   N*sizeof(float),   cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaMemcpy(Dstd.data(), s.D,      N*sizeof(float),   cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaMemcpy(rate.data(), s.rate,   N*sizeof(float),   cudaMemcpyDeviceToHost));

    double we = 0, wi = 0, gE = 0, gI = 0, De = 0, Di = 0, rE = 0, rI = 0;
    long   ne = 0, ni = 0, ce = 0, ci = 0;
    float  wi_min = 1e30f, wi_max = -1e30f;
    const double tau = TAU_SYN_MS;
    for (int i = 0; i < N; ++i) {
        double rowsum = 0;
        for (int e = row_ptr[i]; e < row_ptr[i+1]; ++e) rowsum += w[e];
        const long deg  = row_ptr[i+1] - row_ptr[i];
        const double hz = rate[i] / dt * 1000.0;
        const double contrib = rowsum * Dstd[i] * hz * 1e-3 * tau;   // mV/ms into targets
        if (is_inh[i]) {
            wi += rowsum; ni += deg; gI += contrib; Di += Dstd[i]; rI += hz; ++ci;
            for (int e = row_ptr[i]; e < row_ptr[i+1]; ++e) {
                wi_min = fminf(wi_min, w[e]); wi_max = fmaxf(wi_max, w[e]);
            }
        } else {
            we += rowsum; ne += deg; gE += contrib; De += Dstd[i]; rE += hz; ++ce;
        }
    }
    double gm = 0; long lo = 0, hi = 0;
    for (int i = 0; i < N; ++i) {
        gm += gain[i];
        if (gain[i] <= GAIN_MIN * 1.001f) ++lo;
        if (gain[i] >= GAIN_MAX * 0.999f) ++hi;
    }
    gm /= N; gE /= N; gI /= N;
    // the input quanta, in mV -- one presynaptic event's full PSP vs the ~20 mV
    // rest-to-threshold gap of an Izhikevich RS cell.
    const double psp_e = dt * W_EXC_INIT / (1.0 - exp(-dt / TAU_SYN_MS));
    const double psp_x = dt * W_EXT;
    printf("[ctrl %-6s %7d] w_inh %.3f [%.3f,%.3f] (init %.2f cap %.2f) | w_exc %.3f | <D> E %.3f I %.3f | rate E %.1f I %.1f Hz\n",
           tag, step, ni ? wi/ni : 0.0, ni ? wi_min : 0.0, ni ? wi_max : 0.0,
           (double)W_INH_INIT, (double)W_MAX, ne ? we/ne : 0.0,
           ce ? De/ce : 0.0, ci ? Di/ci : 0.0, ce ? rE/ce : 0.0, ci ? rI/ci : 0.0);
    printf("[ctrl %-6s %7d] gain %.3f (railed lo %.1f%% hi %.1f%%) | drive mV/ms: exc %.3f inh %.3f  I/E %.3f | net %.3f ext %.3f | PSP mV: exc %.1f ext %.1f (gap ~20)\n",
           tag, step, gm, 100.0*lo/N, 100.0*hi/N, gE, gI, gE > 0 ? gI/gE : 0.0,
           gm*(gE - gI), (double)W_EXT * NU_EXT_HZ * dt * 1e-3, psp_e, psp_x);
}

int main(int argc, char** argv) {
    unsigned seed = (argc > 1) ? (unsigned)strtoul(argv[1], nullptr, 10) : 1234u;
    const int   N  = N_NEURONS;
    const float dt = DT_MS;
    printf("=== Phase-0 : the living cell ===  N=%d  dt=%.3f ms  steps=%d  seed=%u\n",
           N, dt, N_STEPS, seed);
    // Every run records its own knob set. Session 4 lost a long time to a knob that was never
    // being varied (TARGET_OUTDEG, constant across 32 sweep rows) because nothing in the output
    // said what the run was built with -- sweep_log.csv had to be maintained by hand. A run that
    // does not state its own configuration cannot be audited. tools/analyze.py parses this line.
    printf("[knobs] W_EXC_INIT=%g W_INH_INIT=%g W_MAX=%g NU_EXT_HZ=%g W_EXT=%g RHO0_HZ=%g "
           "ISTDP_ETA=%g GAIN_ETA=%g GAIN_MIN=%g GAIN_MAX=%g STD_U=%g TAU_REC_MS=%g "
           "TAU_SYN_MS=%g LAMBDA_UM=%g TARGET_OUTDEG=%d MOD_GRID=%d AREA_GRID=%d "
           "V_RESET_OFF=%g D_SCALE=%g N_STEPS=%d PARADOX_INJ=%g PARADOX_START=%d PARADOX_LEN=%d "
           "PARADOX_PERIOD=%d PARADOX_TRIALS=%d\n",
           (double)W_EXC_INIT, (double)W_INH_INIT, (double)W_MAX, (double)NU_EXT_HZ,
           (double)W_EXT, (double)RHO0_HZ, (double)ISTDP_ETA, (double)GAIN_ETA,
           (double)GAIN_MIN, (double)GAIN_MAX, (double)STD_U, (double)TAU_REC_MS,
           (double)TAU_SYN_MS, (double)LAMBDA_UM, (int)TARGET_OUTDEG, (int)MOD_GRID,
           (int)AREA_GRID, (double)V_RESET_OFF, (double)D_SCALE, (int)N_STEPS,
           (double)PARADOX_INJ, (int)PARADOX_START, (int)PARADOX_LEN,
           (int)PARADOX_PERIOD, (int)PARADOX_TRIALS);

    // ---- 1. connectome (host) --------------------------------------------------
    std::vector<float> px, py, pz;
    std::vector<uint8_t> is_inh;
    std::vector<int> row_ptr, col_idx;
    std::vector<float> weight;
    std::vector<uint8_t> delay_bin;
    long M = build_connectome_host(N, seed, px, py, pz, is_inh,
                                   row_ptr, col_idx, weight, delay_bin);

    // ---- 2. Izhikevich parameters (heterogeneous) ------------------------------
    std::vector<float> ha(N), hb(N), hc(N), hd(N), hv(N), hu(N), hgain(N, 1.0f),
                       hzero(N, 0.0f), hone(N, 1.0f);
    uint64_t hs = (uint64_t)seed * 0xABCDEF + 7;
    for (int i = 0; i < N; ++i) {
        if (is_inh[i]) { float ri = hrand(hs);
            ha[i]=0.02f+0.08f*ri; hb[i]=0.25f-0.05f*ri; hc[i]=-65.0f; hd[i]=2.0f;
        } else {         float re = hrand(hs); float re2 = re*re;
            ha[i]=0.02f; hb[i]=0.2f; hc[i]=-65.0f+15.0f*re2; hd[i]=8.0f-6.0f*re2;
        }
        hc[i] += V_RESET_OFF;   // lower the reset barrier (less-negative c) for propagation
        hd[i] *= D_SCALE;       // scale the adaptation jump
        hv[i]=hc[i]; hu[i]=hb[i]*hv[i];
    }

    // ---- 3. device allocation --------------------------------------------------
    NeuronState s{};
    s.v=dcopy(hv); s.u=dcopy(hu); s.a=dcopy(ha); s.b=dcopy(hb); s.c=dcopy(hc); s.d=dcopy(hd);
    s.is_inh=dcopy(is_inh); s.x_trace=dcopy(hzero); s.rate=dcopy(hzero); s.gain=dcopy(hgain);
    s.D=dcopy(hone);        // STD synaptic efficacy starts fully recovered (=1)
    s.g_syn=dcopy(hzero);   // decaying synaptic current starts empty
    s.px=dcopy(px); s.py=dcopy(py); s.pz=dcopy(pz);
    s.rng = dmalloc<curandStatePhilox4_32_10_t>(N);

    Connectome c{}; c.M=M;
    c.row_ptr=dcopy(row_ptr); c.col_idx=dcopy(col_idx);
    c.weight=dcopy(weight);   c.delay_bin=dcopy(delay_bin);

    DelayRing ring{}; ring.buf = dmalloc<float>((long)N_DELAY_BINS * N);
    CUDA_CHECK(cudaMemset(ring.buf, 0, (long)N_DELAY_BINS * N * sizeof(float)));

    SpikeList spikes{}; spikes.idx = dmalloc<int>(N); spikes.count = dmalloc<int>(1);
    int* activity_dev = dmalloc<int>(N_STEPS);

    // ---- 4. derived constants --------------------------------------------------
    const int   block = 256;
    const int   gridN = (N + block - 1) / block;
    const float trace_decay = expf(-dt / TAU_STDP_MS);
    const float rate_decay  = expf(-dt / RATE_TAU_MS);
    // iSTDP set-point (forward-only, single depression term): equilibrium post-rate ~ RHO0
    const float istdp_alpha = (RHO0_HZ * 0.001f) * TAU_STDP_MS;

    k_init_rng<<<gridN, block>>>(s.rng, N, seed);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    // ---- 4b. single-spike test (base-branching check) --------------------------
    // BRAIN_SPIKETEST=<n>: seed ONE spike into a quiescent network (no drive) and count
    // total descendants -- the cleanest measure of whether the base supports an avalanche
    // at all, free of drive/weight confounds. mean >> 1 => supercritical base (m>1);
    // ~0-1 => subcritical (STD cannot help). Build -DSTD_U=0 to test the raw base.
    if (const char* envp = getenv("BRAIN_SPIKETEST")) {
        int n_seed = atoi(envp); if (n_seed <= 0) n_seed = 40;
        const int WIN = 40;            // one "generation" (~ max delay + integration)
        const int TEST_STEPS = 400;
        // first-bin branching sigma = A1/A0 -- the UN-SATURATED base branching (total
        // descendants saturates and is blind above m~1; A1 is graded, dial it to ~2-3).
        std::vector<long> sig, tot;
        uint64_t rs = (uint64_t)seed * 2654435761u + 1;
        // GATE #2: optionally settle to the DEPLETED steady state first (full dynamics),
        // so the seed test measures branching from the state a real seed hits -- not a
        // fresh full-D network. BRAIN_SETTLE=<steps>. Reports the settled mean <D>.
        std::vector<float> hDseed = hone; float mean_D = 1.0f;
        if (const char* se = getenv("BRAIN_SETTLE")) {
            int settle = atoi(se); if (settle < 1000) settle = 30000;
            for (int step = 0; step < settle; ++step) {
                CUDA_CHECK(cudaMemsetAsync(spikes.count, 0, sizeof(int)));
                k_gather_integrate<<<gridN, block>>>(s, ring, spikes, N, step, dt, NU_EXT_HZ, W_EXT, trace_decay, rate_decay);
                k_scatter<<<gridN, block>>>(s, c, ring, spikes, N, step, ISTDP_ETA, istdp_alpha, W_MAX);
                if (step % GAIN_EVERY == 0) k_homeostatic_gain<<<gridN, block>>>(s, N, dt, RHO0_HZ, GAIN_ETA, GAIN_MIN, GAIN_MAX);
            }
            CUDA_CHECK(cudaMemcpy(hDseed.data(), s.D, N*sizeof(float), cudaMemcpyDeviceToHost));
            double sD = 0; for (float dd : hDseed) sD += dd; mean_D = (float)(sD / N);
        }
        for (int t = 0; t < n_seed; ++t) {
            CUDA_CHECK(cudaMemcpy(s.v, hv.data(), N*sizeof(float), cudaMemcpyHostToDevice));
            CUDA_CHECK(cudaMemcpy(s.u, hu.data(), N*sizeof(float), cudaMemcpyHostToDevice));
            CUDA_CHECK(cudaMemcpy(s.g_syn, hzero.data(), N*sizeof(float), cudaMemcpyHostToDevice));
            CUDA_CHECK(cudaMemcpy(s.D, hDseed.data(), N*sizeof(float), cudaMemcpyHostToDevice));   // depleted (or 1 if no settle)
            CUDA_CHECK(cudaMemcpy(s.x_trace, hzero.data(), N*sizeof(float), cudaMemcpyHostToDevice));
            CUDA_CHECK(cudaMemset(ring.buf, 0, (long)N_DELAY_BINS * N * sizeof(float)));
            int sid; do { sid = (int)(hsm(rs) % (uint64_t)N); } while (is_inh[sid]); // excitatory seed
            float vhi = 40.0f;
            CUDA_CHECK(cudaMemcpy(s.v + sid, &vhi, sizeof(float), cudaMemcpyHostToDevice));
            long a1 = 0, total = 0;
            for (int step = 0; step < TEST_STEPS; ++step) {
                CUDA_CHECK(cudaMemsetAsync(spikes.count, 0, sizeof(int)));
                k_gather_integrate<<<gridN, block>>>(s, ring, spikes, N, step, dt,
                                                     0.0f, W_EXT, trace_decay, rate_decay);
                int cnt; CUDA_CHECK(cudaMemcpy(&cnt, spikes.count, sizeof(int), cudaMemcpyDeviceToHost));
                total += cnt;
                if (step >= 1 && step <= WIN) a1 += cnt;   // A1 = first-generation descendants
                k_scatter<<<gridN, block>>>(s, c, ring, spikes, N, step, 0.0f, istdp_alpha, W_MAX);
            }
            sig.push_back(a1); tot.push_back(total);
        }
        std::sort(sig.begin(), sig.end()); std::sort(tot.begin(), tot.end());
        double msig = 0; for (long x : sig) msig += x; msig /= (double)sig.size();
        printf("[spiketest] seeds=%d(exc) WIN=%d  TAU_SYN=%.1f TAU_REC=%.0f STD_U=%.2f W_EXC=%.2f W_INH=%.2f  settled<D>=%.3f\n",
               n_seed, WIN, (float)TAU_SYN_MS, (float)TAU_REC_MS, (float)STD_U, (float)W_EXC_INIT, (float)W_INH_INIT, mean_D);
        printf("[spiketest] first-bin sigma (A1/A0): mean=%.2f  median=%ld  max=%ld   |  total@%dst median=%ld   (target sigma ~2-3)\n",
               msig, sig[sig.size()/2], sig.back(), TEST_STEPS, tot[tot.size()/2]);
        return 0;
    }

    // ---- 5. simulation loop ----------------------------------------------------
    std::vector<int> win(PROBE_WINDOW);
    std::vector<int> dump_step, dump_id;   // sparse spike dump for the offline firing animation
    cudaEvent_t t0, t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
    cudaEventRecord(t0);

    // ---- optional per-kernel profile (BRAIN_PROFILE=<samples>) -----------------
    // MODULE.md §6 NFR-binding-constraint asserts the hot path is the scattered atomic RMW into
    // the delay ring, and Phase 0 runs it un-Morton'd on purpose to set the baseline Morton must
    // beat. A single aggregate steps/s cannot test that assertion -- at the certified operating
    // point only ~67 of 200 000 neurons fire per step, so the scatter touches ~6 700 edges while
    // the gather sweeps all N. Sampled with events over mid-run steps; the sync cost is confined
    // to the sampled steps and the profile is off by default (zero overhead).
    const char* profenv = getenv("BRAIN_PROFILE");
    const int   prof_n  = profenv ? atoi(profenv) : 0;
    cudaEvent_t pe[4];
    if (prof_n) for (int q = 0; q < 4; ++q) cudaEventCreate(&pe[q]);
    double t_gath = 0, t_scat = 0, t_gain = 0; long prof_hits = 0, prof_spk = 0;

    for (int step = 0; step < N_STEPS; ++step) {
        const bool prof = prof_n && step >= N_STEPS / 2 && prof_hits < prof_n;
        if (prof) CUDA_CHECK(cudaEventRecord(pe[0]));
        CUDA_CHECK(cudaMemsetAsync(spikes.count, 0, sizeof(int)));
        k_gather_integrate<<<gridN, block>>>(s, ring, spikes, N, step, dt,
                                             NU_EXT_HZ, W_EXT, trace_decay, rate_decay);
        if (prof) CUDA_CHECK(cudaEventRecord(pe[1]));
        // record A_t (== spikes.count after gather) without a host sync
        CUDA_CHECK(cudaMemcpyAsync(activity_dev + step, spikes.count, sizeof(int),
                                   cudaMemcpyDeviceToDevice));
        // sparse spike dump over the animation window (DUMP_LEN=0 => compiled out)
        if (DUMP_LEN > 0 && step >= DUMP_START && step < DUMP_START + DUMP_LEN) {
            int cnt = 0; CUDA_CHECK(cudaMemcpy(&cnt, spikes.count, sizeof(int), cudaMemcpyDeviceToHost));
            if (cnt > 0) {
                size_t base = dump_id.size(); dump_id.resize(base + cnt);
                CUDA_CHECK(cudaMemcpy(dump_id.data() + base, spikes.idx, (size_t)cnt*sizeof(int), cudaMemcpyDeviceToHost));
                dump_step.insert(dump_step.end(), (size_t)cnt, step);
            }
        }
        k_scatter<<<gridN, block>>>(s, c, ring, spikes, N, step,
                                    ISTDP_ETA, istdp_alpha, W_MAX);
        if (prof) CUDA_CHECK(cudaEventRecord(pe[2]));
        if (step % GAIN_EVERY == 0)
            k_homeostatic_gain<<<gridN, block>>>(s, N, dt, RHO0_HZ,
                                                 GAIN_ETA, GAIN_MIN, GAIN_MAX);
        if (prof) {
            CUDA_CHECK(cudaEventRecord(pe[3]));
            CUDA_CHECK(cudaEventSynchronize(pe[3]));
            float ga = 0, sc = 0, gn = 0;
            cudaEventElapsedTime(&ga, pe[0], pe[1]);
            cudaEventElapsedTime(&sc, pe[1], pe[2]);
            cudaEventElapsedTime(&gn, pe[2], pe[3]);
            int cnt = 0; CUDA_CHECK(cudaMemcpy(&cnt, spikes.count, sizeof(int), cudaMemcpyDeviceToHost));
            t_gath += ga; t_scat += sc; t_gain += gn; prof_spk += cnt; ++prof_hits;
        }

        if (step > 0 && step % CTRL_PROBE_EVERY == 0)
            probe_controllers("mid", step, c, s, N, row_ptr, is_inh, dt);

        if (step > 0 && step % PRINT_EVERY == 0) {
            int w0 = step - PROBE_WINDOW; if (w0 < 0) w0 = 0; int wl = step - w0;
            CUDA_CHECK(cudaMemcpy(win.data(), activity_dev + w0, wl*sizeof(int),
                                  cudaMemcpyDeviceToHost));
            double sum = 0; for (int k = 0; k < wl; ++k) sum += win[k];
            double meanA = sum / wl;
            double rate_hz = meanA / N / dt * 1000.0;
            double mh = mhat_regression(win.data(), wl);
            printf("  step %7d | rate %6.2f Hz | A_mean %8.1f | m_hat %.4f\n",
                   step, rate_hz, meanA, mh);
        }
    }
    CUDA_CHECK(cudaDeviceSynchronize());
    cudaEventRecord(t1); cudaEventSynchronize(t1);
    float ms = 0; cudaEventElapsedTime(&ms, t0, t1);
    double sps = N_STEPS / (ms / 1000.0);
    printf("[timing] %.2f s wall | %.0f steps/s | real-time factor %.2fx (>=1 is real time)\n",
           ms / 1000.0, sps, sps / 10000.0);
    if (prof_hits) {
        const double tot = t_gath + t_scat + t_gain;
        printf("[profile] %ld sampled steps, mean A_t = %.1f  (%.4f%% of N fire per step)\n",
               prof_hits, (double)prof_spk / prof_hits, 100.0 * prof_spk / prof_hits / N);
        printf("[profile] gather  %7.1f us/step  %5.1f%%   (all %d neurons, every step)\n",
               1000.0 * t_gath / prof_hits, 100.0 * t_gath / tot, N);
        printf("[profile] scatter %7.1f us/step  %5.1f%%   (~%.0f edges/step -- THE assumed hot path)\n",
               1000.0 * t_scat / prof_hits, 100.0 * t_scat / tot,
               (double)prof_spk / prof_hits * (double)M / N);
        printf("[profile] gain    %7.1f us/step  %5.1f%%   (1 in %d steps)\n",
               1000.0 * t_gain / prof_hits, 100.0 * t_gain / tot, (int)GAIN_EVERY);
        printf("[profile] total   %7.1f us/step -> %.0f steps/s\n",
               1000.0 * tot / prof_hits, 1e6 / (1000.0 * tot / prof_hits));
    }

    probe_controllers("final", N_STEPS, c, s, N, row_ptr, is_inh, dt);

    // ---- 6. pull results + dump ------------------------------------------------
    std::vector<int> A(N_STEPS);
    CUDA_CHECK(cudaMemcpy(A.data(), activity_dev, N_STEPS*sizeof(int), cudaMemcpyDeviceToHost));

    { std::ofstream f("activity.csv"); f << "step,A\n";
      for (int t = 0; t < N_STEPS; ++t) f << t << ',' << A[t] << '\n'; }

    std::vector<long> sizes; std::vector<int> durs;
    detect_avalanches(A.data(), N_STEPS, 0, sizes, durs);
    { std::ofstream f("avalanches.csv"); f << "size,duration\n";
      for (size_t k = 0; k < sizes.size(); ++k) f << sizes[k] << ',' << durs[k] << '\n'; }

    std::vector<float> hrate(N);
    CUDA_CHECK(cudaMemcpy(hrate.data(), s.rate, N*sizeof(float), cudaMemcpyDeviceToHost));
    { std::ofstream f("neurons.csv"); f << "x,y,z,is_inh,rate_hz\n";
      for (int i = 0; i < N; ++i)
        f << px[i] << ',' << py[i] << ',' << pz[i] << ',' << (int)is_inh[i]
          << ',' << (hrate[i] / dt * 1000.0f) << '\n'; }

    if (DUMP_LEN > 0) {
        std::ofstream f("spikes_window.csv"); f << "step,neuron\n";
        for (size_t k = 0; k < dump_id.size(); ++k) f << dump_step[k] << ',' << dump_id[k] << '\n';
        printf("[spikedump] %zu spikes over steps [%d,%d) -> spikes_window.csv\n",
               dump_id.size(), (int)DUMP_START, (int)(DUMP_START + DUMP_LEN));
    }
    long biggest = 0; for (long z : sizes) biggest = std::max(biggest, z);
    printf("[avalanches] count=%zu  largest=%ld\n", sizes.size(), biggest);
    printf("=== done. run:  python tools/analyze.py   (rigorous m_hat + power-law fit) ===\n");
    return 0;
}
