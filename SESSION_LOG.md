# SESSION_LOG.md — `brain_phase0`

Append-only log of working sessions (chronological, newest at the bottom). Each entry:
**intent → change manifest → result → next.** The durable memory of a long solo build.

---

## Session 0 — 2026-07-05 — Orientation · toolchain · relayout · first build

**Intent.** Absorb the canon, stand up persistence (`CLAUDE.md` + this log), verify the
toolchain, relayout the flat repo into the documented `src/`/`include/`/`tools/` structure,
and produce the first **Gate B** scorecard.

**Canon absorbed.** `MODULE.md` (invariants I1–I5, Gate B battery), `include/brain.h` (frozen
contract), `include/config.h` (knobs), `FINAL_BLUEPRINT.md` (skimmed — phase map + Phase-2+
deferrals), all three `.cu` + `tools/analyze.py`, and `original-claude-web-convo-history-arc.txt`
(intent: a true-3D volumetric spiking brain; Phase 0 answers *"does it come alive at the edge
on run 1, and can we measure it?"* — everything RT/Morton/growth/render is Phase 2+).

**Toolchain (verified).** RTX 4070 Ti SUPER, cc 8.9 (Ada) → arch **89**; **16 GB** VRAM;
**CUDA 13.1** (nvcc V13.1.80); **CMake 4.3.3**; driver 610.47; Windows 11 + MSVC.

**Change manifest.**
- Created: `CLAUDE.md`, `SESSION_LOG.md`.
- Relayout (user-approved) — no code edits, files moved verbatim:
  `include/{brain.h,config.h}` · `src/{connectome,sim,main}.cu` · `tools/analyze.py`.
- `CMakeLists.txt` rewritten (**no contract change** — not `brain.h`/`MODULE.md`):
  arch default `89` set *before* `project()`; **curand via `find_package(CUDAToolkit)` +
  `CUDA::curand`** (was fragile `find_library`); static CUDA + MSVC runtimes (self-contained
  exe); `NOMINMAX` / `_CRT_SECURE_NO_WARNINGS` on MSVC. Mirrors the working sibling CUDA
  projects on this PC.
- `brain.h` / `MODULE.md` untouched — contract intact.
- Diff budget: within (CMake + file moves only; zero kernel/logic edits).

**Result.**
- **Build: first-try clean, zero source edits.** The relayout + a robust CMake rewrite
  (`find_package(CUDAToolkit)` + `CUDA::curand` instead of a fragile `find_library`; static
  CUDA+MSVC runtimes; `NOMINMAX`) was the entire fix. `brain.h` / `MODULE.md` untouched.
  Perf: **~24,500 steps/s = 2.46× real-time** at N=200k (RT-factor collapses as the net heats up).
- **Run 1 (default knobs): DEAD.** `m̂=nan`, 0 Hz, one spike at t≈0 then silence for 20 s.
- **Judge defect found + fixed.** `tools/analyze.py` checked 3 boxes but NOT MODULE.md §5
  *self-sustaining*, so a dead startup transient scored `[PASS] near-critical` (MR estimator fits
  noise on an all-but-zero series). Added a **liveness gate** (last-20% mean-A test) and gated all
  three criticality boxes on it. Re-scored r01: false PASSes → honest `[----]`. *(Judge changed —
  acceptance instrument, not the frozen contract; thresholds are tunable.)*
- **Sweep harness built** (`tools/sweep.ps1`): per-point `nvcc` compile (imports VS env via
  `vcvars64.bat`) + run + `analyze.py` + parse → one row in `sweep_log.csv`. `config.h` `[KNOB]`s
  made `-D`-overridable via `#ifndef` guards (defaults byte-identical).
- **Bracket A (dead):** even `W_EXT=20 / W_EXC=6` gives only a startup transient (peak 8 neurons)
  then silence → **ignition failure**. Archived to `sweep_log_bracketA.csv` (pre-liveness-gate).
- **Bracket B (liftoff → tonic):** `NU_EXT 2k→10k` sustains **1.65 → 16.3 → 36 Hz** (`alive=PASS`),
  but `aval_count=1` — activity is **continuous** (never returns to 0) → no avalanche separation →
  not critical. Both failure walls now mapped empirically.
- **Key diagnostic:** `aval_count` reads the regime — **dead ≈ 3**, **tonic = 1**, **critical =
  many hundreds**. Criticality lives in the *intermediate, intermittent* regime neither bracket hit.

**Next (Session 1).** 2D search of the intermediate regime for **intermittent** activity
(avalanches separated by silence): moderate drive (`NU_EXT ~50–500`, `W_EXT` mid) × recurrence
(`W_EXC ~2–6`) × inhibition (`W_INH`, E/I ~1:2–1:4), targeting `aval_count` in the hundreds–
thousands at rate ~1–10 Hz. Once avalanches appear, tune `m̂→0.98` and check `τ→1.5, KS<0.1`; then
lean on iSTDP (`ISTDP_ETA`) + gain to hold the edge. Watch RT-factor stays ≥1.

**Files this session.** Created: `CLAUDE.md`, `SESSION_LOG.md`, `tools/sweep.ps1`,
`sweep_log.csv`. Rewrote: `CMakeLists.txt`. Edited: `include/config.h` (`#ifndef` guards),
`tools/analyze.py` (liveness gate). Relayout: flat → `include/` `src/` `tools/`. **No `brain.h`
or `MODULE.md` changes — contract intact.**

---

## Session 1 — 2026-07-06 — Criticality search: mapped the landscape, found the obstacle

**Intent.** Find the intermittent-avalanche operating point and tune toward Gate B
(m̂≈0.98, τ≈1.5, KS<0.1, self-sustaining). Sweep-only session (no kernel/contract edits).

**Change manifest.** `tools/analyze.py` liveness gate corrected (peak-clause → steady-bulk
clause; the old clause wrongly failed healthy low-rate intermittent regimes). Sweep plan
(`tools/sweep.ps1` `$runs`) iterated across brackets C–H; all rows in `sweep_log.csv`.
**No `brain.h` / `MODULE.md` / kernel changes.**

**Brackets & findings.**
- **C (drive descent, W_EXC=4, g=4):** found the INTERMITTENT regime at NU≈600–800 —
  15k+ well-separated avalanches, activity quiesces between cascades. c2 (NU=600) scores
  **3/4 boxes** (self-sustaining + near-critical + crackling) but avalanches **subcritical**
  (τ=6, bounded ~100–200, ~10 ms oscillation). NU≥1200 → tonic.
- **liveness-gate fix:** c2 was visibly sustained yet scored dead (peak inflated by the
  startup transient). Fixed → c2 correctly alive.
- **D (W_EXC 5→8):** null — τ stuck ~5.3, rate pinned 0.13. Excitation gain inert.
- **E (drive×inhib 2×2):** W_INH 12→8 at NU=800 flattened τ 5.06→3.52 (best τ); NU=1200 → tonic.
- **F (W_INH 7→4):** τ bounced 4–4.9, no tonic flip even at g=0.67; suspected controller washout.
- **G (controllers OFF, W_INH 12→5):** **decisive negative** — τ still 3.5–4.6, rate still
  0.25. It was never the controllers: the network is **drive-dominated** — at ~0.25 Hz
  recurrent input is negligible, so E/I weights don't matter.
- **H (strong balanced, W_MAX=80, W_EXC=10, W_INH 40–60, NU 3k–5k):** high drive → **tonic**
  (aval=1) at 3–12 Hz; strong inhibition only slightly dents the drive-set rate. Balanced =
  asynchronous-continuous "soup", not avalanches. (h4 = exactly 3.0 Hz but tonic.)

**The obstacle (honest).** Two-sided: **low rate** ⇒ recurrence negligible (τ stuck 3.5–6);
**high rate** ⇒ drive-forced continuous firing (tonic/soup). The critical window
(recurrence-dominated AND intermittent) isn't reachable by (drive × E/I-weight) alone —
at ~0.25 Hz each neuron gets a recurrent input only every ~400 steps (K=100 × 0.25 Hz), so
cascades can't compound. **Best point: e2** (NU=800, W_EXC=6, W_INH=8): alive, 3/4 boxes,
τ=3.52, KS=0.064.

**Next (fork for the operator).** (1) **Sweep `TARGET_OUTDEG` (K: 100→300→600)** at the
intermittent drive — the most promising *in-bounds* lever: more inputs/neuron makes recurrence
govern at lower rates. Costs bigger connectome (M∝K) but fits 16 GB. (2) If K doesn't crack
τ→1.5, that's a substantive Phase-0 finding: the iSTDP+gain set is *rate* homeostasis, not a
*criticality* self-organizer — the blueprint's **short-term depression** (Levina 2007 SOC) is
a Phase-1 mechanism absent here; whether STD belongs in Phase 0 is a **contract/scope decision**,
not a knob sweep.

**Files this session.** Edited: `tools/analyze.py` (liveness gate), `tools/sweep.ps1` (plans
C–H). `sweep_log.csv` grew (brackets C–H). No contract/kernel changes.

**Bracket I (out-degree K — operator-chosen lever).** Held total recurrent gain ~constant
(K×W_EXC≈800), K 100→1000, NU=800, controllers off. **Negative, informative:** τ stayed
3.9–4.9, rate pinned 0.25 Hz, aval ~1300–1500 — granularity didn't help; RT-factor fell
1.34→0.32 (scatter ∝ K). Why: at 0.25 Hz the mean recurrent current/step (∝ rate·K·W) ≈ 0.02
vs external ≈ 0.64 — **external drive is ~40× recurrent input**, so the net is structurally
drive-dominated; no K/W scaling fixes that without raising rate or drive (→ tonic).

**Session-1 conclusion (the Phase-0 information).** Across 9 brackets (drive 80–10k, W_EXC
0.8–10, W_INH 1–60, g 0.67–6, K 100–1000, controllers on/off): rate is **entirely drive-set**;
avalanche τ **stuck subcritical (3.5–6)** in the intermittent regime; tonic/soup at high drive.
The naked Phase-0 mechanism set (iSTDP + input-gain + basic Izhikevich adaptation on a
random-geometric connectome) **cannot self-organize scale-free criticality by [KNOB] sweep** —
it lacks an intermittency/SOC mechanism at meaningful rates. Candidate deferred mechanisms:
**short-term depression** (Levina 2007 SOC; blueprint §2.5 layer-4, currently Phase-1) and/or a
**hierarchical-modular connectome** for a Griffiths phase (blueprint §2.6, Phase-2+). Both are
contract/scope decisions for the operator, not knob sweeps. Best achieved: **e2** (NU=800,
W_EXC=6, W_INH=8 — alive, 3/4 boxes, τ=3.52, KS=0.064). `sweep_log.csv` holds all rows A–I.

---

## Session 1 (cont.) — 2026-07-06 — 3D modular connectome (operator-directed MODULE §1 amendment)

**Operator decision.** After the drive-dominated finding, the operator directed building the
real 3D brain STRUCTURE first ("skip the 2d, proceed directly to 3d"). **Approved amendment to
MODULE.md §1:** Phase-0 wiring changed from pure exponential-distance to the two-factor rule
`exp(-d/λ) × module_bias` over hierarchical-modular placement. Grounded in blueprint §2.5
("architecture buys a wide [Griffiths] target; homeostasis keeps you in it").

**Change manifest.** `src/connectome.cu` rewritten — clustered-modular placement (MOD_GRID³
columns nested in AREA_GRID³ areas) + two-factor wiring + structure-metrics printout.
`include/config.h` — added MOD_GRID/AREA_GRID/MOD_GAP/W_SAME_AREA/W_DIFF_AREA (guarded knobs).
**`build_connectome_host` signature + all kernels unchanged — `brain.h` contract intact.** Clean
CMake build.

**Structure verified.** N=200k, M=20.0M, out-degree 100 preserved. **Modularity Q=0.707**
(random graph ≈ 0); edges **70.9% intra-column / 27.8% same-area / 1.4% long-range** — a genuine
hierarchical-modular 3D connectome.

**Brackets J–K (criticality on the modular net, controllers off).** The structure **changed the
dynamics** — the qualitative win: **τ now responds to drive** (2.0→3.6→tonic as NU rises) whereas
on the random net it was pinned 3.5–6 regardless; and a **clean-power-law region appeared**
(KS<0.1 at NU 500–800). j1 (=e2 knobs) τ=3.58 ≈ e2's 3.52 → confirms it's topology, not knobs.
**Honest caveat:** the low-drive τ≈2.0 (NU 300–400) has **KS≈0.33 (poor fit)** — not a real
power law, just MLE on sparse data. Where KS is clean, τ is still subcritical (5–6). **Clean
τ≈1.5 not yet achieved.**

**Next.** Test whether WEIGHTS now bite on the modular net (they were inert on the random net):
sweep W_INH/W_EXC at a clean-KS drive (NU≈700) to push τ from 5–6 toward 1.5 while holding KS<0.1
and alive. If weights move τ, tune to Gate B, then re-enable iSTDP+gain to hold the edge.
`sweep_log.csv` holds rows A–K.

**Brackets L–O (the wall, definitively).** Chased τ→1.5 on the modular net across every lever:
**L** (drive 900–1500): τ bottoms ~3.5 then tonic. **M** (inter-module coupling WSA 0.4→1.0):
inert (τ 3.2–4.9). **N** (recurrence-dominated: low drive + strong W_EXC, ctl ON): **closest
τ=1.787** (n2) but sparse/not-alive, KS=0.23. **O** (nudge n2 drive up to self-sustain): τ climbs
2.5→5.8 as it becomes alive. **Robust across 15 brackets / ~60 points / both connectomes:** the
self-sustaining + clean-scale-free (τ≈1.5, KS<0.1) point does **not exist** in the reachable
space — low-τ ⟺ sparse/dying/poor-fit; alive + clean-KS ⟺ τ subcritical (3.9–6).

**Definitive Phase-0 finding.** The model lacks a **self-organized-criticality (SOC) mechanism.**
iSTDP + gain are RATE homeostasis, not CRITICALITY self-organization; the network stays
drive-dominated (external ~40× recurrent) → quasi-independent firing → subcritical avalanches
when alive. The 3D modular structure genuinely helped (created the critical transition, cleaned
the statistics, pushed achievable τ from 3.5–6 → ~1.8) but couldn't close it. **Prime suspect
(blueprint §2.5 layer-4): short-term synaptic depression (Levina 2007 SOC)** — deplete-after-burst
→ quiescence → recover → next cascade, which resolves the exact alive-vs-critical tension.
Currently a Phase-1 mechanism. **Best built:** a genuinely alive, self-sustaining, cleanly-
power-law 3D hierarchical-modular spiking brain — **3/4 Gate B boxes** (self-sustaining ✓,
near-critical m̂≈0.99 ✓, crackling ✓), τ subcritical. `sweep_log.csv` rows A–O.

**Next (operator fork).** (a) implement STD in Phase 0 (scope amendment, ~30–50 LOC in `sim.cu`
+ knobs) — highest-probability unlock; (b) operator searches how reference 3D/SNN criticality
models reach self-sustaining τ=1.5 (predict: dynamic synapses / STD); (c) bank the alive modular
brain as a Phase-0.5 milestone.

---

## Session 1 (cont.) — 2026-07-06 — STD + measurement fixes (web-Claude consult) [contract amendment]

**Amendment (operator-relayed, web-Claude spec).** Pulled short-term synaptic depression
(blueprint §2.5 L4, Levina 2007) into Phase 0. **`brain.h` contract amended:** `NeuronState +=
float* D` (per-presynaptic STD efficacy). `config.h += STD_U` (release/spike, dflt 0.2),
`TAU_REC_MS` (recovery, dflt 400). `sim.cu`: k_gather recovers D + depletes on spike; k_scatter
delivers `w*D[i]`. `main.cu` inits D=1. Two measurement fixes web-Claude flagged: `analyze.py`
now (1) bins avalanches at **⟨IEI⟩** (Beggs–Plenz; raw-dt binning alone moves τ 1.5↔5), and
(2) reports a **CRITICAL** verdict = m̂ and τ must AGREE (critical branching ties m→1 & τ→1.5;
m̂≈1 with τ≈5 is an artifact, not "3/4 done"). Clean build. sweep_log schema += IEI/CRITICAL/STD
knobs; pre-STD rows archived to `sweep_log_preSTD.csv`.

**Brackets P–R (STD, and the deeper blocker).**
- **P** (STD on, low drive 10–100, W_EXC=15, ctl on): **DEAD** — STD depletes a net that can't
  self-sustain → deeper death.
- **Q** (STD off, NU=20, ramp W_EXC 30→150): **DEAD at every point** — recurrence CANNOT
  self-sustain at low drive even at W_EXC=150 (fan-out dilutes: one 150-spike over 100 targets =
  sub-threshold each; reset+adaptation blocks reverberation). **The low-drive self-sustaining base
  STD needs does not exist for this Izhikevich network.**
- **R** (STD on at the alive regime NU=600–800): alive but **IEI=1** (drive fills every step, no
  quiescent gaps), so STD only modestly lowers τ (5.8→4.1 at U=0.4), still subcritical, m̂–τ
  inconsistent.

**Refined impasse (for web-Claude).** The recipe assumed a low-drive self-sustaining regime — it
read bracket N's τ=1.787 as that, but N was a sparse **dying transient**, not self-sustaining.
This net is **fundamentally drive-dependent**: no recurrence-only attractor at low drive (Q), so
STD has nothing to organize; and where it's alive, the drive removes the quiescent gaps SOC needs
(R, IEI=1). Open question: how to give this Izhikevich net a low-drive self-sustaining regime —
candidates: less-negative reset `c` / depolarizing bias so neurons reverberate; a *balanced-state*
ν_ext (not near-zero) + STD; per-synapse (not per-neuron) STD; conductance-based synapses; or the
fuller homeostatic stack. **STD + the measurement fixes are IN and correct — the blocker is
upstream of STD.** `sweep_log.csv` rows P–R.

---

## Session 1 (cont.) — 2026-07-06 — Synaptic summation: THE root cause (web-Claude consult #2)

**Root cause (web-Claude #2, confirmed by single-spike test).** STD only tunes branching DOWN, so
it can't rescue a sub-1 base — and the base was sub-1 because Phase-0 synapses are **instantaneous
(delta)**: a spike delivers current for one 0.1 ms step then it's gone, so inputs never summate →
a lone spike reaches ≈0 descendants. Bracket Q didn't show "recurrence can't self-sustain"; it
showed **a lone spike can't summate to threshold.**

**Fixes (contract amendment).** `brain.h` `NeuronState += float* g_syn` (decaying synaptic current).
`sim.cu` k_gather: `g_syn = g_syn·exp(-dt/TAU_SYN) + I_rec`, integrate `I = gain·g_syn`. `config.h`
+= `TAU_SYN_MS` (5), `V_RESET_OFF` (0), `D_SCALE` (1) [KNOBs]. `main.cu`: init g_syn=0; apply
reset/adaptation barrier knobs; added a **single-spike test** (`BRAIN_SPIKETEST=n`) — seed one spike
into a quiescent net, count descendants = base branching, no drive/weight confounds.

**Single-spike test — decisive.** delta (τ_syn≈0): base **m=0.8 (subcritical)** — the invisible
root cause of every dead bracket. Synaptic **τ_syn=5 ms: base m≫1** (~40M descendants at W_EXC=6)
— supercritical. **Temporal summation flips the base sub→super.** Clean build.

**Bracket S (STD + slow drive on the supercritical base): dead — for two specific, fixable reasons.**
(1) base at W_EXC=6 is *too* supercritical (40M = saturation → boom-bust, not gentle avalanches) →
dial W_EXC to *modest* super (m~2–100); (2) at slow drive a single external event (W_EXT=8) is too
weak to SEED a spike (one summed input ≈ a few mV) → no seeds → dead → raise W_EXT (~40+) so one
event fires a neuron while NU stays low (IEI>1).

**Next (endgame).** (a) single-spike-test dial W_EXC to modest supercritical (m~2–100); (b) bracket T:
that base + effective seeding (high W_EXT, low NU → IEI>1) + STD on + ctl → slow-driven SOC; judge on
CRITICAL. Engine / 3D structure / STD / synaptic summation / honest instrument are all IN and
correct — remaining work is a bounded 2-D tune (base gain × seed strength). `sweep_log.csv` rows P–S.

---

## Session 1 (cont.) — 2026-07-06 — CRITICALITY ACHIEVED (endgame, web-Claude consult #3)

**web-Claude #3 corrections applied.** (1) Total descendants SATURATES (blind above m≈1) → fixed
the single-spike test to report **first-bin σ = A₁** (un-saturated, graded). (2) Target σ≈2–3
(σ=100 → ⟨D⟩→0.01 → periodic bursting; σ~2–3 → ⟨D⟩~0.3–0.5 → healthy avalanches). (3) Calibrate
the seed. (4) Contingency: τ stuck high + clean KS → modular cap → loosen coupling.

**The σ dial (single-spike, first-bin, STD off).** Clean graded 1-D knob: W_EXC 1.5→2→2.5→**3.0**→4
gives σ 0.6→1.2→1.8→**2.5**→4.5 (W_EXC=3.0 → σ≈2.5, cascade ~47, finite = modest-super base;
W_EXC≥4 runs away).

**Brackets T–W (slow-driven SOC).** STD on + base σ~2.5 (W_EXC≈3.5) + calibrated seeding (W_EXT
40–55) + low NU + controllers on → walked to the critical point. Bracket W confirmed the low-drive
steepness is NOT the module cap (loosening coupling didn't lower τ).

**RESULT — criticality achieved (40 s runs).** The 3D hierarchical-modular Izhikevich brain sits at
criticality: **self-sustaining ✓, near-critical m̂=0.99 ✓, avalanche τ=1.51 (dead on 1.5) ✓,
crackling ✓ — 3 of 4 Gate B boxes formally PASS.** The 4th (size power law) has τ perfect but
**KS=0.11 vs <0.1** — NOT sample size (longer run didn't lower it): the points run at **IEI=1**
(continuous, no quiescent gaps), mildly distorting the avalanche-size shape. Formal-KS polish needs
**IEI>1** (genuine gaps) via STD-timescale tuning (longer TAU_REC + slower drive) — the open lever.

**Critical operating point:** modular connectome (Q=0.707) · synaptic τ_syn=5 ms · STD U=0.2 /
TAU_REC=400 · W_EXC=3.2–3.5, W_INH=4.3–4.7, W_EXT=55, NU=70–75 · controllers on. `sweep_log.csv`
rows T–W + u3_long/u4_long.

**Full journey:** delta synapses (base m=0.8, subcritical) → synaptic summation (base m≫1) → σ dial
to ~2.5 → STD (SOC) → slow-driven regime → **τ=1.51, m̂=0.99, alive 40 s, crackling.** From "≈20 dead
brackets, mysterious" to a living brain at the edge. Contract amendments this arc: modular connectome
(MODULE §1), STD + g_syn (blueprint §2.5 L4) — `brain.h` `NeuronState += D, g_syn`; kernels + probe
extended; all operator-approved and logged.

---

## Session 1 (cont.) — 2026-07-06 — Adjudication: the τ=1.5 was CONFOUNDED (web-Claude consult #4)

**Discipline check (web-Claude #4): TEST the failing box, don't explain it away.** Ran the rigorous
CSN/Vuong adjudication (`tools/plfit.py`, self-contained — the `powerlaw` pkg is numpy-buggy) on the
IEI-binned avalanche sizes.

**(A) Is it a power law? YES (not lognormal).** Vuong LLR strongly favors power_law over BOTH
lognormal and exponential at every point (u4: R=+103 vs lognormal, p<0.001; v2: R=+319, p=0.003).
Distribution is genuinely power-law-shaped, not lognormal — that part is clean.

**(B) Is τ=1.5 robust? NO — drive-dependent (overlap artifact confirmed).**
- **u4 (high drive):** τ=1.44, KS=0.111, max CDF deviation at the LOW end (size≈xmin=3) = systematic
  curvature; only 381 avalanches (heavily merged at IEI=1).
- **v2 (low drive):** τ=**3.10**, KS=0.058 (clean), deviation at the UPPER tail (size≈1232, 93% in) =
  up-state dragon-kings on an otherwise-clean power law; 3160 avalanches (better resolved).
- Same network reads τ=1.44 vs 3.10 by drive → the gap-less-merging confound. Well-resolved exponent
  is ~3.1 (subcritical); τ=1.5 is a merging artifact of the IEI=1 regime.
- **m̂ (MR) is a weak discriminator** (reads ~0.96–0.99 across dead/alive/sub alike) → earlier
  "m̂↔τ agree at u4" is NOT strong evidence. m̂(v2)=0.99 vs τ(v2)=3.1 is inconsistent → one artifactual.

**Honest verdict: criticality NOT cleanly established.** τ=1.5 was premature — an overlap artifact of
the gap-less (IEI=1) regime. Every alive point has been IEI=1; genuine timescale separation (IEI>1)
was never achieved. **Did NOT bake a default or write "passed."**

**Real remaining work.** Achieve **IEI>1** (genuine quiescent gaps): truly rare seeding + STD holding
the net silent between cascades (much longer TAU_REC) so cascades don't overlap; re-measure τ
un-confounded with `plfit.py` + a stronger branching estimator than the MR m̂ (subsampling-corrected,
or shape-collapse). Tools now in place: `plfit.py` (Vuong LLR), single-spike first-bin σ, IEI binning.

---

## Session 2 — 2026-07-06 — Measurement upgrades (web-Claude #5): shape-collapse is the verdict

**Sequencing: MEASUREMENT BEFORE TUNING.** Built three estimator upgrades into `analyze.py`, with
the explicit understanding that branching estimators only discriminate once IEI>1 (a drive-filled
system's autocorrelation is the drive's statistics, not branching — which is exactly why the MR
read ~0.99 everywhere):
1. **running-σ** — avalanche branching = slope of B[t+1] on B[t] over active bins (IEI series).
2. **improved MR** — Wilting-Priesemann fit over the CLEAN exponential window (skip offset, stop at
   the oscillatory upturn), not all k.
3. **SHAPE COLLAPSE — now the PRIMARY Gate B certificate.** Mean profile of avalanches of each
   duration T, rescaled A·T^(1-γ) vs t/T, must collapse onto one curve with γ matching the crackling
   relation γ=(τ_t-1)/(τ-1). Merging/finite-size fake exponents; they cannot fake a geometric
   collapse of all durations. **KS demoted to corroborating.** Verdict rewritten + 4th plot panel.

**Smoke-test on u4 (IEI=1): correctly NOT critical.** No phantom: shape-collapse γ=2.04 vs crackling
γ=1.34 (|diff|=0.70 → FAIL); MR/σ (both ≈1.0) flagged untrustworthy by the IEI=1 warning. CRITICAL
= ----, honestly. (Only 3 clean durations at IEI=1 — the collapse, like the branching estimators,
gets meaningful once IEI>1 yields separated avalanches.)

**Ready for the decisive session.** Estimators built → next: engineer **IEI>1** (long TAU_REC 1-4 s
+ rare-strong seeding), **re-run single-spike σ at the chosen TAU_REC** (base branching may drift
with the recovery constant), then adjudicate with shape-collapse + plfit. Either branch is a finish
line: collapse + γ-match = Gate B passed; no collapse = iSTDP+gain+STD insufficient → Phase-1
mandate (cross-homeostasis, Mackwood 2022). Tools: `analyze.py` (shape-collapse verdict), `plfit.py`,
single-spike first-bin σ, `viz3d.py` / `animate.py`.

---

## Session 2 (cont.) — 2026-07-06 — DECISIVE RUN, self-adjudicated (web-Claude #6): Phase 0 closes

**Three gates built (web-Claude #6):** #1 = mean-quiet/mean-duration ≥5 (validity of the whole
adjudication); #2 = σ measured from the DEPLETED steady state (`main.cu` `BRAIN_SETTLE` settles to
the operating ⟨D⟩, then single-spike from there); #3 = shape collapse, trusted only if #1–#2 pass.

**Gate #2 — the seeding paradox, quantified.** At the dialed base (W_EXC=3.2, σ≈2.5 at D=1) the STD
steady state depletes ⟨D⟩ so far that **σ-from-depleted ≈ 0 at every TAU_REC** (400–4000 ms): the
operating recurrence is subcritical (threshold nonlinearity collapses σ_eff below the naive
σ_base·⟨D⟩). Raising the base to **W_EXC≈9** restores σ-from-depleted ≈ 1.6 (ignitable). So the base
must be ~9 (not 2.5) to survive STD depletion.

**Decisive run at the compensated base (W_EXC=9, TAU_REC=1500, slow drive NU 8/15/25), self-adjudicated:**
- **GATE #1 FAILS everywhere: quiet/duration = 0.22 / 0.07 / 0.04 (need ≥5) → INVALID.** No genuine
  timescale separation; avalanches overlap → every exponent + the collapse are confounded, and the
  gate correctly refuses to adjudicate. (collapse γ vs crackling γ: 1.20/1.53, 1.14/1.61, 1.62/2.36 —
  all mismatched, but INVALID regardless.)
- The paradox is inescapable: low base ⇒ σ-from-depleted<1 (drive-sustained, no gaps); base high
  enough to ignite ⇒ continuously active (no gaps). **No alive + gapped operating point exists.**

**VERDICT — Phase 0 closes honestly: iSTDP + gain + STD is INSUFFICIENT for self-organized
criticality with timescale separation in this architecture.** A mechanism result (gates never clear),
not a tuning failure. **Phase-1 mandate:** the fuller homeostatic stack — cross-homeostasis
(Mackwood 2022, the rule that provably reaches the ISN regime), circuit-breaker, slow scaling
(blueprint §2.5). The instrument won the argument; no pass was manufactured.

**Phase-0 deliverable, honestly stated:** a living 3D hierarchical-modular spiking brain (Q=0.707,
self-sustaining, genuinely power-law) + a rigorous self-adjudicating criticality instrument (IEI
binning, shape-collapse verdict, gate-1 separation, gate-2 σ-from-depleted, plfit Vuong LLR,
single-spike σ) + offline 3D viz — and a **decisive negative** on reaching criticality with this
mechanism set. Alive + instrumented + honest. Phase 1 inherits a sharp mandate.

---

## Session 2 (cont.) — 2026-07-06 — STD-landscape: the paradox is STRUCTURAL (web-Claude #7)

**Measure before building the fix (web-Claude #7): does an alive+gapped+σ≈1 point exist ANYWHERE in
STD space?** Swept STD (U × TAU_REC) at fixed base W_EXC=9, measuring σ-from-depleted (+⟨D⟩, gate #2)
and quiet/duration (gate #1):

| STD (U,TREC) | ⟨D⟩ | σ-from-depleted | quiet/dur | meanA |
|---|---|---|---|---|
| U0.05,T500  | 0.58 | 1.82 | 0.01 | 839 |
| U0.05,T2000 | 0.77 | 3.02 | 0.01 | 410 |
| U0.15,T500  | 0.75 | 2.75 | 0.04 | 322 |
| U0.15,T2000 | 0.76 | 2.55 | 0.06 | 191 |
| U0.40,T500  | 0.56 | 0.70 | 0.07 | 135 |
| U0.40,T2000 | 0.18 | 0.03 | 0.08 | 118 |

**STRUCTURAL, not a tuning valley.** Across the ENTIRE landscape quiet/dur is 0.01–0.08 — never near
the ≥5 for separation; and σ>1 (ignitable) occurs EXACTLY where the net is most continuous (weak STD).
No σ≈1-AND-gapped point exists anywhere. STD at any strength cannot create timescale separation here.

**The read (web-Claude's 3 futures): #2 — a σ-TARGETING controller.** #1 (tune STD harder) is RULED
OUT (no valley). Root cause = every controller here regulates RATE; you cannot reach a criticality
set-point with only rate-targeting controllers (the project's core lesson, now proven twice).
Cross-homeostasis addresses E/I balance, NOT the σ_eff-at-⟨D⟩ tension → would reproduce the paradox.

**Phase-1 mandate (evidence-driven):** implement a **σ-homeostat** — measure running branching
(running-σ, already built) and slowly nudge a per-neuron excitability gain toward σ=1, on a
timescale separated from iSTDP/STD. Bounded `sim.cu` addition; verify with the same self-adjudicating
gates (gate #1 separation, gate #2 σ-from-depleted, shape-collapse). This is the specific missing
mechanism the diagnostics point to — not the blueprint's next menu item.

---

## Session 2 (cont.) — 2026-07-06 — THE REFRAME (web-Claude #8): wrong paradigm + broken ruler → σ-homeostat ON HOLD

**This INVERTS the entry above.** The ~25-bracket struggle + the STD-landscape "structural negative"
are likely an artifact of testing a **contradictory Gate B** with a **broken branching estimator** —
not proof that the mechanism set is insufficient. Three claims, held to the same bar as everything else:

1. **The seeding paradox is a THEOREM, not a tuning failure.** The net is an absorbing-state phase
   transition (directed-percolation class): subcritical → dies to silence (finite avalanches);
   supercritical → self-sustaining, NEVER silent; critical → measure-zero edge. "Self-sustaining
   (never silent)" and "silence-separated avalanches" sit on OPPOSITE sides of the transition — they
   coincide only at the measure-zero point. So "no alive-and-gapped point exists anywhere in STD space"
   is GUARANTEED by the phase diagram. Session-2's diagnostic was correct; it proved a theorem, and we
   mis-read a theorem as a mechanism verdict.

2. **Gate B is internally contradictory.** It demands self-sustaining (active phase = reverberating
   picture, Wilting–Priesemann) AND silence-separated, shape-collapsing avalanches (absorbing-transition
   picture, Beggs–Plenz). Incompatible. The tell we kept stepping over: **m̂≈0.98 IS the Wilting–
   Priesemann reverberating value** — in vivo cortex is continuously active, slightly-subcritical ~0.98,
   NOT the perfectly-critical absorbing point. The project's OWN vision ("watch it think", never dies) =
   the **reverberating / sustained** frame, which is what real cortex is (clean power-law spike
   avalanches ~never appear in vivo — a subsampling/thresholding artifact; hence Priesemann's group
   certifies with the branching ratio, not shape-collapse). **⟹ DROP the gapped-avalanche +
   shape-collapse requirement.** Certify criticality the sustained way: branching ratio ≈0.98 on
   CONTINUOUS activity + spatial-correlation / dynamic scaling.

3. **BUT the linchpin — the branching estimator — is BROKEN.** This is the honest catch that stops the
   reframe from being motivated reasoning. `mr_branching_ratio` reads **≈0.99 for DEAD (Poisson-driven,
   silent) networks too** (we saw exactly this in Session-1 #4: "weak discriminator, ~0.96–0.99 across
   dead/alive/sub alike"). A correct estimator MUST give **m→0 for dead**, ~0.98 only for genuinely
   reverberating. Contamination: the drive's own autocorrelation (Priesemann & Shriki 2018 — external
   drive manufactures APPARENT criticality) and/or the exp-fit window swallowing the drive tail. **Until
   MR discriminates dead-from-alive, both "reverberating" and "subcritical" are UNMEASURABLE.** The
   estimator is the order parameter; every verdict rode on it and it's untrustworthy.

**NEXT ACTIONS — strict order (supersedes the σ-homeostat mandate above as the immediate task):**
1. **FIX + VALIDATE the branching estimator FIRST (make-or-break).** Fix `mr_branching_ratio` to give
   m→0 for a drive-only DEAD net + a bin-width-robust value for the alive one (remove drive/mean-field
   contribution; restrict to the genuinely-branching lag window). **VALIDATE on synthetic BPs of KNOWN
   m** — tiny generator `A_{t+1} ~ Poisson(m·A_t)+h`, confirm recovery for m∈{0,0.5,0.8,0.98,1.0} and
   →0 for pure Poisson. Do NOT trust MR on the sim until it passes. Then confirm on the real DEAD
   baseline (run 1) vs ALIVE (`run/dec_nu8`, `run/u3_long`): fixed MR must cleanly separate them.
2. **Re-measure the EXISTING alive point in the SUSTAINED frame.** Validated MR + spatial-correlation-
   length / dynamic scaling on continuous activity. **We have the FULL network (no subsampling) — a real
   advantage over every in vivo study; use it.** Retire shape-collapse-on-global-silence as the verdict.
3. **THEN decide the σ-homeostat.** If validated MR says the alive point is already ~0.98 with critical
   correlations → **Gate B passed in the correct frame**; σ-homeostat becomes Phase-1 polish to HOLD it
   (`g ← g + κ(m̂−0.98)`, now well-posed — continuous activity means m is always estimable). If validated
   MR says genuinely subcritical (m≈0.8–0.9) → the σ-homeostat is the real fix. **Do NOT build it yet;
   do NOT chase gaps.**

**Held to the same bar.** The instrument repeatedly refused to fool us (phantom m̂ passes, the τ=1.5
overlap artifact via plfit, the σ-from-depleted paradox). The reframe MUST clear the same bar: it is
earned ONLY if the fixed estimator discriminates dead from alive. "The test was wrong" is what you say
when you want the pass — the antidote is that we've attached a HARDER, currently-FAILING requirement
(a working discriminating estimator) rather than waving the result through. Fix the ruler first; then
let the correct rubric say pass or fail. Full rehydration crib: `NEXT_SESSION.md`.

---

## Session 3 — 2026-07-06 — STEP 1 DONE: the branching estimator is fixed, validated, ported

**The make-or-break task passed.** Built `tools/bp_validate.py` (ground-truth rig) + `tools/real_check.py`
(real-trace confirmation), diagnosed exactly why the incumbent MR read ~0.99 on dead nets, fixed it,
validated on synthetic branching processes of KNOWN m, confirmed on real dead-vs-alive traces, and
ported the validated estimator into `analyze.py::mr_branching_ratio` (flagged instrument change).

**Diagnosis — two failure modes, both pushing m̂→1:** (1) the naive estimator fit `log(r_k)` and
exponentiated the slope, so a flat (no-branching) autocorrelation gave slope≈0 → `exp(0)=1` —
**absence of branching read as perfectly critical**; (2) the homeostat's slow drift kept r_k high
across lags → tiny negative slope → m̂≈1 (**drive manufactures apparent criticality**, Priesemann &
Shriki 2018). A dead net has both → reads 0.99.

**The fix (three ingredients, each killing a failure mode):** (0) **liveness gate** — a net active in
< 10% of bins is absorbing/dead ⇒ m=0 (the branching ratio certifies the SUSTAINED regime; alive
traces are 82%+ active, dead <1%); (1) **edge-normalized high-pass detrend** — removes the drift tail
(a naive `convolve(mode=same)` fabricated boundary humps → knife-edge failure at m=0; edge-normalized
cumsum fixed it); (2) **offset-exponential fit** `r_k = b·m^k + c` — c absorbs the stationary drive
floor, b-significance guard returns m→0 when there's no exponential component.

**Validation (`bp_validate.py`, T=120k):** fixed estimator recovers true m = {0.00→0.000, 0.50→0.49,
0.80→0.81, 0.98→0.98, 1.00→1.00}, **robust to a ±60% slow drive drift** (incumbent read ~1.0 for
every m under drift), and reads **0 on dead**. **Real traces (`real_check.py`):** dead/drive-only
(`r00_baseline`, `r01_drive`@0.2%, `p1_nu10`) → **0.000**; alive (`dec_nu8`@82%, `u3_long`/`u4_long`
@99%) → **0.99+**. Incumbent read 0.94–0.99 on dead AND alive alike. **The ruler now discriminates.**

**The finding it unlocks (feeds step 2):** the existing alive operating points read **m̂≈0.99** —
`dec_nu8` 0.992 (82% active, the cleanest/least-saturated), `u3/u4_long` ~0.99 (99% active, near-
saturation → interpret with care). That is the **near-critical / reverberating band**, NOT the deeply-
subcritical (m≈0.8) world. So the reframe's optimistic branch ("already ~reverberating") is favored —
**pending step-2 corroboration** (spatial-correlation / dynamic scaling) and care around the 99%
saturation. The honest catch is cleared: the reframe was earned by a harder, now-passing requirement,
not waved through.

**Manifest:** +`tools/bp_validate.py`, +`tools/real_check.py`, `analyze.py::mr_branching_ratio`
rewritten (liveness + high-pass + offset-fit; return signature `(m,ks,rk)` preserved; verified
end-to-end on `dec_nu8` → m̂=0.992, both plots wrote). No contract (`brain.h`/`MODULE.md`) touched.
Verdict PASS-logic deliberately UNCHANGED this session (still shape-collapse-primary + the stale
"IEI=1 not trustworthy" caption) — retiring that absorbing-frame scaffolding is step 2's job.

**NEXT — step 2 (re-measure the alive point in the SUSTAINED frame):** (2a) add spatial-correlation-
length / dynamic-scaling to `analyze.py` on continuous activity — additive, safe; (2b) **restructure
the verdict** to certify the sustained way (m̂≈0.98 on continuous activity + critical correlations),
retire shape-collapse-on-silence + gate#1-separation, fix the stale caption — this changes the
*acceptance criterion itself*, so FLAG it / consult before baking. Then step 3: decide the σ-homeostat
(polish-to-hold if already ~0.98 with critical correlations; the real fix if genuinely subcritical).

---

## Session 3 (cont.) — 2026-07-06 — ADMISSIBILITY probe: no admissible m̂ exists; the landscape is bimodal (web-Claude saturation catch)

**Web-Claude flagged a THIRD counterfeit of m̂≈1: saturation/pinning** (if A_t is clamped against a
ceiling the lag-1 slope is ~1 by construction — variance squashed — and even a good estimator can't
see through it). Built `tools/admiss.py`: per trace, mean-A, CV, **Fano=var/mean** (THE tell: ~1 =
Poisson/pinned, ≫1 = genuinely bursty), mean/N (ceiling fraction), and **m̂ at bin widths {1,2,5,10}**
(a genuine near-critical m̂ is bin-stable; a pinning/synchrony artifact drifts) — startup transient
excluded. Also scans all 77 self-sustaining points for the sparsest (the reverberating-regime hunt).

**Result — saturation RULED OUT, but m̂ still inadmissible everywhere, for the opposite reason:**
| point | meanA | CV | Fano | mean/N | act% | maxA | m̂ @ bin 1/2/5/10 |
|---|---|---|---|---|---|---|---|
| dec_nu8 | 105 | 11.6 | **14225** | 0.0005 | 83 | 25722 | **0.00/0.998/0.968/0.932** |
| u3_long | 85 | 6.2 | 3231 | 0.0004 | 99.9 | 7556 | 0.00/0.00/0.988/0.962 |
| u4_long | 120 | 5.0 | 2951 | 0.0006 | 99.9 | 7670 | 0.00/0.00/0.990/0.966 |

- **Not saturated:** mean/N≈0.0005 (0.05% of neurons/bin — sparse per-neuron, ~8 Hz). The "82/99%"
  was fraction-of-BINS-active, not neurons. CV huge, Fano in the THOUSANDS.
- **Synchronized BURSTING:** recurring population spikes up to 25,722 neurons in one 0.1 ms bin
  (12.9% of the net), on a sparse background → supercritical/synchronous, not scale-free.
- **m̂ bin-unstable (0.00 ↔ 0.99):** no well-defined branching ratio → INADMISSIBLE by the web-Claude
  bin-width criterion. (Real: at 0.1 ms a synchronous burst is a single-bin event, low lag-1
  autocorr → 0; rebinning smears it → ~1. Branching is ill-defined for this signal.)
- **Sparse end (77-pt scan): Fano≈1.0, m̂=0** — the sparsest self-sustaining points (k1_nu400 meanA
  0.70 … ) are PURE POISSON = drive-sustained, no recurrence. Estimator correctly says no branching.

**Verdict: the landscape is BIMODAL with a gap where reverberation should be** — sparse⇒Poisson
drive-floor (Fano 1, m̂ 0), dense⇒synchronized bursting (Fano 1000s, m̂ bin-unstable). **The
reverberating regime (sparse + recurrently self-sustaining + moderate Fano + bin-stable m̂≈0.98) is
ABSENT from the entire bracket history.** Honest state = one notch back from "near reverberating"
(exactly what web-Claude warned about the 99% points): the ruler is now trustworthy + admissibility-
gated, and it says NONE of the existing points are reverberating.

**Sequencing update:** step 2a (spatial correlations) has nothing admissible to run on yet. Re-points
to **step 3 = the σ-homeostat, job now precise: drive the net from synchronized-bursting DOWN toward
sparse-fluctuating m≈0.98** (reach the missing regime, don't confirm a present one). **Open design
question it raises:** the servo must estimate m̂ on SOME bin width, and m̂ is bin-dependent on bursty
input — pin the servo's timescale down first. **Manifest:** +`tools/admiss.py` (probe only; no
contract, no verdict change). Pending web-Claude adjudication of the readout before building step 3.

**FOLLOW-UP (`tools/binsweep.py`) — servo timescale RESOLVED + a real lead found.**
Delay scale: `COND_VEL=300µm/ms`, `DT=0.1ms` ⇒ 1 bin = 30µm; with `λ=150µm` the mean synaptic delay
≈ **5–10 bins (0.5–1ms)** = one generation. (1) **Bin-width law = coarse-graining `m_coarse≈m_fine^b`**
— no plateau; m̂ decays smoothly after onset. The Poisson floor reads **m̂=0 at EVERY bin width**
(clean "no recurrence"); bursty points read 0 at sub-propagation bins 1–3 (<0.3ms) then decay from
~0.99. ⇒ **servo bin width = generation scale (~5–10 bins), NOT bin 1** — m̂ smooth/differentiable
there. Open design Q answered. (2) **Fano landscape is a stark BIMODAL VOID**: of 77 self-sustaining
points, **52 at Fano≈1 (Poisson floor), 22 at Fano>2000 (synchronized bursting), and only 3 in the
whole middle — ZERO in Fano 2–20.** The gentle-criticality band where reverberation lives is nearly
empty; the Poisson→synchrony transition is near-discontinuous. (3) **NEW CONSTRAINT:** at the
generation scale m̂≈0.97–0.998 for bursty AND middle points alike — **m̂ does NOT distinguish
reverberating from seizing; Fano/CV does.** ⇒ a pure `g←g+κ(m̂−0.98)` servo could lock onto a seizing
state; step 3 needs a synchrony/variance term, not m̂ alone.

**THE LEAD — `t4_wx80_nu100` (CORRECTED knobs: W_EXT=80, ν=100, base W_EXC=3.0, W_INH=4.0, STD on):**
the sole Fano-128 point, qualitatively unlike the seizers — CV **0.74** (vs 11.6), largest burst
**0.78%** of the net (vs 12.9%), m̂@bin5 0.998, continuously active. NOT "high recurrence/low drive"
(my earlier misread of the label) — it's **modest recurrence (W_EXC=3) + STRONG external seed
(W_EXT=80) + moderate drive (ν=100)** with STD. The least-synchronized recurrent point in the whole
history — a corner the brackets barely swept.

**⚠ Discipline check (web-Claude): "the reverberating regime may be UNDER-EXPLORED, not absent" is the
hopeful-read sentence shape this project exists to distrust (τ=1.5, 3/4-boxes in new clothes).** One
point at Fano 128 in a bimodal void is at least as consistent with "a lone sample that landed on the
knife-edge while crossing the discontinuity" as with "a hidden band." A REAL band = a CLUSTER of
moderate-Fano points, not a solitary one. So the corner sweep is reframed as a **two-hypothesis
adjudication with the VOID as the null**, plus the plateau test + the E/I mechanism probe.

---

## Session 3 (cont.) — 2026-07-06 — PRE-REGISTERED: the t4-corner sweep (band vs void; E/I test)

**Locked before data (so no post-hoc wriggle).** Built `tools/sweep_t4.ps1` (build+run 9 points) +
`tools/sweep_report.py` (Fano/CV + m̂-plateau adjudicator). Web-Claude's three sharpenings, all adopted:
- **(a) PLATEAU TEST:** a genuinely critical point shows m̂ **FLAT** across bins around the generation
  scale (scale-invariance); pure m^b decay (large spread) = no scale-invariant regime = artifact.
  Report m̂@{3,5,7,10} + spread for every point. Cleaner than m̂ at any single bin.
- **(b) TWO HYPOTHESES, void = null:** **H0** = t4 isolated → no stable asynchronous-irregular (AI)
  regime → "insufficient mechanism" CONFIRMED with a cleaner instrument → E/I-stabilization mandate.
  **H1** = a CLUSTER of Fano 2–200 + flat-plateau points fills in near t4 → real under-explored band.
  If t4 comes back alone, **that is the finding, not a null to explain away.**
- **(c) E/I actuator, σ-homeostat DEMOTED:** the near-discontinuous Poisson→synchrony void is the
  signature of a system with no stable AI fixed point — what fast feedback inhibition (ISN/Mackwood)
  creates. Per-neuron gain can't fight synchronization (wrong actuator; best case cramped, worst case
  oscillates). **Sweep axis C tests this directly:** at seizing W_EXC=9, raise W_INH 4→10→16 — if
  rising inhibition drags Fano DOWN into the band, the missing actuator is inhibition, not gain.

**Sweep plan (t4 base W_EXT=80/W_MAX=20/STD_U=0.2/TAU_REC=400, seed 1234):**
Axis A recurrence: `x_we{3,4,5,6,9}` (W_INH=4, ν=100) — does Fano climb through a band or jump?
Axis C E/I rescue: `x_we9_wi{10,16}` — does inhibition open a band at seizing recurrence?
Axis B drive: `x_we4_nu{50,150}`. Adjudicate with `sweep_report.py` (+ `plfit` on candidates).
**No contract / verdict change; pure exploration.** Launched as a background build+run (~30 min).

**RESULT — H1 REJECTED, the void is confirmed and sharpened (letting the negative be the finding).**
| point | meanA | CV | Fano | maxA/N% | m̂@3/5/7/10 | plateau |
|---|---|---|---|---|---|---|
| x_we3 (=t4) | 236 | 0.69 | **112** | 0.73 | 0/.998/.992/.974 | FLAT(.024) |
| x_we4 | 357 | 1.19 | 502 | 1.9 | 0/.996/.988/.970 | FLAT(.026) |
| x_we5 | 468 | 1.28 | 765 | 1.9 | 0/.996/.988/.972 | FLAT(.024) |
| x_we6 | 592 | 1.41 | 1178 | 3.1 | 0/.990/.982/.966 | FLAT(.024) |
| x_we9 | 1311 | 2.31 | **7004** | 9.5 | .992/.972/.958/.938 | slope(.054) |
| x_we9_wi10 | 1312 | 2.31 | 7026 | 9.3 | (identical to we9) | slope |
| x_we9_wi16 | 1306 | 2.38 | 7418 | 9.8 | (identical to we9) | slope |

1. **No reverberating band.** Recurrent Fano FLOORS at ~112 (t4/x_we3) and climbs SMOOTHLY to 7004 as
   W_EXC 3→9 (not a knife-edge). The gentle band (Fano 2–20) is empty; below the ~112 floor you fall
   to the Poisson dead-line (Fano 1). t4 = the least-bursty point of an ALWAYS-bursty recurrent branch,
   **not** a hidden critical corner. "Under-explored, not absent" was the hopeful read; refuted.
2. **t4 not critical.** `plfit` on x_we3 REFUTES a clean power law (KS=0.312, MID-tail curvature =
   systematic, not dragon-kings); IEI=1/gap-less anyway ⇒ avalanche frame is the wrong instrument.
   Fano+plateau were right: "moderately bursty," not "critical."
3. **E/I test NULL — and verified why.** W_INH 4→10→16 ⇒ BYTE-IDENTICAL operating points (Fano
   ~7000, meanA 1310, same m̂). Cause (sim.cu:107–110): forward-only iSTDP sets `dw=η·(x_trace−α)`,
   driving inhibitory weight to the RATE target ⇒ washes out W_INH_INIT over 20 s. **Static inhibitory
   GAIN is not a lever; rate-homeostasis nullifies it.**

**VERDICT: insufficient-mechanism negative CONFIRMED with the trustworthy instrument, and named:** the
recurrent dynamics are INTRINSICALLY SYNCHRONIZING; the rate-homeostatic inhibition already present
produces a bursty E/I balance it cannot desynchronize. **Missing ingredient = a DESYNCHRONIZING
mechanism** — and NOT "more inhibition gain" (nullified). Candidates for the Phase-1 mandate: (i)
faster/effective feedback inhibition not slaved to rate, (ii) spike-frequency adaptation (per-neuron
self-limiting breaks population synchrony), (iii) iSTDP retargeted onto a synchrony/variance signal.
The σ-homeostat (per-neuron gain) is doubly wrong. Contract-touching build ⇒ operator approval +
web-Claude design read before implementing. Manifest: +`tools/sweep_t4.ps1`, +`tools/sweep_report.py`,
9 new `run/x_we*` dirs. No contract / verdict-code change. (Held the line: did NOT sweep-one-more-corner
to chase the band — the void is the finding.)

**FOLLOW-UP — candidate (ii) spike-frequency ADAPTATION tested via existing D_SCALE knob (no contract): REJECTED.**
`tools/sweep_dscale.ps1` (D_SCALE scales Izhikevich adaptation jump d; baseline exc 8→2, inh 2; >1 =
stronger SFA). Dose-response, `sweep_report.py`:
| base | D_SCALE 1→8 Fano | meanA 1→8 |
|---|---|---|
| x_we6 | 1178→964→866→848→729→**702** | 592→…→236 |
| x_we9 (seizer) | 7004→1985→**1443** | 1311→368 |
| x_we3 (floor) | 112→256→**316** (UP!) | 236→187 |
1. Weakly dampens extreme synchrony (seizer 7004→1443 ~5×; we6 1178→702) but **never reaches the 2–20
   band** (best ~700, 35× too high) and **drags activity toward death** (meanA halves) — no alive-in-band
   window. 2. On the LEAST-bursty base adaptation **INCREASED** Fano (112→316): its slow timescale
   *promotes* population synchrony — not even a clean desynchronizer. ⇒ **SFA-magnitude is not the fix.**

**⇒ NO-CONTRACT LEVERS EXHAUSTED.** Recurrence, drive, static inhibition-gain (iSTDP-nullified), and
adaptation-magnitude ALL tested; none open the void. The void is structural, confirmed FOUR ways. The
desynchronizer must now be a **contract-touching mechanism**: **(i) fast feedback inhibition decoupled
from rate-iSTDP** (my lean — inhibition is the actuator but static gain is washed out, so it needs SPEED
+ a controller not slaved to the rate target) or **(iii) synchrony-retargeted iSTDP**. Manifest:
+`tools/sweep_dscale.ps1`, `sweep_report.py` takes labels via argv, 9 new `run/d{3,6,9}_ds*` dirs.
**GATE: next step touches sim.cu (likely brain.h) ⇒ operator approval + web-Claude design read FIRST.**

---

## Session 4 — 2026-07-25 — THE VOID WAS AN ARTIFACT: the rate homeostat had no authority

**Intent.** Get bearings after an 18-day gap, verify the recorded position against disk, and — before
building the mandated contract-touching desynchronizer — check the one pillar it rests on: the E/I null.

**Bearings (verified, not recalled).** Nothing had moved since 2026-07-07. `bp_validate.py` passes
(recovers m∈{0,.5,.8,.98,1} clean + under drift, 0.000 on dead); `sweep_report.py` reproduces the t4 table
exactly (Fano floor 112 → 7004). The recorded position was real. Two things the handoff omitted: QC-H1/H2
were still unfixed, and `MODULE.md` §5 still encodes the *old contradictory* Gate B that Session 3 retired
in practice — canon and practice have diverged, so "done" is currently undefined.

**Two hypotheses formed and one killed before spending compute.**
1. *Granularity.* `sweep_log.csv` has `TARGET_OUTDEG=100` and `LAMBDA_UM=150` in **all 32 rows** — never
   swept. Unitary EPSP = `dt·w/(1−e^{−dt/τ_syn})` = **15.2 mV** at W_EXC=3 against a **20 mV** rest→threshold
   gap (Izhikevich RS: v_rest −70, v_thr −50), with only ~5.5 concurrent inputs vs ~200 in cortex. Looked
   like the answer. **Tested and REJECTED:** single Izhikevich cell, exact `sim.cu` integration, balanced
   E/I input bisected to 10 Hz → **CV_ISI 0.948 at K=100**. Irregular firing is perfectly reachable at the
   current granularity. A large K-sweep was saved by a 3-minute test.
2. *Controller authority.* Of the 9 knobs `CLAUDE.md` names for the Gate B search, only 4 were ever varied.
   `RHO0_HZ`, `ISTDP_ETA`, `GAIN_ETA`, `LAMBDA_UM`, `TARGET_OUTDEG` are **constant in all 32 rows** — and
   the first three are precisely the homeostatic-authority knobs. Nothing in the run output could reveal
   whether the controllers were saturated, so it had never been observed either way. **This was the one.**

**Manifest (no contract change; `brain.h`/`MODULE.md` untouched).**
- `sim.cu` — I4 guard rewritten: explicit clamp, and **clamped before the `u`-update** (QC-H2, a real bug:
  the old order fed a diverged `v` into `u += dt*(a*(b*v−u))` and never guarded `u`, so `u` could latch at
  ±Inf while the `v`-guard re-fired the neuron forever). `u` now clamped too.
- `config.h` — `V_FLOOR_MV`/`U_FLOOR`/`U_CEIL` (not knobs) + `CTRL_PROBE_EVERY`.
- `main.cu` — `probe_controllers()`: mean/min/max `w_inh`, `gain` + rail occupancy, `<D>` split E/I, and the
  actual E vs I drive in mV/ms. Host-side, ~5 D2H copies/run, no new kernel.
- `tools/sweep_ei.ps1` (8 pts), `tools/sweep_drive.ps1` (4 pts), `RELAY_EI_ANOMALY.md`.

**QC-H1 REFUTED empirically.** The review's HIGH-severity suspicion — `-use_fast_math` folds `isfinite()`
to `true` and deletes the guard — is **false on this toolchain**. PTX for sm_89 under CUDA 13.1 still emits
`abs.ftz.f32` + `setp.geu.ftz.f32` + `selp.f32` with fast-math. **Prior results carry no unguarded-
divergence risk from this cause.** `CLAUDE.md` "Known risks" and `QC_REVIEW_2026-07-07.md` H1 should be
updated to record this. The clamp was kept anyway (equivalent, toolchain-independent, and it is what makes
the H2 reordering expressible; it also maps NaN to the floor instead of manufacturing a spike at +30).

**A correction to my own opening argument.** I claimed the recorded explanation of the E/I null ("iSTDP
washes out `W_INH_INIT`") was numerically impossible, computing Δw ≈ 0.3 over a 20 s run at t4. **Measured:
`w_inh` 4.0 → mean 8.07.** Wrong by ~13×, because iSTDP samples `x_trace[j]` at *presynaptic* spike times —
in a bursting network exactly when postsynaptic traces are elevated — and because the 100 Hz startup
transient does much of the accumulation. The objection was wrong; the instrument built to test it found the
real mechanism, which is neither account.

**RESULT 1 — the E/I null was a CEILING artifact.** `e_w9_ctl` (the exact settings behind every logged
result) ends with **`w_inh` = 19.997 against `W_MAX` = 20.000. Railed.** That is the entire explanation of
"W_INH 4→10→16 ⇒ identical": iSTDP drove all three initial values into the same ceiling. The Session-3
conclusion — *"static inhibitory gain is not a lever; rate-homeostasis nullifies it"* — was too strong.
Correct statement: **inhibitory weight was saturated at its ceiling, so neither its initial value nor any
increase could register. Inhibition was never tested; it was clamped.** `e_t4_ctl` further shows the network
sitting at **8.5 Hz against a 3 Hz target with gain railed low on 99.9 % of neurons** — both controllers out
of authority, at every operating point in the entire bracket history.

**RESULT 2 — the Fano void is FILLED, by no-contract knobs.** Crossing `ISTDP_ETA` × `W_MAX` at both bases:

| point | eta | W_MAX | w_inh | I/E | rate E | meanA | CV | **Fano** |
|---|---|---|---|---|---|---|---|---|
| e_t4_ctl | .005 | 20 | 8.07 | 1.02 | 8.5 | 236.6 | 0.62 | **90.9** |
| e_t4_eta50 | .05 | 20 | 18.00 | 2.71 | 3.9 | 112.9 | 0.14 | **2.1** |
| e_t4_wi16 | .005 | 60 | 16.12 | 2.37 | 4.2 | 131.9 | 0.20 | **5.0** |
| e_w9_ctl | .005 | 20 | 20.00 railed | 0.69 | 59.4 | 1316.3 | 2.41 | **7631** |
| e_w9_wi16 | .005 | 60 | 34.69 | 1.08 | 23.7 | 609.5 | 1.53 | **1434** |
| e_w9_eta200 | .2 | 60 | 59.90 | 2.30 | 9.9 | 235.9 | 0.09 | **2.0** |

Fano **7631 → 2.0** at the seizing base, **90.9 → 2.1** at t4, alive throughout at 3.8–9.9 Hz. Graded
dose-response along inhibitory authority (`e_w9_wi16` = the intermediate 1434), not a jump.

**RESULT 3 — they are NOT the Poisson drive-floor.** m̂ across bin widths separates three regimes cleanly:
floor (`k1_nu400`) reads **0 at every width with 100 % of neurons silent**; seizers read 0 at fine bins (a
synchronous burst has no lag-1 structure) then rise on rebinning; **`e_t4_eta50` reads 0.996 at bin 1** —
genuine step-to-step propagation — with **0 % silent** and per-neuron rates centred on the 3 Hz target
(median 3.74, p05 1.93, p95 6.35).

**RESULT 4 — SELF-SUSTAINING at the strong-inhibition base; the weak one is drive-propped.** Pre-registered
drive knockdown (`sweep_drive.ps1`): `NU_EXT` 100 → 25 → 5, cutting external drive 0.800 → 0.200 → **0.040
mV/ms (20×)**.

| base | Fano @nu=100 | @nu=25 | @nu=5 | rate E (Hz) 100→5 |
|---|---|---|---|---|
| **e_w9_eta200** (W_MAX 60, eta .2) | 2.0 | 2.7 | **3.1** | 9.9 → 8.8 → 8.5 |
| e_t4_eta50 (W_MAX 20, eta .05) | 2.1 | 43.3 | **5550** | 3.9 → 2.9 → 3.8 |

The **w9/eta=0.2 base holds the band across the full 20× drive cut**. At nu=5 its recurrent excitatory
drive is **16.249 mV/ms vs 0.040 external — 99.75 % recurrent**. That is a genuinely self-sustaining
reverberating point, and it is the session's winner: `e_w9_eta200` / `k_w9e200_nu5`.

The t4/eta=0.05 base does **not**. Its *rate* holds (3.9 → 3.8 Hz) but the *regime* collapses back into
synchronized bursting (Fano 2.1 → 5550, maxA 11.4 % of the net). Its low-Fano state was partly propped up
by the independent per-neuron Poisson drive acting as an external desynchronizer; with `W_MAX`=20 it lacks
the inhibitory authority to hold an asynchronous state on its own. **Recorded as the partial it is — the
pre-registration said not to round this up, and it is not rounded up.** (I had called this base
"self-sustaining, proven" off the rate alone before the Fano landed; that was premature.)

**⇒ THE PHASE-1 MANDATE IS RETIRED.** "No-contract levers exhausted; the void is structural; the fix must be
a contract-touching desynchronizing mechanism" is **withdrawn**. The void was an artifact of an
under-powered rate homeostat. No `brain.h` change is needed, and the fast-inhibition mechanism should NOT
be built.

**FLAGGED — the plateau criterion may be backwards (do not use it to accept or reject until adjudicated).**
Pre-registered criterion (a) says a critical point shows m̂ **flat** across bins. But for a branching process
rebinning by B gives m̂(B) = m₁^B *by construction*, so flatness holds iff m₁ = 1 — the test accepts exactly
the seizing end. The data agrees: the only `FLAT` points in the whole sweep are the **bursty** ones (`x_we3`
Fano 112, `e_t4_ctl` Fano 91), while every in-band point reads `slope`. Propagating `m₁ = 0.996` from
`e_t4_eta50` to the ~5-bin generation scale gives **0.996⁵ = 0.980** — the Wilting–Priesemann reverberating
value. I am deliberately NOT relaxing an acceptance criterion in the direction of my own result; sent to
web-Claude for adjudication (`RELAY_EI_ANOMALY.md` §5).

**NOT claimed.** Not a Gate B pass — no point has been through the full battery, and by the letter of the
current plateau criterion every in-band point fails. CV_ISI (the per-neuron AI signature) is unmeasured —
needs a spike dump (`DUMP_LEN>0`); the CV in the tables is CV of `A_t`, a different quantity. The per-neuron
rate distribution is narrow (CV_rate 0.38 at `e_t4_eta50` vs 0.63 at `e_w9_eta200`) where cortex is
broad/lognormal — possibly the gain homeostat clamping everyone to one rate; **regulated is not critical**.

**NEXT (in order).** (1) Adjudicate the plateau criterion — it gates everything downstream. (2) Measure
CV_ISI + pairwise correlation on `e_t4_eta50`/`e_w9_eta200` via `DUMP_LEN` (the Phase-0.5 battery, and the
real AI test). (3) Resolve the canon/practice divergence: amend `MODULE.md` §5 + `analyze.py` to the
sustained frame — **contract change, needs operator approval**. (4) Then a proper sweep of the newly-opened
(`ISTDP_ETA` × `W_MAX` × `W_EXC` × `RHO0_HZ`) space for the best-conditioned reverberating point, logged to
`sweep_log.csv`. (5) `viz3d.py`/`animate.py` on the winner — the "watch it think" deliverable.


---

## Session 4 (cont.) — 2026-07-25 — AI BATTERY: the winner is genuinely asynchronous-irregular

**Intent.** Close the one evidence gap left by the E/I result. Fano and m̂ are *population*
statistics — neither can see whether individual neurons fire irregularly or whether pairs are
decorrelated, and those are the two defining properties of the asynchronous-irregular (AI) state.
A network of out-of-phase metronomes would score a perfect Fano while being the opposite of cortex.

**Manifest.** +`tools/airegime.py` (CV_ISI, pairwise spike-count correlation vs its finite-sample
noise floor, per-neuron Fano, near-vs-far pair split), +`tools/sweep_dump.ps1` (3 points with
`DUMP_LEN=40000` — a 4 s all-spike window starting at 10 s). No contract change.

**RESULT — the winner passes every AI axis, and the seizing control fails every one.**

| metric | **d_w9e200_nu5** (99.75 % recurrent) | d_w9e200_nu100 | d_w9_ctl (seizing) | Poisson | cortex |
|---|---|---|---|---|---|
| CV_ISI exc (mean / median) | **0.907 / 0.825** | 0.844 / 0.765 | 3.558 / 3.548 | 1.0 | 0.8–1.2 |
| CV_ISI inh | **1.006 / 0.995** | 0.983 / 0.976 | 3.137 / 3.119 | 1.0 | — |
| % exc in [0.7, 1.3] | **59.0 %** | 53.2 % | 0.1 % | — | — |
| pairwise r, all pairs | **+0.0005** | +0.0004 | +0.3214 | 0 | 0.01–0.1 |
| pairwise r, same column | **+0.0470** | +0.0265 | +0.8812 | 0 | — |
| pairwise r, distant | −0.0001 | +0.0001 | +0.3000 | 0 | — |
| per-neuron Fano (100 ms) | **1.021 / 0.890** | 0.867 / 0.736 | 8.335 / 7.944 | 1.0 | — |

Three things worth stating precisely:

1. **The correlation distribution is indistinguishable from independent spike trains.** Observed
   sd of r = 0.0513 against a finite-sample noise floor of 1/√(nbins−1) = 0.0501. Only the *mean*
   carries information at this sample size, and it is +0.0005. There is no hidden synchrony —
   this is not a smooth population rate hiding locked neurons.
2. **Removing the drive made it MORE cortex-like, not less.** nu=100 → nu=5 moves CV_ISI
   0.844 → 0.907, per-neuron Fano 0.867 → **1.021**, and same-column correlation
   0.0265 → **0.0470**. The external Poisson drive was *masking* the network's own spatial
   correlation structure; the intrinsic dynamics are more irregular than the driven ones.
3. **The modular connectome is doing work.** Correlation is +0.047 within a column and −0.0001
   beyond 875 µm — a real, distance-dependent structure (the near-pair mean has standard error
   0.0007 over 5,082 pairs, so it is ~65σ from zero), and it is in the cortical 0.01–0.1 range
   while the global average sits at zero, exactly as in the awake asynchronous state.

The seizing control is the perfect foil: **88 % correlated within a column, 30 % correlated across
the whole 3.5 mm volume**, CV_ISI 3.6, per-neuron Fano 8.3, and 0.1 % of neurons irregular.

**⇒ `e_w9_eta200` / `k_w9e200_nu5` = {W_EXC 9, W_INH 4, W_MAX 60, ISTDP_ETA 0.2, W_EXT 80, STD_U 0.2,
TAU_REC 400, NU_EXT 5–100} now satisfies:** self-sustaining across a 20× drive knockdown (99.75 %
recurrent) · Fano 2.0–3.1 (the previously-empty band) · m̂ ≈ 0.98 at the generation scale ·
CV_ISI 0.91 exc / 1.01 inh · pairwise r ≈ 0 global, 0.047 within-column · per-neuron Fano ≈ 1.0 ·
0 % silent neurons. **This is the reverberating regime the project has been hunting since Session 1.**

**NEW GAP FOUND — the slow controller is still railed, so Gate B's two-controller clause is NOT met.**
The `[ctrl]` readout at the winner reads `gain 0.508 (railed lo 88.2%)`. The operating point is held
by iSTDP essentially alone; the per-neuron gain controller is pinned at `GAIN_MIN` on ~9 of 10
neurons. MODULE.md §5 requires the state be "held by ≥2 controllers on separated timescales," so a
point held by one saturated controller is a *tuned* point, not a self-organised one. Diagnosis:
W_EXC=9 gives a unitary PSP of **45.5 mV against a ~20 mV threshold gap** — one presynaptic spike is
suprathreshold — and gain rails at 0.5 trying to divide that down. Launched `tools/sweep_gain.ps1`
(axis A: lower W_EXC; axis B: widen the gain floor). `GAIN_MIN`/`GAIN_MAX` were plain `#define`s and
therefore unsweepable — now `#ifndef`-guarded and marked `[KNOB]`, **defaults unchanged**.

**Still not claimed.** Not a Gate B pass: (i) the two-controller clause is unmet pending
`sweep_gain`; (ii) the plateau criterion remains flagged as possibly backwards and is out for
adjudication; (iii) `MODULE.md` §5 still specifies the *old contradictory* battery (avalanche
τ≈1.5 + crackling + shape-collapse) that Session 3 retired in practice, so there is no coherent
written definition of "done" to pass. Resolving (iii) is a **contract amendment requiring operator
approval** and is now the critical path — the physics is in hand well before the paperwork.


---

## Session 4 (cont.) — 2026-07-25 — CONTROLLER AUTHORITY: both homeostats off their rails

**Intent.** Close the gap the AI battery exposed: the winner was held by iSTDP essentially alone
(`gain 0.508, railed lo 88.2%`), so Gate B's "held by ≥2 controllers on separated timescales" was
not met. A regime held by one saturated controller is a *tuned* point, not a self-organised one.

**Manifest.** +`tools/sweep_gain.ps1` (6 pts), +`tools/sweep_headroom.ps1` (3 pts). `config.h`:
`GAIN_MIN`/`GAIN_MAX` and `N_STEPS` were plain `#define`s and therefore unsweepable — now
`#ifndef`-guarded and marked `[KNOB]`, **defaults unchanged**. No contract change.

**RESULT 1 — a better point, and the flattest plateau in the project's history.** Axis A (lower
`W_EXC` so a unitary PSP stops being suprathreshold) monotonically frees the gain controller:
rail occupancy **88.2 % (W_EXC 9) → 65.8 % (5) → 51.5 % (4) → 34.6 % (3)**. The drive-independent
check `g_we5_nu5` = {W_EXC 5, W_MAX 60, ISTDP_ETA 0.2, NU_EXT 5} is the standout:

| property | value | target |
|---|---|---|
| m̂ @ bins 3/5/7/10 | 0.988 / **0.980 / 0.980 / 0.980** → **FLAT(0.008)** | ≈0.98, flat |
| Fano | 3.5 | 2–20 |
| CV_ISI exc / inh | 0.848 / 0.866 | ≈1 |
| pairwise r all (sd 0.0359 vs noise floor 0.0354) | +0.0004 | ≈0 |
| pairwise r same-column | +0.0176 | 0.01–0.1 |
| per-neuron Fano (100 ms) | 1.007 | ≈1 |
| recurrent fraction | 99.2 % (4.976 vs 0.040 mV/ms) | self-sustaining |
| rate vs RHO0 | 3.4 vs 3.0 Hz | on target |

**MY PLATEAU-CRITERION OBJECTION WAS WRONG — refuted by data, recorded as a near-miss.** I had
argued (and written into the relay brief) that criterion (a) was mis-specified because rebinning
gives m̂(B) = m₁^B, so flatness would hold only for m₁ = 1 and the test would accept exactly the
seizing end. `g_we5_nu5` reads **flat at 0.980, not 1.0** — so flatness does not require m₁ = 1,
the AR(1) argument was too naive (the MR estimator fits `r_k = b·m^k + c` across lags and is
genuinely bin-robust when the autocorrelation has a clean exponential timescale), and **the
criterion stands as written**. The earlier in-band points read `slope` because they really were
less scale-invariant. I came within one point of relaxing an acceptance criterion in the direction
of my own result; the only thing that stopped it was the criterion turning out to be satisfiable.

**RESULT 2 — the controller timescales, measured.** `k_homeostatic_gain` runs 100×/s and moves
`gain` by `GAIN_ETA·(RHO0−r)` each time. At a 0.7 Hz error that is **0.0070/s — at most 0.14 over
an entire 20 s run.** iSTDP's per-spike increment is `η(x_trace−α)`: **+0.0028 at 3.7 Hz but
+0.3880 during the 100 Hz startup transient, a 140× ratio.** So both controllers do the bulk of
their work in the first ~1 s and are near-frozen afterwards. Consequence: **`N_STEPS`=200 000 is
too short to assess the two-controller clause at all** — hence the new `[KNOB]` guard.

**RESULT 3 — BOTH CONTROLLERS OFF THEIR RAILS.** `sweep_headroom` at the `g_we5_nu5` base:

| point | W_MAX | GAIN_MIN | w_inh (of cap) | gain (railed lo) | rate E | Fano | plateau |
|---|---|---|---|---|---|---|---|
| g_we5_nu5 | 60 | 0.5 | 59.3 (**99 %**) | 0.614 (29.4 %) | 3.4 | 3.5 | FLAT(0.008) |
| h_wm120 | 120 | 0.5 | 105.6 (88 %) | 0.593 (39.4 %) | 3.7 | 2.2 | slope(0.098) |
| h_wm120_gmin01 | 120 | 0.1 | 105.8 (88 %) | 0.419 (**4.4 %**) | 3.3 | 10.9 | FLAT(0.018) |
| **h_wm200_gmin01** | 200 | 0.1 | **120.6 (60 %)** | **0.418 (4.3 %)** | **2.9** | 11.6 | FLAT(0.026) |

`h_wm200_gmin01` has **neither controller railed** — `gain` regulating on 95.7 % of neurons,
`w_inh` at 60 % of its ceiling with headroom left — and the rate converges to **2.9 Hz against the
3.0 Hz `RHO0` target**, while staying in-band (Fano 11.6), flat-plateau (0.984/0.966/0.958/0.978)
and 99.2 % recurrent. Inhibitory neuron rate also fell 7.4 → 3.6 Hz, i.e. the I population is now
regulated to target too rather than running 2× hot.

**A correction to my own intermediate read.** After `h_wm120` I wrote that iSTDP "consumes whatever
ceiling it is given" and that the operating point was set by the transient rather than a converged
equilibrium. `h_wm200_gmin01` refutes the strong form: given a high enough cap **and** a gain
controller with room below it, `w_inh` settles at 60 % of the ceiling and the rate lands on target.
The binding constraint was the **gain floor** (`GAIN_MIN`=0.5), not the controllers' speed. The
speed arithmetic in Result 2 is still correct and still means 20 s is too short to *verify* this.

**NEXT.** Running `L_wm200_100s`: 100 s (`N_STEPS`=1 000 000) at `h_wm200_gmin01`, with `[ctrl mid]`
now reporting every 25 s for a convergence trace, plus a spike dump over 90–98 s to confirm the AI
battery survives at Fano 11.6. Then: (1) `GAIN_ETA` is the last never-swept authority knob
(1.0e-4 in all 32 logged rows); (2) **amend `MODULE.md` §5** — it still specifies the old
contradictory battery, so there is no coherent written definition of "done" for these points to
pass. That is a contract change and the critical path; the physics is ahead of the paperwork.


---

## Session 4 (cont.) — 2026-07-25 — 100 s RUN: converged, stationary, CV_ISI median 1.000

**Intent.** Two questions in one run. (a) Was `h_wm200_gmin01`'s two-controller equilibrium real, or
was it still drifting at the 20 s cutoff? (b) Does the AI state survive at Fano ~11.6, measured after
the controllers have fully settled? `L_wm200_100s` = `h_wm200_gmin01` at `N_STEPS`=1 000 000 (100 s,
5× the default), `[ctrl mid]` every 25 s, spike dump over 90–98 s.

**RESULT A — converged and stationary.** The `[ctrl]` trace over the last 75 s:

| t | w_inh (cap 200) | gain (railed lo) | rate E | rate I | I/E drive |
|---|---|---|---|---|---|
| 25 s | 120.778 | 0.414 (4.6 %) | 3.1 | 3.7 | 6.86 |
| 50 s | 121.509 | 0.414 (4.6 %) | 3.4 | 4.0 | 6.78 |
| 75 s | 122.231 | 0.411 (4.6 %) | 3.3 | 3.9 | 6.88 |
| 100 s | 122.945 | 0.412 (4.6 %) | 3.3 | 4.0 | 6.89 |

`w_inh` drifts **+1.8 % over 75 s** and sits at 61 % of its ceiling; `gain` is flat to three decimals
with **4.6 % rail occupancy**; both rates and the I/E ratio are stationary. This is a genuine
homeostatic steady state held by **two unsaturated controllers**, not a transient and not a drift.
Timing: 5 127 steps/s, **real-time factor 0.51×**.

**RESULT B — the AI signatures got BETTER after settling.** Battery at t = 90–98 s vs the same point
measured at 20 s:

| metric | **L_wm200_100s (90–98 s)** | g_we5_nu5 (20 s) | Poisson | cortex |
|---|---|---|---|---|
| CV_ISI exc mean / **median** | **1.058 / 1.000** | 0.848 / 0.771 | 1.0 | 0.8–1.2 |
| CV_ISI inh | 0.986 / 0.989 | 0.866 / 0.842 | 1.0 | — |
| **% exc in [0.7, 1.3]** | **81.4 %** | 56.7 % | — | — |
| pairwise r, all (sd vs floor) | +0.0028 (0.0376 / 0.0354) | +0.0004 | 0 | 0.01–0.1 |
| pairwise r, same column | +0.0353 | +0.0176 | 0 | — |
| pairwise r, distant | +0.0022 | +0.0002 | 0 | — |
| per-neuron Fano (100 ms) | 1.061 | 1.007 | 1.0 | — |
| population Fano | 9.4 | 3.5 | — | — |
| m̂ @ 3/5/7/10 | 0.988/0.978/0.978/0.992 **FLAT(0.014)** | FLAT(0.008) @0.980 | — | ≈0.98 |

**CV_ISI median = 1.000 exactly**, with **81.4 %** of excitatory neurons inside the cortical irregular
band (up from 56.7 %). Letting the controllers converge made the network *more* irregular, not less.
The correlation sd (0.0376) now sits slightly above the independent-train noise floor (0.0354),
i.e. there is a small amount of *genuine* structure beyond sampling noise — consistent with the
+0.0353 same-column / +0.0022 distant split. That is the modular connectome showing through, and it
is inside the cortical 0.01–0.1 range.

**⇒ THE FULL SUSTAINED-FRAME BATTERY IS MET ON A SINGLE POINT.**
`L_wm200_100s` = {N=200 000, W_EXC 5, W_INH_INIT 4, W_MAX 200, ISTDP_ETA 0.2, GAIN_MIN 0.1,
W_EXT 80, NU_EXT 5, STD_U 0.2, TAU_REC 400, seed 1234}:

- **near-critical:** m̂ ≈ 0.98, FLAT across bins 3–10 (spread 0.014) — the Wilting–Priesemann value
- **asynchronous:** pairwise r +0.003 global, +0.035 within-column, +0.002 distant
- **irregular:** CV_ISI median 1.000, 81.4 % of neurons in [0.7, 1.3]; per-neuron Fano 1.06
- **self-sustaining:** 99.2 % recurrent (5.042 vs 0.040 mV/ms external), 100 s with no drift
- **not seizing / not silent:** population Fano 9.4, maxA 0.09 % of N, 0 % silent neurons
- **held by ≥2 controllers on separated timescales:** gain 4.6 % railed and iSTDP at 61 % of ceiling,
  both stationary; rate 3.3 Hz against the 3.0 Hz `RHO0` target

**STILL NOT A DECLARED GATE B PASS, and this is the honest blocker.** `MODULE.md` §5 continues to
specify the *old contradictory* battery (avalanche τ≈1.5 + KS<0.1 + crackling + shape-collapse on
global silence) that the Session-3 reframe retired in practice but never amended, and `analyze.py`
still prints that verdict. **There is no coherent written criterion for this point to pass.** Amending
§5 to the sustained-frame battery above is a **contract change requiring operator approval** and is
now the sole critical path. The physics is done; the paperwork is not.

**NEXT.** (1) `MODULE.md` §5 amendment + `analyze.py` verdict restructure — needs approval, blocks
everything. (2) `GAIN_ETA` is the last never-swept authority knob (1.0e-4 in all 32 logged rows);
worth confirming the point is robust to it. (3) Seed-robustness: every result here is seed 1234.
(4) `viz3d.py` / `animate.py` on `L_wm200_100s` — the "watch it think" deliverable, now that there is
something worth watching. (5) `sweep_log.csv` has not been updated with any Session-4 point.


---

## Session 4 (cont.) — 2026-07-25 — MODULE.md §5 AMENDED (approved); seeds + GAIN_ETA close the robustness case

**Intent.** Apply the operator-approved contract amendment, then discharge the two caveats the
proposal itself listed as preconditions for any Gate B pass: seed-robustness (everything to date
was seed 1234) and `GAIN_ETA` (the last never-swept authority knob, 1.0e-4 in all 32 logged rows).

**Manifest (CONTRACT CHANGE — operator-approved).** `MODULE.md`: §5 replaced (5 clauses → **B1–B7**,
+ run-length clause + ≥3-seed clause), **§5.1 added** (retired avalanche clauses + the cost, stated
plainly, with the "does the sustained frame still owe a power-law statement" question recorded as
**OPEN**), §3 **I4** reworded to the property rather than the `isfinite` mechanism, §8 corrected to
record that the decisive knobs were controller *authority*. 93 insertions / 17 deletions; all
section headers intact. Rationale preserved in `MODULE_AMENDMENT_PROPOSAL.md`.
+`tools/sweep_gaineta.ps1`. No `brain.h` change.

**RESULT 1 — SEED ROBUSTNESS: all seven clauses on four independent seeds.** 100 s runs, seeds
{1234, 7, 99, 31337}:

| clause | requirement | 1234 | 7 | 99 | 31337 |
|---|---|---|---|---|---|
| B1 | 0.9 < m̂ < 1.02 | 0.978 | 0.978 | 0.978 | 0.980 |
| B2 | plateau spread < 0.03 | **FLAT 0.014** | FLAT 0.016 | FLAT 0.016 | FLAT 0.016 |
| B3 | Fano 2–20, maxA/N ≪ 1 % | 9.4, 0.09 % | 9.1, 0.09 % | 10.5, 0.09 % | 12.4, 0.09 % |
| B4 | \|r\| < 0.05 | +0.0028 | +0.0025 | +0.0024 | +0.0063 |
| B5 | CV_ISI med 0.8–1.2 / majority in band | 1.000 / 81.4 % | 0.932 / 81.7 % | 0.980 / 83.8 % | 0.920 / 78.1 % |
| B6 | recurrent ≫ external | 99.2 % | 99.1 % | 99.1 % | 99.2 % |
| B7 | gain railed < 20 %, stationary, rate on target | 0.412 / 4.6 % | 0.411 / 4.5 % | 0.417 / 4.4 % | 0.410 / 4.5 % |

`meanA` = **67.3–67.4** on all four; `w_inh` settles at 122.9–123.9 of a 200 cap on all four;
per-neuron Fano 1.000–1.061. This is a **regime, not a realisation** — the ≥3-seed precondition
in the amended §5 is discharged.

**RESULT 2 — GAIN_ETA: a bounded robust band, both pre-registered failure modes confirmed.**

| GAIN_ETA | gain (railed lo) | w_inh | rate E | meanA | Fano | plateau | verdict |
|---|---|---|---|---|---|---|---|
| 1e-5 | 0.544 (2.8 %) **still drifting** | 134.5 | **5.8** | 146.5 | 3.7 | slope(0.150) | **FAIL B2, B7** |
| **1e-4** | 0.413 (4.6 %) | 123.0 | 3.3 | 67.4 | 10.8 | **FLAT(0.012)** | PASS |
| **5e-4** | 0.413 (5.0 %) | 122.2 | 3.0 | 61.2 | 12.1 | **FLAT(0.004)** | PASS |
| **2e-3** | 0.399 (7.5 %) | 121.9 | 3.1 | 62.8 | 7.0 | **FLAT(0.008)** | PASS |
| 1e-2 | 0.364 (**18.8 %**) | 121.4 | 3.1 | 65.4 | 3.3 | slope(0.048) | **FAIL B2** |

**A 20× wide robust band (1e-4 → 2e-3) bounded on both sides**, with the certified point sitting
inside it rather than on a knife-edge — and both bounds are the ones predicted before the data:

- **Too slow (1e-5):** the controller is still monotonically descending at 100 s
  (gain 0.837→0.720→0.623→0.544 at t=25/50/75/100 s) with rate stuck at 5.8 Hz against the 3.0 Hz
  target. **This verifies the timescale arithmetic (0.0070/s at a 0.7 Hz error) rather than
  assuming it.**
- **Too fast (1e-2):** rail occupancy climbs to 18.8 % — right at B7's 20 % boundary — and the
  plateau degrades to slope(0.048). The timescale *separation* is collapsing: the "slow"
  controller becomes fast enough to compete with iSTDP instead of complementing it. Reported as
  an upper bound, not omitted.

The AI battery across the same band (B4/B5), which confirms the slow bound a *third* independent way:

| GAIN_ETA | CV_ISI median | % exc in [0.7,1.3] | r all | r near | per-neuron Fano | B4 | B5 |
|---|---|---|---|---|---|---|---|
| 1e-5 | **0.719** | **45.6 %** | +0.0002 | +0.0151 | 0.896 | ✅ | **FAIL** |
| 1e-4 | 1.030 | 82.9 % | +0.0040 | +0.0340 | 1.051 | ✅ | ✅ |
| 5e-4 | 0.990 | 78.3 % | +0.0026 | +0.0327 | 1.068 | ✅ | ✅ |
| 2e-3 | 1.004 | 70.1 % | +0.0014 | +0.0313 | 1.133 | ✅ | ✅ |
| 1e-2 | 1.087 | 72.1 % | +0.0005 | +0.0190 | 1.206 | ✅ | ✅ |

So `1e-5` fails **B2, B5 and B7** independently (median CV_ISI 0.719 is below the 0.8 floor and only
a *minority* of neurons are irregular — an unconverged slow controller leaves the network measurably
more clock-like), while `1e-2` fails **B2 alone**. Net: **passing region = 1e-4 … 2e-3**, with the
certified point ≥10× from the nearest failure below and 100× above.

**`gE_5e4` is arguably the better operating point than the certified `1e-4`:** rate exactly on the
`RHO0` target (3.0 vs 3.0 Hz), the flattest plateau in the entire project (**FLAT 0.004**), and the
most centred position in the band (50× above the slow failure, 20× below the fast one). Its only
blemish is the `m@10` estimator zero noted below. Worth considering as the headline point.

**A drafting note worth keeping.** `gE_1e5` has gain rail occupancy of only **2.8 %** — a
rail-occupancy test *alone* would have passed it. It fails only because B7 also requires
**stationary** and **rate on target**. Without those two conditions the clause would have been
too weak, and a still-converging controller would have counted as a settled one.

**Instrument nit (recorded, not swept under):** `gE_5e4` reads `m@10 = 0.000` while m@3/5/7 are
0.990/0.986/0.990 — the estimator's b-significance guard firing at that one bin width. The
plateau statistic ignores it, so the FLAT(0.004) verdict stands on 3/5/7, but the zero is an
estimator instability at a single bin, not a physical feature, and should not be quoted as data.

**STATUS.** Every clause of the amended §5 now holds on 4 seeds, with the operating point interior
to a 20× band in the last unswept knob. **Remaining before anyone writes "Gate B PASSED":**
(1) `tools/analyze.py` still prints the *pre-amendment* verdict (shape-collapse-primary + the stale
"IEI=1 → m̂ not trustworthy" caption) — the scorecard must be restructured to B1–B7 before it is
the auto-verifier §5 names; (2) `sweep_log.csv` has no Session-4 rows; (3) the §5.1 open question
(does the sustained frame owe a power-law statement?) is out to the web instance and is the one
place an outside read should land first. **The physics is done and robust; the verdict code is not.**


---

## Session 4 (cont.) — 2026-07-26 — analyze.py restructured to B1–B7; sweep log rebuilt

**Intent.** Close the contract/code disagreement the amendment created: §5 names `analyze.py` as the
auto-verifier, but `analyze.py` still implemented the *pre-amendment* battery. CLAUDE.md is explicit
that when code and contract disagree the contract wins and the code is fixed.

**Manifest.** `tools/analyze.py` restructured (B1–B7 scorecard, `[ctrl]`/`[knobs]` parsing, CLI
`[rundir] [--append]`, plots re-cut to B2 plateau + B7 controller trace). `tools/airegime.py`
refactored: computation extracted into `measure(rundir)` returning a dict, so `analyze.py` **imports**
B4/B5 rather than growing a second CV_ISI implementation that could drift from it. `src/main.cu`:
new `[knobs]` line. `sweep_log.csv` rebuilt on the B-schema; the pre-amendment log preserved intact
as `sweep_log_preB.csv`. No contract change (§5 was amended in the previous entry).

**Design decisions worth recording.**
- **A missing measurement is never a pass.** Clauses whose inputs are absent report `UNMEASURED`
  and the verdict is `INCOMPLETE`, not `PASS`. Every 20 s run without a spike dump therefore reads
  INCOMPLETE — correct, since B4/B5 are genuinely unmeasured there.
- **Retired ≠ deleted.** The avalanche/τ/KS/crackling/shape-collapse code still runs and prints,
  under an explicit "diagnostic only, NOT part of the verdict" header. §5.1 leaves open whether the
  sustained frame owes *some* power-law statement; deleting the code would foreclose answering it.
- **The historical log cannot be rescored, so it is not padded.** Pre-Session-4 rows came from
  binaries that printed no `[ctrl]` readout and dumped no spikes — B4/B5/B7 are unrecoverable for
  them. Preserved as `sweep_log_preB.csv` (the project's existing convention, cf.
  `sweep_log_preSTD.csv`) rather than back-filled with blanks that would later read as measurements.
- **`[knobs]` line in `main.cu`.** Session 4 lost substantial time to a knob that was never being
  varied (`TARGET_OUTDEG`, constant across all 32 logged rows) because nothing in a run's output
  stated what it was built with. Every run now records its full knob set; `analyze.py` parses it.
  Runs built before this fall back to what `[ctrl]` implies (W_EXC/W_INH/W_MAX directly, W_EXT from
  the external PSP, NU_EXT from the mean external drive) and leave the rest **blank rather than
  guessed**.

**A bug in my own clause, caught by running it.** B3's `maxA/N` was computed over the whole trace
and read **31.9 %** on the certified point — a FAIL — because the startup transient peaks near a
third of N on a *healthy* run. Every other B3 term was computed on the transient-dropped series;
this one was not. Fixed to use it, giving 0.078 %. Had I written the clause and not immediately run
it against a known-good point, the instrument would have failed everything.

**INSTRUMENT VALIDATION — the scorecard discriminates, and demonstrates its own necessity.**

| run | B1 | B2 | B3 | B4 | B5 | B6 | B7 | verdict |
|---|---|---|---|---|---|---|---|---|
| `L_wm200_100s` (certified) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **PASS** |
| `gE_1e5` (slow controller) | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ | FAIL |
| `d_w9_ctl` (seizing) | **✅** | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | FAIL |
| `d_w9e200_nu5` (right base, 20 s) | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | FAIL |

**The seizing control PASSES B1 at m̂ = 0.972.** That is the Session-3 finding ("m̂ cannot separate
reverberating from seizing; Fano can") now demonstrated live in the instrument's own output — and it
is why B3 exists. Under the pre-amendment battery, where the branching ratio was effectively the
primary certificate, a seizing network read as near-critical. Equally: `d_w9e200_nu5` is the *same
base* as a passing point but at 20 s, and fails B2/B7 — the run-length clause is load-bearing, not
bookkeeping.

**RESULT — `sweep_log.csv` rebuilt, 34 Session-4 runs scored.** Six PASS: `L_wm200_100s` and the
three seed replicas {7, 99, 31337}, plus `gE_1e4` and `gE_5e4`. All six are 100 s runs on the same
operating point; the seed replicas discharge §5's ≥3-seed clause and the two `gE_*` points sit
inside the GAIN_ETA robust band.

**NEXT.** (1) `viz3d.py` / `animate.py` on the certified point — the "watch it think" deliverable,
and the only Phase-0 artefact still outstanding. (2) The §5.1 open question (does the sustained
frame owe a power-law statement?) is out to the web instance and should land before anyone writes
"Gate B PASSED" without qualification. (3) Nothing is committed; the working tree carries the whole
of Sessions 1–4.


---

## Session 4 (cont.) — 2026-07-26 — "watch it think": the offline 3D view, on the certified point

**Intent.** Produce the last outstanding Phase-0 deliverable. MODULE.md §1: *"the deliverable is
measured self-sustaining criticality **plus an offline 3D view**."* The measurement half has been
done since the amendment; the view half had never been run on a point that passed.

**Manifest.** `tools/animate.py` loader switched to the pandas fast path (`np.genfromtxt` takes many
minutes on the multi-million-spike dumps the 100 s certification runs produce — same loader as
`airegime.py`). `tools/analyze.py` two plot fixes (below). Artefacts written into
`run/L_wm200_100s/` and `run/d_w9_ctl/`; `run/ai_vs_seizing.png`. No contract change.

**Two plotting defects found by looking at the output rather than trusting it.**
1. Panel 1 plotted `A_t` over the **first 2 s**. On a 100 s certification run the startup transient
   peaks near 30 % of N, so the y-axis was set by the transient and the entire settled regime was
   squashed into a flat line at the bottom — the plot showed nothing about the state being
   certified. Now plots a settled 2 s window from mid-run: activity fluctuating 20–120 around a
   mean of 67, which is what the reverberating regime actually looks like.
2. Panel 3 drew a bare exponential `r_k[0]·m^k` while the estimator fits **`r_k = b·m^k + c`** (the
   offset `c` absorbs the stationary drive floor — that is one of the three fixes that made the
   estimator trustworthy in the first place). The drawn line visibly diverged from the data and
   misrepresented the fit quality. Now refits `b,c` given `m` and draws the actual fitted curve,
   which tracks the data closely. A plot that misdraws its own fit is an instrument-honesty bug,
   not cosmetics.

**Artefacts (certified point `L_wm200_100s`, seed 1234, 100 s, all seven clauses PASS):**
- `brain3d.html` (9.0 MB) — interactive offline 3D view, 40 k of 200 k neurons, rotate/zoom, colour
  by module / firing rate / E-I. **This is the §1 "offline 3D view" deliverable.**
- `firing.gif` (18.0 MB, 160 frames, 25 k neurons) and `firing_small.gif` (8.7 MB, 100 frames) —
  the firing dynamics over the settled window t = 90–98 s.
- `criticality.png` — B1 fit, B2 plateau, B7 controller trace, settled activity.
- `pointcloud.png` — mean firing rate in 3D; visibly uniform, 0–7.5 Hz, no hot or dead regions.

**THE CONTRAST — `run/ai_vs_seizing.png`.** Same renderer, same frame index, certified point vs the
seizing control `d_w9_ctl`:

| | certified `L_wm200_100s` | seizing `d_w9_ctl` |
|---|---|---|
| CV_ISI | 1.00 | 3.55 |
| pairwise r | +0.003 | +0.321 |
| Fano | 7.2 | 7631 |
| **what you see** | sparse scattered flashes, mostly dim, no wave | the whole volume blazing at once |

The visual and the statistics agree completely, which is the point of producing it: the numbers said
asynchronous-irregular versus synchronized bursting, and that is exactly what the two animations
show. Worth keeping as the single most legible artefact of the session — the project's own vision
sentence is *"watch it think, never dies,"* and the seizing control is what "watching it seize"
looks like for comparison.

**STATUS — every Phase-0 deliverable now exists.** Measured self-sustaining criticality (B1–B7 on
4 seeds, interior to a 20× band in the last unswept knob) **and** the offline 3D view. Remaining
before an unqualified "Gate B PASSED": the §5.1 open question (does the sustained frame owe some
power-law statement?) is out to the web instance — the one place the bar was changed rather than
cleared. Nothing is committed; the working tree carries Sessions 1–4.


---

## Session 4 (cont.) — 2026-07-26 — BLUEPRINT cross-reference: 2 of 3 spatial signatures present; ISN untested; the certified point is FRAGILE

**Intent.** Cross-reference the certified point against `FINAL_BLUEPRINT.md` (§2.5 five-layer
homeostatic stack, §5 phased build path, §7.4 acceptance battery) and run the two blueprint
clauses that could still overturn the pass.

**Manifest.** +`tools/spatial.py` (assemblies, metastability, travelling waves), +`tools/paradox.py`
+ `tools/sweep_paradox.ps1` (ISN paradoxical-effect test), `config.h` PARADOX_* knobs, `sim.cu`
compile-time-gated injection into the inhibitory population, `main.cu` `[knobs]` extended. No
contract change.

### THE CROSS-REFERENCE — six gaps

1. **The contradiction is in the BLUEPRINT, not just MODULE.md.** §7.4 demands avalanche α≈1.5,
   β≈2.0, crackling and shape-collapse *and* §2.5 targets the reverberating m≈0.98 regime, which
   is never silent and in which those statistics are undefined. This is the same incompatibility
   Session 2 found in Gate B — **it originates in the north-star document.** §5.1's open question
   is therefore a blueprint-level question, and that is the framing to put to the web instance.
2. **NFR-perf MISSED.** MODULE.md §6 demands "far past real time", ≥10 000 steps/s. The certified
   point runs **5127 steps/s, real-time factor 0.51×**. Nobody had called this. §6 says the naive
   scatter is measured in Phase 0 precisely to set the baseline Morton must beat — that baseline
   now exists and it is a miss.
3. **Coupling is 12.6× the blueprint's prescription.** §2.5 specifies strong-sparse balance
   `J_E ≈ (V_th−V_rest)/√K` = 20/√100 = **2.0 mV**; we run a unitary EPSP of **25.3 mV**, with
   `g = w_inh/w_exc = 24.6` against the prescribed 4–8. We pass the AI battery anyway. This is the
   same axis as the granularity hypothesis I killed on single-neuron CV_ISI evidence — the
   blueprint independently prescribes that scaling, which is reason to hold that rejection loosely.
4. **Three blueprint stabilizers absent:** cross-homeostasis (Mackwood 2022, called "the single
   most important stabilizer upgrade… load-bearing"), fast inhibition τ_I < τ_E, and the global
   circuit-breaker. **Notable: the authority fix reached the AI state without any of them.**
5. **Never measured:** paradoxical effect, travelling waves, metastable switching, small-world
   index, Rent's p. (Only Q = 0.707 was reported.) Items 1–3 of these are addressed below.
6. **Fence conflict, flagged not resolved.** Blueprint Phase 0 includes "the 1-day CSR-vs-RT
   routing micro-benchmark [VALIDATE B1]"; CLAUDE.md's phase fence bars RT/OptiX from Phase 0.
   CLAUDE.md wins (the blueprint is "context, not the work order") so it was NOT built — but the
   two documents disagree about a Phase-0 deliverable and that is the operator's to settle.

### RESULT A — spatial structure: 2 of 3 present (`tools/spatial.py`, no new runs)

| signature | certified `L_wm200_100s` | verdict |
|---|---|---|
| assembly structure | near-module r **+0.302**, far +0.030, noise floor 0.050 | **PRESENT** (6× floor) |
| metastability | ACF excess over surrogate **+0.188 @100 ms, +0.103 @200 ms**, −0.037 @500 ms | **PRESENT** |
| travelling waves | significant pairs 57.8 %, implied velocity 13 µm/ms vs axonal 300 | **ABSENT** |

**This matters for §5.1.** Metastability is the blueprint's *other* named defence against "the
soup," and it holds **independently of the avalanche clause that was retired.** The per-neuron
pairwise correlation of +0.003 could not resolve any of this; averaging ~390 neurons per column
lifts it out.

**A false positive I caught in my own tool.** The first version reported travelling waves PRESENT
at +69 ms/mm. Artifact: near pairs are genuinely correlated and peak at zero lag, far pairs are
uncorrelated so their argmax is uniform over the scan window — regressing |lag| on distance
manufactures a positive slope from that gradient alone. Tells: mean |lag| 214 ms against 250 ms
for pure noise, and an implied velocity 23× slower than axonal conduction. Fixed with a
significance filter on the peak plus a velocity sanity bound, and a short-trace guard (the seizing
control's dump was 95 bins against a ±25-bin lag scan — its wave number was never trustworthy).

### RESULT B — ISN paradoxical effect: UNTESTED, and two invalid designs on the way

Final (paired, trial-averaged, 20 pulses each compared to its own preceding baseline):

```
control  (INJ=0)    inh +0.243 +/- 0.318 Hz        <- intrinsic fluctuation floor
r_inj0p1 (INJ=0.1)  inh -0.205 +/- 0.576  z=-0.4   10/20 trials voided (exc collapse)
r_inj0p3 (INJ=0.3)  inh +0.891 +/- 0.564  z=+1.6   15/20 trials voided
```

Neither clears 2σ. **The ISN claim is UNTESTED, not refuted.** The intrinsic fluctuation floor is
as large as any perturbation small enough to stay in the linear regime.

**Two invalid designs, both caught by running them:**
- *Cross-build comparison is meaningless here.* Four runs that should have been bit-identical
  before the injection had baselines of 3.06 / 2.25 / 3.61 / 3.35 Hz. Adding the injection branch
  perturbs codegen and a chaotic balanced network then diverges completely within seconds. All
  comparisons must be WITHIN a run.
- *Amplitude saturation.* The first amplitudes (1.5, 4.0) drove exc from 3.4 Hz to **0.003 Hz**.
  A linear-response property cannot be measured in a network knocked out of its operating point.
  `paradox.py` now voids any trial whose exc rate halves, and says NO VALID AMPLITUDE rather than
  reporting the sign of a saturated response.

### RESULT C — the important one: THE CERTIFIED POINT IS FRAGILE

The void rate is more informative than the test it was blocking. **At INJ = 0.1 — about 2 % of the
excitatory drive onto the inhibitory population — HALF the trials collapse the excitatory
population entirely. At 0.3, three quarters do.** A robust ISN absorbs a 2 % perturbation without
its E population shutting off.

Corroborating, from the paradox time courses: the network **spontaneously wanders between
near-silence and ~6 Hz on a sub-second timescale** (exc 0.2 → 5.8 Hz within one second). That is
consistent with the metastability in Result A — arguably the up/down states the blueprint wants —
but it also means "0 % silent neurons" and "rate 3.3 Hz", both quoted from 100 s aggregates,
average over real excursions toward silence.

**⇒ B1–B7 measures TIME-AVERAGES and never probes PERTURBATION ROBUSTNESS. It therefore passes a
network that is genuinely fragile.** This is a gap in the battery I wrote, not merely a caveat
about this operating point, and it should be weighed before the certification is treated as
settled. Candidate eighth clause: *survives a small perturbation without the excitatory population
collapsing*.

**Honest tally for the session:** three false positives from my own instruments today — the
plateau-criterion argument, the wave-slope artifact, and the cross-build paradox comparison. Every
one was caught by checking against a null or a physical sanity bound, none by inspection. That is
the strongest available argument for keeping §5.1 genuinely open.

**NEXT.** (1) §5.1 to the web instance, reframed as the blueprint-level contradiction. (2) Decide
whether robustness becomes clause B8. (3) Powering the ISN test properly needs ~10× the trials
(SEM ∝ 1/√n) at an amplitude below 0.05 — or an E/I-split activity trace so it does not depend on
spike dumps. (4) NFR-perf: 0.51× real time is a standing miss; Morton is the designated fix and is
fenced to Phase 2.


---

## Session 4 (cont.) — 2026-07-26 — B8 added and PASSED both directions: the regime is a basin, not a tuned point

**Intent.** Add the robustness clause the fragility finding demanded, and re-test the certified
point against it. **I expected it to fail. It passed.**

**Manifest (CONTRACT CHANGE — operator-approved).** `MODULE.md` §5 **+B8**, with its rationale and
a recorded known limitation. +`tools/sweep_b8.ps1`; `tools/paradox.py` gains `--robust` (the dip
distribution); `tools/analyze.py` labels perturbed runs so a B8 scorecard can never be mistaken
for an unperturbed certification. No `brain.h` change.

**How B8 was defined, and why it introduces no new free parameter.** The obvious form —
"excitatory rate must not fall below X % of baseline" — is unusable, because the measured dip
distribution is **continuous** and the threshold would therefore decide the verdict:

| perturbation | median min exc (fraction of own baseline) | trials below 10 % |
|---|---|---|
| control (0 %) | 0.833 | 0.0 % |
| +2 % | 0.377 | **26.3 %** |
| +6 % | 0.015 | 63.2 % |

At a 10 % silence threshold the point fails; at 2 % it passes. So B8 instead **re-applies B1–B6
under a sustained ±2 % perturbation** — no new threshold at all. B7 is excluded by construction:
the controllers are *expected* to move in order to absorb the perturbation, and requiring them not
to would test the opposite of the intended property. The perturbation runs t=10→100 s, exactly the
window `analyze.py` scores, so the verdict is the steady state OF THE PERTURBED NETWORK after the
homeostats have had ~90 s — the fair test, since absorbing perturbations is what they are for.

**RESULT — B8 PASSES in both directions.**

| | b8_plus (+2.4 %) | b8_minus (−2.1 %) | unperturbed |
|---|---|---|---|
| B1 m̂ | 0.984 | 0.980 | 0.980 |
| B2 plateau | FLAT 0.012 | FLAT 0.016 | FLAT 0.014 |
| B3 Fano | 6.90 | 8.54 | 7.23 |
| B4 pairwise r | +0.0048 | +0.0021 | +0.0028 |
| B5 CV_ISI median | 0.928 | 0.984 | 1.000 |
| B6 recurrent | 106× | 120× | 126× |
| **verdict** | **all clauses PASS** | **all clauses PASS** | PASS |

The homeostats visibly absorbed it: excitatory drive 5.042 → 4.254 mV/ms, I/E 6.89 → 7.42, rate
3.3 → 2.7 Hz. **The operating point moved and stayed inside the certified envelope on every
clause. The certified regime is a BASIN, not a tuned point.**

**My prediction was wrong, for an identifiable reason.** I expected failure because a sustained
2 % injection had previously driven exc to 0.013 Hz. That measurement was of a *sudden* pulse
hitting an unadapted network; a *sustained* perturbation gives iSTDP (fast) and the gain
controller (slow) tens of seconds to compensate. The two are not in conflict — they measure
different things.

**AND THAT IS A LIMITATION OF THE CLAUSE I WROTE, recorded in §5 rather than hidden by the pass.**
Choosing to reuse B1–B6 to avoid an arbitrary threshold made B8 a **steady-state** test, and a
steady-state test structurally cannot see transient collapse. The transient fragility is real and
remains unmeasured by the battery: a sudden 200 ms pulse of the same magnitude still drops exc
below a tenth of baseline in ~26 % of trials. It always recovered. Whether transient
collapse-and-recover is disqualifying is recorded as **OPEN** — "never dies" plausibly means never
*permanently* dies — and a transient clause would need exactly the depth threshold B8 was written
to avoid. Not adopted by default; a question for the consult alongside §5.1.

**Standing after this entry.** B1–B8 hold on the certified point; B1–B7 additionally on 4 seeds;
the GAIN_ETA band is 20× wide with the point interior; 2 of 3 blueprint spatial signatures
present (assemblies, metastability; waves absent). Still open: §5.1 (does the sustained frame owe
a power-law statement — a **blueprint-level** contradiction, not just a MODULE.md one), transient
robustness, the untestable-as-yet ISN paradoxical effect, and the NFR-perf miss (0.51× real time).


---

## Session 4 (cont.) — 2026-07-26 — PERF: the NFR "miss" is WITHDRAWN; and §6's binding-constraint claim is wrong

**Intent.** Fix the NFR-perf miss. The canonical fix (Morton reordering) is **FENCED to Phase 2**
by `CLAUDE.md`, so it was refused and the fence cited. Instead did the thing §6 explicitly makes a
Phase-0 deliverable: *measure* the baseline, which existed only as one aggregate number.

**Manifest.** `main.cu` per-kernel profile, off by default (`BRAIN_PROFILE=<samples>`, sampled
mid-run so the sync cost is confined to sampled steps). No contract change. No Morton.

### CORRECTION — "NFR-perf MISSED (0.51× real time)" is WITHDRAWN

That finding, logged and committed earlier today, came from a **single non-reproducible
measurement**. Re-running the **exact same binary** on an idle GPU:

| run | steps/s | RT factor |
|---|---|---|
| original `L_wm200_100s` (logged) | **5127** | 0.51× |
| same binary, re-run today | **9152** | 0.92× |
| same config, no spike dump | **9957** | 1.00× |
| same config, 300 k steps, no dump | **10 420** | 1.04× |

The spike dump costs only **6 %** (9957 → 9371), not the 2× I hypothesised. The 5127 figure is
simply not reproducible — most plausibly concurrent GPU load during that run; it cannot now be
determined retroactively. **Honest number: ~9 200–10 400 steps/s, i.e. 0.92–1.04× real time,
against a ≥1.0× requirement. NFR-perf is AT the line, not 2× under it.** Run-to-run spread is ±7 %
even on an idle machine, so any future perf claim needs repeated measurement on a quiet box —
which is the actual lesson, and one I violated by reporting a single number as a finding.

### RESULT — §6's NFR-binding-constraint is FALSE at the certified operating point

```
[profile] 400 sampled steps, mean A_t = 86.4  (0.0432% of N fire per step)
[profile] gather     89.9 us/step   54.3%   (all 200000 neurons, every step)
[profile] scatter    66.5 us/step   40.2%   (~8642 edges/step -- THE assumed hot path)
[profile] gain        9.1 us/step    5.5%
```

(Absolute values are inflated ~1.7× because event sampling forces a sync and destroys pipelining;
the **ratios** are the valid product.)

`MODULE.md` §6 states: *"the hot path is the **scattered atomic RMW** into the delay ring — the
same term FINAL_BLUEPRINT names as the real ceiling."* **It is not, here.** At the certified point
only **0.043 %** of neurons fire per step, so the scatter touches ~8 600 edges while the **gather
sweeps all 200 000 neurons every step**. Gather 54 %, scatter 40 %.

**Consequence for the phase plan — this is the important part.** Morton reordering optimises
scatter memory locality. **If the scatter is 40 % of runtime, Morton's ceiling is 1.67× even if it
made the scatter entirely free.** The Phase-2 optimisation bet is premised on the scatter being
the binding constraint, and that premise does not hold for the sparse-firing regime Phase 0 just
certified. It *would* hold in a dense/bursting regime — the seizing control fires 9.5 % of N per
step, ~220× more edge traffic — but the certified point is sparse by construction, and sparse is
what the project wants.

**⇒ Recommended before any Phase-2 Morton work:** re-measure this breakdown at the target scale.
If the gather stays dominant, the higher-leverage optimisations are gather-side and NOT fenced —
e.g. the per-neuron `curandStatePhilox4_32_10_t` is ~48–64 B of state read AND written every step
for all N (~20–26 MB/step, plausibly the single largest memory term), and Philox is counter-based
so it can be regenerated from (seed, id, step) with no stored state at all. **That would touch
`brain.h` (`NeuronState.rng`) ⇒ contract change ⇒ flagged, not done.**

### Standing

NFR-perf: met to within measurement noise. NFR-mem: ~220 MB, well inside the ≤300 MB budget.
NFR-determinism: holds. **NFR-binding-constraint: refuted at this operating point** — §6's text
should be amended to say the binding constraint is *regime-dependent* (gather-bound when sparse,
scatter-bound when dense), but that is a contract edit and is flagged, not made.


---

## Session 4 (cont.) — 2026-07-26 — Two contract changes FLAGGED (not applied); RNG state priced

**Intent.** Formally flag the two contract changes the profile surfaced, per CLAUDE.md's
"contract change => STOP, show diff + rationale, get approval". Priced change A first so the
proposal carries a measurement rather than the estimate I had been quoting.

**Manifest.** +`CONTRACT_CHANGES_PROPOSED.md` (both diffs + rationale + risks). `sim.cu`/`config.h`
gain `RNG_STATELESS`, **defaulted OFF**, a timing-only probe that measures the proposed change
without touching the contract (it uses a literal seed, since passing the real one is itself the
signature change under review). **No contract file edited.**

**A — `brain.h`: remove the stored per-neuron RNG state.** `curandStatePhilox4_32_10_t` is ~64 B
read AND written every step for every neuron (~25.6 MB/step at N=200k). Philox is counter-based;
the state can be regenerated from `(seed, i, step)`. Requires `NeuronState.rng` removed,
`k_init_rng` removed, and `seed` added to `k_gather_integrate` — all `brain.h`.

| | gather µs/step | wall steps/s |
|---|---|---|
| stored (contract) | **68.5** | 9 514 |
| stateless (proposed) | **47.7** | 15 210 |

**The honest figure is the gather, −30 %** — activity-independent, therefore a clean comparison.
**The wall-clock 9 514 → 15 210 is NOT a 1.6× speedup and I am explicitly not quoting it as one:**
the probe uses a different RNG stream, so the runs sat at different activity levels (scatter 6 460
vs 3 112 edges/step) and the lighter scatter flatters the stateless run. Holding scatter fixed,
122.3 → 101.5 µs/step ≈ **1.20× overall**. Plus 12.8 MB VRAM freed (≈256 MB at the blueprint's 4 M
target, where synapse storage is the binding term). Determinism is preserved and arguably
strengthened — `(seed,i,step)` addressing removes the stored version's dependence on how many
draws were previously consumed.

**B — `MODULE.md` §6: the binding constraint is regime-dependent.** §6 asserts the scattered
atomic RMW is the hot path and tells Phase 0 to measure it as the baseline Morton must beat.
Phase 0 measured it, and at the certified sparse point the assertion is **false** (gather 54 %,
scatter 40 %). This is a correction of fact, and the one that matters more of the two: a wrong
claim in the contract propagates — it would send Phase 2 at the wrong kernel with the contract's
authority behind it — whereas a missed 1.2× does not.

**Neither change is required for Gate B.** The certified point stands either way. Morton remains
un-built and fenced.
