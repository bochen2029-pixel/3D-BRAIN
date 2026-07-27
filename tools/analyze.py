#!/usr/bin/env python3
"""
analyze.py -- the Gate B acceptance instrument (MODULE.md Sec.5, amended 2026-07-25).

Emits the B1-B7 scorecard -- the part of Gate B measurable from ONE run. Gate B has nine clauses;
B8 (robustness) and B9 (inhibition-stabilized) are CROSS-RUN and are named but not verified here:
  B8 -> re-run with a sustained +/-2% perturbation (tools/sweep_b8.ps1) and require B1-B6 again
  B9 -> tools/sweep_isn.ps1 + tools/isn.py (needs the RATEDUMP_* E/I-split trace)
A run passes B1-B7 iff all seven hold:

  B1 near-critical     m_hat ~ 0.98 (MR estimator, generation scale)   0.9 < m < 1.02
  B2 scale-invariant   m_hat FLAT across bins 3-10                     spread < 0.03
  B3 not seizing/floor population Fano in 2-20, 0% silent, maxA/N << 1%
  B4 asynchronous      mean pairwise r < 0.05, vs its noise floor      [needs spike dump]
  B5 irregular         CV_ISI median 0.8-1.2, majority in [0.7,1.3]    [needs spike dump]
  B6 self-sustaining   alive + recurrent >> external drive             [knockdown = companion run]
  B7 two controllers   both off rails, stationary, rate on RHO0        [needs sim.log ctrl trace]

B4/B5 are computed by tools/airegime.py (imported, not reimplemented) and need a build with
-DDUMP_LEN>0. B7 parses the [ctrl] readout from sim.log. Clauses whose inputs are absent report
**UNMEASURED**, never PASS -- a missing measurement is not a satisfied one.

RETIRED (MODULE.md Sec.5.1): avalanche tau/KS, the crackling relation, and shape collapse. An
avalanche presupposes silence between cascades; the reverberating regime is never silent (IEI=1
everywhere), so tau is an artifact of the binning threshold, not a property of the dynamics.
They are still COMPUTED and printed below as diagnostics -- clearly demoted, never part of the
verdict -- because Sec.5.1 leaves open whether the sustained frame still owes some power-law
statement, and throwing the code away would foreclose answering that.

Deps: numpy, matplotlib.  Run from a run/ folder (activity.csv, neurons.csv, sim.log).
"""
import os, re, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

SKIP_FRAC   = 0.10          # drop the startup transient before any steady-state statistic
GEN_BIN     = 5             # generation scale in steps (~0.5 ms; COND_VEL 300 um/ms, lambda 150 um)
PLATEAU_BINS = (3, 5, 7, 10)

# B7 checks the settled rate against the homeostatic set-point. Sweep builds override RHO0_HZ at
# compile time (-DRHO0_HZ=...) and the binary does not record it, so read the default from
# config.h and allow an explicit override for sweep points that changed it.
def _cfg(name, default):
    try:
        p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "include", "config.h")
        m = re.search(rf"^#define\s+{name}\s+([\d.eE+-]+)f?", open(p, encoding="utf-8",
                                                                  errors="replace").read(), re.M)
        return float(m.group(1)) if m else default
    except Exception:
        return default
RHO0_HZ = float(os.environ.get("BRAIN_RHO0", _cfg("RHO0_HZ", 3.0)))

# ---------------------------------------------------------------- load
def load_col(path, cols):
    d = np.genfromtxt(path, delimiter=",", names=True)
    return [np.asarray(d[c], dtype=float) for c in cols]

# CLI:  python analyze.py [rundir] [--append]
#   rundir   -- analyse that run instead of the cwd (so a sweep can be scored in a loop)
#   --append -- append this run's B1-B7 row to sweep_log.csv (see write_log_row at the bottom)
_POS    = [a for a in sys.argv[1:] if not a.startswith("--")]
APPEND  = "--append" in sys.argv
_LOGDIR = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
RUNDIR  = os.path.abspath(_POS[0]) if _POS else os.getcwd()
if _POS:
    os.chdir(RUNDIR)
LABEL   = os.path.basename(RUNDIR)

A            = load_col("activity.csv",   ["A"])[0].astype(np.int64)

