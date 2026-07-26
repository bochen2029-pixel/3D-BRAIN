# HANDOFF — 3D-BRAIN (Volumetric Brain Engine · Phase 0) — snapshot 2026-07-06

> **Self-contained rehydration for a FRESH session (any model), written by the session that lived it.**
> Paste this whole file in to resume. Then run the calibrated-handshake at the bottom before acting.

## READ-FIRST / reconstitution pointer (do this in order)
1. Read this file top-to-bottom.
2. Read `C:\3D-BRAIN\NEXT_SESSION.md` (the crisp crib) → then the **tail** of `C:\3D-BRAIN\SESSION_LOG.md`
   (full arc, Sessions 0–3; the last ~4 entries are Session 3 and carry the live state).
3. Read `C:\3D-BRAIN\CLAUDE.md` (canon, phase fence, session protocol — **LAW**).
4. **VERIFY REALITY before acting** (disk wins over this doc):
   - `python C:\3D-BRAIN\tools\bp_validate.py` → estimator should recover m∈{0,.5,.8,.98,1}, read 0 on dead.
   - `python C:\3D-BRAIN\tools\sweep_report.py` → the t4-corner table (Fano floor ~112 → 7004).
   - `git -C C:\3D-BRAIN status` / `git log --oneline -5` (uncommitted; do NOT commit unless asked).
5. **Trust the files over any recalled summary. Never resume blind.** For specifics this dump dropped,
   grep the raw transcript: `C:\Users\user\.claude\projects\C--3D-BRAIN\b47e3c82-a866-4296-9f13-3306adf700e2.jsonl`
   (don't read it whole — it won't fit; concept-search it, or use `C:\TRANSPORTER\claude_archive_viewer_v4.html`).

---

## CORE (never drop)
- **Goal.** Phase 0 = **provable criticality (Gate B)** for a living, truly-3D, hierarchically-modular
  Izhikevich spiking brain (200k neurons, modular connectome Q=0.707). "Watch it think, never dies."
- **Current position (the verdict).** The project's **"iSTDP+gain+STD is insufficient" negative is
  CONFIRMED — now with a trustworthy instrument and, for the first time, a NAMED mechanism.** The
  recurrent dynamics are **intrinsically synchronizing**; the rate-homeostatic inhibition already in the
  model produces a bursty E/I balance it structurally cannot desynchronize. **No static knob opens the
  gap** where the reverberating regime should live (confirmed 4 independent ways).
- **THE SINGLE NEXT ACTION.** Choose + build a **DESYNCHRONIZING mechanism**. My lean: **(i) FAST
  feedback inhibition decoupled from rate-iSTDP** (vs (iii) synchrony-retargeted iSTDP). **This is
  GATED**: it touches `sim.cu` (likely `brain.h` `NeuronState`/globals) ⇒ a **contract change** ⇒ STOP,
  show diff + rationale, get operator approval FIRST. Also worth the web-instance's design read on (i) vs (iii).
- **Hard constraints.** Canon (`brain.h` + `MODULE.md` invariants I1–I5) is **LAW** — code yields to it.
  **Phase fence** (refuse + flag): RT cores/OptiX, Morton reorder, structural growth, real-time render,
  dendritic/AdEx/Tensor/multi-GPU, transpose-CSR = Phase 2+. **Contract/instrument changes → flag, don't
  silently edit.** Diff budget ≤ ~300 LOC. **Don't commit unless the operator asks.**
- **Source of truth on disk.** `NEXT_SESSION.md` (crib) · `SESSION_LOG.md` (full arc) · this file ·
  `memory/*.md` · the `.jsonl` transcript (backstop, grep it).

---

## RING 1 — active state, open threads, decisions + WHY

**The whole arc collapses to one story:** we replaced a broken/contradictory acceptance test with a
trustworthy one, and it revealed the real blocker is **population synchrony**, not branching.

