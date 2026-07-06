#!/usr/bin/env python3
"""
analyze.py -- the rigorous half of Gate B.

Reads the CSVs written by brain_phase0 and reports the acceptance instrument
*properly* (not by eyeballing a log-log line):

  * m_hat via the multistep-regression (MR) estimator   [Wilting & Priesemann 2018]
  * avalanche size power-law via MLE + KS               [Clauset-Shalizi-Newman 2009]
  * duration exponent + the crackling-noise relation
  * plots: activity trace, size distribution, m_k decay, 3D firing point cloud

Deps: numpy, matplotlib.  (For the gold-standard fit you can also `pip install powerlaw`.)
Run from the folder containing activity.csv / avalanches.csv / neurons.csv.
"""
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ---------------------------------------------------------------- load
def load_col(path, cols):
    d = np.genfromtxt(path, delimiter=",", names=True)
    return [np.asarray(d[c], dtype=float) for c in cols]

A            = load_col("activity.csv",   ["A"])[0].astype(np.int64)
sizes, durs  = load_col("avalanches.csv", ["size", "duration"])
sizes = sizes[sizes > 0]

# ---------------------------------------------------------------- MR estimator
def mr_branching_ratio(A, kmax=150):
    """Estimate branching ratio m by fitting slope_k ~ b*m^k over k=1..kmax."""
    A = A.astype(float)
    A0 = A - A.mean()
    var = np.dot(A0, A0)
    ks, rk = [], []
    for k in range(1, kmax + 1):
        cov = np.dot(A0[:-k], A0[k:])
        r = cov / var
        if r > 0:
            ks.append(k); rk.append(r)
    ks, rk = np.array(ks), np.array(rk)
    if len(ks) < 5:
        return float("nan"), ks, rk
    # log r_k = log b + k log m  -> weighted linear fit
    coeff = np.polyfit(ks, np.log(rk), 1)
    return float(np.exp(coeff[0])), ks, rk

m_hat, ks, rk = mr_branching_ratio(A)

# ---------------------------------------------------------------- MLE power law
def fit_powerlaw_mle(x):
    """Continuous MLE (CSN): scan x_min, alpha = 1 + n / sum ln(x/x_min), pick min KS."""
    x = np.sort(x[x > 0].astype(float))
    cand = np.unique(x)
    cand = cand[cand < cand[-1]]              # need data above x_min
    best = dict(ks=np.inf, alpha=np.nan, xmin=np.nan, n=0)
    for xmin in cand:
        xt = x[x >= xmin]
        n = len(xt)
        if n < 20:
            continue
        alpha = 1.0 + n / np.sum(np.log(xt / xmin))
        # KS between empirical and fitted CDF
        cdf_emp = np.arange(1, n + 1) / n
        cdf_fit = 1.0 - (xt / xmin) ** (1.0 - alpha)
        ks = np.max(np.abs(cdf_emp - cdf_fit))
        if ks < best["ks"]:
            best = dict(ks=ks, alpha=alpha, xmin=xmin, n=n)
    return best

pl_s = fit_powerlaw_mle(sizes)
pl_d = fit_powerlaw_mle(durs)

# crackling / scaling relation:  (tau_t - 1)/(tau - 1) should match <S> vs T slope
tau, tau_t = pl_s["alpha"], pl_d["alpha"]
predicted = (tau_t - 1) / (tau - 1) if (tau and tau_t and tau > 1) else np.nan
# measured <S>(T)
mask = durs > 0
uT = np.unique(durs[mask])
meanS = np.array([sizes[durs == T].mean() for T in uT])
good = meanS > 0
measured = np.polyfit(np.log(uT[good]), np.log(meanS[good]), 1)[0] if good.sum() > 3 else np.nan

# ------------------------------------------------- self-sustaining (MODULE.md §5)
# Gate B requires activity that "neither dies nor saturates" over the full 20 s.
# A network that fires only a startup transient then goes silent must NOT score
# near-critical: the MR estimator returns a spurious m_hat on an all-but-zero
# timeseries. So we compute a liveness gate from the activity tail and require it
# for every criticality box below.
n_steps = len(A)
a_all   = float(A.mean())                     if n_steps else 0.0
a_tail  = float(A[int(0.8 * n_steps):].mean()) if n_steps else 0.0   # mean A over last 20%
a_body  = float(A[int(0.2 * n_steps):int(0.8 * n_steps)].mean()) if n_steps else 0.0  # steady bulk
a_peak  = float(A.max())                      if n_steps else 0.0
# alive = still meaningfully active at the END (absolute floor) and not decayed to a
# small fraction of the steady bulk. Do NOT gate on peak: a startup transient inflates
# it and would wrongly fail a healthy low-rate intermittent/avalanche regime.
self_sustaining = (a_tail > 0.5) and (a_tail > 0.2 * a_body)

