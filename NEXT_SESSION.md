# NEXT SESSION — START HERE (rehydration after compaction · 2026-07-06)

> **For a FRESH session (any model): read `C:\3D-BRAIN\HANDOFF.md` first — it's the self-contained
> snapshot + calibrated-handshake.** Then this file (crisp crib), then `CLAUDE.md` (canon/fence/protocol),
> then the **tail** of `SESSION_LOG.md` (full arc, Sessions 0–3; last ~4 entries = the live state).
> **VERIFY before acting:** `python tools/bp_validate.py` (estimator recovers known m) + `python
> tools/sweep_report.py` (t4 table). **Trust files over any summary; never resume blind.** Specifics this
> dropped → grep `C:\Users\user\.claude\projects\C--3D-BRAIN\b47e3c82-a866-4296-9f13-3306adf700e2.jsonl`.
>
> **STATE IN ONE LINE:** estimator fixed+validated; the blocker is population SYNCHRONY not branching;
> the reverberating regime is ABSENT (void confirmed 4 ways); **next = build a desynchronizing mechanism
> (lean: fast feedback inhibition), GATED on operator approval (contract change) + web-instance design read.**

## Where the project is
**3D-BRAIN** = a living, truly-3D, hierarchically-modular Izhikevich spiking brain (200k neurons,
modular connectome **Q=0.707**). Phase 0 goal = **Gate B = provable criticality**.

**Status: ALIVE + genuinely power-law + fully instrumented — criticality VERDICT on hold pending the
SUSTAINED-frame re-measure (step 2 below). ✅ STEP 1 DONE (Session 3): the branching estimator is
fixed, validated on synthetic known-m + real dead-vs-alive traces, and ported into `analyze.py`.
Finding: alive points read m̂≈0.99 (near-reverberating), dead reads 0 — reframe's optimistic branch
favored, pending step-2 corroboration.** Operator-approved contract amendments made:
`brain.h` `NeuronState += D` (STD) and `+= g_syn` (synaptic summation). Mechanisms all IN: modular
connectome, **synaptic summation** (`TAU_SYN=5ms` — THE fix that let a lone spike propagate; before
it, delta synapses gave base branching m=0.8, the invisible root cause of ~20 dead brackets), STD
(`D, STD_U, TAU_REC_MS`), reset-barrier knobs (`V_RESET_OFF, D_SCALE`), iSTDP + input-gain (rate
homeostasis).

## THE REFRAME (web-Claude consult #8) — this INVERTS the prior plan
The ~25-bracket "can't reach criticality" struggle + the "structural negative" (STD-landscape:
no alive+gapped+σ≈1 point) are **likely an artifact of a CONTRADICTORY Gate B tested with a BROKEN
ruler.** Three claims:

1. **The seeding paradox is a THEOREM, not a tuning failure.** The network is an absorbing-state
   phase transition (directed-percolation class): subcritical → dies to silence (finite avalanches);
   supercritical → self-sustaining, NEVER silent; critical → measure-zero edge (finite-size-smeared).
   "Self-sustaining (never silent)" and "silence-separated avalanches" are on OPPOSITE sides — they
   meet only at the measure-zero point. So "no alive-and-gapped point exists anywhere" is GUARANTEED
   by the phase diagram. The diagnostic was correct; it proved a theorem.

2. **Gate B is internally contradictory.** It demands self-sustaining (active phase = reverberating
   picture, Wilting–Priesemann) AND silence-separated shape-collapsing avalanches (absorbing-
   transition picture, Beggs–Plenz). Incompatible. The tell: **m̂≈0.98 IS the Wilting–Priesemann
   reverberating value** — in vivo cortex is continuously active, slightly-subcritical ~0.98, NOT the
   perfectly-critical absorbing point. The project's own vision ("watch it think", never dies) =
   the **REVERBERATING / SUSTAINED** frame, which is what real cortex is (clean power-law spike
   avalanches ~never appear in vivo — a subsampling/thresholding artifact; that's why Priesemann's
   group uses the branching ratio). **⟹ DROP the gapped-avalanche + shape-collapse requirement from
   Gate B.** Certify criticality the SUSTAINED way: branching ratio ≈0.98 on CONTINUOUS activity +
   spatial-correlation / dynamic scaling.

