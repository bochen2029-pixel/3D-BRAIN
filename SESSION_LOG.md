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
