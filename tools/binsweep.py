#!/usr/bin/env python3
"""binsweep.py -- pin the sigma-homeostat's operating timescale (step-3 prerequisite).

m_hat is bin-dependent on bursty input: a branching process coarse-grains as m_coarse ~ m_fine^b,
so a live servo must estimate m_hat at a FIXED bin width matched to the synaptic-delay / one-
generation timescale -- NOT bin=1 (0.1 ms is sub-propagation: a synchronous burst is a single-bin
event, no cross-bin branching visible -> m_hat artifactually 0/unstable). This probe:
  (A) sweeps bin width on representative points -> find the smoothly-varying (meaningful) region and
      whether m_hat is a stable branching ratio at the generation scale;
  (B) maps Fano across all self-sustaining points -> is the landscape truly BIMODAL (Poisson floor
      vs synchronized bursting, gap between) or is there an intermediate reverberating candidate?
Run: python tools/binsweep.py"""
import sys, glob, os, numpy as np
sys.path.insert(0, r"C:\3D-BRAIN\tools")
from bp_validate import mr_fixed

N_CEIL, SKIP, BASE = 200000, 20000, r"C:\3D-BRAIN\run"

def load(name):
    A = np.asarray(np.genfromtxt(BASE + "\\" + name + r"\activity.csv", delimiter=",", names=True)["A"], float)
    return A[SKIP:] if len(A) > SKIP else A

def rebin(A, b):
    nb = len(A) // b
    return A[:nb * b].reshape(nb, b).sum(1) if (b > 1 and nb > 0) else A

def fano(A):
    m = A.mean(); return (A.var() / m if m > 0 else 0.0)

# ---- (A) bin-width sweep on representative points -----------------------------
BINS = [1, 2, 3, 4, 5, 7, 10, 15, 20, 30, 50]
pts  = ["dec_nu8", "u3_long", "u4_long", "k3_nu600"]   # 3 bursty + 1 Poisson-floor for contrast
print("(A) m_hat vs bin width   (bin b = b x 0.1 ms;  so 10 = 1 ms, 20 = 2 ms)\n")
hdr = "     point |" + "".join(f"{b:>7}" for b in BINS)
print(hdr); print("-" * len(hdr))
for p in pts:
    A = load(p)
    print(f"{p:>10} |" + "".join(f"{mr_fixed(rebin(A, b)):7.3f}" for b in BINS))
print("\n    Fano vs bin width  (coarser bins average out synchrony -> Fano falls):")
print(hdr); print("-" * len(hdr))
for p in pts:
    A = load(p)
    print(f"{p:>10} |" + "".join(f"{fano(rebin(A, b)):7.1f}" for b in BINS))

# ---- (B) Fano landscape across all self-sustaining points ---------------------
rows = []
for pth in sorted(glob.glob(BASE + r"\*\activity.csv")):
    try:
        A = np.asarray(np.genfromtxt(pth, delimiter=",", names=True)["A"], float)
    except Exception:
        continue
    if len(A) <= SKIP:
        continue
    body = A[SKIP:]; tail = A[int(0.8 * len(A)):]
    if body.mean() <= 0 or not (tail.mean() > 0.5 and tail.mean() > 0.2 * body.mean()):
        continue
    rows.append((os.path.basename(os.path.dirname(pth)), body.mean(), fano(body)))
rows.sort(key=lambda r: r[2])
print(f"\n(B) Fano landscape -- {len(rows)} self-sustaining points, bucketed (is there a middle?):")
print(f"{'Fano bucket':>18} | count | example points  name(Fano,meanA)")
print("-" * 78)
for lo, hi, lab in [(0, 2, "~1  Poisson floor"), (2, 20, "2-20  (MIDDLE?)"),
                    (20, 200, "20-200 (MIDDLE?)"), (200, 2000, "200-2000"),
                    (2000, 1e12, ">2000  bursting")]:
    grp = [r for r in rows if lo <= r[2] < hi]
    ex = ", ".join(f"{n}(F{f:.0f},A{m:.0f})" for n, m, f in grp[:5])
    print(f"{lab:>18} | {len(grp):5d} | {ex}")
print("-" * 78)
print("want: a bin width where m_hat is smooth/stable near the generation scale (A), and ideally an")
print("intermediate-Fano point (B) that is neither Poisson-dead nor synchronized -- the reverb target.")