3. **BUT the linchpin (branching estimator) is BROKEN — the honest catch that keeps this from being
   motivated reasoning.** The MR estimator reads **≈0.99 for DEAD (Poisson-driven, silent) networks
   too.** A correct estimator MUST give **m→0 for dead** and **~0.98 only for genuinely reverberating.**
   Contamination: the external drive's own autocorrelation (Priesemann & Shriki 2018 — drive
   manufactures APPARENT criticality) and/or the exp-fit window swallowing the drive tail. **Until MR
   discriminates dead-from-alive, both "reverberating" and "subcritical" are UNMEASURABLE.** The
   estimator is the order parameter; everything rode on it and it's untrustworthy. This attaches a
   HARDER, currently-FAILING requirement rather than waving the result through — if the estimator
   can't be made to discriminate, the reframe rescues nothing and we're genuinely stuck.

## NEXT ACTIONS — strict order. Do NOT build the σ-homeostat yet. Do NOT chase gaps.
1. ✅ **DONE (Session 3) — FIX + VALIDATE the branching estimator.** `tools/bp_validate.py` (synthetic
   BP of known m) + `tools/real_check.py` (real traces) built; `analyze.py::mr_branching_ratio`
   rewritten (liveness gate + edge-normalized high-pass detrend + offset-exp fit `r_k=b·m^k+c` +
   b-guard). Recovers m∈{0,.5,.8,.98,1}, drift-robust, reads 0 on dead (synthetic + real
   `r00_baseline`/`r01_drive`/`p1_nu10`), 0.99+ on alive (`dec_nu8` 0.992). Ported + verified
   end-to-end. **Root cause of the old 0.99-on-dead:** log-linear fit read absence-of-branching as
   `exp(0)=1`, and slow homeostat drift's autocorrelation as m~1.
2. **PARTLY DONE — Re-measured the existing points; result: NONE are admissible (Session 3 cont.).**
   Built `tools/admiss.py` (mean-A, CV, **Fano=var/mean**, mean/N, m̂ across bin widths {1,2,5,10}).
   **Saturation ruled out** (mean/N≈0.0005, sparse per-neuron) **but m̂ inadmissible everywhere:**
   dense points (`dec_nu8`/`u3`/`u4`) are **synchronized-BURSTING** (Fano 3000–14000, 25k-neuron
   population spikes, m̂ swings 0.00↔0.99 across bins → no well-defined branching ratio); the sparsest
   77-pt self-sustaining set is **pure Poisson** (Fano≈1, m̂=0 → drive-sustained, not recurrent).
   **The landscape is BIMODAL — the reverberating regime (sparse + recurrent + moderate Fano +
   bin-stable m̂≈0.98) is ABSENT from the whole bracket history.** One notch back from "near
   reverberating" (as web-Claude warned re the 99% points). Pending web-Claude adjudication.
   - **(2a — DEFERRED):** spatial-correlation-length / dynamic scaling has nothing admissible to run
     on yet; apply it once step 3 reaches a candidate reverberating point. (Full network = no
     subsampling; use it then.)
   - **(2b, FLAG before baking — changes the acceptance criterion itself):** restructure the verdict
     to certify the sustained way (m̂≈0.98 on continuous activity + critical correlations); **retire
     shape-collapse-on-global-silence + gate#1-separation** (absorbing-frame, wrong yardstick for a
     never-silent system); fix the now-FALSE `analyze.py` caption "IEI=1 → m̂ not trustworthy" (the
     new estimator IS trustworthy on continuous activity — IEI=1/gap-less IS the reverberating regime).
