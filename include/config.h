#pragma once
// =============================================================================
//  PHASE-0 CONFIG · "THE LIVING CELL"
//  Every tunable lives here. Change values here, never inside kernels.
//  The values marked [KNOB] are the ones you sweep to find criticality (Gate B).
//
//  SWEEP OVERRIDE: the [KNOB] macros are #ifndef-guarded so the sweep harness
//  (tools/sweep.ps1) can override them at compile time with nvcc -D, e.g.
//  `nvcc -DW_EXC_INIT=1.5f -DW_EXT=3.0f ...`. Defaults below are UNCHANGED when
//  no -D is passed, so the canonical CMake build stays byte-for-byte identical.
// =============================================================================

// ---- Population -------------------------------------------------------------
#define N_NEURONS        200000     // Phase-0 scale (100k-300k). Memory is cheap;
                                    // the dynamics is what's on trial, not the size.
#define FRAC_INHIB       0.20f      // 80/20 excitatory/inhibitory (cortical)

// ---- Geometry (a real 3D volume, microns) -----------------------------------
// Keep VOL ~ 20-25 * LAMBDA so wiring stays LOCAL and host generation stays cheap
// (candidate count per neuron ~ N * (4*LAMBDA/VOL)^3).
#define VOL_SIZE_UM      3500.0f    // cube side
#ifndef LAMBDA_UM
#define LAMBDA_UM        150.0f     // exponential distance-rule length constant  [KNOB]
#endif
#define CONN_CUTOFF_UM   (4.0f*LAMBDA_UM)   // beyond this exp() is negligible; = grid cell
#ifndef TARGET_OUTDEG
#define TARGET_OUTDEG    100        // ~ average out-degree K                     [KNOB]
#endif

// ---- Hierarchical-modular structure (3D "brain" wiring; MODULE §1 amendment) --
// Neurons cluster into MOD_GRID^3 columns nested into AREA_GRID^3 areas; wiring is
// the two-factor rule  exp(-d/lambda) * module_bias.  Distance-only = a random
// geometric graph (no Griffiths phase); modularity buys an extended critical band.
// MOD_GRID=1 disables modules (reverts to ~distance-only, for A/B).
#ifndef MOD_GRID
#define MOD_GRID         8          // leaf modules (columns) per side -> MOD_GRID^3  [KNOB]
#endif
#ifndef AREA_GRID
#define AREA_GRID        2          // areas per side (coarse level of the hierarchy) [KNOB]
#endif
#ifndef MOD_GAP
#define MOD_GAP          0.12f      // spatial gap fraction between columns (separability)
#endif
#ifndef W_SAME_AREA
#define W_SAME_AREA      0.30f      // wiring bias: same area, different column        [KNOB]
#endif
#ifndef W_DIFF_AREA
#define W_DIFF_AREA      0.06f      // wiring bias: different area (long-range)         [KNOB]
#endif

// ---- Time -------------------------------------------------------------------
#define DT_MS            0.1f       // 0.1 ms => 10,000 steps/s == real time
// Run length. Guarded (default UNCHANGED) because Session 4 showed the SLOW controller cannot
// converge inside 20 s: at a 0.7 Hz rate error GAIN_ETA moves gain by only ~0.007/s, i.e. ~0.14
// over an entire default run. Testing Gate B's "held by >=2 controllers on separated timescales"
// requires a window long enough for the slow one to settle.
#ifndef N_STEPS
#define N_STEPS          200000     // 20 s of biological time                     [KNOB]
#endif

// ---- Conduction / delays ----------------------------------------------------
#define COND_VEL_UM_PER_MS 300.0f   // ~0.3 m/s local axon
#define N_DELAY_BINS     32         // ring-buffer depth D (uint8 delays, 1..D-1)
#define MIN_DELAY_STEPS  1          // spikes never deliver same-step (ring safety)

// ---- Synaptic weights (arbitrary current units — tune to reach the edge) -----
#ifndef W_EXC_INIT
#define W_EXC_INIT       0.5f       // initial excitatory magnitude               [KNOB]
#endif
#ifndef W_INH_INIT
#define W_INH_INIT       2.0f       // initial inhibitory magnitude (stronger)    [KNOB]
#endif
#ifndef W_MAX
#define W_MAX            8.0f       // clamp on plastic inhibitory weights         [KNOB]
#endif

// ---- Background drive (Poisson noise floor so the network "breathes") --------
#ifndef NU_EXT_HZ
#define NU_EXT_HZ        3.0f       // per-neuron external Poisson rate            [KNOB]
#endif
#ifndef W_EXT
#define W_EXT            1.2f       // external synapse current                    [KNOB]
#endif

