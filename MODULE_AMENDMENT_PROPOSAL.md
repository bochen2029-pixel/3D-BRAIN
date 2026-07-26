# PROPOSED CONTRACT AMENDMENT — `MODULE.md` §5 (+ §3 I4, §8) — **FOR REVIEW, NOT APPLIED**

- **Date:** 2026-07-25 · **Author:** Session 4 · **Status:** awaiting operator approval.
- **Nothing in `MODULE.md` has been changed.** This file is the diff + rationale.
- **Why now:** Session 4 produced a point (`L_wm200_100s`) that meets every criterion the project
  has actually been measuring since the Session-3 reframe — but `MODULE.md` §5 still specifies the
  *pre-reframe* battery, which is internally contradictory and partly unmeasurable in this regime.
  There is currently **no coherent written definition of "done."** That, not the physics, is the blocker.

> **Read §C first.** It states what this amendment *costs* in evidential strength. An amendment that
> only lists its own merits is the failure mode this project exists to distrust.

---

## A. The diff

### A1 — §5, replaced in full

```diff
 ## 5. Test Contract — the Acceptance Sub-Battery (Gate B)

-"Watchable" is not the bar; **provably alive** is. A run PASSES iff all hold,
-auto-verified by `tools/analyze.py` (rigorous, offline — not eyeballed):
-
-- [ ] **Near-critical:** `m̂ ≈ 0.98` via the **MR estimator** (multistep, subsampling-
-      corrected), i.e. `0.9 < m̂ < 1.02`.
-- [ ] **Scale-free avalanches:** size exponent `τ ≈ 1.5` fit by **MLE + KS**
-      (Clauset-Shalizi-Newman), `KS < 0.1`. *A raw power law is necessary, NOT
-      sufficient.*
-- [ ] **Crackling relation:** `(τ_t−1)/(τ−1)` matches the measured `⟨S⟩(T)` slope
-      within ~0.3.
-- [ ] **Self-sustaining:** activity neither dies (`m̂→0`, silence) nor saturates
-      (`m̂>1`, seizure) over the full 20 s, held there by ≥2 controllers on
-      separated timescales (iSTDP fast + input-gain slow).
-- [ ] **Irregular & balanced** *(add in Phase 0.5):* `CV_ISI ≈ 1`, low pairwise
-      correlation — biological asynchronous-irregular firing, not lockstep.
+"Watchable" is not the bar; **provably alive** is. A run PASSES iff all seven hold,
+auto-verified offline (`tools/analyze.py` + `tools/admiss.py` + `tools/airegime.py`) —
+never eyeballed.
+
+**Frame (this is load-bearing).** Gate B certifies the **reverberating / sustained**
+regime (Wilting–Priesemann): a continuously-active, cortex-like network held slightly
+subcritical. It does **not** certify the absorbing-state transition (Beggs–Plenz), whose
+silence-separated avalanche statistics are *undefined* for a network that is never silent.
+The two are opposite sides of a phase transition and cannot both be required. See §5.1.
+
+- [ ] **B1 — Near-critical.** `m̂ ≈ 0.98` via the MR estimator (multistep, edge-normalised
+      high-pass detrend, offset-exponential fit `r_k = b·m^k + c`, liveness-gated,
+      b-significance guarded), i.e. `0.9 < m̂ < 1.02`, measured at the generation scale.
+- [ ] **B2 — Scale-invariant.** `m̂` FLAT across bin widths spanning the generation scale
+      (bins 3–10 ≈ 0.3–1 ms): spread **< 0.03**. A pure `m^b` decay means there is no
+      scale-invariant regime and fails, however good the single-bin value.
+- [ ] **B3 — Neither seizing nor the drive floor.** Population `Fano = var(A)/mean(A)` in
+      **2–20**. Fano ≈ 1 with `m̂ = 0` at every bin width is the Poisson drive floor (no
+      recurrence at all); Fano ≫ 100 is synchronized bursting. **`m̂` alone cannot separate
+      reverberating from seizing — both read ≈ 0.98 at the generation scale. Fano is the
+      discriminator.** Also require 0 % silent neurons and `max(A)/N` well under 1 %.
+- [ ] **B4 — Asynchronous.** Mean pairwise spike-count correlation (10 ms bins) `|r| < 0.05`,
+      reported **against the finite-sample noise floor `1/√(nbins−1)`** — with a few hundred
+      bins the *spread* of `r` is ~0.05 for independent trains, so only the mean is
+      informative. Structured local correlation (higher within-column than distant) is
+      expected and welcome; it is the modular connectome showing through.
+- [ ] **B5 — Irregular.** `CV_ISI` median in `[0.8, 1.2]` with a **majority of excitatory
+      neurons inside `[0.7, 1.3]`**, and per-neuron Fano at 100 ms ≈ 1. Biological
+      asynchronous-irregular firing — not lockstep, and not clockwork. (Promoted from
+      "add in Phase 0.5" to a core clause: a network of out-of-phase metronomes would pass
+      B1–B3 while being the opposite of cortex.)
+- [ ] **B6 — Self-sustaining on RECURRENCE.** Activity neither dies (`m̂→0`) nor saturates
+      (`m̂>1`) for the full run, **and survives a drive knockdown**: with the external
+      Poisson rate cut ≥10×, the point stays in-band, with recurrent input ≫ external
+      (report the recurrent fraction). *"Alive while strongly driven" is not self-sustaining* —
+      the drive floor was alive for 20 s at every one of 52 logged operating points.
+- [ ] **B7 — Held by ≥2 controllers on separated timescales.** At the end of the run both
+      iSTDP (fast) and input-gain (slow) are **off their rails and stationary**: gain rail
+      occupancy **< 20 %**, mean inhibitory weight comfortably below `W_MAX`, and the measured
+      rate on the `RHO0` target. **A point held by one saturated controller is *tuned*, not
+      self-organised, and fails.** Every run must print the controller-authority readout.
+
+**Run length.** B6 and B7 cannot be assessed in 20 s. At a 0.7 Hz rate error the slow
+controller moves `gain` by only ~0.007/s — ~0.14 over an entire default run — so a 20 s
+window measures where the startup transient dumped the controllers, not their equilibrium.
+**Certify on ≥100 s (`N_STEPS` ≥ 1e6)** with the controller trace reported at intervals.

 Failure of Gate B is **information, not defeat**: it says the *dynamics* need work
 before any substrate does — exactly the risk the phase exists to surface early.
+
+### 5.1 Retired: the avalanche clauses, and what that costs
+
+The original battery required scale-free avalanches (`τ ≈ 1.5`, MLE+KS, `KS < 0.1`) and the
+crackling relation. Both are retired. On the record:
+
+**They are inapplicable, not merely inconvenient.** An avalanche (§2) is a maximal run of
+active bins, which presupposes silence between them. The reverberating regime is never
+silent — measured **IEI = 1 at every operating point in the project's history** — so a run
+collapses to a single avalanche and `τ` becomes an artifact of the binning threshold's
+fragmenting and merging, not a property of the dynamics. This was confirmed empirically, not
+assumed: the `τ ≈ 1.5` that once read as a pass was refuted by `tools/plfit.py` as an overlap
+confound (Session 1), and `plfit` later rejected a clean power law at the best candidate
+(`x_we3`, KS = 0.31, systematic mid-tail curvature). Requiring silence-separated avalanches
+**and** self-sustaining activity demands both sides of a phase transition simultaneously.
+
+**What it costs, plainly.** Clean power-law avalanche statistics are the single strongest
+piece of criticality evidence, and dropping them makes this battery **weaker on that axis**.
+B2 recovers part of the force — scale-invariance of `m̂` across bin widths *is* a scale-free
+requirement, applied to the autocorrelation rather than to event sizes — but it is a weaker
+claim than a fitted `τ` with `KS < 0.1`. That is an honest reduction in evidential strength
+and must not be presented as anything else.
+
+**Why the battery is nonetheless harder in aggregate.** Seven clauses replace five, and
+**B2–B7 were all failed by every operating point in the project's history up to Session 4**
+(the Fano band was empty, correlations were ≥ 0.3, CV_ISI was ≈ 3.5, the drive floor collapsed
+under knockdown, and both controllers were railed at every point ever logged). The one removed
+clause was unmeasurable in this regime; the six added ones are measurable, instrumented, and
+were unmet for the project's entire history.
```

