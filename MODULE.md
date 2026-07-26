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
4. **I4 — Numerical guard.** Izhikevich integrates in two half-steps; `v` is clamped to a
   legal range **before** the `u` update, and `u` is clamped too. The quadratic must never
   emit NaN/Inf into state, **and a divergent `v` must never contaminate `u`.**
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

"Watchable" is not the bar; **provably alive** is. A run PASSES iff all seven hold,
auto-verified offline (`tools/analyze.py` + `tools/admiss.py` + `tools/airegime.py`) —
never eyeballed.

**Frame (this is load-bearing).** Gate B certifies the **reverberating / sustained**
regime (Wilting–Priesemann): a continuously-active, cortex-like network held slightly
subcritical. It does **not** certify the absorbing-state transition (Beggs–Plenz), whose
silence-separated avalanche statistics are *undefined* for a network that is never silent.
The two are opposite sides of a phase transition and cannot both be required. See §5.1.

- [ ] **B1 — Near-critical.** `m̂ ≈ 0.98` via the MR estimator (multistep, edge-normalised
      high-pass detrend, offset-exponential fit `r_k = b·m^k + c`, liveness-gated,
      b-significance guarded), i.e. `0.9 < m̂ < 1.02`, measured at the generation scale.
- [ ] **B2 — Scale-invariant.** `m̂` FLAT across bin widths spanning the generation scale
      (bins 3–10 ≈ 0.3–1 ms): spread **< 0.03**. A pure `m^b` decay means there is no
      scale-invariant regime and fails, however good the single-bin value.
- [ ] **B3 — Neither seizing nor the drive floor.** Population `Fano = var(A)/mean(A)` in
      **2–20**. Fano ≈ 1 with `m̂ = 0` at every bin width is the Poisson drive floor (no
      recurrence at all); Fano ≫ 100 is synchronized bursting. **`m̂` alone cannot separate
      reverberating from seizing — both read ≈ 0.98 at the generation scale. Fano is the
      discriminator.** Also require 0 % silent neurons and `max(A)/N` well under 1 %.
- [ ] **B4 — Asynchronous.** Mean pairwise spike-count correlation (10 ms bins) `|r| < 0.05`,
      reported **against the finite-sample noise floor `1/√(nbins−1)`** — with a few hundred
      bins the *spread* of `r` is ~0.05 for independent trains, so only the mean is
      informative. Structured local correlation (higher within-column than distant) is
      expected and welcome; it is the modular connectome showing through.
- [ ] **B5 — Irregular.** `CV_ISI` median in `[0.8, 1.2]` with a **majority of excitatory
      neurons inside `[0.7, 1.3]`**, and per-neuron Fano at 100 ms ≈ 1. Biological
      asynchronous-irregular firing — not lockstep, and not clockwork. (Promoted from
      "add in Phase 0.5" to a core clause: a network of out-of-phase metronomes would pass
      B1–B3 while being the opposite of cortex.)
- [ ] **B6 — Self-sustaining on RECURRENCE.** Activity neither dies (`m̂→0`) nor saturates
      (`m̂>1`) for the full run, **and survives a drive knockdown**: with the external
      Poisson rate cut ≥10×, the point stays in-band, with recurrent input ≫ external
      (report the recurrent fraction). *"Alive while strongly driven" is not self-sustaining* —
      the drive floor was alive for 20 s at every one of 52 logged operating points.
- [ ] **B7 — Held by ≥2 controllers on separated timescales.** At the end of the run both
      iSTDP (fast) and input-gain (slow) are **off their rails and stationary**: gain rail
      occupancy **< 20 %**, mean inhibitory weight comfortably below `W_MAX`, and the measured
      rate on the `RHO0` target. **A point held by one saturated controller is *tuned*, not
      self-organised, and fails.** Every run must print the controller-authority readout.

- [ ] **B8 — Robust to perturbation.** Under a **sustained ±2 % perturbation of the excitatory
      drive, applied to the inhibitory population only**, the point must still satisfy **B1–B6**
      at steady state. **A regime that exists only at exactly one E/I operating point is *tuned*,
      not stable** — and B1–B7 structurally cannot see the difference, because every one of them
      is a time-average of a single *unperturbed* run. Magnitude is expressed as a fraction of the
      measured excitatory drive (the `[ctrl]` readout), so the clause is scale-free across
      operating points; the sign must be tested in **both** directions.
      *Deliberately defined by re-applying B1–B6 rather than by a new depth-of-dip threshold: the
      measured dip distribution is continuous, so any such threshold decides the verdict by where
      it is placed. Added 2026-07-26 after the perturbation probe found that an injection of 2 % of
      the excitatory drive onto I collapsed the excitatory population below a tenth of baseline in
      26 % of trials at a point that had passed B1–B7 — i.e. the battery certified a fragile network.*
      **KNOWN LIMITATION, recorded rather than hidden: B8 is a STEADY-STATE test and does not
      capture the transient behaviour that motivated it.** A *sustained* perturbation is absorbed
      by the homeostats over tens of seconds (`b8_plus`/`b8_minus` pass every clause); a *sudden*
      200 ms pulse of the same magnitude still collapses the excitatory population below a tenth
      of baseline in ~26 % of trials, recovering afterwards. Whether transient collapse-and-recover
      should itself be disqualifying is **OPEN** — "never dies" plausibly means never *permanently*
      dies, and the network always recovered. A transient clause would need the depth threshold
      this one was written to avoid, so it is not adopted by default.

