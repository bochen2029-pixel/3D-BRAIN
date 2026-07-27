# PROPOSED CONTRACT CHANGES — `brain.h` + `MODULE.md` §6 — **FOR REVIEW, NOT APPLIED**

- **Date:** 2026-07-26 · **Author:** Session 4 · **Status:** awaiting operator approval.
- **Nothing in `brain.h` or `MODULE.md` §6 has been changed.** This file is the diff + rationale.
- Per `CLAUDE.md`: a contract change means **STOP, show diff + rationale, get approval**.
- Both arose from the per-kernel profile. Change **A** is a performance change supported by a
  measurement taken specifically to price it; change **B** is a factual correction to a claim the
  profile refuted.

---

## A. `brain.h` — remove the stored per-neuron RNG state

### A.1 The diff

```diff
 struct NeuronState {
     float*  v;        // membrane potential (mV)
     float*  u;        // Izhikevich recovery
     ...
     float*  px;       // geometry, kept for render + delay derivation + analysis
     float*  py;
     float*  pz;
-    curandStatePhilox4_32_10_t* rng;
 };
```

```diff
-__global__ void k_init_rng(curandStatePhilox4_32_10_t* rng, int N, unsigned seed);
-
 // Read arriving current, add noise, apply gain, integrate Izhikevich, detect
 // spikes, update traces + rate, compact fired neurons. One thread per neuron.
+// `seed` is the run seed: the external-drive RNG is counter-based and its state is
+// regenerated per call from (seed, neuron_id, step) rather than stored per neuron.
 __global__ void k_gather_integrate(
     NeuronState s, DelayRing ring, SpikeList spikes,
     int N, int step, float dt_ms,
-    float nu_ext_hz, float w_ext, float trace_decay, float rate_decay);
+    float nu_ext_hz, float w_ext, float trace_decay, float rate_decay,
+    unsigned seed);
```

Call-site change in `sim.cu` (already implemented behind `RNG_STATELESS`, currently using a
literal seed because the probe may not change the signature):

```diff
-    curandStatePhilox4_32_10_t st = s.rng[i];
     float mean = nu_ext_hz * dt_ms * 0.001f;
-    unsigned n_ext = curand_poisson(&st, mean);
-    s.rng[i] = st;
+    curandStatePhilox4_32_10_t st;
+    curand_init(seed, (unsigned long long)i, (unsigned long long)step, &st);
+    unsigned n_ext = curand_poisson(&st, mean);
```

### A.2 Why — the measurement, and what it does *not* show

`curandStatePhilox4_32_10_t` is ~64 B and is **read and written every step for every neuron** —
~25.6 MB/step of traffic at N=200 k, plausibly the largest single memory term in the gather.
Philox is *counter-based* (Random123): its whole design point is that state need not be stored.

Measured at the certified operating point, `BRAIN_PROFILE=400`:

| | gather µs/step | wall steps/s |
|---|---|---|
| stored state (contract) | **68.5** | 9 514 |
| stateless (proposed) | **47.7** | 15 210 |

**The honest figure is the gather, −30 %.** The gather is activity-independent (all N neurons
every step), so it is a clean comparison. **The wall-clock 9 514 → 15 210 is NOT a clean 1.6×
speedup and must not be quoted as one:** the probe uses a different RNG stream, so the two runs
sat at different activity levels (scatter 6 460 vs 3 112 edges/step) and the lighter scatter
flatters the stateless run. Holding scatter fixed, a 30 % gather saving is
`122.3 → 101.5 µs/step` ≈ **1.20× overall** at this operating point.

Secondary benefit: **12.8 MB of VRAM** freed at N=200 k — and this scales, ~256 MB at the
blueprint's 4 M-neuron target, against a budget where synapse storage is the binding term.

### A.3 Risks, and why each is acceptable

- **NFR-determinism (§6) is preserved, arguably strengthened.** A fixed `seed` still fixes the
  whole stream, and `(seed, i, step)` addressing makes each neuron's draw independent of *how many
  draws were previously consumed* — removing an ordering dependence the stored-state version has.
- **Per-call `curand_init` cost.** For Philox this is key setup plus a counter store, not the long
  warm-up XORWOW needs. The measurement settles it: 30 % *faster* despite initialising every call.
- **Statistical quality.** Distinct `subsequence` per neuron and `offset` per step is the standard
  Random123 usage; streams cannot overlap. `curand_poisson` at λ≈5e-4 consumes only a couple of
  words via Knuth's method, well inside one counter block.
- **Blast radius.** `k_init_rng` disappears from the contract; `main.cu` drops its allocation and
  launch. `dcopy`/`dmalloc` of `s.rng` goes. No other kernel touches `rng`.
- **What would falsify the benefit:** re-measuring at a *dense* operating point, where the scatter
  dominates and a 30 % gather saving is worth much less. Recommend re-measuring at target scale
  before this is treated as a scaling win rather than a Phase-0 tidy-up.

---

## B. `MODULE.md` §6 — the binding constraint is regime-dependent

### B.1 The diff

```diff
-- **NFR-binding-constraint (validate):** the hot path is the **scattered atomic RMW**
-  into the delay ring — the same term FINAL_BLUEPRINT names as the real ceiling.
-  Phase 0 does it naive (un-Morton'd) on purpose; measuring it here sets the
-  baseline Morton must beat later.
+- **NFR-binding-constraint (MEASURED 2026-07-26 — the constraint is REGIME-DEPENDENT):**
+  FINAL_BLUEPRINT names the **scattered atomic RMW** into the delay ring as the real ceiling.
+  That holds only when firing is DENSE. At the certified sparse operating point
+  (**0.043 % of N fires per step**) the profile reads **gather 54 %, scatter 40 %, gain 6 %**:
+  the scatter touches ~8 600 edges while the **gather sweeps all N every step**, so the
+  **gather binds**. The seizing control, firing 9.5 % of N per step (~220× the edge traffic),
+  is the regime where the scatter binds. Report the `BRAIN_PROFILE` breakdown, not just
+  steps/s, and state which regime a perf claim was measured in.
+  **Consequence for Phase 2:** Morton reordering optimises *scatter* locality, so its ceiling
+  at the certified point is **1.67× even if it made the scatter free**. Re-measure this
+  breakdown at target scale before committing to Morton as the scaling fix.
```

### B.2 Why

This is a correction of fact, not a preference. `MODULE.md` §6 currently asserts the scatter is
the hot path and instructs Phase 0 to measure it as the baseline Morton must beat. Phase 0 has now
measured it, and at the operating point Phase 0 actually certified, **the assertion is false** —
which changes what the Phase-2 optimisation should target. Leaving the text as-is would send Phase
2 at the wrong kernel with the contract's authority behind it.

Note this does **not** contradict the blueprint so much as scope it: the blueprint's bandwidth
arithmetic assumes millions of neurons at higher rates, where edge traffic dominates. The
disagreement is about *this* regime at *this* scale, which is exactly what §6 asked Phase 0 to
find out.

---

## C. What I am not asking for

- Neither change is required for Gate B. **A** is a ~1.2× performance improvement and a VRAM
  saving; **B** is documentation accuracy. The certified point stands either way.
- I have **not** implemented Morton (fenced to Phase 2 by `CLAUDE.md`) and am not proposing to.
- The `RNG_STATELESS` probe in `sim.cu`/`config.h` is **defaulted off** and is timing-only; it
  should be deleted or promoted depending on the decision on **A**.
- If only one is approved, **B** is the more important: a wrong claim in the contract propagates,
  whereas a missed 1.2× does not.
