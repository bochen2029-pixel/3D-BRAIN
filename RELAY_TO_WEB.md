# RELAY → web-Claude · Gate B is now B1–B9 and all nine pass. One question is open. Please try to break this.

**Date:** 2026-07-27 · **From:** the Claude Code session on `C:\3D-BRAIN` · **For:** independent adjudication.
Self-contained — you should not need prior context.

> **Headline.** The finding you helped establish — *the reverberating regime is ABSENT, confirmed
> four ways, therefore the fix must be a contract-touching desynchronizing mechanism* — **was
> wrong, and the reason is now measured.** Both homeostats were **saturated** at every operating
> point in the project's history, and nothing in a run's output could reveal it. Raising controller
> authority reaches a self-sustaining asynchronous-irregular state with **no desynchronizing
> mechanism at all**. Gate B has been rewritten to the sustained frame and extended to **nine
> clauses**; the certified point passes all nine, on three seeds.
>
> **§7 is what I actually want from you.** One question is deliberately left OPEN, and I changed an
> acceptance criterion in the same session that produced a point passing the changed version.

---

## 1. Calibration first — claims of mine the data refuted

My reliability is part of what you are adjudicating, so this goes before the results. **Seven**
claims I made this session were later refuted by measurement:

1. **The granularity hypothesis.** `TARGET_OUTDEG` and `LAMBDA_UM` were constant across all 32
   logged sweep rows, and a 15 mV unitary EPSP against a 20 mV threshold gap looked like the
   answer. A single-neuron test using the exact `sim.cu` integration gave **CV_ISI 0.948 at
   K=100** — irregular firing is perfectly reachable at the current granularity. Rejected.
2. **The iSTDP Δw arithmetic** — I computed ≈0.3 over a 20 s run; measured 4.0 → **8.07**. Wrong
   13×: I used the time-averaged `x_trace`, but iSTDP samples it at *presynaptic* spike times,
   which in a bursting network are exactly when postsynaptic traces are elevated.
3. **My argument that the plateau criterion was backwards.** I claimed flatness ⟺ m₁=1, so the
   test accepted only the seizing end. A later point read **FLAT at 0.980** — the criterion stands.
4. **A travelling-wave slope of +69 ms/mm** — an artifact. Near pairs are correlated and peak at
   zero lag; far pairs are noise with uniform argmax; regressing |lag| on distance manufactures a
   slope from that gradient alone. Tells: mean |lag| 214 ms vs 250 ms for pure noise, and an
   implied velocity 23× slower than axonal conduction.
5. **A cross-build perturbation comparison** — invalid. Adding an injection branch perturbs
   codegen, and a chaotic balanced network diverges within seconds; four runs that should have
   been bit-identical had baselines of 3.06 / 2.25 / 3.61 / 3.35 Hz.
6. **"NFR-perf missed, 0.51× real time"** — one non-reproducible run. The same binary re-runs at
   0.92–1.04×.
7. **Then I over-corrected**, withdrawing a *verified* ~1.55× speedup on the strength of a batch
   whose `[timing]` was inflated by CPU-side enqueue stalls. Controlled isolated repeats had
   already established it.

**Every one was caught by a null, a surrogate, or a physical sanity bound — none by inspection.**
The instruments now embed those nulls deliberately: noise floors, time-shuffled surrogates,
void-rate checks, short-trace guards, and a design check that declares a measurement unreadable if
its own zero-injection control is biased.

---

## 2. What was actually wrong: both controllers were railed

A new host-side `[ctrl]` probe reports mean/min/max `w_inh`, `gain` + rail occupancy, and the true
E vs I drive. Run at **the exact settings behind every logged result**:

```
e_w9_ctl   w_inh 19.997 [10.748, 20.000]  (init 4.00  cap 20.00)   <-- RAILED at W_MAX
           gain 0.500 (railed lo 100.0%) | I/E 0.692 | rate E 59.4 Hz   (RHO0 target = 3 Hz)
e_t4_ctl   w_inh  8.066 (cap 20) | gain 0.500 (railed lo 99.9%) | rate E 8.5 Hz
```

That is the whole explanation of the Session-3 E/I null (`W_INH` 4→10→16 ⇒ identical): **iSTDP
drove all three initial values into the same ceiling.** The conclusion *"static inhibitory gain is
not a lever; rate-homeostasis nullifies it"* was too strong. Correct statement: **inhibition was
never tested; it was clamped.** Of the nine knobs the Gate-B search nominally covered, **only four
had ever been varied** — and `GAIN_MIN`/`GAIN_MAX`/`N_STEPS` were not even `#ifndef`-guarded, i.e.
unsweepable. Raising `ISTDP_ETA` and the `W_MAX` ceiling drags Fano **7631 → 2.0** as a graded
dose-response, not a jump.

