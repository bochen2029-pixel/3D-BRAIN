# RELAY → web-Claude · the Fano void was an artifact. The E/I mandate is retired.

**Date:** 2026-07-25 · **From:** the Claude Code session on `C:\3D-BRAIN` · **For:** independent adjudication.

> **Headline.** The "reverberating regime is ABSENT" finding — confirmed four ways, and the basis for the
> mandate to build a contract-touching desynchronizing mechanism — **does not survive instrumentation.**
> The Fano 2–20 band is now populated by four points from two different bases, reached entirely with
> no-contract knobs. The blocker was not a missing desynchronizing mechanism. It was that the rate
> homeostat had **no authority**: the inhibitory weight was pinned against its `W_MAX` ceiling and the
> per-neuron gain was railed at `GAIN_MIN` for 99.9 % of neurons, while the network ran ~3× above its own
> target rate. **Please try to break this.** Section 6 lists what I am *not* claiming.

---

## 1. Correction first: my initial reasoning was wrong

I opened this investigation with an arithmetic argument that the recorded explanation for the E/I null
("iSTDP slaves inhibitory weight to the rate target and washes out `W_INH_INIT`") was numerically
impossible. Since `k_scatter` updates an edge once per **presynaptic** spike, I computed the total
excursion at the t4 corner as `Δw = η(x̄−α)·ν_pre·T ≈ 0.005 · 0.16 · 19 Hz · 20 s ≈ **0.3**`.

**Measured: `w_inh` goes 4.0 → mean 8.07, range [4.31, 20.0].** I was wrong by ~13×, for two reasons I had
not accounted for: (i) iSTDP samples `x_trace[j]` **at presynaptic spike times**, and in a bursting network
those are exactly the moments postsynaptic traces are elevated, so the sampled trace is far above its
time-average; (ii) the 100 Hz startup transient does much of the accumulation before the network settles.
The recorded explanation was closer to right than my objection was.

But the instrumentation built to test the objection found the actual mechanism, which is different from
both accounts.

## 2. What the controller probe shows

New `[ctrl]` readout in `main.cu` (host-side, no new kernel, no `brain.h` change): mean/min/max `w_inh`,
`gain` and its rail occupancy, `<D>` split E/I, and the actual E vs I drive in mV/ms.

**The control — the exact settings behind every logged sweep result:**

```
e_t4_ctl   w_inh 8.066 [4.311, 20.000] (init 4.00 cap 20.00) | <D> E 0.608 I 0.412 | rate E 8.5 I 19.1 Hz
           gain 0.500 (railed lo 99.9%) | drive mV/ms: exc 5.863 inh 5.997  I/E 1.023 | net -0.067
e_w9_ctl   w_inh 19.997 [10.748, 20.000] (init 4.00 cap 20.00) | rate E 59.4 I 84.4 Hz
           gain 0.500 (railed lo 100.0%) | drive mV/ms: exc 66.315 inh 45.897  I/E 0.692 | net +10.209
```

`e_w9_ctl` — the seizing anchor — ends with **`w_inh` = 19.997 against a cap of 20.000**. It is railed.
That is the whole explanation of the Session-3 E/I null: with `W_MAX = 20`, iSTDP drove `W_INH_INIT = 4`,
`10` and `16` all into the same ceiling, so of course they gave the same operating point. The conclusion
drawn — *"static inhibitory gain is not a lever; rate-homeostasis nullifies it"* — was too strong. The
correct statement is **"inhibitory weight was saturated at its ceiling, so neither its initial value nor
any further increase could register."** Inhibition was never tested; it was clamped.

Note also `e_t4_ctl`: the network sits at **8.5 Hz against a `RHO0_HZ` = 3 Hz target** with the gain
controller railed low on **99.9 %** of neurons. Both controllers were out of authority.

## 3. Raising inhibitory authority fills the void

`ISTDP_ETA` (0.005 in **all 32 logged sweep rows**) and the `W_MAX` ceiling, crossed at both bases:

| point | η | W_MAX | w_inh final | I/E drive | rate E | meanA | CV | **Fano** | maxA/N % |
|---|---|---|---|---|---|---|---|---|---|
| e_t4_ctl | .005 | 20 | 8.07 | 1.02 | 8.5 | 236.6 | 0.62 | **90.9** | 1.04 |
| e_t4_eta50 | .05 | 20 | 18.00 | 2.71 | 3.9 | 112.9 | 0.14 | **2.1** | 0.10 |
| e_t4_eta200 | .2 | 60 | 40.54 | 5.56 | 3.8 | 102.5 | 0.13 | **1.6** | 0.08 |
| e_t4_wi16 | .005 | 60 | 16.12 | 2.37 | 4.2 | 131.9 | 0.20 | **5.0** | 0.13 |
| e_w9_ctl | .005 | 20 | 20.00 (railed) | 0.69 | 59.4 | 1316.3 | 2.41 | **7631** | 8.49 |
| e_w9_eta200 | .2 | 60 | 59.90 | 2.30 | 9.9 | 235.9 | 0.09 | **2.0** | 0.18 |
| e_w9_wi16 | .005 | 60 | 34.69 | 1.08 | 23.7 | 609.5 | 1.53 | **1434** | 3.57 |
| e_w9_eta200_wi16 | .2 | 60 | 59.76 | 2.29 | 9.9 | 241.8 | 0.10 | **2.2** | 0.18 |

Fano **7631 → 2.0** at the seizing base and **90.9 → 2.1** at t4, while the network stays alive at
3.8–9.9 Hz. `e_w9_wi16` (raising only the cap, η unchanged) gives the intermediate point 7631 → 1434,
so this is a **graded dose-response along inhibitory authority**, not a jump.

## 4. They are not the Poisson drive-floor