// ---- Homeostasis (the self-sustaining machinery — the actual physics) --------
#ifndef RHO0_HZ
#define RHO0_HZ          3.0f       // TARGET firing rate. Everything chases this. [KNOB]
#endif
#ifndef ISTDP_ETA
#define ISTDP_ETA        0.005f     // inhibitory-STDP rate (fast controller)      [KNOB]
#endif
#define TAU_STDP_MS      20.0f      // eligibility-trace time constant
#ifndef GAIN_ETA
#define GAIN_ETA         1.0e-4f    // slow homeostatic input-gain rate (slow ctl) [KNOB]
#endif
// Slow-controller authority range. These were plain #defines and therefore NOT sweepable;
// Session 4 found the network pinned at GAIN_MIN on 88-100% of neurons at every operating
// point in the bracket history, i.e. the slow controller had no authority and Gate B's
// "held by >=2 controllers on separated timescales" was not actually satisfied. Guarded so
// the range itself can be swept. Defaults UNCHANGED.
#ifndef GAIN_MIN
#define GAIN_MIN         0.5f       // floor on homeostatic input gain              [KNOB]
#endif
#ifndef GAIN_MAX
#define GAIN_MAX         2.0f       // ceiling on homeostatic input gain            [KNOB]
#endif
#define GAIN_EVERY       100        // apply slow controller every N steps (10 ms)
#define RATE_TAU_MS      1000.0f    // low-pass window for per-neuron rate estimate

// ---- Short-term depression (the SOC organizer; blueprint §2.5 L4, Levina 2007) --
// Per-presynaptic-neuron synaptic efficacy D in (0,1]: releases a fraction STD_U per
// spike, recovers over TAU_REC_MS. deplete -> quiesce -> recover self-tunes avalanches
// to criticality WITHOUT fine-tuning. STD_U=0 disables it. SOC needs slow-drive/
// fast-cascade timescale separation -- use with LOW drive, never strong fast drive.
#ifndef STD_U
#define STD_U            0.2f       // release fraction per spike (0 disables STD)     [KNOB]
#endif
#ifndef TAU_REC_MS
#define TAU_REC_MS       400.0f     // recovery time constant, ms (sets avalanche IEI) [KNOB]
#endif

// ---- Synaptic summation + firing barrier (base-branching fixes; web-Claude consult) --
// Instantaneous delta synapses give NO temporal summation -> a lone spike can't reach
// threshold -> base branching << 1 (and STD only tunes DOWN, so it can't rescue that).
// TAU_SYN_MS decays arrived current over ms (real PSCs), widening the coincidence window
// ~50x so inputs accumulate. V_RESET_OFF/D_SCALE lower the reset+adaptation barrier so
// EPSPs propagate (keep neurons quiet at rest). Goal: a lone seed -> a cascade (m>1).
#ifndef TAU_SYN_MS
#define TAU_SYN_MS       5.0f       // synaptic current decay time constant, ms         [KNOB]
#endif
#ifndef V_RESET_OFF
#define V_RESET_OFF      0.0f       // added to Izhikevich reset c (less negative = lower) [KNOB]
#endif
#ifndef D_SCALE
#define D_SCALE          1.0f       // scales adaptation jump d (smaller = lower barrier)  [KNOB]
#endif

// ---- Numerical guards (invariant I4) ----------------------------------------
// Explicit range clamps, NOT isfinite(): the sweep harness builds with
// -use_fast_math, which permits nvcc to assume finite operands and constant-fold
// isfinite() to `true`, silently deleting the guard (QC review 2026-07-07, H1).
// These bounds sit far outside legal Izhikevich dynamics (v rests at -70, fires at
// +30; u runs roughly [-30,+60]) so they never touch healthy state -- they only
// catch divergence. NOT knobs: do not sweep these.
#define V_FLOOR_MV      -150.0f     // NaN/blow-up floor for membrane potential
#define U_FLOOR         -400.0f     // recovery-variable sanity range (QC H2)
#define U_CEIL           400.0f

// ---- Probe / criticality ----------------------------------------------------
#define PROBE_WINDOW     4000       // steps used for the live m-hat regression print
#define PRINT_EVERY      4000       // progress cadence
#define CTRL_PROBE_EVERY (N_STEPS/4)  // controller-authority readout cadence (main.cu)

// ---- Spike dump (for the offline firing animation; tools/animate.py) ---------
// When DUMP_LEN>0 the sim records every spike (step, neuron_id) over the window
// [DUMP_START, DUMP_START+DUMP_LEN) to spikes_window.csv. 0 = off (zero overhead).
#ifndef DUMP_START
#define DUMP_START       50000      // window start step
#endif
#ifndef DUMP_LEN
#define DUMP_LEN         0          // window length in steps (0 = off)               [KNOB]
#endif
