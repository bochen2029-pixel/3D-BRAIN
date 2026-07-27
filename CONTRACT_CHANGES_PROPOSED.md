# CONTRACT CHANGES — proposals and their disposition

Per `CLAUDE.md`, a contract change (`brain.h` / `MODULE.md`) means **STOP, show diff + rationale,
get approval**. This file is the record of each one.

| | change | status |
|---|---|---|
| **A** | `brain.h` — remove the stored per-neuron RNG state | **APPROVED + APPLIED 2026-07-27** |
| **B** | `MODULE.md` §6 — binding constraint is regime-dependent | **APPROVED + APPLIED 2026-07-27** |
| **C** | `MODULE.md` §5 — add **B9**, inhibition-stabilized | **PROPOSED — awaiting approval** |

> **Note on B as applied:** the diff below is what was *proposed*; the text actually applied differs,
> because **A invalidated B's measurement**. Removing the RNG state cut the gather's cost and flipped
> which kernel binds (gather 54 %→35–42 %, scatter 40 %→55–62 %). The applied §6 records both rows.
> The two changes were proposed as independent and were not.

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

## A + B — scope notes recorded at proposal time

- Neither change was required for Gate B. **A** was a performance and VRAM change; **B** was
  documentation accuracy. The certified point stood either way — and was **re-certified** after
  application, since A changes the RNG stream and therefore made every prior result a different
  realisation (B1–B8 pass on 3 seeds + both B8 directions; `run/V_*`).
- Morton was **not** implemented (fenced to Phase 2 by `CLAUDE.md`) and was not proposed.
- The `RNG_STATELESS` probe was deleted on approval, having been promoted into the contract.
- Stated at the time: *"if only one is approved, **B** is the more important — a wrong claim in the
  contract propagates, whereas a missed 1.2× does not."* That held up: B had to be corrected twice
  before it was right, and the wrong version would have sent Phase 2 at the wrong kernel.

---

# C. `MODULE.md` §5 — add **B9: inhibition-stabilized (paradoxical-effect-positive)**

- **Date:** 2026-07-27 · **Status:** awaiting operator approval. **Not applied.**
- Changes A and B in this file were approved and applied on 2026-07-27; this is a new proposal.

## C.1 The diff

```diff
 - [ ] **B8 — Robust to perturbation.** ...
+- [ ] **B9 — Inhibition-stabilized (paradoxical-effect-positive).** Injecting extra *excitatory*
+      current into the *inhibitory* population must make the inhibitory rate **fall**, measured as
+      a paired, trial-averaged response against a zero-injection control, at an amplitude small
+      enough that <10 % of trials lose the excitatory population. Require the drift-corrected
+      inhibitory delta to be negative at **|z| ≥ 2**, with **monotonic** amplitude dependence and a
+      control whose own paired delta is consistent with zero.
+      *This is FINAL_BLUEPRINT §7.4's "paradoxical-effect-positive" — the one clause in the
+      blueprint's battery that can FALSIFY the mechanism claim rather than corroborate the
+      dynamics. B1–B8 are all statistics of an unperturbed or steadily-perturbed run and none of
+      them can distinguish an inhibition-STABILIZED network from a merely inhibition-DOMINATED one.*
```

## C.2 Why, and the measurement

Gate B currently omits a blueprint acceptance clause. The project has claimed an ISN regime
implicitly since the E/I reframe; until 2026-07-27 that claim had never been tested. It now has:

| injection | usable trials | Δ exc (Hz) | Δ inh, drift-corrected (Hz) | z |
|---|---|---|---|---|
| 0 (control) | 195/199 | +0.029 ± 0.049 | +0.020 ± 0.044 | — |
| **0.05 (≈1 % of the excitatory drive onto I)** | **187/199** | −0.481 ± 0.062 | **−0.259 ± 0.069** | **−3.7** |
| 0.15 (≈3 %) | 85/199 | −1.194 ± 0.089 | −0.464 ± 0.087 | −5.3 |

Run `pwsh tools/sweep_isn.ps1` then `python tools/isn.py`. Needs `RATEDUMP_*` (no contract change).

## C.3 Risks and honest limits

- **Amplitude sensitivity is real.** At 0.15, 114/199 trials voided for excitatory collapse — that
  amplitude is partly out of the linear regime. The clause therefore *specifies* a void-rate
  ceiling rather than leaving the amplitude free, otherwise the test can be made to say anything.
- **Cost:** three 100 s runs (~6 min). Comparable to B8.
- **This is a measurement of the certified point, not of every point.** A different operating point
  could be inhibition-dominated without being inhibition-stabilized; that is precisely why the
  clause is worth having.
- **It does not rescue §5.1.** B9 is a mechanism test, not a criticality test. The open question of
  whether the sustained frame owes a power-law statement is untouched by it.

## C.4 If declined

The result stands as a recorded measurement in `SESSION_LOG.md` either way; declining B9 only means
Gate B continues not to cover it. My recommendation is to adopt it — it is the only clause in the
battery capable of falsifying the mechanism story rather than confirming the phenomenology.
