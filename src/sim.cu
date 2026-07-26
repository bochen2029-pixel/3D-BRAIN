// =============================================================================
//  sim.cu · the per-step machinery.
//    k_gather_integrate : arriving current -> Izhikevich -> spikes  (1 thread/neuron)
//    k_scatter          : spikes -> delay ring + forward-only iSTDP  (1 thread/fired)
//    k_homeostatic_gain : slow rate controller                       (1 thread/neuron)
//  + host-side criticality probe (m-hat, avalanche detection).
//
//  Step order per tick (enforced in main.cu):  gather -> scatter -> (gain).
//  Kernels are serialized on the default stream, so cross-kernel reads are safe.
// =============================================================================
#include "brain.h"
#include <cmath>
#include <vector>

// ---------- RNG init ---------------------------------------------------------
__global__ void k_init_rng(curandStatePhilox4_32_10_t* rng, int N, unsigned seed) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;
    curand_init(seed, (unsigned long long)i, 0ULL, &rng[i]);
}

// ---------- gather + integrate ----------------------------------------------
__global__ void k_gather_integrate(
    NeuronState s, DelayRing ring, SpikeList spikes,
    int N, int step, float dt_ms,
    float nu_ext_hz, float w_ext, float trace_decay, float rate_decay)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;

    const int D = N_DELAY_BINS;
    int slot = step % D;

    // current arriving from the ring THIS step, folded into a DECAYING synaptic current
    // g_syn (temporal summation -- real synapses aren't instantaneous). tau_syn widens the
    // coincidence window so inputs across ~tau_syn/dt steps accumulate toward threshold.
    float I_rec = ring.buf[(long)slot * N + i];
    ring.buf[(long)slot * N + i] = 0.0f;      // clear for reuse (we own i => no race)
    float g = s.g_syn[i] * expf(-dt_ms / TAU_SYN_MS) + I_rec;
    s.g_syn[i] = g;

    // external Poisson noise floor
    curandStatePhilox4_32_10_t st = s.rng[i];
    float mean = nu_ext_hz * dt_ms * 0.001f;  // expected ext spikes this step
    unsigned n_ext = curand_poisson(&st, mean);
    s.rng[i] = st;

    // total input: gain scales the (summed) recurrent drive; noise is an ungained floor
    float I = s.gain[i] * g + w_ext * (float)n_ext;

    // Izhikevich, two half-steps for numerical stability (S4 guard)
    float v = s.v[i], u = s.u[i];
    float a = s.a[i], b = s.b[i], c = s.c[i], d = s.d[i];
    v += 0.5f * dt_ms * (0.04f*v*v + 5.0f*v + 140.0f - u + I);
    v += 0.5f * dt_ms * (0.04f*v*v + 5.0f*v + 140.0f - u + I);
    // I4 guard, replacing `if (!isfinite(v)) v = 30.0f` (QC review 2026-07-07).
    //  H2 (REAL, this is the fix): clamp v BEFORE the u-update. The old order fed a
    //      diverged v into u += dt*(a*(b*v-u)) and never guarded u at all, so u could
    //      latch at +-Inf while the v-guard kept re-firing the neuron -> a permanently
    //      firing cell quietly inflating A_t. u is now clamped too.
    //  H1 (TESTED AND REFUTED 2026-07-25): the review suspected -use_fast_math folds
    //      isfinite() to a constant `true` and deletes the guard. It does not -- PTX
    //      for sm_89 under CUDA 13.1 still emits abs.ftz.f32 + setp.geu.ftz.f32 +
    //      selp.f32 with -use_fast_math. Prior results carry no unguarded-divergence
    //      risk from this cause. The clamp is kept anyway: it is equivalent, it does
    //      not depend on compiler behaviour holding across toolchain versions, and it
    //      is what makes the H2 reordering expressible. NaN maps to V_FLOOR_MV (PTX
    //      min/max return the non-NaN operand), which recovers in ~2 steps since
    //      dv/dt is strongly positive there -- unlike the old guard, which mapped NaN
    //      to +30 and thereby manufactured a spike out of a numerical failure.
    v = fminf(fmaxf(v, V_FLOOR_MV), 30.0f);
    u += dt_ms * (a * (b * v - u));
    u = fminf(fmaxf(u, U_FLOOR), U_CEIL);

    bool fired = (v >= 30.0f);
    if (fired) { v = c; u += d; }
    s.v[i] = v;
    s.u[i] = u;

    // short-term depression (STD -> self-organized criticality, Levina 2007): recover
    // toward 1 each step, release a fraction STD_U on spike. k_scatter then delivers
    // this neuron's spikes at efficacy w * D[i]. (STD_U=0 => D stays 1 => STD off.)
    float Dstd = s.D[i] + (1.0f - s.D[i]) * dt_ms / TAU_REC_MS;
    if (fired) Dstd *= (1.0f - STD_U);
    s.D[i] = Dstd;

    // eligibility trace (decay, +1 on spike) and low-pass rate
    s.x_trace[i] = s.x_trace[i] * trace_decay + (fired ? 1.0f : 0.0f);
    s.rate[i]    = s.rate[i]    * rate_decay + (fired ? (1.0f - rate_decay) : 0.0f);

    // compact fired neurons for the scatter pass; *spikes.count becomes A_t
    if (fired) {
        int p = atomicAdd(spikes.count, 1);
        spikes.idx[p] = i;
    }
}