1. **THE REFRAME (web-Claude #8).** Gate B was internally contradictory — it demanded self-sustaining
   activity (reverberating picture, Wilting–Priesemann, m̂≈0.98 = real cortex) AND silence-separated
   shape-collapsing avalanches (absorbing picture, Beggs–Plenz). Incompatible. The project's vision is
   the **reverberating/sustained** frame. ⇒ dropped shape-collapse-on-silence; certify via branching
   ratio on continuous activity. **But the linchpin (the MR estimator) read ~0.99 on DEAD nets too**, so
   it had to be fixed FIRST or the reframe was motivated reasoning.
2. **Estimator FIXED + VALIDATED (the make-or-break, DONE).** `analyze.py::mr_branching_ratio` rewritten:
   **liveness gate** (dead→0) + **edge-normalized high-pass detrend** (kills homeostat drift, the
   Priesemann-Shriki contamination) + **offset-exponential fit** `r_k=b·m^k+c` + **b-significance guard**
   (absence-of-branching → 0, not exp(0)=1). Validated on synthetic BP of known m (`tools/bp_validate.py`:
   recovers {0,.5,.8,.98,1}, drift-robust) and real dead-vs-alive traces (`tools/real_check.py`).
   **The ruler now discriminates.**
3. **The SATURATION catch (web) → admissibility probe (`tools/admiss.py`).** m̂ was reading ~0.99 on the
   "alive" points — but they're NOT saturated (mean/N≈0.0005, sparse per-neuron; the "82/99% active" was
   fraction-of-*bins* not neurons). They're **synchronized-BURSTING**: Fano in the thousands, 25k-neuron
   population spikes. m̂ is **inadmissible** there (bin-unstable 0↔0.99). **Fano = the discriminator**
   (≈1 Poisson/pinned, ≫1 bursty); m̂ can't tell reverberating from seizing.
4. **THE VOID.** Across 77 self-sustaining points: **52 at Fano≈1 (Poisson drive-floor, m̂=0), 22 at
   Fano>2000 (synchronized bursting), ~nothing in Fano 2–20.** The gentle-criticality / asynchronous-
   irregular (AI) band where reverberation lives is **empty**. The reverberating regime is absent.
5. **t4-corner sweep — PRE-REGISTERED, void=null (`sweep_t4.ps1`+`sweep_report.py`). H1 REJECTED.**
   Recurrent Fano **floors at ~112** (t4/x_we3), climbs **smoothly** to 7004 (W_EXC 3→9) — not a
   knife-edge; t4 is the least-bursty point of an ALWAYS-bursty branch, not a hidden band. `plfit` refutes
   a clean power-law at t4 (KS 0.31, mid-tail). **E/I test NULL + mechanism found:** raising W_INH 4→10→16
   gave **byte-identical** operating points — because iSTDP (`sim.cu:107–110`, `dw=η·(x_trace−α)`) slaves
   inhibitory weight to the RATE target and washes out W_INH_INIT. **Static inhibitory gain is NOT a lever.**
