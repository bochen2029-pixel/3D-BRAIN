# HANDOFF — 3D-BRAIN (Volumetric Brain Engine · Phase 0) — snapshot 2026-07-27

> **Self-contained rehydration for a FRESH session (any model).** Read this top-to-bottom, then
> `CLAUDE.md` (canon/fence/protocol), then the **tail** of `SESSION_LOG.md`.
> **VERIFY BEFORE ACTING — disk wins over this doc.**

## STATE IN ONE LINE
**Gate B (B1–B8) PASSES** on the certified operating point across **≥3 seeds** and **both B8
perturbation directions**, with `brain.h` amended once (RNG state removed) and `MODULE.md` §5
rewritten to the sustained-frame battery. **The physics is done. What remains is one open
question of principle, out for external review.**

---

## THE CERTIFIED POINT

```
N=200000  W_EXC_INIT=5  W_INH_INIT=4  W_MAX=200  ISTDP_ETA=0.2  GAIN_ETA=1e-4
GAIN_MIN=0.1  W_EXT=80  NU_EXT_HZ=5  STD_U=0.2  TAU_REC_MS=400  N_STEPS=1e6 (100 s)
```
Reference runs: `run/V_s1234`, `V_s7`, `V_s99` (seeds), `V_b8p` / `V_b8m` (B8 ±2 %).
Build/run: `pwsh tools/recertify.ps1`, then `python tools/analyze.py run/V_s1234`.

| clause | requirement | measured (3 seeds) |
|---|---|---|
| B1 near-critical | 0.9 < m̂ < 1.02 | **0.982** |
| B2 scale-invariant | plateau spread < 0.03 | **0.012–0.016 FLAT** |
| B3 not seizing / not floor | Fano 2–20, 0 % silent | **8.1–8.5**, 0 %, maxA/N 0.09 % |
| B4 asynchronous | \|r\| < 0.05 | **+0.0014 … +0.0030** |
| B5 irregular | CV_ISI median 0.8–1.2, majority in band | **0.93–1.00**, 80–83 % |
| B6 self-sustaining on recurrence | ≥10× drive cut, recurrent ≫ ext | **102–119× recurrent** |
| B7 two controllers off rails | gain railed < 20 %, stationary, on target | **gain 0.41, 4.4 % railed** |
| B8 robust to ±2 % perturbation | B1–B6 still hold | **PASS both directions** |

Not clauses, but measured (`tools/spatial.py`): **assembly structure PRESENT** (near-module
r ≈ +0.29 vs a 0.050 floor, far +0.035), **metastability PRESENT** (ACF excess +0.12 @200 ms),
**travelling waves ABSENT**. Under B8 perturbation metastability drops to +0.079 — *below* the
0.10 line used for the ABSENT/PRESENT call. Borderline; recorded, not buried.

---

## WHAT CHANGED IN SESSION 4 (the whole arc, compressed)

The session opened under a standing mandate to build a **contract-touching desynchronizing
mechanism**, because "the reverberating regime is ABSENT, confirmed four ways." **That was wrong.**

- **The void was an artifact of saturated homeostats.** At every operating point in the project's
  history the inhibitory weight sat pinned at `W_MAX` and the gain was railed at `GAIN_MIN` on
  99.9 % of neurons — and *nothing in a run's output could reveal it*. Of the nine knobs the
  Gate-B search nominally covered, only four had ever been varied. Raising controller authority
  (`ISTDP_ETA`, `W_MAX`, `GAIN_MIN`) reaches the asynchronous-irregular regime with **no
  desynchronizing mechanism at all**. The mandate is withdrawn.
- **`MODULE.md` §5 replaced** with B1–B8 + run-length (≥100 s) + ≥3-seed clauses; §5.1 records the
  retired avalanche/crackling clauses **and what retiring them costs**.
- **`brain.h` amended (2026-07-27):** `NeuronState.rng` and `k_init_rng` removed, `seed` added to
  `k_gather_integrate`. Philox is counter-based, so the drive stream is regenerated from
  `(seed, neuron, step)`. Frees 12.8 MB VRAM and ~25.6 MB/step of traffic.
- **`MODULE.md` §6 amended:** the binding constraint is **regime- and version-dependent**. With the
  RNG state stored it read gather 54 % / scatter 40 %; with it removed, gather 35–42 % / scatter
  55–62 %. The RNG state had been *masking* the true constraint; the blueprint's scatter claim is
  right once it is gone.
- **Deliverables exist:** `brain3d.html` (the §1 offline 3D view), `firing.gif`, `criticality.png`,
  `pointcloud.png`, and `run/ai_vs_seizing.png` (certified vs seizing, same renderer).

---

## OPEN — in priority order

