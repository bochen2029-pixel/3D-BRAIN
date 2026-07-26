#!/usr/bin/env python3
"""airegime.py -- the ASYNCHRONOUS-IRREGULAR battery (CLAUDE.md Phase-0.5).

Fano and m_hat are POPULATION statistics. Neither can see whether individual neurons fire
irregularly, or whether pairs are decorrelated -- and those are the two defining properties of
the asynchronous-irregular (AI) state that the reverberating regime is supposed to be. A network
in which every neuron fires like a metronome, out of phase with its neighbours, would produce a
smooth population rate and an excellent Fano score while being the opposite of cortex-like.

Measured per run (needs spikes_window.csv from a DUMP_LEN>0 build; see tools/sweep_dump.ps1):
  * CV_ISI per neuron   -- irregularity.  Poisson = 1.0 exactly. Cortex in vivo ~ 0.8-1.2.
                           Clock-like < 0.5.  Bursty > 1.5.
  * pairwise correlation of binned spike counts -- synchrony. Cortex ~ 0.01-0.1; the awake
                           asynchronous state is famously near 0 (Ecker 2010). Synchronized
                           bursting >> 0.1.  Reported against the finite-sample noise floor
                           1/sqrt(nbins-1), because with a few hundred bins the SPREAD of r is
                           ~0.05 for independent trains -- only the MEAN is informative.
  * per-neuron Fano at 100 ms -- single-cell count variability (Poisson = 1).
  * near vs far pairs   -- the modular connectome should show higher within-column correlation;
                           if near-pair correlation is also ~0 the modules are not doing anything.

Usage:  python tools/airegime.py [label ...]     (default: the Session-4 dump set)
"""
import sys, os
import numpy as np

BASE   = r"C:\3D-BRAIN\run"
MIN_SP = 15        # neurons need this many spikes in the window for a CV_ISI estimate
NPAIR  = 1200      # neurons sampled for the pairwise-correlation matrix
BIN_MS = 10.0      # correlation bin width (standard for cortical noise correlations)
DT_MS  = 0.1
NEAR_UM = 437.5    # one column side at MOD_GRID=8, VOL=3500 -> "near" = same column scale


MAXROW = 24_000_000   # cap: a seizing run dumps ~50M spikes (~700 MB). Spikes are written in
                      # step order, so truncating ROWS truncates the TIME WINDOW -- ISIs stay
                      # valid, the window just gets shorter. Always reported when it triggers.

def load_spikes(path):
    try:
        import pandas as pd
        df = pd.read_csv(path, engine="c", nrows=MAXROW)
        return df["step"].to_numpy(np.int64), df["neuron"].to_numpy(np.int64)
    except ImportError:
        a = np.loadtxt(path, delimiter=",", skiprows=1, dtype=np.int64, max_rows=MAXROW)
        return a[:, 0], a[:, 1]


def load_neurons(path):
    a = np.genfromtxt(path, delimiter=",", names=True)
    return (np.asarray(a["x"], float), np.asarray(a["y"], float), np.asarray(a["z"], float),
            np.asarray(a["is_inh"], int))


def cv_isi(step, nid, nmax):
    """Per-neuron CV of inter-spike intervals. Fully vectorised."""
    o = np.argsort(nid, kind="stable")          # stable => step order preserved within a neuron
    n_s, t_s = nid[o], step[o]
    same = np.diff(n_s) == 0
    isi = np.diff(t_s)[same].astype(np.float64) * DT_MS
    own = n_s[:-1][same]
    cnt = np.bincount(own, minlength=nmax).astype(np.float64)
    s1 = np.bincount(own, weights=isi, minlength=nmax)
    s2 = np.bincount(own, weights=isi * isi, minlength=nmax)
    ok = cnt >= MIN_SP
    mu = np.divide(s1, cnt, out=np.zeros_like(s1), where=ok)
    va = np.divide(s2, cnt, out=np.zeros_like(s2), where=ok) - mu * mu
    cv = np.zeros(nmax)
    good = ok & (mu > 0)
    cv[good] = np.sqrt(np.maximum(va[good], 0)) / mu[good]
    return cv, good


