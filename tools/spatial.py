#!/usr/bin/env python3
"""spatial.py -- travelling waves and metastable assembly switching (FINAL_BLUEPRINT §7.4).

The blueprint's battery asks for more than the asynchronous-irregular statistics Gate B B1-B7
measures. It asks that the spatial/modular structure actually PRODUCE something:

    "distance-dependent + heavy-tailed + hierarchical-modular connectivity with geometric delays
     -> travelling waves, nested oscillations, metastable assembly switching"

and it names the failure mode those defend against -- "the soup": self-sustaining, non-seizing,
no avalanches, no metastability, passes every "is it alive?" smoke test and is still not
brain-like. Gate B retired the avalanche clause (MODULE.md §5.1), so metastability is now the
main independent check that the certified point is not soup.

Measured per run, from an existing spike dump (no new simulation needed):
  * module-level activity   -- MOD_GRID^3 columns from position; averaging ~390 neurons lifts
                               structure that per-neuron correlations cannot resolve
  * assembly correlation    -- module-module correlation, near vs far, against its noise floor
  * metastability           -- autocorrelation time of module activity vs a time-shuffled
                               surrogate; up/down switching shows a slow tail the surrogate lacks
  * travelling waves        -- cross-correlation peak lag vs inter-module distance. A wave of
                               velocity v gives lag ~ distance/v, i.e. a positive slope well
                               outside the shuffled floor.

EVERY statistic is reported against an explicit null. With near-zero pairwise correlation the
honest expectation is that waves and assemblies are ABSENT, and a tool that cannot return a
clean null is useless for deciding that.

Usage:  python tools/spatial.py [label ...]
"""
import sys, os
import numpy as np

BASE   = r"C:\3D-BRAIN\run"
DT_MS  = 0.1
VOL    = 3500.0     # config.h VOL_SIZE_UM
MODG   = 8          # config.h MOD_GRID
BIN_MS = 20.0       # module-activity bin (slow enough for assemblies, fast enough for waves)
MAXLAG = 25         # +/- bins for the cross-correlation lag scan (25 * 20 ms = 500 ms)
NPAIR  = 4000       # module pairs sampled for the wave/assembly statistics


def load(rundir):
    sp = os.path.join(rundir, "spikes_window.csv")
    if not os.path.exists(sp):
        return None
    try:
        import pandas as pd
        df = pd.read_csv(sp, engine="c", nrows=24_000_000)
        step, nid = df["step"].to_numpy(np.int64), df["neuron"].to_numpy(np.int64)
    except ImportError:
        a = np.loadtxt(sp, delimiter=",", skiprows=1, dtype=np.int64, max_rows=24_000_000)
        step, nid = a[:, 0], a[:, 1]
    d = np.genfromtxt(os.path.join(rundir, "neurons.csv"), delimiter=",", names=True)
    return step, nid, np.asarray(d["x"], float), np.asarray(d["y"], float), np.asarray(d["z"], float)


