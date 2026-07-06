# MODULE: `brain_phase0` — The Living Cell

> Phase 0 of the Volumetric Brain Engine. The one module whose only job is to
> settle **Gate B** before a single line of RT/Morton/growth code is written:
> *does a truly-3D spiking network come alive, self-sustain at the edge on run 1,
> and can we measure it?* If Gate B fails, no substrate is worth building. If it
> passes, the FINAL_BLUEPRINT substrate exists only to scale a proven-alive thing.

---

## 1. System Intent

Simulate ~10⁵–10⁶ Izhikevich point neurons at real 3D `(x,y,z)` positions, wired
by the exponential-distance rule, self-stabilised at slightly-subcritical dynamics
by two homeostatic controllers, and instrument the result against an automatic
acceptance battery. **No task, no I/O loop, no usefulness** — the deliverable is
*measured self-sustaining criticality* plus an offline 3D view. Sub-ant, alive,
and provable.

Explicit non-goals (deferred to later phases, see §7): RT-core field/growth/render,
Morton reordering, structural plasticity, real-time GL rendering, dendritic units,
Tensor-core anything, multi-GPU.

---

## 2. Ubiquitous Glossary (forbidden synonyms in parentheses)

- **A_t** — active count: number of neurons that fired at step `t`. The single
  observable everything downstream is built from. (not "activity level")
- **m̂ (m-hat)** — branching ratio: expected descendant spikes per spike. Target
  **≈ 0.98** (slightly subcritical). (not "gain", not "criticality index")
- **Edge list (CSR)** — the connectome as `row_ptr/col_idx/weight/delay_bin`,
  **row = presynaptic**. Spikes propagate by *following edges*, never by spatial
  query. (This is the corrected core: **spikes ride edges, not rays**.)
- **Delay ring** — `buf[b*N+j]`: current pending for neuron `j` at the future step
  whose `step % D == b`. Written by scattered atomic add. (not "synapse queue")
- **Avalanche** — maximal run of active bins (`A > 0`); *size* = ΣA over the run.
- **Homeostasis** — the machinery that holds the network at the edge: iSTDP (fast)
  + input-gain control (slow). This *is* the physics of "self-sustaining."

---

## 3. Invariants (must hold in every kernel; violating any is a bug)

1. **I1 — Presynaptic ownership.** A synapse belongs to exactly one source row.
   `weight[e]` is written only by the thread scattering source `i`. ⇒ weight
   updates need **no atomics**; only the delay-ring accumulate is atomic.
2. **I2 — Ring safety.** Every delay ∈ `[1, D-1]`. The slot cleared at step `t`
   (`t%D`) is never written by step `t`'s scatter (min delay ≥ 1) and is refilled
   by steps `t+1 … t+D-1`. No same-slot read/clear/write race.
3. **I3 — Kernel order.** Per tick: `gather → scatter → (gain)`, serialized. Any
   cross-kernel read (e.g. scatter reading `x_trace[j]`) sees the completed writer.
4. **I4 — Numerical guard.** Izhikevich integrates in two half-steps; `v` is reset
   on `isfinite` failure. The quadratic must never emit NaN/Inf into state.
5. **I5 — Conservation of identity.** `A_t` recorded every step equals
   `*spikes.count` after gather; the activity timeseries is lossless.

---

## 4. Contracts (the boundaries — see `include/brain.h`)

Data layout and every kernel signature are frozen in `brain.h`; `.cu` files
conform to it. The boundaries between kernels are **buffer layouts**, not APIs:

| Producer | Buffer (layout) | Consumer |
|---|---|---|
| `k_scatter` (step t-δ) | `DelayRing.buf[b*N+j]` (net current) | `k_gather_integrate` (step t) |
| `k_gather_integrate` | `SpikeList{idx[N], count}` (compacted fired) | `k_scatter` |
| `k_gather_integrate` | `NeuronState.x_trace[N]` (elig. trace) | `k_scatter` (iSTDP) |
| `k_gather_integrate` | `NeuronState.rate[N]` (lowpass rate) | `k_homeostatic_gain` |
| host `build_connectome_host` | CSR `{row_ptr,col_idx,weight,delay_bin}` | all kernels |

