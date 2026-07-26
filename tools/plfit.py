#!/usr/bin/env python3
"""
plfit.py -- rigorous power-law adjudication (Clauset-Shalizi-Newman / Vuong) for a
run's IEI-binned avalanche sizes. Self-contained (numpy + math; the `powerlaw`
package is buggy on new numpy). Answers what KS<0.1 cannot:
  (1) Is it a power law AT ALL? -> normalized log-likelihood-ratio (Vuong) vs
      lognormal and exponential, both normalized on the SAME tail support [xmin,inf).
      R>0 favors power_law; p<0.1 significant.
  (2) WHERE does the deviation sit? -> CDF-residual location (upper-tail = up-state
      dragon-kings, supports the story; low/mid = systematic curvature, refutes).
Run from a folder containing activity.csv.
"""
import numpy as np, math, sys

d = np.genfromtxt("activity.csv", delimiter=",", names=True)
A = np.asarray(d["A"], dtype=np.int64)

def avalanches_iei(A):
    A = np.asarray(A, dtype=np.int64)
    if A.sum() <= 0: return np.array([]), 1
    act = np.flatnonzero(A > 0)
    iei = 1 if len(act) < 2 else max(1, int(round(float(np.mean(np.diff(act))))))
    nb = len(A) // iei
    B = A[:nb*iei].reshape(nb, iei).sum(axis=1) if nb > 0 else A.copy()
    s, out = 0, []
    for b in B:
        if b > 0: s += int(b)
        elif s > 0: out.append(s); s = 0
    if s > 0: out.append(s)
    return np.asarray(out, float), iei

sizes, iei = avalanches_iei(A); sizes = sizes[sizes > 0]

def fit_pl(x):
    x = np.sort(x.astype(float)); cand = np.unique(x); cand = cand[cand < cand[-1]]; best = None
    for xmin in cand:
        xt = x[x >= xmin]; n = len(xt)
        if n < 30: continue
        a = 1.0 + n / np.sum(np.log(xt / xmin))
        ce = np.arange(1, n+1)/n; cf = 1 - (xt/xmin)**(1-a); ks = np.max(np.abs(ce-cf))
        if best is None or ks < best[0]: best = (ks, a, xmin, n)
    return best

res = fit_pl(sizes)
if res is None: print(f"n_aval={len(sizes)}: too few for a fit"); sys.exit(0)
ks, alpha, xmin, ntail = res
xt = np.sort(sizes[sizes >= xmin]); n = len(xt); lx = np.log(xt)

# per-point log-likelihoods, each normalized on the tail support [xmin, inf)
ll_pl = np.log((alpha-1.0)/xmin) - alpha*np.log(xt/xmin)
mu, sig = lx.mean(), lx.std(ddof=0)
Phi = lambda z: 0.5*(1.0 + math.erf(z/math.sqrt(2.0)))
Z = max(1.0 - Phi((math.log(xmin)-mu)/sig), 1e-300)            # lognormal mass on tail
ll_ln = (-np.log(xt) - math.log(sig*math.sqrt(2*math.pi)) - (lx-mu)**2/(2*sig*sig)) - math.log(Z)
mx = np.mean(xt - xmin); lam = 1.0/mx if mx > 0 else 1e-30
ll_ex = math.log(lam) - lam*(xt - xmin)

def vuong(la, lb):
    dd = la - lb; R = dd.sum(); s = dd.std(ddof=0)
    if s <= 0: return R, 1.0
    z = R/(math.sqrt(len(dd))*s); return R, math.erfc(abs(z)/math.sqrt(2.0))

print(f"n_aval={len(sizes):.0f}  IEI={iei}  tail_n={n}  xmin={xmin:.0f}  tau={alpha:.3f}  KS={ks:.3f}  max={sizes.max():.0f}")
print("  --- Vuong LLR (R>0 favors power_law; p<0.1 significant) ---")
for nm, ll in [('lognormal', ll_ln), ('exponential', ll_ex)]:
    R, p = vuong(ll_pl, ll)
    fav = ('power_law' if R > 0 else nm.upper()) if p < 0.1 else 'TIE (inconclusive)'
    print(f"    power_law vs {nm:11s}: R={R:+9.1f}  p={p:.3f}  -> {fav}")

ce = np.arange(1, n+1)/n; cf = 1 - (xt/xmin)**(1-alpha); resid = np.abs(ce - cf)
im = int(np.argmax(resid)); fr = im/n
loc = "UPPER-TAIL (up-states/dragon-kings -> supports story)" if fr > 0.7 else \
      ("LOW/MID range (systematic curvature -> refutes power law)" if fr < 0.6 else "MID-tail")
print(f"  max|CDF resid|={resid.max():.3f} at size={xt[im]:.0f} ({fr*100:.0f}% into tail) -> {loc}")