def module_series(step, nid, px, py, pz):
    """columns x time matrix of spike counts, plus each column's centre."""
    side = VOL / MODG
    ix = np.clip((px / side).astype(np.int64), 0, MODG - 1)
    iy = np.clip((py / side).astype(np.int64), 0, MODG - 1)
    iz = np.clip((pz / side).astype(np.int64), 0, MODG - 1)
    mod_of = (iz * MODG + iy) * MODG + ix
    nmod = MODG ** 3
    binw = int(BIN_MS / DT_MS)
    t0 = int(step.min())
    b = (step - t0) // binw
    nb = int(b.max()) + 1
    flat = mod_of[nid] * nb + b
    M = np.bincount(flat, minlength=nmod * nb).reshape(nmod, nb).astype(np.float64)
    ctr = np.stack([((np.arange(nmod) % MODG) + 0.5) * side,
                    ((np.arange(nmod) // MODG) % MODG + 0.5) * side,
                    ((np.arange(nmod) // (MODG * MODG)) + 0.5) * side], axis=1)
    return M, ctr, nb


def acf_time(Z, maxlag=60):
    """mean normalised autocorrelation across modules; return the curve and its 1/e crossing."""
    T = Z.shape[1]
    ac = np.array([np.mean(np.sum(Z[:, :T - k] * Z[:, k:], axis=1) / (T - k)) for k in range(maxlag)])
    ac = ac / (ac[0] + 1e-12)
    below = np.flatnonzero(ac < 1.0 / np.e)
    return ac, (float(below[0]) * BIN_MS if len(below) else float("nan"))


def analyse(label):
    rd = os.path.join(BASE, label)
    got = load(rd)
    if got is None:
        print(f"{label:<18} NO spikes_window.csv"); return
    step, nid, px, py, pz = got
    M, ctr, nb = module_series(step, nid, px, py, pz)
    live = M.sum(1) > 0
    M, ctr = M[live], ctr[live]
    sd = M.std(1); keep = sd > 0
    M, ctr, sd = M[keep], ctr[keep], sd[keep]
    Z = (M - M.mean(1, keepdims=True)) / sd[:, None]
    nmod = len(Z)

    rng = np.random.default_rng(11)
    Zs = np.stack([Z[i][rng.permutation(nb)] for i in range(nmod)])   # time-shuffled surrogate

    # --- assembly correlation: module-module, near vs far, vs noise floor -----------
    R = (Z @ Z.T) / nb
    iu = np.triu_indices(nmod, k=1)
    r = R[iu]
    d = np.sqrt(((ctr[:, None, :] - ctr[None, :, :]) ** 2).sum(-1))[iu]
    noise = 1.0 / np.sqrt(nb - 1)
    near, far = d < VOL / MODG * 1.5, d > VOL / 2

    # --- metastability: ACF time vs surrogate --------------------------------------
    ac, tau = acf_time(Z)
    acs, taus = acf_time(Zs)

    # --- travelling waves: peak cross-correlation lag vs distance ------------------
    # CAUTION (a false positive this test produced before being fixed): regressing |peak lag| on
    # distance over ALL pairs manufactures a positive slope out of nothing. Near pairs are
    # genuinely correlated and peak near zero lag; far pairs are uncorrelated, so their argmax is
    # uniform over the scan window and averages to MAXLAG/2. The resulting "wave" is a
    # correlated-vs-noise gradient, not propagation. Two guards: (1) keep only pairs whose peak
    # correlation is significant, so noise pairs cannot contribute a lag at all; (2) report the
    # implied velocity against COND_VEL -- a wave far slower than axonal conduction is suspect.
    ii = rng.choice(nmod, size=(min(NPAIR, nmod * (nmod - 1) // 2), 2))
    ii = ii[ii[:, 0] != ii[:, 1]]
    lags = np.arange(-MAXLAG, MAXLAG + 1)
    def peak(Zm):
        lg = np.empty(len(ii)); pk = np.empty(len(ii))
        for n, (a, b) in enumerate(ii):
            xa, xb = Zm[a], Zm[b]
            cc = np.array([np.dot(xa[max(0,-k):nb-max(0,k)], xb[max(0,k):nb-max(0,-k)]) / (nb-abs(k))
                           for k in lags])
            j = int(np.argmax(cc)); lg[n] = lags[j] * BIN_MS; pk[n] = cc[j]
        return lg, pk
    pl,  pk  = peak(Z)
    pls, pks = peak(Zs)
    dd  = np.sqrt(((ctr[ii[:, 0]] - ctr[ii[:, 1]]) ** 2).sum(-1))
    sig = pk > 3 * noise                      # only pairs that are actually correlated
    if sig.sum() > 20:
        sl = np.polyfit(dd[sig], np.abs(pl[sig]), 1)[0] * 1000.0     # ms per mm
        vel = (1000.0 / sl) if sl > 1e-6 else float("inf")           # um/ms
    else:
        sl, vel = float("nan"), float("nan")
    sl_all = np.polyfit(dd, np.abs(pl), 1)[0] * 1000.0
    sl_sur = np.polyfit(dd, np.abs(pls), 1)[0] * 1000.0
    rand_lag = MAXLAG * BIN_MS / 2.0          # mean |lag| if argmax were uniform = pure noise

    print(f"\n===== {label}   {nmod} live modules, {nb} bins of {BIN_MS:.0f} ms "
          f"({nb*BIN_MS*1e-3:.1f} s), {len(step):,} spikes =====")
    print(f"  module rate: mean {M.mean():.1f} spikes/bin  (={M.mean()/(BIN_MS*1e-3)/ (len(px)/MODG**3):.2f} Hz/neuron)")
    print(f"  ASSEMBLY  module-module r: all {r.mean():+.4f}  near {r[near].mean():+.4f}"
          f"  far {r[far].mean():+.4f}   | noise floor {noise:.4f}")
    print(f"  METASTABILITY  ACF excess over surrogate: @100ms {ac[int(100/BIN_MS)]-acs[int(100/BIN_MS)]:+.3f}"
          f"  @200ms {ac[int(200/BIN_MS)]-acs[int(200/BIN_MS)]:+.3f}"
          f"  @500ms {ac[int(500/BIN_MS)]-acs[int(500/BIN_MS)]:+.3f}   (1/e time {tau:.0f} ms, bin-limited)")
    print(f"  WAVES  significant pairs {100*sig.mean():.1f}%  |  slope(sig) {sl:+.2f} ms/mm"
          f"  -> velocity {vel:.0f} um/ms  (axonal COND_VEL = 300)")
    print(f"         slope(all pairs) {sl_all:+.2f}  surrogate {sl_sur:+.2f}"
          f"  |  mean |lag| {np.abs(pl).mean():.0f} ms vs {rand_lag:.0f} ms if pure noise")
    # A lag scan of +/-MAXLAG over only nb bins is unreliable: the (nb-|k|) normalisation gets
    # noisy and argmax drifts to the scan edges. Require the trace to be >=5x the scan width.
    short = nb < 5 * MAXLAG
    if short:
        print(f"  [!] trace is {nb} bins vs a +/-{MAXLAG}-bin lag scan -- WAVE RESULT UNRELIABLE")
        print(f"      (needs >= {5*MAXLAG} bins; dump a longer window). Reported as ABSENT, not as a null.")
    assembly = r[near].mean() > 3 * noise
    meta     = (ac[int(200/BIN_MS)] - acs[int(200/BIN_MS)]) > 0.10
    wave     = bool(not short and sig.sum() > 20 and np.isfinite(sl) and sl > 0.5 and 30 < vel < 3000)
    for name, v in (("assembly structure (near-module r >> floor)", assembly),
                    ("metastable slow tail (ACF excess @200 ms > 0.10)", meta),
                    ("travelling wave (significant pairs, plausible velocity)", wave)):
        print(f"    [{'PRESENT' if v else ' ABSENT'}] {name}")


if __name__ == "__main__":
    labels = sys.argv[1:] or ["L_wm200_100s", "d_gwe5_nu5", "d_w9_ctl"]
    print("Spatial structure battery. Every statistic is reported against an explicit null;")
    print("with near-zero pairwise correlation the honest expectation is ABSENT for waves.")
    for L in labels:
        analyse(L)
