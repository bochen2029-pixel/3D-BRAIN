#!/usr/bin/env python3
"""
bp_validate.py -- ground-truth rig for the branching-ratio estimator (Step 1 of the reframe).

The whole reframe hinges on ONE thing: an estimator that reads m->0 on a DEAD (drive-only) network
and ~0.98 on a genuinely reverberating one. Before trusting ANY m_hat on the sim, prove it on a
synthetic branching process of KNOWN m:   A_{t+1} ~ Poisson(m*A_t + h)   [Wilting-Priesemann 2018].

Two estimators, tested against ground truth on CLEAN and DRIFTING (nonstationary) series:
  * mr_current -- the incumbent tools/analyze.py::mr_branching_ratio (log-linear fit, no offset,
                  no detrend). Hypothesis: correct on clean series, but a slow drift's long-lag
                  autocorrelation fools it toward m~1 -> this is why it reads 0.99 on dead nets.
  * mr_fixed   -- high-pass detrend (kills slow homeostat ramp) + fit r_k = b*m^k + c (the offset c
                  absorbs a stationary drive contribution) + a b-significance guard so a
                  non-branching (drive-only) series returns m->0.

The "drift" column models the sim's DEAD net: the input-gain homeostat keeps ramping the drive
because the rate never reaches target, injecting a slow trend. That trend -- not any branching --
is what a naive autocorrelation misreads as criticality. Killing it is the make-or-break.

No file deps (pure synthetic). Run:  python tools/bp_validate.py
"""
import numpy as np

# ---- synthetic branching process of known m -------------------------------
def gen_bp(m, h, T=120_000, seed=0, drift_amp=0.0, burn=3000):
    """A_{t+1} ~ Poisson(m*A_t + h_t).  drift_amp>0 adds a slow sinusoidal swing to the drive h_t
    (adversarial stand-in for the homeostat ramp -- harder to remove than a pure linear ramp)."""
    rng = np.random.default_rng(seed)
    n = T + burn
    A = np.empty(n)
    A[0] = max(1.0, (h / max(1e-6, 1.0 - m)) if m < 1.0 else 5.0)
    for t in range(1, n):
        ht = h * (1.0 + drift_amp * np.sin(2.0 * np.pi * t / n))
        A[t] = rng.poisson(max(0.0, m * A[t-1] + ht))
    return A[burn:]

# ---- incumbent estimator (verbatim from analyze.py::mr_branching_ratio) ----
def mr_current(A, kmax=150):
    A = A.astype(float); A0 = A - A.mean(); var = np.dot(A0, A0)
    if var <= 0: return float('nan')
    ks = np.arange(1, kmax + 1)
    rk = np.array([np.dot(A0[:-k], A0[k:]) / var for k in ks])
    r1 = rk[0]; win = []
    for i in range(len(ks)):
        if rk[i] <= 0 or (r1 > 0 and rk[i] < 0.02 * r1): break
        if i > 2 and rk[i] > rk[i-1]: break
        win.append(i)
    if len(win) < 5:
        pos = np.flatnonzero(rk > 0); win = list(pos[:min(30, len(pos))])
    if len(win) < 5: return float('nan')
    coeff = np.polyfit(ks[win], np.log(rk[win]), 1)
    return float(np.exp(coeff[0]))

# ---- candidate fix --------------------------------------------------------
def _rk(A, kmax):
    A0 = A - A.mean(); var = np.dot(A0, A0)
    if var <= 0: return None
    return np.array([np.dot(A0[:-k], A0[k:]) / var for k in range(1, kmax + 1)])

def _highpass(A, W):
    """Subtract a centered moving average, normalized by the ACTUAL in-bounds count at each point
    (no zero-pad boundary humps -- that fake slow structure is what fooled the naive convolve)."""
    n = len(A); half = W // 2
    csum = np.concatenate([[0.0], np.cumsum(A)])
    idx = np.arange(n)
    lo = np.maximum(0, idx - half); hi = np.minimum(n, idx + half + 1)
    baseline = (csum[hi] - csum[lo]) / (hi - lo)
    return A - baseline

def mr_fixed(A, kmax=150, live_frac=0.10):
    A = A.astype(float)
    # (0) LIVENESS precondition: the branching ratio certifies the SUSTAINED (reverberating) regime.
    #     A network active in < live_frac of bins is in the absorbing (dead) phase -> m=0 by
    #     definition, regardless of within-blip autocorrelation. (Alive traces are 82%+ active,
    #     dead ones <1% -- a huge margin.) This is what makes a sparse drive-only net read dead
    #     instead of reporting the decay shape of isolated drive-triggered blips as "branching."
    if A.size == 0 or float(np.mean(A > 0)) < live_frac:
        return 0.0
    # (1) high-pass: subtract a long-window moving average -> removes drift slower than W while
    #     preserving branching autocorrelation (which lives at lags << W).
    W = int(min(len(A) // 4, 20 * kmax))
    if W >= 3:
        A = _highpass(A, W)
    rk = _rk(A, kmax)
    if rk is None or rk[0] < 0.05:      # (2) no lag-1 correlation => not branching => dead
        return 0.0
    ks = np.arange(1, kmax + 1)
    # (3) fit r_k = b*m^k + c ; linear in (b,c) given m, so a clean 1-D search over m.
    best = (np.inf, 0.0, 0.0, 0.0)
    for m in np.linspace(0.02, 1.06, 521):
        X = np.column_stack([m ** ks, np.ones_like(ks, float)])
        sol, *_ = np.linalg.lstsq(X, rk, rcond=None)
        res = float(np.sum((X @ sol - rk) ** 2))
        if res < best[0]:
            best = (res, m, sol[0], sol[1])
    _, m, b, c = best
    if b <= 0 or b < 0.05 * (abs(b) + abs(c) + 1e-9):   # (4) exponential part negligible => m->0
        return 0.0
    return float(m)

# ---- battery --------------------------------------------------------------
def main():
    Ms = [0.0, 0.5, 0.8, 0.98, 1.0]
    print("branching estimator vs ground truth   (T=120k;  drift = slow +/-60% drive swing)\n")
    print(f"{'true m':>7} | {'cur clean':>9} {'fix clean':>9} | {'cur drift':>9} {'fix drift':>9}")
    print("-" * 57)
    for i, m in enumerate(Ms):
        h = max(1.0, 200.0 * (1.0 - m)) if m < 1.0 else 4.0
        Ac = gen_bp(m, h, seed=1 + i, drift_amp=0.0)
        Ad = gen_bp(m, h, seed=101 + i, drift_amp=0.6)
        print(f"{m:7.2f} | {mr_current(Ac):9.3f} {mr_fixed(Ac):9.3f} | "
              f"{mr_current(Ad):9.3f} {mr_fixed(Ad):9.3f}")
    print("-" * 57)
    # the money row: a DEAD drive-only network must read m -> 0, drift or not.
    Ap  = gen_bp(0.0, 150.0, seed=999, drift_amp=0.0)
    Apd = gen_bp(0.0, 150.0, seed=998, drift_amp=0.8)
    print(f"DEAD (pure Poisson drive):  clean cur={mr_current(Ap):.3f} fix={mr_fixed(Ap):.3f}   |   "
          f"drift cur={mr_current(Apd):.3f} fix={mr_fixed(Apd):.3f}")
    print("\nPASS iff: fix recovers true m on clean AND drift, and reads ~0 on DEAD (both columns).")

if __name__ == "__main__":
    main()