def counts_matrix(step, nid, sel, t0, t1, binw_steps, nmax):
    nb = int((t1 - t0) // binw_steps)
    idx = np.full(nmax, -1, np.int64); idx[sel] = np.arange(len(sel))
    k = idx[nid]
    m = k >= 0
    b = (step[m] - t0) // binw_steps
    kk, bb = k[m], b
    ok = (bb >= 0) & (bb < nb)
    flat = kk[ok] * nb + bb[ok]
    C = np.bincount(flat, minlength=len(sel) * nb).reshape(len(sel), nb).astype(np.float32)
    return C, nb


def measure(rundir):
    """Compute the AI battery for one run directory. Returns a dict, or None if the run has no
    spike dump (build with -DDUMP_LEN>0). This is the single implementation -- analyze.py imports
    it for Gate-B clauses B4/B5 rather than growing a second copy of CV_ISI that could drift."""
    sp = os.path.join(rundir, "spikes_window.csv")
    if not os.path.exists(sp):
        return None
    step, nid = load_spikes(sp)
    px, py, pz, is_inh = load_neurons(os.path.join(rundir, "neurons.csv"))
    nmax = len(is_inh)
    t0, t1 = int(step.min()), int(step.max()) + 1

    cv, good = cv_isi(step, nid, nmax)
    exc = good & (is_inh == 0)
    inh = good & (is_inh == 1)

    # pairwise correlations over a random excitatory sample
    cand = np.flatnonzero(exc)
    rng = np.random.default_rng(7)
    sel = rng.choice(cand, size=min(NPAIR, len(cand)), replace=False)
    C, nb = counts_matrix(step, nid, sel, t0, t1, int(BIN_MS / DT_MS), nmax)
    sd = C.std(1)
    keep = sd > 0
    Z = (C[keep] - C[keep].mean(1, keepdims=True)) / sd[keep][:, None]
    R = (Z @ Z.T) / nb
    ks = sel[keep]
    iu = np.triu_indices(len(ks), k=1)
    r = R[iu]
    d = np.sqrt((px[ks][:, None] - px[ks][None, :]) ** 2 +
                (py[ks][:, None] - py[ks][None, :]) ** 2 +
                (pz[ks][:, None] - pz[ks][None, :]) ** 2)[iu]
    near, far = d < NEAR_UM, d >= 2 * NEAR_UM

    # per-neuron Fano at 100 ms
    Cf, _ = counts_matrix(step, nid, sel, t0, t1, int(100.0 / DT_MS), nmax)
    mf = Cf.mean(1); vf = Cf.var(1)
    fano = vf[mf > 0] / mf[mf > 0]

    return dict(
        nspikes=len(step), t0=t0, t1=t1, dur_s=(t1 - t0) * DT_MS * 1e-3,
        capped=len(step) >= MAXROW, n_exc=int(exc.sum()), n_inh=int(inh.sum()),
        cv_exc_mean=float(cv[exc].mean()), cv_exc_med=float(np.median(cv[exc])),
        cv_exc_p10=float(np.percentile(cv[exc], 10)), cv_exc_p90=float(np.percentile(cv[exc], 90)),
        cv_exc_frac_band=float(np.mean((cv[exc] > 0.7) & (cv[exc] < 1.3))),
        cv_inh_mean=float(cv[inh].mean()) if inh.sum() else float("nan"),
        cv_inh_med=float(np.median(cv[inh])) if inh.sum() else float("nan"),
        cv_inh_p10=float(np.percentile(cv[inh], 10)) if inh.sum() else float("nan"),
        cv_inh_p90=float(np.percentile(cv[inh], 90)) if inh.sum() else float("nan"),
        nb=nb, npairs=len(r), nsel=len(ks),
        r_mean=float(r.mean()), r_med=float(np.median(r)), r_sd=float(r.std()),
        r_noise=float(1.0 / np.sqrt(nb - 1)),
        r_near=float(r[near].mean()) if near.sum() else float("nan"), n_near=int(near.sum()),
        r_far=float(r[far].mean()) if far.sum() else float("nan"), n_far=int(far.sum()),
        fano_mean=float(fano.mean()), fano_med=float(np.median(fano)),
    )


def analyse(label):
    rd = os.path.join(BASE, label)
    m = measure(rd)
    if m is None:
        print(f"{label:<16} NO spikes_window.csv (build with -DDUMP_LEN=...)"); return
    cap = "  [ROW CAP HIT -- window truncated]" if m["capped"] else ""
    print(f"\n===== {label}  ({m['nspikes']:,} spikes over {m['dur_s']:.1f} s, {m['t0']}-{m['t1']}) ====={cap}")
    print(f"  CV_ISI  exc  n={m['n_exc']:6d}  mean {m['cv_exc_mean']:.3f}  median {m['cv_exc_med']:.3f}"
          f"  p10 {m['cv_exc_p10']:.3f}  p90 {m['cv_exc_p90']:.3f}"
          f"  | in [0.7,1.3]: {100*m['cv_exc_frac_band']:.1f}%")
    if m["n_inh"]:
        print(f"  CV_ISI  inh  n={m['n_inh']:6d}  mean {m['cv_inh_mean']:.3f}  median {m['cv_inh_med']:.3f}"
              f"  p10 {m['cv_inh_p10']:.3f}  p90 {m['cv_inh_p90']:.3f}")
    print(f"  pairwise r ({BIN_MS:.0f} ms bins, {m['nb']} bins, {m['npairs']:,} pairs of {m['nsel']} exc neurons)")
    print(f"      mean {m['r_mean']:+.4f}   median {m['r_med']:+.4f}   sd {m['r_sd']:.4f}"
          f"   |  independent-train noise floor sd = {m['r_noise']:.4f}")
    if m["n_near"]: print(f"      near (<{NEAR_UM:.0f} um, same-column scale) mean {m['r_near']:+.4f}  n={m['n_near']:,}")
    if m["n_far"]:  print(f"      far  (>{2*NEAR_UM:.0f} um)                    mean {m['r_far']:+.4f}  n={m['n_far']:,}")
    print(f"  per-neuron Fano (100 ms): mean {m['fano_mean']:.3f}  median {m['fano_med']:.3f}")


if __name__ == "__main__":
    labels = sys.argv[1:] or ["d_w9e200_nu100", "d_w9e200_nu5", "d_w9_ctl"]
    print("AI battery. Poisson reference: CV_ISI = 1.000, pairwise r = 0, per-neuron Fano = 1.000.")
    print("Cortex in vivo: CV_ISI ~ 0.8-1.2, pairwise r ~ 0.01-0.1. Clock-like: CV << 0.5.")
    for L in labels:
        analyse(L)