### A2 — §3, invariant I4 (the guard text now misdescribes the code)

```diff
-4. **I4 — Numerical guard.** Izhikevich integrates in two half-steps; `v` is reset
-   on `isfinite` failure. The quadratic must never emit NaN/Inf into state.
+4. **I4 — Numerical guard.** Izhikevich integrates in two half-steps; `v` is clamped to a
+   legal range **before** the `u` update, and `u` is clamped too. The quadratic must never
+   emit NaN/Inf into state, **and a divergent `v` must never contaminate `u`.**
```

Two reasons. (i) The old wording specified a *mechanism* (`isfinite`) rather than the property,
and that mechanism ran **after** the `u` update — so a diverging `v` corrupted `u`, which had no
guard at all, producing a permanently-firing neuron that silently inflates `A_t` (QC-2026-07-07 H2,
a real defect, fixed in Session 4). (ii) QC H1 — the suspicion that `-use_fast_math` deletes the
`isfinite` guard — was **tested and refuted** (PTX for sm_89/CUDA 13.1 still emits
`abs.ftz.f32` + `setp.geu.ftz.f32` + `selp.f32`); the clamp is kept because it does not depend on
compiler behaviour holding across toolchains, not because `isfinite` was failing.

### A3 — §8, the knob list understates what matters