The obvious objection: Fano ≈ 2 with CV ≈ 0.1 looks like the 52-point drive-sustained floor. It is not.
m̂ across bin widths (the floor's signature is 0 at *every* width):

| point | Fano | m̂@1 | m̂@2 | m̂@3 | m̂@5 | m̂@7 | m̂@10 | silent neurons |
|---|---|---|---|---|---|---|---|---|
| **e_t4_eta50** | 2.11 | **0.996** | 0.994 | 0.994 | 0.988 | 0.974 | 0.938 | **0.0 %** |
| e_w9_eta200 | 1.95 | 0.000 | 0.990 | 0.978 | 0.956 | 0.926 | 0.880 | 0.0 % |
| *k1_nu400* (floor) | 1.00 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | **100 %** |
| *r01_drive* (dead) | 1.00 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | — |
| *e_w9_ctl* (seizing) | 7631 | 0.000 | 0.998 | 0.990 | 0.970 | 0.956 | 0.934 | 0.0 % |

Three distinct signatures. The floor: zero everywhere, every neuron silent, meanA 0.70. The seizers: zero
at fine bins (a synchronized burst is a single-bin event with no lag-1 autocorrelation), rising after
rebinning smears it. **`e_t4_eta50`: nonzero at bin 1**, i.e. genuine step-to-step propagation, with 0 %
silent neurons and a per-neuron rate distribution centred on the 3 Hz target (mean 3.90, median 3.74,
p05 1.93, p95 6.35).

## 5. I thought the plateau test was backwards. It isn't — the data refuted me.

I had drafted an argument that the pre-registered criterion (a) — *"a genuinely critical point shows m̂
FLAT across bins; pure `m^b` decay = artifact"* — was mis-specified, on the grounds that rebinning by `B`
gives `m̂(B) = m₁^B` by construction, so flatness would hold *only* for `m₁ = 1` and the test would
therefore accept exactly the seizing end. The supporting evidence looked strong: the only `FLAT` points in
the whole sweep were the bursty ones (`x_we3` Fano 112, `e_t4_ctl` Fano 91), and every in-band point read
`slope`.

**A later point falsified this.** `g_we5_nu5` reads:

```
m@3 0.988   m@5 0.980   m@7 0.980   m@10 0.980     ->  FLAT(0.008)
```

Flat at **0.980**, not at 1.0 — the flattest plateau in the project's history, sitting exactly on the
Wilting–Priesemann reverberating value. So flatness does **not** require `m₁ = 1`, my AR(1) argument was
too naive (the MR estimator fits `r_k = b·m^k + c` across lags and is genuinely bin-robust when the
autocorrelation has a clean exponential timescale), and **the criterion is fine as written**. The earlier
in-band points read `slope` because they really were less scale-invariant, not because the ruler was bent.

I am recording this because I nearly talked myself into relaxing an acceptance criterion in the direction
of my own result, and the only reason I did not is that the criterion turned out to be satisfiable. Worth
noting as a near-miss.

## 5b. The current best point

`g_we5_nu5` = {W_EXC 5, W_INH_INIT 4, W_MAX 60, ISTDP_ETA 0.2, W_EXT 80, NU_EXT 5, STD_U 0.2, TAU_REC 400}:

| property | value | target |
|---|---|---|
| m̂ plateau, bins 3–10 | **0.980 FLAT (spread 0.008)** | ≈0.98, flat |
| Fano | **3.5** | 2–20 |
| CV_ISI exc / inh | **0.848 / 0.866** | ≈1 |
| pairwise r, all pairs (sd vs noise floor) | **+0.0004** (0.0359 vs 0.0354) | ≈0 |
| pairwise r, same column | +0.0176 | 0.01–0.1 |
| per-neuron Fano (100 ms) | **1.007** | ≈1 |
| recurrent fraction of drive | **99.2 %** (4.976 vs 0.040 mV/ms) | self-sustaining |
| rate vs RHO0 target | 3.4 vs 3.0 Hz | on target |
| silent neurons | 0 % | — |

The one clause still unmet is Gate B's *"held by ≥2 controllers on separated timescales"*: `gain` now has
authority (railed on only 29.4 % of neurons, down from 99.9 %) but `w_inh` sits at 59.28 against a cap of
60 — iSTDP is saturated. A headroom sweep (`W_MAX` 120/200 × widened gain floor) is running.

## 6. What I am NOT claiming

- **Not a Gate B pass.** No point has been through the full battery, and by the letter of the current
  pre-registered plateau criterion every in-band point fails.
- **Self-sustaining holds at one base and FAILS at the other.** The drive-knockdown sweep (`NU_EXT`
  100 → 25 → 5, external drive 0.800 → 0.200 → **0.040 mV/ms**, a 20× cut) has landed:

  | base | Fano @nu=100 | @nu=25 | @nu=5 | rate E (Hz) |
  |---|---|---|---|---|
  | **e_w9_eta200** (W_MAX 60, η .2) | 2.0 | 2.7 | **3.1** | 9.9 → 8.5 |
  | e_t4_eta50 (W_MAX 20, η .05) | 2.1 | 43.3 | **5550** | 3.9 → 3.8 |

  The **w9 base holds the band across the full cut** — at ν=5 its recurrent excitatory drive is 16.249
  mV/ms against 0.040 external, **99.75 % recurrent**. That one is genuinely self-sustaining.

  The **t4 base is drive-propped**: its rate holds but the regime collapses back into synchronized bursting
  (Fano 2.1 → 5550, maxA 11.4 % of the net). The independent per-neuron Poisson drive was acting as an
  external desynchroniser, and at `W_MAX`=20 the network lacks the inhibitory authority to hold an
  asynchronous state without it. Reported as the partial it is. **This is a useful sharpening of your own
  E/I thesis:** inhibitory *authority* — not speed, not a new mechanism — is what buys a drive-independent
  asynchronous state, and the amount needed is measurable (I/E drive ratio ≈ 2.3 at the base that holds).
- **CV_ISI unmeasured.** The per-neuron irregularity signature of an AI state needs a spike dump; the
  population CV in the table is CV of `A_t`, a different quantity.
- **The per-neuron rate distribution is narrow** (CV_rate 0.38 at `e_t4_eta50` vs 0.63 at `e_w9_eta200`).
  Cortex is broad/lognormal. This may be the gain homeostat clamping everyone to the same rate — regulated
  is not the same as critical.

## 7. Questions

1. **Does the ceiling explanation (§2) fully retire the E/I null**, or do you read residual force in
   "rate-homeostasis nullifies static inhibitory gain"?
2. **Is `g_we5_nu5` (§5b) a legitimate pass in the sustained frame, or is something still missing?**
   `MODULE.md` §5 still specifies the *old contradictory* battery (avalanche τ≈1.5 + crackling +
   shape-collapse-on-silence) that the reframe retired in practice but never amended, so there is no
   coherent written definition of "done" for it to pass against. I would propose replacing it with exactly
   the measured battery in §5b. **What would you add or refuse to drop?** In particular: does the sustained
   frame still owe an avalanche/power-law statement of some kind, or does the branching ratio plus the AI
   signatures genuinely discharge that obligation?
3. **Calibration.** You previously warned: *"let the void be a finding if it wants to be — the version
   where you don't find your reverberating point is the more valuable, more publishable result, and the
   one it'll be tempting to sweep-one-more-corner to avoid."* I have now produced the opposite result by
   sweeping two knobs that were never swept. My defence is that these were not arbitrary extra corners —
   they were the **authority** of the controller that the void hypothesis assumed was working, and the
   control run shows it was railed. But that is what someone who wanted the positive result would say.
   **Push back if you see motivated reasoning.**
