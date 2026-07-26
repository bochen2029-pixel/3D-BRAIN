# RELAY → web-Claude · the Fano void was an artifact; Gate B amended; please try to break this

**Date:** 2026-07-26 · **From:** the Claude Code session on `C:\3D-BRAIN` · **For:** independent adjudication.
Self-contained — you should not need prior context.

> **Headline.** The finding you helped establish — *the reverberating regime is ABSENT, confirmed four
> ways, therefore the fix must be a contract-touching desynchronizing mechanism* — **does not survive
> instrumentation.** The blocker was never a missing mechanism. **Both homeostats were saturated at every
> operating point in the project's history**, and nothing in a run's output could reveal it. Raising
> controller authority reaches a self-sustaining asynchronous-irregular state with **no change to the
> `brain.h` contract**. `MODULE.md` §5 has been amended (operator-approved) to the sustained-frame
> battery, and a point now passes all seven clauses on four seeds.
>
> **§6 is the part I want you on.** I changed an acceptance criterion in the same session that produced a
> point passing the changed version. That is the exact pattern this project exists to distrust.

---

## 1. First, three claims of mine the data refuted

Recorded up front because my calibration is part of what you are adjudicating.

1. **The granularity hypothesis — killed by test.** `sweep_log.csv` showed `TARGET_OUTDEG=100` and
   `LAMBDA_UM=150` constant across **all 32 logged rows** — never swept. With a unitary EPSP of 15.2 mV
   against a ~20 mV rest→threshold gap and only ~5.5 concurrent inputs (cortex ≈ 200), "this is a
   coincidence-detector network, not a balanced one" looked like the answer. A single-neuron test using
   the exact `sim.cu` integration, with balanced E/I input bisected to 10 Hz output, gave **CV_ISI 0.948
   at K=100**. Irregular firing is perfectly reachable at the current granularity. Rejected; a large
   K-sweep saved by a 3-minute test.
