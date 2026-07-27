# CLAUDE.md — `brain_phase0` (Volumetric Brain Engine · Phase 0)

**Read this first, every session.** This is the working agreement for a long, contract-first
solo build. **`include/brain.h` and the `MODULE.md` invariants are LAW** — when code and
contract disagree, the contract wins and you fix the code.

## The canon (source of truth, priority order)
1. **`MODULE.md`** — the Phase-0 contract: intent, glossary, invariants **I1–I5**, kernel
   boundaries, and the **Gate B** acceptance battery that *defines* "done."
2. **`include/brain.h`** — the frozen contract surface (SoA `NeuronState`, CSR `Connectome`,
   `DelayRing`, `SpikeList`, kernel + host-probe signatures). A `.cu` that disagrees is the bug.
3. **`include/config.h`** — the `[KNOB]` values. **Gate B is a *sweep* over these.**
4. **`FINAL_BLUEPRINT.md`** — the multi-phase north star. **Context, not the work order.**
   Phase 0 is a deliberately *naked* subset of it.
5. **`README.md`** — build/run.

Implementation: `src/connectome.cu` (host wiring → CSR) · `src/sim.cu` (3 device kernels +
host criticality probe) · `src/main.cu` (init, loop, CSV dumps) · `tools/analyze.py`
(rigorous Gate B verdict + plots).

## What Phase 0 IS
~200k Izhikevich point neurons at true 3D `(x,y,z)`, wired by the **exponential-distance rule**
into a **CSR edge list (row = presynaptic)**; **spikes ride edges** — a CUDA scatter into an
**atomic delay ring** — held slightly-subcritical by two homeostatic controllers (forward-only
iSTDP = fast, per-neuron input-gain = slow) + an ungained Poisson floor. Deliverable =
**measured self-sustaining criticality** + an offline 3D view. No task, no I/O, no live render.

## The invariants (I1–I5) — must hold in every kernel
- **I1 Presynaptic ownership** → each row owned by one source ⇒ weight writes need *no atomics*;
  only the delay-ring accumulate is atomic.
- **I2 Ring safety** → delays ∈ `[1, D-1]`; the slot cleared at step `t` is never written by
  step `t` — no same-slot read/clear/write race.
- **I3 Kernel order** → `gather → scatter → (gain)`, serialized on the default stream.
- **I4 Numerical guard** → Izhikevich in two half-steps; `v` clamped to a legal range **before**
  the `u` update, and `u` clamped too; never emit NaN/Inf into state, and never let a divergent
  `v` contaminate `u`. (Amended 2026-07-27 — the old `isfinite` reset ran *after* the `u` update.)
- **I5 Conservation of identity** → recorded `A_t` == `*spikes.count` after gather; the activity
  timeseries is lossless.

## Definition of done = Gate B (MODULE.md §5), verified by `tools/analyze.py` — NEVER by vibes
**AMENDED 2026-07-25/27 — the battery below replaced the old one. `MODULE.md` §5 is authoritative;
this is the summary.** PASS iff **all nine** hold, on **≥3 seeds**, on runs of **≥100 s**
(`N_STEPS ≥ 1e6` — the slow controller cannot converge in 20 s):
**B1** near-critical m̂≈0.98 · **B2** m̂ FLAT across bins 3–10 (spread <0.03) · **B3** Fano 2–20,
0 % silent (m̂ alone cannot separate reverberating from seizing — Fano can) · **B4** pairwise
r<0.05 vs its finite-sample noise floor · **B5** CV_ISI median 0.8–1.2 · **B6** self-sustaining
**on recurrence** (survives a ≥10× drive cut) · **B7** both controllers **off their rails** and
stationary · **B8** all of B1–B6 still hold under a sustained ±2 % perturbation · **B9** inhibition-STABILIZED —
injecting excitatory current into the inhibitory population makes its rate FALL (the one clause that
can falsify the mechanism claim rather than corroborate the phenomenology).

**RETIRED (see MODULE.md §5.1):** avalanche τ≈1.5 + KS, and the crackling relation. An avalanche
presupposes silence between cascades; the reverberating regime is never silent, so τ is an artifact
of the binning threshold. **§5.1 records what that costs in evidential strength, and leaves OPEN
whether the sustained frame still owes some power-law statement — that question is out for external
review and NOTHING should be called an unqualified Gate B pass until it lands.**

## THE PHASE FENCE (hard boundary — refuse + flag scope violations)
These are **Phase 2+** and MUST NOT be added in Phase 0. If asked to add any now, **refuse,
cite this fence, flag it as a scope violation**, then continue Phase-0 work:
- **RT cores / OptiX** (volume-transmission field, RT growth, RT render) — Phase 2/3
- **Morton / space-filling reorder** — Phase 2
- **Structural plasticity / growth trickle** — Phase 4
- **Real-time CUDA↔GL / Vulkan render** — Phase 1 (offline point cloud is enough for Gate B)
- **Dendritic subunits · AdEx · Tensor-core anything · multi-GPU** — Phase 5
- **Transpose-CSR (acausal / symmetric STDP)** — Phase 1+

