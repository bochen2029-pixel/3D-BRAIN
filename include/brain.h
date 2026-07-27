#pragma once
// =============================================================================
//  BRAIN.H · the contract surface for Phase 0.
//  Data layouts + every kernel/function signature live here and NOWHERE else.
//  If a .cu file and this header disagree, this header is right — fix the .cu.
// =============================================================================
#include <cstdint>
#include <vector>
#include <curand_kernel.h>
#include "config.h"

// ---- Structure-of-Arrays neuron state (device pointers) ---------------------
// Coalesced access is the whole game; every attribute is its own array.
struct NeuronState {
    float*  v;        // membrane potential (mV)
    float*  u;        // Izhikevich recovery
    float*  a;        // Izhikevich params, per-neuron (heterogeneous)
    float*  b;
    float*  c;
    float*  d;
    uint8_t* is_inh;  // 1 = inhibitory, 0 = excitatory
    float*  x_trace;  // STDP eligibility trace (forward-only => one trace/neuron)
    float*  rate;     // low-pass firing-rate estimate (spikes/step, lowpassed)
    float*  gain;     // homeostatic input gain (the slow controller's state)
    float*  D;        // short-term depression efficacy in (0,1] (STD -> SOC; blueprint §2.5 L4)
    float*  g_syn;    // decaying synaptic current (temporal summation; tau_syn PSC time course)
    float*  px;       // geometry, kept for render + delay derivation + analysis
    float*  py;
    float*  pz;
    // NO stored RNG state. Philox is counter-based (Random123), so the external-drive stream is
    // regenerated per call from (seed, neuron_id, step). Storing it cost ~64 B read AND written
    // every step for every neuron -- ~25.6 MB/step at N=200k, measured as 30% of the gather
    // kernel (68.5 -> 47.7 us/step) and 12.8 MB of VRAM. Determinism is preserved and
    // strengthened: a draw no longer depends on how many draws preceded it.
    // (Contract amendment 2026-07-27, CONTRACT_CHANGES_PROPOSED.md change A.)
};

// ---- CSR connectome (device). Row = PRESYNAPTIC neuron. ----------------------
// Each source owns its row => weights can be written without atomics.
struct Connectome {
    int*     row_ptr;    // size N+1
    int*     col_idx;    // size M   (postsynaptic target indices)
    float*   weight;     // size M   (magnitude >=0; sign applied at scatter by is_inh)
    uint8_t* delay_bin;  // size M   (1..D-1)
    long     M;          // total synapses
};

// ---- Delay ring buffer ------------------------------------------------------
// buf[b*N + j] = current pending for neuron j at the future step where (step % D)==b.
// Scattered atomic RMW into this array is THE bandwidth bottleneck (naive on purpose).
struct DelayRing {
    float* buf;          // size D * N
};

// ---- Per-step fired-neuron compaction ---------------------------------------
struct SpikeList {
    int* idx;            // compacted indices of neurons that fired this step (size N)
    int* count;          // device counter; == A_t (active count) after gather
};

// =============================================================================
//  HOST: connectome construction (exponential-distance rule over a uniform grid)
//  Fills host-side CSR + positions + inhibitory mask. Returns synapse count M.
// =============================================================================
long build_connectome_host(
    int N, unsigned seed,
    std::vector<float>& px, std::vector<float>& py, std::vector<float>& pz,
    std::vector<uint8_t>& is_inh,
    std::vector<int>& row_ptr, std::vector<int>& col_idx,
    std::vector<float>& weight, std::vector<uint8_t>& delay_bin);

// =============================================================================
//  DEVICE KERNELS (the contract — implemented in sim.cu)
// =============================================================================
// (k_init_rng removed 2026-07-27 — there is no persistent RNG state left to initialise.)

// Read arriving current, add noise, apply gain, integrate Izhikevich, detect
// spikes, update traces + rate, compact fired neurons. One thread per neuron.
// `seed` is the run seed: the external-drive RNG is counter-based and its state is
// regenerated per call from (seed, neuron_id, step) rather than stored per neuron.
__global__ void k_gather_integrate(
    NeuronState s, DelayRing ring, SpikeList spikes,
    int N, int step, float dt_ms,
    float nu_ext_hz, float w_ext, float trace_decay, float rate_decay,
    unsigned seed);

// One thread per FIRED neuron (grid sized for N; threads past *spikes.count return).
// Scatters weighted current into the delay ring and applies forward-only iSTDP.
__global__ void k_scatter(
    NeuronState s, Connectome c, DelayRing ring, SpikeList spikes,
    int N, int step, float istdp_eta, float istdp_alpha, float w_max);

// Slow homeostatic controller: nudge per-neuron input gain toward target rate.
__global__ void k_homeostatic_gain(
    NeuronState s, int N, float dt_ms, float rho0_hz,
    float gain_eta, float gain_min, float gain_max);

// =============================================================================
//  HOST: criticality probe (implemented in sim.cu) — the acceptance instrument
// =============================================================================
// Branching ratio estimate m-hat = slope of A[t+1] vs A[t] over a window.
// (Live/cheap; subsampling-biased. The rigorous MR estimator is in tools/analyze.py.)
double mhat_regression(const int* A, int len);

// Detect avalanches from the activity timeseries (threshold = active-bin, thr=0).
// Appends avalanche sizes (sum of A over the active run) and durations.
void detect_avalanches(const int* A, int len, int thr,
                       std::vector<long>& sizes, std::vector<int>& durs);