6. **D_SCALE adaptation sweep — candidate (ii) spike-freq-adaptation. REJECTED (`sweep_dscale.ps1`).**
   Stronger adaptation weakly dampens seizing (7004→1443; 1178→702) but **never reaches the band** (best
   ~700), **costs activity** (meanA halves toward death), and on the least-bursty base **INCREASES** Fano
   (112→316; adaptation's slow timescale *promotes* synchrony). No alive-in-band window.
7. **⇒ NO-CONTRACT LEVERS EXHAUSTED** (recurrence, drive, static inhibition-gain, adaptation-magnitude).
   The void is structural. **Mandate = a desynchronizing mechanism, necessarily contract-touching.**
   σ-homeostat (per-neuron gain) is DOUBLY wrong (rate-nullified + can't fight synchrony) — dropped.

**Web-Claude's E/I guidance (the load-bearing recent directive, distilled verbatim-faithful):**
> "A synchronized population spike is a *network* instability — runaway recurrent excitation that
> inhibition fails to catch fast enough. The knob is the E/I operating point and the **speed/gain of
> inhibitory feedback** (the inhibition-stabilized-network regime, Mackwood's territory), not per-neuron
> excitability. Lower every neuron's gain and you get a *sparser* bursting network — you haven't touched
> the mechanism that makes them fire *together*. The Fano void — near-discontinuous Poisson→synchrony
> with nothing between — is the classic signature of a system with **no stable asynchronous-irregular
> fixed point**, which is exactly what fast feedback inhibition exists to create. So the actuator is E/I
> feedback (fast inhibition), σ-homeostat is at most a secondary fine-tune *once a stable AI regime
> exists to fine-tune within*." Plus the calibration note: **"let the void be a finding if it wants to
> be — the version where you don't find your reverberating point is the more valuable, more publishable
> result, and the one it'll be tempting to sweep-one-more-corner to avoid."** (We held that line.)

---

## RING 2 — completed work (terse; verifiable from files/git)
- **Sessions 0–2:** built the engine (`src/{connectome,sim,main}.cu`), the hierarchical-modular
  connectome (Q=0.707), synaptic summation (TAU_SYN, the fix that let a lone spike propagate), STD,
  iSTDP+gain; reached a "structural negative" (later reframed). Full detail in `SESSION_LOG.md`.
- **Session 3 (this session):** estimator fix+validation → admissibility probe → t4 sweep → D_SCALE
  sweep. Each result is a table in `SESSION_LOG.md`.
- **Instrument/tools built (`tools/`):** `bp_validate.py` (synthetic known-m validator), `real_check.py`
  (dead-vs-alive), `admiss.py` (Fano/CV/mean-N/m̂-bins), `binsweep.py` (bin-width + Fano landscape),
  `sweep_t4.ps1`+`sweep_report.py` (corner adjudicator, Fano+plateau; report takes labels via argv),
  `sweep_dscale.ps1`, `plfit.py` (Vuong LLR power-law vs lognormal/dragon-king), `analyze.py` (Gate-B
  scorecard — **verdict still shape-collapse-primary; retiring that for the sustained frame is deferred
  work, flagged**), `viz3d.py`/`animate.py` (offline 3D + firing GIF).

## Key operational facts
- **Toolchain:** RTX 4070 Ti SUPER (sm_89), CUDA 13.1, CMake 4.3.3, VS2022 MSVC, Win11 + PowerShell.
  Canonical build: `cmake --build build --config Release`. **Per-point sweeps use raw nvcc** — MUST
  import `vcvars64.bat` first (the sweep `.ps1`s do this via `vswhere`) or "cannot find cl.exe".
  nvcc line: `-std=c++17 -O3 -use_fast_math -arch=sm_89 -cudart static -I include -Xcompiler=/MT,... -lcurand`.
- **Scale/params:** `N_NEURONS=200000`, `N_STEPS=200000` (20 s @ DT=0.1 ms). Generation scale ≈ **5–10
  bins** (1 bin=30 µm axon; λ=150 µm; COND_VEL=300 µm/ms). Servo/estimator bin = generation scale, NOT 1.
- **Metrics:** **Fano=var/mean** (≈1 Poisson, ≫1 bursty — THE synchrony discriminator). **m̂-plateau**:
  flat across bins ≈ scale-invariant/critical, `m^b`-slope = artifact. **admissible m̂** needs sustained
  activity (act% not tiny) + non-pinned + bin-stable.
- **Key run dirs:** dead baseline `run/r00_baseline`, Poisson `run/r01_drive`; alive-but-bursty
  `run/dec_nu8` (Fano 14k), `run/u3_long`/`u4_long`; sweep `run/x_we*` (t4 corner), `run/d{3,6,9}_ds*`
  (adaptation). t4 = `run/t4_wx80_nu100` = {W_EXC=3, W_INH=4, W_EXT=80, ν=100, STD_U=0.2, TAU_REC=400}.
- **PowerShell gotchas (bit us):** use the **PowerShell tool** for Windows paths (the Bash tool strips
  backslashes). Vars are **case-INSENSITIVE** (`$D` clobbers `$d`). Unset env with `Remove-Item Env:\X`
  (not `SetEnvironmentVariable($null)`). Run built exes in a clean process (no stale BRAIN_* env).
- **Git:** on `master`, large uncommitted diff. Do NOT commit unless the operator asks.
- **Operator (Bo Chen):** solo contract-first builder; grants broad autonomy ("do whatever it takes")
  BUT wants Phase-2+ scope creep refused, contract/instrument edits flagged, and **honest
  dead/seizing/soup/critical verdicts over a manufactured pass**. Consults a "web Claude" instance for
  sharp reviews and relays them here — the collaboration has been genuinely load-bearing.

---

## CALIBRATED HANDOFF — do this before taking over (Procedure C)
You are the fresh session. Do NOT just start executing. First:
1. Run the VERIFY-REALITY checks above; confirm the estimator validates and the sweep tables match
   (Fano floor ~112 → 7004; adaptation never reaching the band).
2. **Interrogate back to the operator:** state the position as you now understand it and post your
   concrete questions — e.g. *"Confirm the next move is designing the (i) fast-inhibition mechanism as a
   review-only diff (no code) pending approval? Do you want the web-instance's (i)-vs-(iii) read first?
   Any change since the snapshot?"* Get correction before acting.
3. Only after the operator acknowledges → proceed. For the first mechanism step, remember the **GATE**:
   fast-inhibition touches `sim.cu`/`brain.h` ⇒ show a diff + rationale and get approval; do not write
   committed code first. A safe no-contract first deliverable = the **mechanism design proposal**
   (what the fast-inhibition term looks like, the state/globals it needs, the new `[KNOB]`s, a `brain.h`
   diff PREVIEW) for review.
4. Verify any built mechanism with `admiss.py` (does Fano drop into 2–20 while alive?) + `sweep_report.py`
   plateau + `plfit`. Append a `SESSION_LOG.md` entry. Don't declare a pass by vibes.
