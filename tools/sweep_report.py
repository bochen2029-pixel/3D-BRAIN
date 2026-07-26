#!/usr/bin/env python3
"""sweep_report.py -- adjudicate the t4-corner sweep: band (H1) vs void (H0).

For each swept point (+ t4 & dec_nu8 references): meanA, CV, Fano, maxA/N, and m_hat across bins
{3,5,7,10} with the PLATEAU SPREAD -- a genuinely critical (scale-invariant) point shows m_hat FLAT
around the generation scale; pure m^b decay (large spread) = no scale-invariant regime = artifact.
  H1 (band): a CLUSTER of moderate-Fano (2-200) + flat-plateau points near t4 -> real under-explored
             band, Gate B may be closer than the negative implied.
  H0 (void): only Fano~1 (Poisson floor) or Fano>1000 (seizing), t4 isolated -> no stable
             asynchronous-irregular regime -> E/I-stabilization mechanism mandate (verdict confirmed).
Run: python C:\\3D-BRAIN\\tools\\sweep_report.py"""
import sys, numpy as np
sys.path.insert(0, r"C:\3D-BRAIN\tools")
from bp_validate import mr_fixed

N_CEIL, SKIP, BASE = 200000, 20000, r"C:\3D-BRAIN\run"
LABELS = sys.argv[1:] if len(sys.argv) > 1 else \
         ["x_we3", "x_we4", "x_we5", "x_we6", "x_we9", "x_we9_wi10", "x_we9_wi16",
          "x_we4_nu50", "x_we4_nu150", "t4_wx80_nu100", "dec_nu8"]
BINS = [3, 5, 7, 10]

def load(name):
    A = np.asarray(np.genfromtxt(BASE + "\\" + name + r"\activity.csv", delimiter=",", names=True)["A"], float)
    return A[SKIP:] if len(A) > SKIP else A

def rebin(A, b):
    nb = len(A) // b
    return A[:nb * b].reshape(nb, b).sum(1) if (b > 1 and nb > 0) else A

print("band(H1) vs void(H0) adjudication -- Fano moderate + m_hat plateau FLAT = reverberating candidate\n")
print(f"{'label':>16} | {'meanA':>8} {'CV':>6} {'Fano':>9} {'maxA/N%':>8} | " +
      " ".join(f"{'m@'+str(b):>6}" for b in BINS) + " | plateau")
print("-" * 100)
for name in LABELS:
    try:
        A = load(name)
    except Exception as e:
        print(f"{name:>16} | (no data: {type(e).__name__})")
        continue
    mean = A.mean(); cv = (A.std() / mean if mean > 0 else 0.0); fano = (A.var() / mean if mean > 0 else 0.0)
    maxN = 100.0 * A.max() / N_CEIL
    mh = [mr_fixed(rebin(A, b)) for b in BINS]
    nz = [x for x in mh if x > 0]
    spread = (max(nz) - min(nz)) if len(nz) >= 2 else float("nan")
    tag = "--" if len(nz) < 2 else ("FLAT" if spread < 0.03 else "slope")
    mhs = " ".join(f"{x:6.3f}" for x in mh)
    band = ""
    if 2.0 <= fano <= 200.0 and maxN < 3.0:
        band = "  <-- moderate-Fano candidate"
    print(f"{name:>16} | {mean:8.1f} {cv:6.2f} {fano:9.1f} {maxN:8.2f} | {mhs} | {tag}({spread:.3f}){band}")
print("-" * 100)
print("H1 if moderate-Fano candidates CLUSTER (a neighborhood, not a lone point) with flat plateaus;")
print("H0 if the middle stays empty (only Fano~1 or Fano>1000) -> t4 was a lone crossing -> E/I mandate.")
print("Also watch axis C (x_we9 -> _wi10 -> _wi16): if rising inhibition drags Fano DOWN into the band,")
print("that is direct evidence the missing actuator is inhibitory stabilization, not per-neuron gain.")