**Rule: don't scale a corpse.** Each deferred item is a wager that only pays out after Gate B passes.

## Session protocol (every session)
1. **State intent** — the one thing this session changes.
2. **Change manifest** — files touched · any contract change (`brain.h` / `MODULE.md` → **STOP**,
   show diff + rationale, get approval) · the verification · **diff budget ≤ ~300 LOC**.
3. **Implement.**
4. **Verify against Gate B** — run `brain_phase0` + `tools/analyze.py`; read the scorecard.
5. **Append to `SESSION_LOG.md`** (intent, manifest, result, next).
6. **Stop.**

## Sweep discipline (Gate B is a search, not a single run)
Never tune blind. Override knobs → run → `python tools/analyze.py <rundir> --append` (writes the
B1–B7 row to `sweep_log.csv` itself; do not hand-maintain it). Failure modes:
**silent** (`m̂→0`) → raise `W_EXC_INIT` / `NU_EXT_HZ`, or lower `W_INH_INIT`;
**seizing** (Fano ≫ 100) → raise `ISTDP_ETA` / `W_MAX`, or lower `W_EXC_INIT`.
Knobs: `W_EXC_INIT, W_INH_INIT, W_MAX, NU_EXT_HZ, W_EXT, RHO0_HZ, ISTDP_ETA, GAIN_ETA, GAIN_MIN,
GAIN_MAX, N_STEPS, LAMBDA_UM, TARGET_OUTDEG, STD_U, TAU_REC_MS`.

**THE LESSON THAT COST THE MOST (Session 4):** the search stalled for three sessions on a
"structural void" that was really **two saturated homeostats** — inhibitory weight pinned at
`W_MAX`, gain railed at `GAIN_MIN` on 99.9 % of neurons — and *nothing in a run's output could
reveal it*. Of the nine knobs then listed, only four had ever been varied. So: **every run now
prints a `[knobs]` line and a `[ctrl]` controller-authority readout. Read the rails before
concluding a lever does not work.** A lever that is clamped looks exactly like a lever that does
nothing.

## Toolchain (this machine — verified Session 0, 2026-07-05)
- GPU **RTX 4070 Ti SUPER**, compute capability **8.9** (Ada) → `CMAKE_CUDA_ARCHITECTURES=89`.
  **16 GB VRAM** (blueprint assumed 24 GB — irrelevant for Phase 0's ~220 MB; matters at scale).
- **CUDA 13.1** (nvcc V13.1.80) · **CMake 4.3.3** · driver 610.47 · Windows 11 + MSVC.
- Reference CUDA projects on this PC for toolchain patterns (**reference, don't edit**):
  `C:\Buddhabrot_CUDA` (CUDA+GL+OptiX), `C:\backrooms` (DXR). Both build here.
- **curand**: link `CUDA::curand` via `find_package(CUDAToolkit REQUIRED)` — not `find_library`.
- Build: `cmake -B build -S . -DCMAKE_CUDA_ARCHITECTURES=89` →
  `cmake --build build --config Release`; exe at `build/Release/brain_phase0.exe`.

## Known risks
- ~~`--use_fast_math` may weaken the **I4** `isfinite` guard.~~ **TESTED AND REFUTED 2026-07-26:**
  PTX for sm_89 under CUDA 13.1 still emits `abs.ftz.f32` + `setp.geu.ftz.f32` + `selp.f32` with
  fast-math. No prior result carries unguarded-divergence risk from this cause. I4 now uses an
  explicit clamp anyway — not because `isfinite` was failing, but because the clamp does not
  depend on compiler behaviour holding, and it is what makes the (real) `u`-ordering fix expressible.
- **PERF MEASUREMENT IS UNRELIABLE ON THIS MACHINE.** Identical binaries have measured
  4922–16411 steps/s. `[timing]` brackets the loop with CUDA events, so CPU-side enqueue stalls
  inflate it — batch runs that each flush ~140 MB of CSV are **not** valid perf measurements.
  **Never quote a perf number from a single run;** use isolated repeats. Two claims were made and
  withdrawn in one session for want of this.
- **The ISN paradoxical effect is UNTESTED** (not refuted) — the blueprint §7.4 requires it and
  Gate B does not cover it. The certified point is also **fragile to sudden perturbation**: a 2 %
  pulse into the inhibitory population collapses the excitatory rate below a tenth of baseline in
  ~26 % of trials, always recovering. B8 is a steady-state test and cannot see this.
- **§5.1 is OPEN** — whether the sustained frame still owes a power-law statement. The
  contradiction is in `FINAL_BLUEPRINT.md` itself (§7.4 demands avalanche statistics, §2.5 targets
  the never-silent regime in which they are undefined). Out for external review.

## Local tooling
Fixed-path helpers (see `C:\Users\user\.claude\CLAUDE.md`): `C:\everything` (locate files),
`C:\chunker` (read/size huge files), `C:\imguard` (view images safely — use before opening
`criticality.png` / `pointcloud.png`), `C:\earshot` (audio/video → text).