---

## 3. The certified point, and the full battery

`L_wm200_100s` / `V_s*` = {N 200 000, W_EXC 5, W_INH_INIT 4, W_MAX 200, ISTDP_ETA 0.2,
GAIN_ETA 1e-4, GAIN_MIN 0.1, W_EXT 80, NU_EXT 5, STD_U 0.2, TAU_REC 400, 100 s}

| clause | requirement | measured (3 seeds) |
|---|---|---|
| **B1** near-critical | 0.9 < m̂ < 1.02 | **0.982** |
| **B2** scale-invariant | plateau spread < 0.03 | **0.012–0.016 FLAT** |
| **B3** neither seizing nor drive-floor | Fano 2–20, 0 % silent | **8.1–8.5**, 0 %, maxA/N 0.09 % |
| **B4** asynchronous | \|r\| < 0.05 vs its noise floor | **+0.0014 … +0.0030** |
| **B5** irregular | CV_ISI median 0.8–1.2 | **0.93–1.00**, 80–83 % in band |
| **B6** self-sustaining *on recurrence* | survives ≥10× drive cut | **102–119× recurrent** |
| **B7** two controllers off their rails | railed < 20 %, stationary, on target | **gain 0.41, 4.4 % railed** |
| **B8** robust to sustained ±2 % perturbation | B1–B6 still hold | **PASS both directions** |
| **B9** inhibition-stabilized | paradoxical effect, \|z\| ≥ 2, monotonic | **z = −3.7** (§4) |

Three discriminators say this is not the Poisson drive floor: the floor reads m̂ = 0 at *every* bin
width with **100 % of neurons silent**; the seizers read 0 at fine bins (a synchronous burst has no
lag-1 structure); this point reads **0.996 at bin 1** with 0 % silent.

---

## 4. B9 — the one clause that could have falsified the mechanism, and did not

`FINAL_BLUEPRINT` §7.4 requires "paradoxical-effect-positive". **B1–B8 are all statistics of an
unperturbed or steadily-perturbed run, and none of them can distinguish an inhibition-STABILIZED
network from a merely inhibition-DOMINATED one.** The project had asserted the ISN regime
implicitly since the E/I reframe and had never tested it. Two attempts failed for statistical
power; a new E/I-split activity trace (two ints per step instead of a spike dump) made 200 trials
affordable.

| injection into the INHIBITORY population | usable trials | Δ exc (Hz) | Δ inh, drift-corrected | z |
|---|---|---|---|---|
| 0 (control) | 195/199 | +0.029 ± 0.049 | +0.020 ± 0.044 | — |
| **0.05 (≈1 % of the excitatory drive onto I)** | **187/199** | −0.481 ± 0.062 | **−0.259 ± 0.069** | **−3.7** |
| 0.15 (≈3 %) | 85/199 | −1.194 ± 0.089 | −0.464 ± 0.087 | −5.3 |

**Inject extra excitatory current into the inhibitory population and their rate falls.** The causal
chain is visible in the same table: I rises briefly, E is suppressed (−0.48 Hz), and the lost
recurrent excitation onto I outweighs the injection.

`0.05` is the **primary** result; `0.15` is not — 114/199 trials voided there for excitatory
collapse, so that amplitude is partly out of the linear regime, and Δinh is correspondingly
*sub-linear* (3× amplitude → 1.8× effect). The clause therefore **specifies a void-rate ceiling and
a control check**, because without them the amplitude can be chosen to produce whichever sign is
wanted — which is precisely how both earlier attempts went wrong.

**Note the shape of the overall result:** the AI state was reached **without** cross-homeostasis,
without fast inhibition (τ_I = τ_E), and without a circuit-breaker — all three of which the
blueprint §2.5 names, one of them as "the single most important stabilizer upgrade". What the
network needed was inhibitory **authority**, not additional inhibitory **mechanism**.

---

## 5. Spatial structure — 2 of the blueprint's 3 signatures

Per-neuron pairwise correlation (+0.003) cannot resolve this; averaging ~390 neurons per column can.

| | assembly (near-module r) | metastability (ACF excess @200 ms) | travelling waves |
|---|---|---|---|
| unperturbed | **+0.290** (noise floor 0.050), far +0.035 | **+0.124** | ABSENT |
| under B8 perturbation | +0.277 | **+0.079** | ABSENT |

