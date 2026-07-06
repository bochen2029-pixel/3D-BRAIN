# Volumetric Brain Engine — Phase 0: The Living Cell

A truly-3D spiking network that has to **come alive and hold at the edge on run 1**.
No RT cores, no Morton, no growth, no real-time renderer — those are Phase 2+ and
only earn their place once *this* proves the dynamics live. This is **Gate B** from
the design: the make-or-break test the FINAL_BLUEPRINT buried under GPU cleverness.

Read `MODULE.md` first — it's the contract (intent, invariants, kernel boundaries,
and the acceptance battery that defines "pass").

## What it does
- 200k Izhikevich neurons in a real 1 mm-ish 3D cube, 80/20 E/I.
- Exponential-distance-rule wiring → CSR edge list; **spikes ride edges** (CUDA),
  not rays. Geometry-derived, bucketed `uint8` delays in a ring buffer.
- Current-based synapses, **scattered atomic accumulate** (the naive version of the
  real bottleneck, on purpose).
- Two homeostatic controllers — forward-only iSTDP (fast) + input-gain (slow) — plus
  a Poisson noise floor, so it self-stabilises toward a target rate.
- Live `m̂` + activity readout; dumps CSVs for a rigorous offline verdict.

## Build (Windows 11 + RTX, PowerShell)
Requires the CUDA Toolkit (nvcc) and CMake. From the project root:
```powershell
cmake -B build -S . -DCMAKE_CUDA_ARCHITECTURES=89   # 4090=89, 5090=120, 3090=86
cmake --build build --config Release
./build/Release/brain_phase0.exe                    # optional: pass a seed, e.g. 7
```
(Linux: `cmake -B build -S . && cmake --build build -j && ./build/brain_phase0`.)

## Read the result
```powershell
pip install numpy matplotlib
python tools/analyze.py            # run in the folder with the *.csv it just wrote
```
You get `criticality.png` (activity, avalanche fit, MR fit), `pointcloud.png`
(3D firing), and a printed **Gate B** scorecard: `m̂`, avalanche exponent + KS,
and the crackling relation.

## How to actually pass Gate B
First runs will probably be **dead** (`m̂→0`, silent) or **seizing** (`m̂>1`, saturated).
That's expected — this phase *is* the search for the operating point. Sweep the
`[KNOB]` values in `include/config.h`:
- too silent → raise `W_EXC_INIT` / `NU_EXT_HZ`, or lower `W_INH_INIT`.
- seizing → raise `W_INH_INIT` / `ISTDP_ETA`, or lower `W_EXC_INIT`.
- rate off target → the controllers should pull it to `RHO0_HZ`; if not, raise
  `ISTDP_ETA` (fast) and check `GAIN_*` (slow).
Target: `m̂ → 0.98`, size exponent `τ ≈ 1.5` with `KS < 0.1`, self-sustaining for
the full 20 s. When that holds, the dynamics are proven alive — and Phase 2 (RT
field/render, Morton, scale to millions) has something real to accelerate.

## Honest status
Written to compile against your RTX toolchain but **not compiled/run in the
environment it was authored in** (no GPU there). Most-likely tweak points on first
build: `CMAKE_CUDA_ARCHITECTURES` for your card, the `curand` link (adjust the
`find_library` hint if CMake can't locate it), and block size (256) if you profile.
The physics knobs are meant to be swept regardless.

## Layout
```
include/config.h     all tunables (the KNOBs)
include/brain.h      contract: SoA state, CSR, kernel signatures
src/connectome.cu    host: 3D positions + exp-distance wiring -> CSR
src/sim.cu           device kernels + host criticality probe
src/main.cu          init, sim loop, CSV dumps
tools/analyze.py     rigorous MR estimator + MLE power-law + plots
MODULE.md            the spec / contract / acceptance battery
```