// ---------- scatter + forward-only iSTDP ------------------------------------
// Grid is sized for N; threads with f >= *spikes.count return immediately
// (avoids a per-step device->host sync just to size the launch).
__global__ void k_scatter(
    NeuronState s, Connectome c, DelayRing ring, SpikeList spikes,
    int N, int step, float istdp_eta, float istdp_alpha, float w_max)
{
    int f = blockIdx.x * blockDim.x + threadIdx.x;
    if (f >= *spikes.count) return;

    const int D = N_DELAY_BINS;
    int i = spikes.idx[f];
    bool inh = (s.is_inh[i] != 0);
    float Di = s.D[i];                                // presynaptic STD efficacy in (0,1]

    int start = c.row_ptr[i], end = c.row_ptr[i + 1];
    for (int e = start; e < end; ++e) {
        int j       = c.col_idx[e];
        float w     = c.weight[e];
        uint8_t db  = c.delay_bin[e];
        int dslot   = (step + (int)db) % D;

        float contrib = inh ? -(w * Di) : (w * Di);   // STD-scaled efficacy; sign by source
        atomicAdd(&ring.buf[(long)dslot * N + j], contrib);   // THE hot scatter

        // forward-only inhibitory STDP: drive postsynaptic rate toward target.
        // dw>0 when post trace exceeds alpha (post too active) => more inhibition.
        if (inh) {
            float dw = istdp_eta * (s.x_trace[j] - istdp_alpha);
            w += dw;
            w = fminf(fmaxf(w, 0.0f), w_max);
            c.weight[e] = w;                          // we own row i => no race
        }
    }
}

// ---------- slow homeostatic input-gain controller --------------------------
__global__ void k_homeostatic_gain(
    NeuronState s, int N, float dt_ms, float rho0_hz,
    float gain_eta, float gain_min, float gain_max)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;
    // s.rate is lowpassed spikes/step; convert to Hz
    float r_hz = s.rate[i] / dt_ms * 1000.0f;
    float g = s.gain[i] + gain_eta * (rho0_hz - r_hz);
    s.gain[i] = fminf(fmaxf(g, gain_min), gain_max);
}

// =============================================================================
//  HOST criticality probe
// =============================================================================
// m-hat = OLS slope of A[t+1] on A[t]. Under a branching process this estimates
// the branching ratio. NOTE: subsampling-biased; the unbiased multistep (MR)
// estimator (Wilting & Priesemann 2018) is computed offline in tools/analyze.py.
double mhat_regression(const int* A, int len) {
    if (len < 3) return 0.0;
    long double sx=0, sy=0, sxx=0, sxy=0; long n = len - 1;
    for (int t = 0; t < len - 1; ++t) {
        long double x = A[t], y = A[t + 1];
        sx += x; sy += y; sxx += x*x; sxy += x*y;
    }
    long double denom = n * sxx - sx * sx;
    if (denom == 0) return 0.0;
    return (double)((n * sxy - sx * sy) / denom);
}

// Avalanche = maximal run of active bins (A > thr), size = sum of A over the run.
// thr=0 is the fully-observed convention (bin width = dt).
void detect_avalanches(const int* A, int len, int thr,
                       std::vector<long>& sizes, std::vector<int>& durs) {
    long size = 0; int dur = 0;
    for (int t = 0; t < len; ++t) {
        if (A[t] > thr) { size += A[t]; ++dur; }
        else if (dur > 0) { sizes.push_back(size); durs.push_back(dur); size = 0; dur = 0; }
    }
    if (dur > 0) { sizes.push_back(size); durs.push_back(dur); }
}