# ----- avalanches, binned at the mean inter-event interval (Beggs-Plenz convention) --
# Binning at raw dt with thr=0 alone can move tau between 1.5 and 5 (too fine fragments
# cascades -> steep; too coarse merges them). The correct bin width is <IEI>, the mean
# gap between active frames. (Only meaningful once there are real quiescent gaps, i.e.
# the low-drive SOC regime.) Recompute from activity.csv, ignoring the C++ raw bins.
def avalanches_iei(A):
    A = np.asarray(A, dtype=np.int64)
    if A.sum() <= 0:
        return np.array([]), np.array([]), 1, [], np.array([])
    active = np.flatnonzero(A > 0)
    iei = 1 if len(active) < 2 else max(1, int(round(float(np.mean(np.diff(active))))))
    nb = len(A) // iei
    B = A[:nb * iei].reshape(nb, iei).sum(axis=1).astype(float) if nb > 0 else A.astype(float)
    profiles, cur = [], []                       # profiles = the temporal SHAPE of each avalanche
    for b in B:
        if b > 0: cur.append(float(b))
        elif cur: profiles.append(np.asarray(cur, float)); cur = []
    if cur: profiles.append(np.asarray(cur, float))
    sizes = np.asarray([p.sum() for p in profiles], float)
    durs  = np.asarray([len(p)  for p in profiles], float)
    return sizes, durs, iei, profiles, B

sizes, durs, iei_bin, profiles, Bser = avalanches_iei(A)

# ----- GATE #1: separation of timescales (validity of the whole adjudication) ----
# Avalanche exponents/collapse are only meaningful once the network truly quiesces
# BETWEEN cascades: mean quiet-time must exceed mean avalanche-duration (aim >=5x).
# Below that, concurrent cascades merge -> every downstream number is confounded, and
# no verdict can be trusted regardless of how pretty tau looks.
def quiet_gaps(B):
    B = np.asarray(B); gaps = []; g = 0
    for b in B:
        if b <= 0: g += 1
        elif g > 0: gaps.append(g); g = 0
    return np.asarray(gaps, float)
_gaps      = quiet_gaps(Bser)
mean_quiet = float(_gaps.mean()) if len(_gaps) else 0.0
mean_dur   = float(durs.mean())  if len(durs)  else 0.0
qd_ratio   = (mean_quiet / mean_dur) if mean_dur > 0 else 0.0
gaps_ok    = qd_ratio >= 5.0