```diff
 - **Weights & rates (`W_*`, `NU_EXT`, `RHO0`) are the knobs.** Gate B is a *sweep*:
   turn them until `m̂ → 0.98`. Finding that operating point is the whole exercise.
+- **The decisive knobs turned out to be CONTROLLER AUTHORITY, not weights.** Of the nine knobs
+  the search nominally covered, only four were ever varied across 32 logged sweep rows;
+  `ISTDP_ETA`, `GAIN_ETA`, `LAMBDA_UM` and `TARGET_OUTDEG` were constant throughout, and
+  `GAIN_MIN`/`GAIN_MAX`/`N_STEPS` were not even `#ifndef`-guarded. The reverberating regime was
+  unreachable *only* because both homeostats were saturated — inhibitory weight pinned at
+  `W_MAX`, gain railed at `GAIN_MIN` on 99.9 % of neurons — which no run output could reveal.
+  **Every run must therefore report controller rail occupancy, so saturation can never hide again.**
+  Full knob list: `W_EXC_INIT, W_INH_INIT, W_MAX, NU_EXT_HZ, W_EXT, RHO0_HZ, ISTDP_ETA, GAIN_ETA,
+  GAIN_MIN, GAIN_MAX, N_STEPS, LAMBDA_UM, TARGET_OUTDEG, STD_U, TAU_REC_MS`.
```

---

## B. How the current best point scores against the proposed battery

`L_wm200_100s` = {N 200 000, W_EXC 5, W_INH_INIT 4, W_MAX 200, ISTDP_ETA 0.2, GAIN_MIN 0.1,
W_EXT 80, NU_EXT 5, STD_U 0.2, TAU_REC 400, N_STEPS 1e6, seed 1234}

| clause | requirement | measured | |
|---|---|---|---|
| B1 near-critical | 0.9 < m̂ < 1.02 | **0.978–0.992** | ✅ |
| B2 scale-invariant | spread < 0.03 over bins 3–10 | **FLAT (0.014)** | ✅ |
| B3 not seizing / not floor | Fano 2–20, 0 % silent, maxA/N ≪ 1 % | **9.4**, 0 %, 0.09 % | ✅ |
| B4 asynchronous | \|r\| < 0.05 vs noise floor | **+0.0028** (sd 0.0376 vs floor 0.0354); near +0.035, far +0.002 | ✅ |
| B5 irregular | CV_ISI median 0.8–1.2, majority in [0.7,1.3] | **median 1.000**, **81.4 %**, per-neuron Fano 1.061 | ✅ |
| B6 self-sustaining | survives ≥10× drive cut, recurrent ≫ external | 20× cut, **99.2 % recurrent** (5.042 vs 0.040 mV/ms) | ✅ |
| B7 two controllers | both off rails, stationary, rate on target | gain **4.6 %** railed & flat to 3 d.p. over 75 s; w_inh **61 %** of cap, +1.8 % drift; rate **3.3 vs 3.0 Hz** | ✅ |

**Caveats that are not clauses but should be recorded with any pass:**
- Every Session-4 result is **seed 1234**. Seed-robustness is unverified. I would not sign a Gate B
  pass without ≥3 seeds; that is cheap and should be a precondition, not a follow-up.
- `GAIN_ETA` (1.0e-4) is still never-swept. The point may sit in a narrow basin in that direction.
- B4's correlation sd (0.0376) is *slightly above* the independent-train floor (0.0354), i.e. there
  is a little genuine structure beyond sampling noise. That is expected from the modular wiring and
  is inside the cortical range — but it is not "indistinguishable from independent," and the earlier
  20 s measurements that were should not be quoted as if they characterise this point.

---

## C. The objection to this amendment, stated as strongly as I can

**This amendment relaxes the acceptance criterion in the same session that produced a point which
passes the relaxed version.** That is precisely the pattern this project was built to distrust —
"the test was wrong" is what you say when you want the pass. Three things I would want an
independent reviewer to weigh:

1. **The reframe predates the result.** Dropping the avalanche clause was decided in Session 2
   (web-Claude consult #8), argued from the phase diagram, and was *followed immediately by a
   harder, then-failing requirement* — fix the branching estimator so it reads 0 on dead networks.
   That requirement was met before any of this. The amendment writes down a decision already made
   and already paid for; it does not invent one to fit today's data.
2. **The battery gets harder, not easier.** Six of seven clauses were unmet by every point in the
   project's history. If the goal were a cheap pass, B4/B5/B7 would not be in it — B7 in particular
   failed at *every* operating point ever logged, including today's first four candidates.
3. **But point 2 is not a defence of dropping `τ`.** §5.1 concedes the real cost. If a reviewer
   thinks the sustained frame still owes *some* power-law statement, the honest options are
   (a) require a scale-free measure that is well-defined without silence — e.g. the distribution of
   deviations above the mean rate, or spatial cluster sizes at a threshold — or (b) accept a weaker
   claim explicitly, in the pass wording. **I have no strong view and would take direction.**

**My recommendation:** apply A1–A3, add the ≥3-seed precondition to §5, and treat the "does the
sustained frame owe a power-law clause" question as open — it is the one place where I think an
outside read (the web instance, which has been the sharpest check on exactly this failure mode)
should land before anything is called a pass.