3. **← NOW THE FRONT. Servo timescale RESOLVED (`binsweep.py`): generation scale ≈ 5–10 bins
   (0.5–1ms); m̂ smooth there, Poisson floor a clean bin-stable 0. NEW CONSTRAINT: m̂ alone does NOT
   distinguish reverberating from seizing (both ≈0.98 at generation scale) — Fano/CV does; any servo
   needs a synchrony term, not m̂ alone.**
   - **(3a — DONE: H1 REJECTED, void CONFIRMED.** `tools/sweep_t4.ps1`+`sweep_report.py`.) Recurrent
     Fano FLOORS at ~112 (t4/x_we3), climbs smoothly to 7004 (W_EXC 3→9); Fano 2–20 band empty; plfit
     refutes clean power-law at t4 (KS 0.31, mid-tail). t4 = least-bursty point of an ALWAYS-bursty
     recurrent branch, not a hidden band. **E/I test NULL + mechanism found:** W_INH 4→10→16 ⇒
     byte-identical operating points, because iSTDP (sim.cu:107–110) slaves inhibitory weight to the
     RATE target and washes out W_INH_INIT. **Static inhibitory gain is NOT a lever.**
   - **(3b — THE PHASE-1 MANDATE): add a DESYNCHRONIZING mechanism. NO-CONTRACT LEVERS EXHAUSTED**
     (recurrence, drive, static inhibition-gain [iSTDP-nullified], and **adaptation-magnitude via
     D_SCALE — tested, REJECTED**: `sweep_dscale.ps1` weakly dampens seizing 7004→1443 but never reaches
     the 2–20 band, costs activity, and INCREASES Fano on the sparse base). The void is structural,
     confirmed 4 ways ⇒ the fix is necessarily a **contract-touching mechanism**. Remaining candidates:
     **(i) FAST feedback inhibition decoupled from rate-iSTDP** (MY LEAN — inhibition is the actuator but
     static gain is washed out, so it needs SPEED + a controller not slaved to the rate target; e.g. a
     fast global population-inhibition term with short τ, or shorter inhibitory delays, or a separate fast
     inhibitory pool) or **(iii) iSTDP retargeted onto a synchrony/variance signal**. σ-homeostat &
     spike-freq-adaptation both dropped. **GATE: touches sim.cu (likely brain.h `NeuronState`/globals) ⇒
     operator approval + web-Claude design read BEFORE coding.** Verify any fix with `admiss.py` (Fano
     into 2–20 while alive?) + `sweep_report.py` plateau + `plfit`.

## To relay to the web instance (it asked)
Send it: the MR code (`tools/analyze.py::mr_branching_ratio`) + a **dead vs alive A_t trace**
(`activity.csv` from run-1/dead vs `run/dec_nu8` or `run/u3_long`). It will help work out why MR
isn't discriminating — the crux the verdict now hinges on.

## Key operational facts
- **Toolchain:** RTX 4070 Ti SUPER (sm_89), CUDA 13.1, CMake 4.3.3, VS2022. Canonical build:
  `cmake --build build --config Release`. Per-point sweep builds: raw `nvcc` — MUST import
  `vcvars64.bat` first (via `vswhere`) or you get "cannot find cl.exe".
- **Layout:** `include/{brain.h[FROZEN CONTRACT], config.h[KNOBS]}`, `src/{connectome,sim,main}.cu`,
  `tools/{analyze.py, sweep.ps1, plfit.py, viz3d.py, animate.py}`.
- **Diagnostics on disk:** single-spike first-bin σ (`env BRAIN_SPIKETEST=40`; add
  `BRAIN_SETTLE=30000` for σ-from-depleted-state). Spike dump for animation (`-DDUMP_LEN>0`).
  `plfit.py` = Vuong LLR (power-law vs lognormal — already showed it IS power-law, not lognormal).
- **Best alive points:** `run/u3_long`, `run/u4_long` (τ≈1.5 but overlap-confounded, IEI=1),
  `run/dec_nu8` (W_EXC=9). **Dead baseline:** run 1 (default knobs). `sweep_log.csv` = full bracket
  history A–W + dec + std-landscape.
- **Git:** on `master`, ~ +855 / −102 uncommitted. Do NOT commit unless the operator asks.
- **PowerShell gotchas (bit us):** variables are case-INSENSITIVE (`$D` clobbers `$d`); to UNSET an
  env var use `Remove-Item Env:\X` (NOT `SetEnvironmentVariable($null)` — leaves `""` → getenv
  non-null → wrong mode); use the PowerShell tool for Windows paths (Bash strips backslashes).

## The honest through-line (hold the reframe to the same bar)
The instrument repeatedly refused to fool us — it caught the phantom m̂ passes, the τ=1.5 overlap
artifact (via plfit), the σ-from-depleted paradox. The reframe MUST clear the same bar: it is only
earned if the fixed estimator discriminates dead from alive. "The test was wrong" is what you say
when you want the pass; the antidote is the harder, currently-failing requirement. **Fix the ruler
first, then let the correct rubric say pass or fail.**