# ------------------------------------------- branching estimators (see IEI caveat)
def mr_branching_ratio(A, kmax=150, live_frac=0.10):
    """Wilting-Priesemann branching ratio m_hat, made DRIVE-ROBUST. Validated on synthetic
    branching processes of known m (tools/bp_validate.py): recovers m in {0,.5,.8,.98,1}, stays
    put under slow drive drift, and reads m->0 on dead/drive-only nets -- both synthetic AND the
    real r01_drive / p1_nu10 traces -- where the naive log-linear fit read a spurious ~0.99.
    Three fixes over the naive estimator (before/after battery in tools/bp_validate.py):
      (0) LIVENESS gate: a net active in < live_frac of bins is absorbing/dead => m=0. The
          branching ratio certifies the SUSTAINED (reverberating) regime; alive traces are 82%+
          active, dead <1%. Without it, a sparse drive-only net reports the decay shape of
          isolated blips (~0.94) as if it were branching.
      (1) edge-normalized HIGH-PASS detrend: removes the homeostat's slow drift, whose long-lag
          autocorrelation the naive fit misreads as m~1 (Priesemann & Shriki 2018).
      (2) OFFSET-exponential fit r_k = b*m^k + c: c absorbs the stationary drive floor so only
          genuine exponential structure sets m; a b-significance guard returns m->0 when there is
          no exponential component at all (absence-of-branching then reads 0, not exp(slope~0)=1).
    Returns (m_hat, ks, rk); rk is the detrended normalized autocorrelation, for the plot."""
    A = np.asarray(A, float); ks = np.arange(1, kmax + 1)
    if A.size == 0 or float(np.mean(A > 0)) < live_frac:        # (0) liveness
        return 0.0, ks, np.zeros(kmax)
    W = int(min(len(A) // 4, 20 * kmax))                        # (1) edge-normalized high-pass
    if W >= 3:
        n = len(A); half = W // 2
        csum = np.concatenate([[0.0], np.cumsum(A)])
        idx = np.arange(n); lo = np.maximum(0, idx - half); hi = np.minimum(n, idx + half + 1)
        A = A - (csum[hi] - csum[lo]) / (hi - lo)
    A0 = A - A.mean(); var = float(np.dot(A0, A0))
    if var <= 0: return 0.0, ks, np.zeros(kmax)
    rk = np.array([np.dot(A0[:-k], A0[k:]) / var for k in ks])
    if rk[0] < 0.05: return 0.0, ks, rk                         # no lag-1 corr => not branching
    best = (np.inf, 0.0, 0.0, 0.0)                              # (2) fit r_k = b*m^k + c
    for m in np.linspace(0.02, 1.06, 521):
        X = np.column_stack([m ** ks, np.ones_like(ks, float)])
        sol, *_ = np.linalg.lstsq(X, rk, rcond=None)
        res = float(np.sum((X @ sol - rk) ** 2))
        if res < best[0]: best = (res, m, sol[0], sol[1])
    _, m, b, c = best
    if b <= 0 or b < 0.05 * (abs(b) + abs(c) + 1e-9): return 0.0, ks, rk
    return float(m), ks, rk

m_hat, ks_mr, rk_mr = mr_branching_ratio(A)

def running_sigma(B):
    """Avalanche branching: slope of B[t+1] on B[t] over ACTIVE bins (within avalanches)
    on the IEI series. ~1 at criticality. Like the MR, only trustworthy once IEI>1."""
    B = np.asarray(B, float)
    if len(B) < 20: return float('nan')
    m = B[:-1] > 0; x, y = B[:-1][m], B[1:][m]
    if len(x) < 20 or x.std() == 0: return float('nan')
    return float(np.polyfit(x, y, 1)[0])
sigma_run = running_sigma(Bser)

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

# ----- avalanche SHAPE COLLAPSE (the primary criticality certificate) ------------
# Scaling hypothesis: the mean temporal profile <A(t|T)> of avalanches of duration T,
# rescaled A -> A*T^(1-gamma) and t -> t/T, collapses onto ONE universal curve, with
# gamma matching the crackling relation gamma_cr=(tau_t-1)/(tau-1). Exponents can be
# faked by merging/finite-size; a geometric collapse of ALL durations cannot -- so THIS,
# not KS, is the Gate B verdict. (Friedman et al. 2012; Sethna, crackling noise.)
def shape_collapse(profiles, npts=25, min_per_dur=8, Tmin=4):
    from collections import defaultdict
    byT = defaultdict(list)
    for p in profiles:
        if len(p) >= Tmin: byT[len(p)].append(p)
    Ts = sorted(T for T, ps in byT.items() if len(ps) >= min_per_dur)
    if len(Ts) < 3: return None
    grid = np.linspace(0, 1, npts)
    prof = {T: np.interp(grid, np.linspace(0, 1, T), np.vstack(byT[T]).mean(axis=0)) for T in Ts}
    def resid(g):
        S = np.vstack([prof[T] * (T ** (1.0 - g)) for T in Ts])
        S = S / (S.max(axis=1, keepdims=True) + 1e-12)     # compare SHAPE (unit peak)
        return float(np.mean(np.var(S, axis=0)))
    gs = np.linspace(1.0, 3.0, 101); errs = np.array([resid(g) for g in gs])
    return dict(gamma=float(gs[int(np.argmin(errs))]), resid=float(errs.min()),
                Ts=Ts, grid=grid, prof=prof)

sc = shape_collapse(profiles)
gamma_cr = predicted                                   # crackling-predicted collapse exponent
if sc is not None:
    gamma_sc = sc["gamma"]
    collapse_ok = (sc["resid"] < 0.03) and np.isfinite(gamma_cr) and abs(gamma_sc - gamma_cr) < 0.35
else:
    gamma_sc, collapse_ok = float("nan"), False

# =============================================================================
#  GATE B  ·  B1-B7  (MODULE.md §5, amended 2026-07-25)
# =============================================================================
def rebin(x, b):
    if b <= 1: return np.asarray(x, float)
    nb = len(x) // b
    return x[:nb * b].reshape(nb, b).sum(1).astype(float) if nb else np.asarray(x, float)

n_steps = len(A)
Ass     = A[int(SKIP_FRAC * n_steps):]            # steady state: transient dropped
a_all   = float(A.mean())                      if n_steps else 0.0
a_tail  = float(A[int(0.8 * n_steps):].mean()) if n_steps else 0.0
a_body  = float(A[int(0.2 * n_steps):int(0.8 * n_steps)].mean()) if n_steps else 0.0

# ---- B1 near-critical / B2 scale-invariant ---------------------------------
m_bins = {b: mr_branching_ratio(rebin(Ass, b))[0] for b in PLATEAU_BINS}
m_gen  = mr_branching_ratio(rebin(Ass, GEN_BIN))[0]
# a zero is the b-significance guard firing at one bin width, not a physical value;
# exclude it from the SPREAD but say so, rather than letting it fake or break flatness.
_mv    = [v for v in m_bins.values() if v > 0]
m_spread = (max(_mv) - min(_mv)) if len(_mv) >= 2 else float("nan")
m_zeros  = [b for b, v in m_bins.items() if v <= 0]
B1 = 0.9 < m_gen < 1.02
B2 = np.isfinite(m_spread) and m_spread < 0.03 and len(_mv) >= 3

# ---- B3 neither seizing nor the Poisson drive floor ------------------------
mu, va = float(Ass.mean()), float(Ass.var())
fano   = va / mu if mu > 0 else 0.0
try:
    _rate = load_col("neurons.csv", ["rate_hz"])[0]
    N_tot = len(_rate); silent = float(np.mean(_rate < 0.05))
except Exception:
    N_tot, silent = 0, float("nan")
# steady-state max, NOT A.max(): the startup transient peaks at ~30% of N on a healthy run and
# would fail B3 on every point. Every other B3 term is computed on Ass, so this must be too.
maxA_frac = (float(Ass.max()) / N_tot) if N_tot else float("nan")
B3 = (2.0 <= fano <= 20.0) and (not np.isfinite(silent) or silent < 0.01) \
     and (not np.isfinite(maxA_frac) or maxA_frac < 0.01)

# ---- B4 asynchronous / B5 irregular  (tools/airegime.py, needs -DDUMP_LEN>0) --
try:
    from airegime import measure as ai_measure
    ai = ai_measure(".")
except Exception as e:
    ai = None; print(f"[warn] AI battery unavailable: {e}")
if ai:
    B4 = abs(ai["r_mean"]) < 0.05
    B5 = (0.8 <= ai["cv_exc_med"] <= 1.2) and (ai["cv_exc_frac_band"] > 0.5)
else:
    B4 = B5 = None                                    # UNMEASURED, never PASS

# ---- B7 controller authority (parse the [ctrl] readout from sim.log) --------
def parse_ctrl(path="sim.log"):
    if not os.path.exists(path): return None
    rows = []
    for ln in open(path, encoding="utf-8", errors="replace"):
        if not ln.startswith("[ctrl"): continue
        d = {}
        for pat, keys in ((r"w_inh ([\d.]+) \[[^\]]*\] \(init ([\d.]+) cap ([\d.]+)\)", ("w_inh", "w_init", "w_cap")),
                          (r"w_exc ([\d.]+)",                                          ("w_exc",)),
                          (r"rate E ([\d.]+) I ([\d.]+) Hz",                            ("rE", "rI")),
                          (r"gain ([\d.]+) \(railed lo ([\d.]+)% hi ([\d.]+)%\)",        ("gain", "rlo", "rhi")),
                          (r"exc ([-\d.]+) inh ([-\d.]+)\s+I/E",                         ("d_exc", "d_inh")),
                          (r"ext ([-\d.]+)",                                             ("d_ext",)),
                          (r"PSP mV: exc ([\d.]+) ext ([\d.]+)",                         ("psp_exc", "psp_ext"))):
            mm = re.search(pat, ln)
            if mm:
                for k, v in zip(keys, mm.groups()): d[k] = float(v)
        if d: rows.append((("final" in ln.split("]")[0]), d))
    if not rows: return None
    merged, cur = [], {}
    for is_final, d in rows:                       # the two lines of one probe share a step
        cur.update(d); cur["final"] = is_final
        if "gain" in cur and "w_inh" in cur: merged.append(cur); cur = {}
    return merged or None

ctrl = parse_ctrl()
if ctrl:
    fin = ctrl[-1]
    gains = [c["gain"] for c in ctrl if "gain" in c]
    rates = [c["rE"]   for c in ctrl if "rE"   in c]
    # stationary = the controller has stopped travelling. Compare the last two probes.
    stat = (len(gains) < 2) or (abs(gains[-1] - gains[-2]) <= 0.02 * max(gains[-1], 1e-9))
    rate_ok = abs(fin.get("rE", 0.0) - RHO0_HZ) <= 0.5 * RHO0_HZ if "rE" in fin else False
    w_head  = fin.get("w_inh", 0) < 0.90 * fin.get("w_cap", 1e9)
    B7 = (fin.get("rlo", 100) < 20.0) and (fin.get("rhi", 100) < 20.0) and stat and rate_ok and w_head
    recur = (fin.get("d_exc", 0.0) / fin["d_ext"]) if fin.get("d_ext", 0) > 0 else float("inf")
else:
    B7 = None; fin = {}; gains = rates = []; stat = rate_ok = w_head = False; recur = float("nan")

# ---- B6 self-sustaining ON RECURRENCE --------------------------------------
alive = (a_tail > 0.5) and (a_tail > 0.2 * a_body)
# within-run half: alive AND recurrent drive dominates external. The drive-KNOCKDOWN half is a
# cross-run comparison (tools/sweep_drive.ps1) that a single-run analyser cannot see -- so it is
# reported as a standing requirement, not silently counted as satisfied.
B6 = alive and (recur > 10.0) if np.isfinite(recur) else None

# ---------------------------------------------------------------- report
def mark(b): return "PASS" if b is True else ("UNMEASURED" if b is None else "FAIL")
clauses = [("B1 near-critical",   B1, f"m_hat(bin{GEN_BIN}) = {m_gen:.4f}                    need 0.9 < m < 1.02"),
           ("B2 scale-invariant", B2, f"plateau spread = {m_spread:.4f} over bins {PLATEAU_BINS}   need < 0.03"),
           ("B3 not seize/floor", B3, f"Fano = {fano:.2f}  silent = {100*silent:.2f}%  maxA/N = {100*maxA_frac:.3f}%   need Fano 2-20"),
           ("B4 asynchronous",    B4, (f"mean pairwise r = {ai['r_mean']:+.4f}  (sd {ai['r_sd']:.4f} vs noise floor {ai['r_noise']:.4f})"
                                       if ai else "no spikes_window.csv -- rebuild with -DDUMP_LEN>0")),
           ("B5 irregular",       B5, (f"CV_ISI median = {ai['cv_exc_med']:.3f}  in-band {100*ai['cv_exc_frac_band']:.1f}%  per-neuron Fano {ai['fano_mean']:.3f}"
                                       if ai else "no spikes_window.csv -- rebuild with -DDUMP_LEN>0")),
           ("B6 self-sustaining", B6, (f"alive={alive}  recurrent/external drive = {recur:.1f}x   need >10x"
                                       if np.isfinite(recur) else "no [ctrl] readout in sim.log")),
           ("B7 two controllers", B7, (f"gain {fin.get('gain',float('nan')):.3f} railed lo {fin.get('rlo',float('nan')):.1f}%  "
                                       f"w_inh {fin.get('w_inh',float('nan')):.1f}/{fin.get('w_cap',float('nan')):.0f}  "
                                       f"rate {fin.get('rE',float('nan')):.1f} vs {RHO0_HZ:.1f} Hz  stationary={stat}"
                                       if ctrl else "no [ctrl] readout in sim.log"))]

print("===== GATE B · B1-B7 from this run (B8/B9 are cross-run; MODULE.md §5, 2026-07-27) =====")
print(f"  run: {n_steps} steps ({n_steps*0.1e-3:.1f} s)   mean A = {a_all:.2f}  (bulk {a_body:.2f}, last-20% {a_tail:.2f})")
# B8 is a CROSS-RUN clause: it asks whether B1-B6 still hold under a sustained perturbation, so a
# single run can only report which side of the comparison it is. Say so explicitly rather than
# letting a perturbed run's scorecard be mistaken for an unperturbed certification.
def _knob_val(name, default=0.0, path="sim.log"):
    if os.path.exists(path):
        for ln in open(path, encoding="utf-8", errors="replace"):
            if ln.startswith("[knobs]"):
                m = re.search(rf"\b{name}=([-\d.eE+]+)", ln)
                return float(m.group(1)) if m else default
    return default
_pert = _knob_val("PARADOX_INJ")
if _pert:
    _dex = fin.get("d_exc", float("nan"))
    print(f"  >>> THIS IS A B8 PERTURBED RUN: PARADOX_INJ = {_pert:+g}"
          + (f" ({100*_pert/_dex:+.1f}% of the {_dex:.3f} mV/ms excitatory drive)" if _dex == _dex else "")
          + " <<<")
    print("      B1-B6 below are the B8 test. B7 is not part of B8 (the controllers are expected")
    print("      to move in order to absorb the perturbation -- that is what they are for).")
if n_steps < 1_000_000:
    print("  [!] < 100 s: §5 requires N_STEPS >= 1e6 to certify B6/B7 -- the slow controller")
    print("      cannot converge in a shorter window. Treat B6/B7 below as provisional.")
if m_zeros:
    print(f"  [!] m_hat = 0 at bin(s) {m_zeros}: b-significance guard, an estimator instability at")
    print("      that width, not a physical value. Excluded from the B2 spread -- do not quote it.")
print("  ---------------------------------------------------------------------------")
for name, val, detail in clauses:
    print(f"  [{mark(val):^10}] {name:<20} {detail}")
print("  ---------------------------------------------------------------------------")
_vals = [c[1] for c in clauses]
if any(v is None for v in _vals):
    print("  >>> VERDICT: INCOMPLETE -- clause(s) unmeasured. A missing measurement is NOT a pass.")
elif all(_vals):
    print("  >>> VERDICT: ALL SEVEN CLAUSES PASS on this run.")
    print("      §5 also requires >=3 independent seeds. One run is a realisation, not a regime.")
else:
    print(f"  >>> VERDICT: FAIL -- {', '.join(n for n, v, _ in clauses if v is False)}")
print("  CROSS-RUN clauses NOT checkable here -- a B1-B7 pass above is not a Gate B pass:")
print("    B6 drive-knockdown half : tools/sweep_drive.ps1  -- cut NU_EXT >=10x, stay in-band")
print("    B8 robustness           : tools/sweep_b8.ps1     -- sustained +/-2%, require B1-B6")
print("    B9 inhibition-stabilized: tools/sweep_isn.ps1 + tools/isn.py  -- paradoxical effect")
print("===========================================================================")

# ---- RETIRED clauses, kept as diagnostics (MODULE.md §5.1) -----------------
print("\n-- retired (§5.1) -- diagnostic only, NOT part of the verdict ---------------")
print(f"  avalanche binning <IEI> = {iei_bin} step(s), {len(sizes)} avalanches;"
      f"  quiet/duration = {qd_ratio:.2f}" + ("" if gaps_ok else "  [gap-less: the avalanche frame does not apply here]"))
print(f"  size tau (MLE) = {tau:.3f} KS={pl_s['ks']:.3f}   dur tau_t = {tau_t:.3f} KS={pl_d['ks']:.3f}"
      f"   crackling pred {predicted:.3f} vs measured {measured:.3f}")
print(f"  shape collapse: " + (f"gamma={gamma_sc:.3f} resid={sc['resid']:.4f}" if sc is not None else "too few durations"))
print("  §5.1 leaves OPEN whether the sustained frame owes some power-law statement; these")
print("  numbers are retained to answer that, not to certify anything.")

# ---------------------------------------------------------------- sweep log (--append)
LOG_COLS = ["label", "seed", "N_STEPS", "W_EXC_INIT", "W_INH_INIT", "W_MAX", "NU_EXT_HZ", "W_EXT",
            "RHO0_HZ", "ISTDP_ETA", "GAIN_ETA", "GAIN_MIN", "STD_U", "TAU_REC_MS", "LAMBDA_UM",
            "TARGET_OUTDEG", "m_gen", "m_spread", "fano", "silent_pct", "maxA_pct", "r_mean",
            "r_near", "cv_med", "cv_band_pct", "pn_fano", "recur_x", "gain", "gain_railed_pct",
            "w_inh", "w_cap", "rate_hz", "B1", "B2", "B3", "B4", "B5", "B6", "B7", "GATE_B"]

def _knobs(path="sim.log"):
    """Knob set from main.cu's [knobs] line. Runs built before that line existed fall back to what
    the [ctrl] readout implies: W_EXC/W_INH/W_MAX directly, W_EXT from the external PSP (dt*W_EXT),
    NU_EXT from the mean external drive (W_EXT*nu*dt*1e-3). Everything else stays BLANK rather than
    being guessed -- a blank is honest, an invented value would read as a measurement."""
    k = {}
    if os.path.exists(path):
        for ln in open(path, encoding="utf-8", errors="replace"):
            if ln.startswith("[knobs]"):
                k = {a: float(b) for a, b in re.findall(r"(\w+)=([-\d.eE+]+)", ln)}
                break
    if not k and ctrl:
        f = ctrl[-1]
        k["W_EXC_INIT"], k["W_INH_INIT"], k["W_MAX"] = f.get("w_exc"), f.get("w_init"), f.get("w_cap")
        if f.get("psp_ext"):
            k["W_EXT"] = f["psp_ext"] / 0.1
            if f.get("d_ext") is not None and k["W_EXT"]:
                k["NU_EXT_HZ"] = f["d_ext"] / (k["W_EXT"] * 0.1 * 1e-3)
    return {a: b for a, b in k.items() if b is not None}

def write_log_row():
    import csv
    path = os.path.join(_LOGDIR, "sweep_log.csv")
    # The historical log predates the §5 amendment (tau/KS/crackle/CRITICAL columns) and its rows
    # CANNOT be rescored under B1-B7: the binaries that produced them printed no [ctrl] readout and
    # dumped no spikes, so B4/B5/B7 are unrecoverable for them. Preserve that record intact under
    # the project's existing convention (cf. sweep_log_preSTD.csv) rather than padding it with
    # blanks that would later read as measurements. Never deletes.
    if os.path.exists(path):
        with open(path, newline="", encoding="utf-8") as f:
            hdr = next(csv.reader(f), [])
        if hdr != LOG_COLS:
            keep, i = os.path.join(_LOGDIR, "sweep_log_preB.csv"), 1
            while os.path.exists(keep):
                keep = os.path.join(_LOGDIR, f"sweep_log_preB.{i}.csv"); i += 1
            os.replace(path, keep)
            print(f"  [log] pre-amendment log preserved as {os.path.basename(keep)}")
    kb, seed = _knobs(), ""
    if os.path.exists("sim.log"):
        mm = re.search(r"seed=(\d+)", open("sim.log", encoding="utf-8", errors="replace").readline())
        seed = mm.group(1) if mm else ""
    def g(d, k, fmt="{:g}"):
        v = d.get(k)
        return "" if v is None or (isinstance(v, float) and not np.isfinite(v)) else fmt.format(v)
    row = dict(label=LABEL, seed=seed, N_STEPS=n_steps,
               m_gen=f"{m_gen:.4f}",
               m_spread=("" if not np.isfinite(m_spread) else f"{m_spread:.4f}"),
               fano=f"{fano:.2f}",
               silent_pct=("" if not np.isfinite(silent) else f"{100*silent:.2f}"),
               maxA_pct=("" if not np.isfinite(maxA_frac) else f"{100*maxA_frac:.3f}"),
               r_mean=(f"{ai['r_mean']:+.4f}" if ai else ""),
               r_near=(f"{ai['r_near']:+.4f}" if ai else ""),
               cv_med=(f"{ai['cv_exc_med']:.3f}" if ai else ""),
               cv_band_pct=(f"{100*ai['cv_exc_frac_band']:.1f}" if ai else ""),
               pn_fano=(f"{ai['fano_mean']:.3f}" if ai else ""),
               recur_x=("" if not np.isfinite(recur) else f"{recur:.1f}"),
               gain=g(fin, "gain", "{:.3f}"), gain_railed_pct=g(fin, "rlo", "{:.1f}"),
               w_inh=g(fin, "w_inh", "{:.1f}"), w_cap=g(fin, "w_cap", "{:.0f}"),
               rate_hz=g(fin, "rE", "{:.2f}"))
    for c in ("W_EXC_INIT", "W_INH_INIT", "W_MAX", "NU_EXT_HZ", "W_EXT", "RHO0_HZ", "ISTDP_ETA",
              "GAIN_ETA", "GAIN_MIN", "STD_U", "TAU_REC_MS", "LAMBDA_UM", "TARGET_OUTDEG"):
        row[c] = g(kb, c)
    _b = (B1, B2, B3, B4, B5, B6, B7)
    for nm, v in zip(("B1", "B2", "B3", "B4", "B5", "B6", "B7"), _b):
        row[nm] = mark(v)
    row["GATE_B"] = ("PASS" if all(x is True for x in _b)
                     else ("INCOMPLETE" if any(x is None for x in _b) else "FAIL"))
    new = not os.path.exists(path)
    with open(path, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=LOG_COLS)
        if new: w.writeheader()
        w.writerow({c: row.get(c, "") for c in LOG_COLS})
    print(f"  [log] appended {LABEL} -> sweep_log.csv   GATE_B={row['GATE_B']}")

if APPEND:
    write_log_row()

# ---------------------------------------------------------------- plots
fig, ax = plt.subplots(1, 4, figsize=(21, 4.4))
# Show a SETTLED 2 s window, not the first 2 s: on a 100 s certification run the startup
# transient peaks near 30% of N and squashes the steady state into an invisible flat line.
_w0 = int(0.5 * len(A)); seg = A[_w0:_w0 + min(len(A) - _w0, 20000)]
ax[0].plot(np.arange(len(seg)) + _w0, seg, lw=0.5)
ax[0].set_title(f"network activity A_t (2 s at t={_w0*1e-4:.0f} s, settled)")
ax[0].set_xlabel("step"); ax[0].set_ylabel("# firing")

# B2: the plateau. Flat across the generation scale = scale-invariant; m^b decay = artifact.
_pb = list(PLATEAU_BINS); _pv = [m_bins[b] for b in _pb]
ax[1].plot(_pb, _pv, "o-", lw=1.5)
ax[1].axhspan(0.9, 1.02, color="g", alpha=0.12, label="B1 band 0.9-1.02")
ax[1].set_ylim(0.0, 1.05); ax[1].set_xlabel("bin width (steps)"); ax[1].set_ylabel("m_hat")
ax[1].set_title(f"B2 plateau: spread={m_spread:.3f} ({'FLAT' if B2 else 'slope'})")
ax[1].legend(fontsize=8)

if len(ks_mr):
    ax[2].semilogy(ks_mr, np.clip(rk_mr, 1e-6, None), ".", ms=3, label="r_k (detrended)")
    if np.isfinite(m_hat) and m_hat > 0:
        # Draw the curve the estimator ACTUALLY fits, r_k = b*m^k + c -- not a bare exponential
        # through r_k[0]. The offset c absorbs the stationary drive floor, so a pure exponential
        # is visibly wrong and would misrepresent the fit quality. b,c refit here given m.
        _X = np.column_stack([m_hat ** ks_mr, np.ones_like(ks_mr, float)])
        _bc, *_ = np.linalg.lstsq(_X, rk_mr, rcond=None)
        ax[2].semilogy(ks_mr, np.clip(_X @ _bc, 1e-6, None), "r-",
                       label=f"fit b·m^k+c,  m={m_hat:.3f}")
    ax[2].legend(fontsize=8)
ax[2].set_title("B1: MR autocorrelation fit"); ax[2].set_xlabel("lag k"); ax[2].set_ylabel("r_k")

# B7: the controller trace. Both homeostats must be OFF their rails and STATIONARY.
if ctrl and len(gains) >= 2:
    xs = np.arange(1, len(gains) + 1)
    ax[3].plot(xs, gains, "o-", label="gain")
    ax[3].plot(xs, [c.get("rlo", np.nan) / 100.0 for c in ctrl], "s--", label="gain railed-lo frac")
    ax[3].plot(xs, [c.get("w_inh", np.nan) / max(c.get("w_cap", 1), 1e-9) for c in ctrl],
               "^-.", label="w_inh / cap")
    if rates:
        ax[3].plot(xs, np.asarray(rates) / max(RHO0_HZ, 1e-9), "d:", label=f"rate / RHO0")
    ax[3].axhline(0.2, color="r", lw=0.8, alpha=0.5)
    ax[3].set_ylim(0, 1.25); ax[3].set_xlabel("[ctrl] probe #")
    ax[3].set_title(f"B7 controller authority ({'PASS' if B7 else mark(B7)})")
    ax[3].legend(fontsize=7)
else:
    ax[3].text(0.5, 0.5, "no [ctrl] trace in sim.log", ha="center", va="center")
    ax[3].set_title("B7 controller authority")
fig.tight_layout(); fig.savefig("criticality.png", dpi=120)
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