# ---------------------------------------------------------------- report
print("================ GATE B  ·  acceptance instrument ================")
print(f"  branching ratio  m_hat (MR)      = {m_hat:.4f}      target ~ 0.98")
print(f"  avalanche SIZE   tau  (MLE)      = {tau:.3f}  xmin={pl_s['xmin']:.0f}"
      f"  KS={pl_s['ks']:.3f}  (n={pl_s['n']})      target ~ 1.5")
print(f"  avalanche DUR    tau_t(MLE)      = {tau_t:.3f} xmin={pl_d['xmin']:.0f}"
      f"  KS={pl_d['ks']:.3f}  (n={pl_d['n']})      target ~ 2.0")
print(f"  crackling relation  predicted    = {predicted:.3f}   measured <S>(T) = {measured:.3f}")
print(f"  mean activity A                  = {a_all:.2f}   (bulk = {a_body:.2f}, last-20% = {a_tail:.2f}, peak = {a_peak:.0f})")
def ok(b): return "PASS" if b else "----"
print("  --------------------------------------------------------------")
print(f"  [{ok(self_sustaining)}] self-sustaining (alive through full run, not a startup transient)")
print(f"  [{ok(self_sustaining and 0.9 < m_hat < 1.02)}] near-critical (0.9 < m_hat < 1.02) [gated on liveness]")
print(f"  [{ok(self_sustaining and 1.2 < tau < 1.8 and pl_s['ks'] < 0.1)}] size power law (tau~1.5, KS<0.1)")
print(f"  [{ok(self_sustaining and np.isfinite(predicted) and abs(predicted-measured) < 0.3)}] crackling relation holds")
print("==================================================================")
print("NOTE: a raw power law is necessary, not sufficient. All three boxes +")
print("      balanced-ISN stats + shape collapse = 'provably brain-like'.")

# ---------------------------------------------------------------- plots
fig, ax = plt.subplots(1, 3, figsize=(16, 4.2))
seg = A[:min(len(A), 20000)]
ax[0].plot(seg, lw=0.5); ax[0].set_title("network activity A_t (first 2 s)")
ax[0].set_xlabel("step"); ax[0].set_ylabel("# firing")

# size distribution (log-log) + fitted slope
vals, counts = np.unique(sizes, return_counts=True)
pdf = counts / counts.sum()
ax[1].loglog(vals, pdf, ".", ms=3, alpha=0.6)
if np.isfinite(tau):
    xx = np.array([pl_s["xmin"], vals.max()])
    yy = (xx / pl_s["xmin"]) ** (-tau); yy *= pdf[vals >= pl_s["xmin"]][0] / yy[0]
    ax[1].loglog(xx, yy, "r-", lw=2, label=f"tau={tau:.2f}")
ax[1].set_title("avalanche size distribution"); ax[1].legend()
ax[1].set_xlabel("size S"); ax[1].set_ylabel("P(S)")

ax[2].semilogy(ks, rk, ".")
if np.isfinite(m_hat):
    ax[2].semilogy(ks, rk[0] * m_hat ** (ks - ks[0]), "r-", label=f"m={m_hat:.3f}")
ax[2].set_title("MR: slope_k vs lag k"); ax[2].legend()
ax[2].set_xlabel("lag k"); ax[2].set_ylabel("regression slope")
fig.tight_layout(); fig.savefig("criticality.png", dpi=130)
print("wrote criticality.png")

# 3D firing point cloud (the 'watch it think' teaser, offline)
try:
    x, y, z, inh, rate = load_col("neurons.csv", ["x", "y", "z", "is_inh", "rate_hz"])
    sub = np.random.default_rng(0).choice(len(x), size=min(40000, len(x)), replace=False)
    f3 = plt.figure(figsize=(7, 6)); a3 = f3.add_subplot(111, projection="3d")
    p = a3.scatter(x[sub], y[sub], z[sub], c=rate[sub], s=2,
                   cmap="inferno", vmin=0, vmax=np.percentile(rate, 99))
    a3.set_title("mean firing rate in 3D"); f3.colorbar(p, label="Hz")
    f3.savefig("pointcloud.png", dpi=130); print("wrote pointcloud.png")
except Exception as e:
    print("pointcloud skipped:", e)
