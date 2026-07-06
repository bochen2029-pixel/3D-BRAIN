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

int main(int argc, char** argv) {
    unsigned seed = (argc > 1) ? (unsigned)strtoul(argv[1], nullptr, 10) : 1234u;
    const int   N  = N_NEURONS;
    const float dt = DT_MS;
    printf("=== Phase-0 : the living cell ===  N=%d  dt=%.3f ms  steps=%d  seed=%u\n",
           N, dt, N_STEPS, seed);

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
                       hzero(N, 0.0f);
    uint64_t hs = (uint64_t)seed * 0xABCDEF + 7;
    for (int i = 0; i < N; ++i) {
        if (is_inh[i]) { float ri = hrand(hs);
            ha[i]=0.02f+0.08f*ri; hb[i]=0.25f-0.05f*ri; hc[i]=-65.0f; hd[i]=2.0f;
        } else {         float re = hrand(hs); float re2 = re*re;
            ha[i]=0.02f; hb[i]=0.2f; hc[i]=-65.0f+15.0f*re2; hd[i]=8.0f-6.0f*re2;
        }
        hv[i]=hc[i]; hu[i]=hb[i]*hv[i];
    }

    // ---- 3. device allocation --------------------------------------------------
    NeuronState s{};
    s.v=dcopy(hv); s.u=dcopy(hu); s.a=dcopy(ha); s.b=dcopy(hb); s.c=dcopy(hc); s.d=dcopy(hd);
    s.is_inh=dcopy(is_inh); s.x_trace=dcopy(hzero); s.rate=dcopy(hzero); s.gain=dcopy(hgain);
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

    // ---- 5. simulation loop ----------------------------------------------------
    std::vector<int> win(PROBE_WINDOW);
    cudaEvent_t t0, t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
    cudaEventRecord(t0);

    for (int step = 0; step < N_STEPS; ++step) {
        CUDA_CHECK(cudaMemsetAsync(spikes.count, 0, sizeof(int)));
        k_gather_integrate<<<gridN, block>>>(s, ring, spikes, N, step, dt,
                                             NU_EXT_HZ, W_EXT, trace_decay, rate_decay);
        // record A_t (== spikes.count after gather) without a host sync
        CUDA_CHECK(cudaMemcpyAsync(activity_dev + step, spikes.count, sizeof(int),
                                   cudaMemcpyDeviceToDevice));
        k_scatter<<<gridN, block>>>(s, c, ring, spikes, N, step,
                                    ISTDP_ETA, istdp_alpha, W_MAX);
        if (step % GAIN_EVERY == 0)
            k_homeostatic_gain<<<gridN, block>>>(s, N, dt, RHO0_HZ,
                                                 GAIN_ETA, GAIN_MIN, GAIN_MAX);

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

    long biggest = 0; for (long z : sizes) biggest = std::max(biggest, z);
    printf("[avalanches] count=%zu  largest=%ld\n", sizes.size(), biggest);
    printf("=== done. run:  python tools/analyze.py   (rigorous m_hat + power-law fit) ===\n");
    return 0;
}