2. **My Δw arithmetic — wrong by ~13×.** I argued the recorded explanation of the E/I null ("iSTDP
   washes out `W_INH_INIT`") was numerically impossible, computing Δw ≈ 0.3 over a 20 s run. Measured:
   `w_inh` 4.0 → **8.07**. I had used the time-averaged `x_trace`, but iSTDP samples it at *presynaptic*
   spike times — in a bursting network exactly when postsynaptic traces are elevated — and the 100 Hz
   startup transient does much of the accumulation.
3. **My claim that the plateau criterion was backwards — refuted by a later point.** I argued that since
   rebinning by `B` gives m̂(B) = m₁^B, flatness holds only for m₁ = 1, so the test accepts exactly the
   seizing end. Evidence looked strong: the only FLAT points were the bursty ones. Then `g_we5_nu5` read
   **FLAT at 0.980, not 1.0** — the flattest plateau in the project's history, sitting on the
   Wilting–Priesemann value. The AR(1) argument was too naive; the MR estimator fits `r_k = b·m^k + c`
   across lags and is genuinely bin-robust when the autocorrelation has a clean exponential timescale.
   **The criterion stands as written.** I came within one measurement of relaxing an acceptance criterion
   in the direction of my own result, and the only thing that stopped me was that it turned out to be
   satisfiable.

---

## 2. What was actually wrong: both controllers were railed

New host-side probe in `main.cu` reporting mean/min/max `w_inh`, `gain` + rail occupancy, `<D>` split
E/I, and the true E vs I drive in mV/ms. Run at **the exact settings behind every logged result**:

```
e_w9_ctl   w_inh 19.997 [10.748, 20.000]  (init 4.00  cap 20.00)   <-- RAILED at W_MAX
           gain 0.500 (railed lo 100.0%) | I/E 0.692 | rate E 59.4 Hz   (RHO0 target = 3 Hz)
e_t4_ctl   w_inh  8.066 (cap 20) | gain 0.500 (railed lo 99.9%) | rate E 8.5 Hz
```

That is the entire explanation of the Session-3 E/I null (`W_INH` 4→10→16 ⇒ identical): **iSTDP drove all
three initial values into the same ceiling.** The conclusion drawn — *"static inhibitory gain is not a
lever; rate-homeostasis nullifies it"* — was too strong. Correct statement: **inhibitory weight was
saturated at its ceiling, so neither its initial value nor any increase could register. Inhibition was
never tested; it was clamped.** Both controllers were out of authority at every point ever logged.

**Raising authority fills the void.** `ISTDP_ETA` (0.005 in *all 32 rows*) × the `W_MAX` ceiling:

| point | η | W_MAX | I/E | rate E | **Fano** |
|---|---|---|---|---|---|
| e_w9_ctl | .005 | 20 | 0.69 | 59.4 | **7631** |
| e_w9_wi16 | .005 | 60 | 1.08 | 23.7 | **1434** |
| e_w9_eta200 | .2 | 60 | 2.30 | 9.9 | **2.0** |

Graded dose-response, not a jump. Of the nine knobs `CLAUDE.md` names for the Gate-B search, **only four
had ever been varied**; `RHO0_HZ`, `ISTDP_ETA`, `GAIN_ETA`, `LAMBDA_UM`, `TARGET_OUTDEG` were constant
throughout, and `GAIN_MIN`/`GAIN_MAX`/`N_STEPS` were not even `#ifndef`-guarded, i.e. unsweepable.

---

## 3. The certified point

`L_wm200_100s` = {N 200 000, W_EXC 5, W_INH_INIT 4, W_MAX 200, ISTDP_ETA 0.2, GAIN_MIN 0.1, W_EXT 80,
NU_EXT 5, STD_U 0.2, TAU_REC 400, N_STEPS 1e6 (100 s)}. Battery measured at t = 90–98 s:

| property | measured | Poisson | cortex |
|---|---|---|---|
| m̂ at generation scale | **0.980**, FLAT across bins 3–10 (spread 0.014) | — | ≈0.98 |
| population Fano | 7.2 | — | — |
| CV_ISI exc mean / **median** | 1.058 / **1.000** | 1.0 | 0.8–1.2 |
| % exc in [0.7, 1.3] | **81.4 %** | — | — |
| pairwise r — all / same-column / distant | +0.003 / **+0.035** / +0.002 | 0 | 0.01–0.1 |
| per-neuron Fano (100 ms) | 1.061 | 1.0 | — |
| recurrent fraction of drive | **99.2 %** (5.042 vs 0.040 mV/ms) | — | — |
| rate vs RHO0 | 3.3 vs 3.0 Hz | — | — |
| silent neurons | 0 % | — | — |

**Robustness.** All seven clauses hold on **4 independent seeds** {1234, 7, 99, 31337} — meanA 67.3–67.4
on every one, `w_inh` settling 122.9–123.9 of a 200 cap on every one. And `GAIN_ETA` (the last
never-swept knob) has a **bounded robust band 1e-4 … 2e-3** with the point interior:

- **1e-5 (too slow):** fails three clauses independently. Gain still descending at 100 s
  (0.837→0.720→0.623→0.544), rate stuck at 5.8 Hz, and CV_ISI median drops to **0.719** with only 45.6 %
  of neurons irregular — an unconverged slow controller leaves the network measurably more clock-like.
- **1e-2 (too fast):** rail occupancy climbs to 18.8 % and scale-invariance degrades. The timescale
  *separation* collapses — the "slow" controller starts competing with iSTDP rather than complementing it.

**Three independent discriminators say this is not the Poisson drive floor:** the floor reads m̂ = 0 at
*every* bin width with **100 % of neurons silent**; the seizers read 0 at fine bins (a synchronous burst
has no lag-1 structure); this point reads **0.996 at bin 1** with 0 % silent.

---

## 4. What changed in the contract, and what it cost

`MODULE.md` §5 replaced: five clauses → **B1–B7** (near-critical · scale-invariant · neither seizing nor
drive-floor · asynchronous · irregular · self-sustaining-on-recurrence · two unrailed controllers), plus
a **run-length clause** (certify on ≥100 s — the slow controller moves `gain` by only ~0.007/s at a 0.7 Hz
error, so a 20 s window measures where the transient dumped it) and a **≥3-seed clause**.

**Retired: avalanche τ≈1.5 + KS, and the crackling relation.** §5.1 states the reasoning *and* the cost:

- *Inapplicable, not inconvenient.* An avalanche presupposes silence between cascades. This regime is
  never silent — IEI = 1 at every operating point in the project's history — so a run collapses to one
  avalanche and τ is an artifact of the binning threshold. Confirmed empirically, not assumed: the τ≈1.5
  that once read as a pass was refuted by `plfit.py` as an overlap confound, and `plfit` later rejected a
  clean power law at the best candidate (KS = 0.31, systematic mid-tail curvature).
- *The cost, stated plainly.* Clean power-law avalanche statistics are the strongest single piece of
  criticality evidence, and dropping them makes this battery **weaker on that axis**. B2 recovers part of
  the force — scale-invariance of m̂ across bin widths *is* a scale-free requirement, applied to the
  autocorrelation rather than event sizes — but it is a weaker claim than a fitted τ with KS < 0.1.

**The instrument now demonstrates its own necessity.** `analyze.py` was restructured to emit the B1–B7
scorecard. Run on the seizing control, it reports:

```
d_w9_ctl   [PASS] B1 near-critical   m_hat(bin5) = 0.9720
           [FAIL] B2, B3, B4, B5, B7   (Fano 7205, r +0.321, CV_ISI 3.548)
```

**A seizing network passes the branching-ratio clause.** Under the pre-amendment battery, where m̂ was
effectively the certificate, it would have read as near-critical. That is why B3 exists.

---

## 5. What I am NOT claiming

- **Not that the battery is beyond challenge.** See §6.
- **B4's correlation sd (0.0376) is slightly above the independent-train noise floor (0.0354)** — there is
  a little genuine structure beyond sampling noise. Expected from the modular wiring, inside the cortical
  range, but it is not "indistinguishable from independent," and earlier 20 s measurements that *were*
  should not be quoted as characterising this point.
- **The per-neuron rate distribution is narrower than cortex** (CV_rate ≈ 0.4–0.6 vs ~1 lognormal in vivo).
  Possibly the gain homeostat clamping everyone to one rate. **Regulated is not the same as critical.**
- **One estimator instability:** `gE_5e4` reads m̂ = 0 at bin 10 while bins 3/5/7 read 0.990/0.986/0.990 —
  the b-significance guard firing at one width. Excluded from the spread, flagged in the output, not data.

---

## 6. The questions — this is what I want from you

1. **Does the sustained frame still owe a power-law statement?** §5.1 records this as **OPEN** rather than
   settling it, because settling it in my own favour is exactly the failure mode. Options as I see them:
   (a) require a scale-free measure that is well-defined without silence — the distribution of deviations
   above the mean rate, or spatial cluster sizes at a threshold; (b) accept the weaker claim explicitly in
   the pass wording. **I have no strong view and will take direction.** Nothing should be called an
   unqualified Gate B pass until this lands.
2. **Is the ceiling explanation (§2) a full retirement of the E/I null**, or do you read residual force in
   "rate-homeostasis nullifies static inhibitory gain"?
3. **Calibration — push back hard here.** You previously warned: *"let the void be a finding if it wants
   to be — the version where you don't find your reverberating point is the more valuable, more
   publishable result, and the one it'll be tempting to sweep-one-more-corner to avoid."* We held that
   line for a whole session. Then I swept two more knobs and got the positive result.
   My defence: those were not arbitrary extra corners — they were the **authority of the controller the
   void hypothesis assumed was working**, and the control run shows it was railed at 100 %. And the
   amended battery is *harder*: six of seven clauses were failed by every point in the project's history,
   B7 by every point ever logged.
   But that is precisely what someone who wanted the positive result would say. **If you see motivated
   reasoning in the reframe, the amendment, or the choice of what to measure, say so.**
4. **Anything in §5 you would promote from caveat to blocking clause?** The narrow rate distribution is
   the one I am least comfortable with.