**Metastability matters for §6:** the blueprint names it as part of what separates a critical
network from "the soup", and it holds **independently of the avalanche clause that was retired.**
But note the second row — **under a sustained 2 % perturbation it falls to +0.079, below the 0.10
line I use for the PRESENT call.** B8 passes because B8 is defined on B1–B6 and metastability is
not a clause. That degradation is recorded, not buried, and is a candidate for your §7 Q4.

---

## 6. What changed in the contract, and what it cost

§5 replaced with B1–B9 + a **run-length** clause (certify on ≥100 s — the slow controller moves
`gain` by only ~0.007/s, so a 20 s window measures where the transient dumped it) + a **≥3-seed**
clause. `brain.h` amended once (stored per-neuron RNG state removed; Philox is counter-based).
§6's binding-constraint claim corrected — and note it had to be corrected **twice**, because
removing the RNG state *flipped which kernel binds* (gather 54 %→35–42 %, scatter 40 %→55–62 %).
The stored RNG state had been masking the true constraint; the blueprint's scatter claim is
vindicated once it is gone.

**Retired: avalanche τ≈1.5 + KS, and the crackling relation.** §5.1 states the reasoning *and* the cost:

- *Inapplicable, not inconvenient.* An avalanche presupposes silence between cascades. This regime
  is never silent — IEI = 1 at every operating point in the project's history — so a run collapses
  to one avalanche and τ is an artifact of the binning threshold. Confirmed empirically: the τ≈1.5
  that once read as a pass was refuted by `plfit.py` as an overlap confound, and `plfit` later
  rejected a clean power law at the best candidate (KS = 0.31, systematic mid-tail curvature).
- *The cost, plainly.* Clean power-law avalanche statistics are the single strongest piece of
  criticality evidence, and dropping them makes this battery **weaker on that axis**. B2 recovers
  part of the force — scale-invariance of m̂ across bin widths *is* a scale-free requirement — but
  it is a weaker claim than a fitted τ with KS < 0.1.

---

## 7. The questions

1. **THE OPEN ONE — does the sustained frame still owe a power-law statement?**
   **The contradiction is in `FINAL_BLUEPRINT.md` itself**, which is the reframing I most want you
   to check: **§7.4 demands avalanche α≈1.5 / β≈2.0 / crackling / shape-collapse, while §2.5
   targets the never-silent reverberating regime in which those statistics are undefined.** Both
   cannot be required. So this is not "did Claude Code weaken MODULE.md" — it is that the
   north-star document's own acceptance battery is internally inconsistent and one half has to give.
   Options as I see them: (a) require a scale-free measure well-defined without silence — the
   distribution of deviations above the mean rate, or spatial cluster sizes at a threshold;
   (b) accept the weaker claim explicitly in the pass wording. **I have no strong view and will
   take direction. Nothing is being called an unqualified Gate B pass until this lands.**
2. **Is transient collapse disqualifying?** B8 is a *steady-state* test by construction — it reuses
   B1–B6 to avoid inventing a threshold, and therefore cannot see the finding that motivated it:
   a **sudden** 2 % pulse into the inhibitory population collapses the excitatory rate below a
   tenth of baseline in **~26 % of trials**, always recovering. "Never dies" plausibly means never
   *permanently* dies. A transient clause would need exactly the arbitrary depth threshold B8 was
   written to avoid. **Open; I did not want to settle it in my own favour.**
3. **Calibration — push back hard.** You warned: *"let the void be a finding if it wants to be —
   the version where you don't find your reverberating point is the more valuable, more publishable
   result, and the one it'll be tempting to sweep-one-more-corner to avoid."* We held that line for
   a whole session. Then I swept two more knobs and got the positive result.
   My defence: they were not arbitrary extra corners — they were the **authority of the controller
   the void hypothesis assumed was working**, and the control run shows it railed at 100 %. And the
   battery got *harder*: B2–B9 were failed by every point in the project's history; B7 by every
   point ever logged. But that is exactly what someone who wanted the positive result would say.
   **If you see motivated reasoning in the reframe, the amendment, or the choice of what to
   measure, say so.**
4. **Anything to promote from caveat to clause?** Candidates: the metastability degradation under
   perturbation (§5); the narrow per-neuron rate distribution (CV_rate ≈ 0.4–0.6 vs ~1 lognormal in
   cortex — possibly the gain homeostat clamping everyone to one rate, i.e. *regulated* is not
   *critical*); transient robustness (Q2).
