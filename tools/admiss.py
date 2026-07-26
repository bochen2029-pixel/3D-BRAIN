#!/usr/bin/env python3
"""admiss.py -- ADMISSIBILITY probe for m_hat (web-instance saturation/pinning check, step 2).

A trustworthy estimator on DEGENERATE input still lies: if A_t is pinned (against a ceiling, or at a
stable fixed point) the lag-1 slope is ~1 by construction -- the variance you'd regress on is squashed.
So before trusting any m_hat, ask whether the population activity is SPARSE and FLUCTUATING (the real
reverberating signature) or pinned. Tells, per trace (startup transient excluded):
  * meanA, mean/N   -- sparsity (fraction of the N-neuron ceiling firing per bin)
  * CV(A_t)         -- relative swing of A_t
  * Fano = var/mean -- THE discriminator: ~1 => Poisson/pinned (m_hat trivial/inadmissible);
                       >>1 => genuinely bursty/avalanching (m_hat potentially meaningful)
  * m_hat @ bins 1/2/5/10 -- genuine near-critical m_hat is STABLE across bin widths; a pinning
                       artifact drifts with the bin.
Part B scans every run/*/activity.csv for the SPARSEST self-sustaining point (step-2 hunt for the
reverberating regime). Run:  python tools/admiss.py"""
import sys, glob, os, numpy as np
sys.path.insert(0, r"C:\3D-BRAIN\tools")
from bp_validate import mr_fixed

N_CEIL = 200000                       # N_NEURONS (config.h) -- the A_t ceiling
SKIP   = 20000                        # drop first 10% (startup synchronous burst)
BASE   = r"C:\3D-BRAIN\run"

def load(rel_or_path):
    p = rel_or_path if os.path.isabs(rel_or_path) else BASE + "\\" + rel_or_path
    d = np.genfromtxt(p, delimiter=",", names=True)
    A = np.asarray(d["A"], float)
    return A[SKIP:] if len(A) > SKIP else A

def rebin(A, b):
    if b <= 1: return A
    nb = len(A) // b
    return A[:nb * b].reshape(nb, b).sum(1) if nb > 0 else A

def stats(A):
    mean = float(A.mean()); var = float(A.var()); std = var ** 0.5
    return dict(n=len(A), mean=mean, std=std, cv=(std / mean if mean > 0 else 0.0),
                fano=(var / mean if mean > 0 else 0.0), mx=float(A.max()),
                act=100.0 * float(np.mean(A > 0)), fc=mean / N_CEIL)

# ---- Part A: the three named points, in detail --------------------------------
NAMED = [("dec_nu8", "dec_nu8\\activity.csv"),
         ("u3_long", "u3_long\\activity.csv"),
         ("u4_long", "u4_long\\activity.csv"),
         ("t4_wx80", "t4_wx80_nu100\\activity.csv"),      # the ONLY Fano 20-200 point
         ("std05_500",  "std_u0.05_tr500\\activity.csv"),  # the two Fano 200-2000 points
         ("std05_2000", "std_u0.05_tr2000\\activity.csv")]
print(f"N_ceiling={N_CEIL}   skip first {SKIP} bins (startup transient)\n")
print(f"{'trace':>10} | {'meanA':>8} {'CV':>6} {'Fano':>8} {'mean/N':>8} {'act%':>6} {'maxA':>9} | {'mhat @ bin 1/2/5/10':>24}")
print("-" * 92)
for lab, rel in NAMED:
    try:
        A = load(rel); s = stats(A)
        mhs = "/".join(f"{mr_fixed(rebin(A, b)):.3f}" for b in (1, 2, 5, 10))
        print(f"{lab:>10} | {s['mean']:8.1f} {s['cv']:6.2f} {s['fano']:8.1f} {s['fc']:8.4f} "
              f"{s['act']:6.1f} {s['mx']:9.0f} | {mhs:>24}")
    except Exception as e:
        print(f"{lab:>10} | (failed: {type(e).__name__}: {e})")

# ---- Part B: hunt the sparsest self-sustaining point --------------------------
rows = []
for pth in sorted(glob.glob(BASE + r"\*\activity.csv")):
    try:
        d = np.genfromtxt(pth, delimiter=",", names=True); A = np.asarray(d["A"], float)
    except Exception:
        continue
    if len(A) <= SKIP: continue
    body = A[SKIP:]; tail = A[int(0.8 * len(A)):]
    if body.mean() <= 0 or not (tail.mean() > 0.5 and tail.mean() > 0.2 * body.mean()):
        continue                                   # require self-sustaining
    s = stats(body); s["name"] = os.path.basename(os.path.dirname(pth)); rows.append(s)
rows.sort(key=lambda r: r["mean"])                 # sparsest first
print(f"\nsparsest SELF-SUSTAINING points (candidate reverberating regime; {len(rows)} alive of scanned):")
print(f"{'trace':>16} | {'meanA':>8} {'CV':>6} {'Fano':>8} {'mean/N':>8} {'act%':>6} | {'mhat':>7}")
print("-" * 74)
for s in rows[:10]:
    A = load(s["name"] + "\\activity.csv")
    print(f"{s['name']:>16} | {s['mean']:8.2f} {s['cv']:6.2f} {s['fano']:8.1f} {s['fc']:8.4f} "
          f"{s['act']:6.1f} | {mr_fixed(A):7.3f}")
print("-" * 74)
print("admissible m_hat needs Fano>>1 (genuinely bursty, not pinned/Poisson) + mean/N<<1 + m_hat")
print("stable across bin widths. Fano~1 or bin-drifting m_hat => saturation/pinning, inadmissible.")