Kernel signatures (authoritative in `brain.h`):
`k_init_rng`, `k_gather_integrate`, `k_scatter`, `k_homeostatic_gain`.
Host probe: `mhat_regression`, `detect_avalanches`.

---

## 5. Test Contract — the Acceptance Sub-Battery (Gate B)

"Watchable" is not the bar; **provably alive** is. A run PASSES iff all hold,
auto-verified by `tools/analyze.py` (rigorous, offline — not eyeballed):

- [ ] **Near-critical:** `m̂ ≈ 0.98` via the **MR estimator** (multistep, subsampling-
      corrected), i.e. `0.9 < m̂ < 1.02`.
- [ ] **Scale-free avalanches:** size exponent `τ ≈ 1.5` fit by **MLE + KS**
      (Clauset-Shalizi-Newman), `KS < 0.1`. *A raw power law is necessary, NOT
      sufficient.*
- [ ] **Crackling relation:** `(τ_t−1)/(τ−1)` matches the measured `⟨S⟩(T)` slope
      within ~0.3.
- [ ] **Self-sustaining:** activity neither dies (`m̂→0`, silence) nor saturates
      (`m̂>1`, seizure) over the full 20 s, held there by ≥2 controllers on
      separated timescales (iSTDP fast + input-gain slow).
- [ ] **Irregular & balanced** *(add in Phase 0.5):* `CV_ISI ≈ 1`, low pairwise
      correlation — biological asynchronous-irregular firing, not lockstep.

Failure of Gate B is **information, not defeat**: it says the *dynamics* need work
before any substrate does — exactly the risk the phase exists to surface early.

---

## 6. Non-Functional Requirements

- **NFR-perf:** At N=200k this runs **far past real time** on any RTX (headroom is
  the point). Report `steps/s` and real-time factor every run; ≥10,000 steps/s = RT.
- **NFR-mem:** ≤ ~300 MB VRAM at N=200k (ring `D·N`, CSR `~9B·M`, state `~13 floats·N`).
- **NFR-determinism:** Fixed `seed` ⇒ fixed connectome + Poisson stream ⇒
  reproducible `A_t` (modulo atomic-add float ordering, which perturbs but does not
  destroy the statistics). Needed so the battery is a stable signal.
- **NFR-binding-constraint (validate):** the hot path is the **scattered atomic RMW**
  into the delay ring — the same term FINAL_BLUEPRINT names as the real ceiling.
  Phase 0 does it naive (un-Morton'd) on purpose; measuring it here sets the
  baseline Morton must beat later.

---

## 7. Deliberately NOT Here (and where it goes)

| Deferred | Why not now | Phase |
|---|---|---|
| RT-core field / growth / render | only earns its place once dynamics is proven alive | 2 |
| Morton / space-filling reorder | it's a *scaling* optimisation for a working sim | 2 |
| Real-time CUDA↔GL render | offline point cloud is enough to see Gate B | 1 |
| Structural plasticity (growth) | interacts with criticality — validate stability first | 4 |
| Dendritic / AdEx / Tensor units | criticality is a *network* property; point neurons suffice | 5 |
| Transpose-CSR (acausal STDP) | forward-only iSTDP is cheaper and sufficient for balance | 1+ |

**Rule:** don't scale a corpse. Each deferred item is a wager that only pays out
after Gate B passes.

---

## 8. Decisions (Phase-0 simplifications, on the record)

- **iSTDP is forward-only, single depression term** (`dw ∝ x_post − α`), applied on
  presynaptic inhibitory spikes. Regulates postsynaptic rate → E/I balance without a
  reverse lookup. Full symmetric Vogels rule = Phase 1 (needs transpose CSR).
- **Slow controller = per-neuron input gain**, not literal synaptic scaling — same
  rate-homeostasis effect, forward-only, no reverse lookup. Two controllers on
  separated timescales satisfies the battery.
- **Gain scales recurrent current only**; the Poisson noise floor is ungained so the
  network always has a breath.
- **Live m̂ = OLS slope** (cheap, biased); the **rigorous MR estimator + MLE fit** run
  offline in `analyze.py`. Cheap signal in-sim, honest verdict offline.
- **Weights & rates (`W_*`, `NU_EXT`, `RHO0`) are the knobs.** Gate B is a *sweep*:
  turn them until `m̂ → 0.98`. Finding that operating point is the whole exercise.
