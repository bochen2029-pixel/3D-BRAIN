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
You get `criticality.png` (settled activity, the B2 m̂ plateau, the B1 autocorrelation
fit, the B7 controller trace), `pointcloud.png` (3D firing), and a printed
**B1–B7 scorecard** (B8/B9 are cross-run — see §5). `python tools/analyze.py <rundir> --append` also writes the
row to `sweep_log.csv`.

## The Gate B battery (MODULE.md §5 is authoritative)
PASS iff **all nine** hold, on **≥3 seeds**, on runs of **≥100 s** (`N_STEPS ≥ 1e6`):

| | clause |
|---|---|
| B1 | near-critical — m̂ ≈ 0.98 (MR estimator) |
| B2 | scale-invariant — m̂ FLAT across bins 3–10, spread < 0.03 |
| B3 | neither seizing nor the drive floor — Fano 2–20, 0 % silent |
| B4 | asynchronous — pairwise r < 0.05 vs its finite-sample noise floor |
| B5 | irregular — CV_ISI median 0.8–1.2 |
| B6 | self-sustaining **on recurrence** — survives a ≥10× drive cut |
| B7 | both homeostats **off their rails** and stationary |
| B8 | B1–B6 still hold under a sustained ±2 % perturbation |
| B9 | inhibition-stabilized — the paradoxical effect (blueprint §7.4) |

Avalanche τ ≈ 1.5, KS and the crackling relation were **retired** (§5.1): an avalanche
presupposes silence between cascades, and this regime is never silent, so τ is an
artifact of the binning threshold. §5.1 records what that costs, and leaves open
whether the sustained frame still owes *some* power-law statement.

## Tuning
- too silent → raise `W_EXC_INIT` / `NU_EXT_HZ`, or lower `W_INH_INIT`.
- seizing (Fano ≫ 100) → raise `ISTDP_ETA` / `W_MAX`, or lower `W_EXC_INIT`.
- **read the `[ctrl]` line before concluding a lever does not work.** The search
  once stalled for three sessions on a "structural void" that was really two
  saturated homeostats — a clamped lever looks exactly like a dead one.

## Honest status
**Gate B (B1–B9) passes** on the certified point across 3 seeds and both B8
perturbation directions — see `HANDOFF.md` for the point and the numbers, and
`SESSION_LOG.md` for how it was reached (including the several claims that had to
be withdrawn along the way). Runs at ≈1.5× real time at N=200 000.

One question is deliberately **open**: whether the sustained frame owes a power-law
statement (§5.1). Until that is resolved this is not called an unqualified pass.

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


