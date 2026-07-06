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
- **I4 Numerical guard** → Izhikevich in two half-steps; `v` reset on `!isfinite`; never emit
  NaN/Inf into state.
- **I5 Conservation of identity** → recorded `A_t` == `*spikes.count` after gather; the activity
  timeseries is lossless.

## Definition of done = Gate B (MODULE.md §5), verified by `tools/analyze.py` — NEVER by vibes
PASS iff **all** hold: (1) **near-critical** m̂≈0.98 (MR estimator, `0.9<m̂<1.02`);
(2) **scale-free avalanches** τ≈1.5 (MLE+KS, `KS<0.1`); (3) **crackling relation** within ~0.3;
(4) **self-sustaining** the full 20 s — neither `m̂→0` (silence) nor `m̂>1` (seizure) — held by
≥2 controllers on separated timescales. *(Phase 0.5 adds CV_ISI≈1 / low pairwise correlation.)*

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
Never tune blind. Override knobs → run → parse the `analyze.py` scorecard → append one row to
`sweep_log.csv` (knob values → m̂, τ, rate, RT-factor). Failure modes:
**silent** (`m̂→0`) → raise `W_EXC_INIT` / `NU_EXT_HZ`, or lower `W_INH_INIT`;
**seizing** (`m̂>1`) → raise `W_INH_INIT` / `ISTDP_ETA`, or lower `W_EXC_INIT`.
Knobs: `W_EXC_INIT`, `W_INH_INIT`, `NU_EXT_HZ`, `W_EXT`, `RHO0_HZ`, `ISTDP_ETA`, `GAIN_ETA`,
`LAMBDA_UM`, `TARGET_OUTDEG`. Target: m̂→0.98, τ≈1.5, KS<0.1, self-sustaining 20 s.

## Toolchain (this machine — verified Session 0, 2026-07-05)
- GPU **RTX 4070 Ti SUPER**, compute capability **8.9** (Ada) → `CMAKE_CUDA_ARCHITECTURES=89`.
  **16 GB VRAM** (blueprint assumed 24 GB — irrelevant for Phase 0's ~220 MB; matters at scale).
- **CUDA 13.1** (nvcc V13.1.80) · **CMake 4.3.3** · driver 610.47 · Windows 11 + MSVC.
- Reference CUDA projects on this PC for toolchain patterns (**reference, don't edit**):
  `C:\Buddhabrot_CUDA` (CUDA+GL+OptiX), `C:\backrooms` (DXR). Both build here.
- **curand**: link `CUDA::curand` via `find_package(CUDAToolkit REQUIRED)` — not `find_library`.
- Build: `cmake -B build -S . -DCMAKE_CUDA_ARCHITECTURES=89` →
  `cmake --build build --config Release`; exe at `build/Release/brain_phase0.exe`.

## Known risks (open — not yet acted on)
- `--use_fast_math` lets the compiler assume finite math and can weaken the **I4** `isfinite`
  guard. If NaN blowups appear during the sweep, revisit (drop fast-math on `sim.cu`, or add an
  explicit `v` range clamp alongside the `isfinite` reset).

## Local tooling
Fixed-path helpers (see `C:\Users\user\.claude\CLAUDE.md`): `C:\everything` (locate files),
`C:\chunker` (read/size huge files), `C:\imguard` (view images safely — use before opening
`criticality.png` / `pointcloud.png`), `C:\earshot` (audio/video → text).