1. **§5.1: does the sustained frame still owe a power-law statement?** `RELAY_TO_WEB.md` is written
   and paste-ready for the web-Claude consult. **Key reframing found late: the contradiction is in
   `FINAL_BLUEPRINT.md` itself** — §7.4 demands avalanche α/β/crackling/shape-collapse while §2.5
   targets the never-silent reverberating regime where those are undefined. This is a
   blueprint-level question, not a `MODULE.md` one. **Nothing should be called an unqualified Gate
   B pass until this lands.**
2. **Transient robustness.** B8 is a *steady-state* test by construction (it reuses B1–B6 to avoid
   an arbitrary threshold) and therefore cannot see the finding that motivated it: a *sudden* 2 %
   pulse into the inhibitory population still collapses the excitatory rate below a tenth of
   baseline in ~26 % of trials, always recovering. Whether collapse-and-recover is disqualifying
   is **OPEN** — a transient clause would need exactly the threshold B8 avoids.
3. **ISN paradoxical effect: TESTED AND POSITIVE (2026-07-27).** Injecting extra excitatory current
   into the inhibitory population makes their rate **fall**: drift-corrected **-0.259 +/- 0.069 Hz,
   z = -3.7** at a 1 % perturbation (187/199 trials in the linear regime), monotonic to z = -5.3 at
   3 %, with a clean control (+0.020 +/- 0.044). **The certified network is inhibition-STABILIZED**,
   not merely inhibition-dominated -- a distinction none of B1-B8 can make. Proposed as clause
   **B9** in `CONTRACT_CHANGES_PROPOSED.md`; awaiting approval. Enabled by the `RATEDUMP_*`
   E/I-split trace (`ei_rate.csv`), which needed no contract change.
4. **Blueprint gaps not built:** cross-homeostasis (Mackwood 2022 — the blueprint calls it "the
   single most important stabilizer upgrade"), fast inhibition τ_I < τ_E, circuit-breaker. **The AI
   state was reached without any of them**, which is itself a result worth reporting.
5. **Fence conflict to settle:** blueprint Phase 0 includes the CSR-vs-RT routing micro-benchmark;
   `CLAUDE.md`'s fence bars RT/OptiX from Phase 0. The fence won; the documents disagree.

---

## OPERATIONAL FACTS

- **Toolchain:** RTX 4070 Ti SUPER (sm_89), CUDA 13.1, CMake 4.3.3, VS2022, Win11 + PowerShell.
  Canonical build `cmake --build build --config Release`. Per-point sweeps use raw `nvcc` and MUST
  import `vcvars64.bat` first (the `.ps1` harnesses do it via `vswhere`).
- **Instruments:** `analyze.py` (B1–B8 scorecard; `[rundir] [--append]`), `airegime.py` (CV_ISI,
  pairwise r vs its noise floor, per-neuron Fano), `spatial.py` (assemblies, metastability, waves),
  `isn.py` (ISN paradoxical effect, from `ei_rate.csv`), `paradox.py` (earlier ISN attempts + `--robust`), `admiss.py`, `bp_validate.py`, `plfit.py`, `sweep_report.py`,
  `viz3d.py`, `animate.py`. Harnesses: `sweep_{ei,drive,gain,headroom,gaineta,b8,dump,paradox,isn}.ps1`,
  `recertify.ps1`.
- **Every run self-documents:** `[knobs]` line (full config) and `[ctrl]` readout (controller rail
  occupancy) — added because a knob that was never varied stayed invisible for 32 sweep rows.
  `BRAIN_PROFILE=<n>` gives a per-kernel breakdown.
- **`sweep_log.csv`** is the B-schema log. Pre-amendment history is preserved verbatim in
  `sweep_log_preB.csv` — its rows **cannot** be rescored (no `[ctrl]`, no spike dumps).
- **PERF MEASUREMENT IS UNRELIABLE ON THIS MACHINE.** Identical binaries have measured
  4922–16411 steps/s — a **3.3× spread**. Two perf claims were made and withdrawn this session for
  exactly this reason. **Never quote a perf number from a single run.**
- **PowerShell gotchas:** variables are case-INSENSITIVE; unset env vars with `$env:X = $null`;
  `Remove-Item` on paths under `C:\3D-BRAIN` trips a protection guard — avoid it in scripts.
- **Git:** on `master`, pushed to `github.com/bochen2029-pixel/3D-BRAIN` (**public**). `run/` and
  `build/` are gitignored.

---

## CALIBRATION — read this before trusting any conclusion

Session 4 produced **six** claims from its own instruments that later measurement refuted: the
granularity hypothesis; the iSTDP Δw arithmetic (wrong 13×); the argument that the plateau
criterion was backwards; a travelling-wave slope that was a correlated-vs-noise artifact; a
cross-build paradox comparison invalidated by chaotic divergence; and two separate perf claims.
**Every one was caught by checking against a null, a surrogate, or a physical sanity bound — none
by inspection.** The instruments in `tools/` now embed those nulls deliberately (noise floors,
time-shuffled surrogates, void checks, short-trace guards). Keep them. When a result looks clean,
find the null it should be compared against before reporting it.