**Run length.** B6 and B7 cannot be assessed in 20 s. At a 0.7 Hz rate error the slow
controller moves `gain` by only ~0.007/s — ~0.14 over an entire default run — so a 20 s
window measures where the startup transient dumped the controllers, not their equilibrium.
**Certify on ≥100 s (`N_STEPS` ≥ 1e6)** with the controller trace reported at intervals.

**Seeds.** A pass requires the battery to hold on **≥3 independent seeds**. One seed
measures a realisation, not a regime; the connectome, the Izhikevich heterogeneity and the
Poisson stream all derive from it.

Failure of Gate B is **information, not defeat**: it says the *dynamics* need work
before any substrate does — exactly the risk the phase exists to surface early.

### 5.1 Retired: the avalanche clauses, and what that costs

The original battery required scale-free avalanches (`τ ≈ 1.5`, MLE+KS, `KS < 0.1`) and the
crackling relation. Both are retired. On the record:

**They are inapplicable, not merely inconvenient.** An avalanche (§2) is a maximal run of
active bins, which presupposes silence between them. The reverberating regime is never
silent — measured **IEI = 1 at every operating point in the project's history** — so a run
collapses to a single avalanche and `τ` becomes an artifact of the binning threshold's
fragmenting and merging, not a property of the dynamics. This was confirmed empirically, not
assumed: the `τ ≈ 1.5` that once read as a pass was refuted by `tools/plfit.py` as an overlap
confound (Session 1), and `plfit` later rejected a clean power law at the best candidate
(`x_we3`, KS = 0.31, systematic mid-tail curvature). Requiring silence-separated avalanches
**and** self-sustaining activity demands both sides of a phase transition simultaneously.

**What it costs, plainly.** Clean power-law avalanche statistics are the single strongest
piece of criticality evidence, and dropping them makes this battery **weaker on that axis**.
B2 recovers part of the force — scale-invariance of `m̂` across bin widths *is* a scale-free
requirement, applied to the autocorrelation rather than to event sizes — but it is a weaker
claim than a fitted `τ` with `KS < 0.1`. That is an honest reduction in evidential strength
and must not be presented as anything else. **Whether the sustained frame still owes some
power-law statement — e.g. the distribution of deviations above the mean rate, or spatial
cluster sizes at a threshold — is recorded as OPEN**, not settled by this amendment.

**Why the battery is nonetheless harder in aggregate.** Seven clauses replace five, and
**B2–B7 were all failed by every operating point in the project's history up to Session 4**
(the Fano band was empty, correlations were ≥ 0.3, CV_ISI was ≈ 3.5, the drive floor collapsed
under knockdown, and both controllers were railed at every point ever logged). The one removed
clause was unmeasurable in this regime; the six added ones are measurable, instrumented, and
were unmet for the project's entire history.

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
- **The decisive knobs turned out to be CONTROLLER AUTHORITY, not weights.** Of the nine knobs
  the search nominally covered, only four were ever varied across 32 logged sweep rows;
  `ISTDP_ETA`, `GAIN_ETA`, `LAMBDA_UM` and `TARGET_OUTDEG` were constant throughout, and
  `GAIN_MIN`/`GAIN_MAX`/`N_STEPS` were not even `#ifndef`-guarded. The reverberating regime was
  unreachable *only* because both homeostats were saturated — inhibitory weight pinned at
  `W_MAX`, gain railed at `GAIN_MIN` on 99.9 % of neurons — which no run output could reveal.
  **Every run must therefore report controller rail occupancy, so saturation can never hide again.**
  Full knob list: `W_EXC_INIT, W_INH_INIT, W_MAX, NU_EXT_HZ, W_EXT, RHO0_HZ, ISTDP_ETA, GAIN_ETA,
  GAIN_MIN, GAIN_MAX, N_STEPS, LAMBDA_UM, TARGET_OUTDEG, STD_U, TAU_REC_MS`.
