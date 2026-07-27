#!/usr/bin/env python3
"""isn.py -- the ISN paradoxical-effect test, from the E/I-split activity trace (ei_rate.csv).

An inhibition-stabilized network's defining, counter-intuitive signature: inject extra EXCITATORY
current into the INHIBITORY population and their rate FALLS. The injection raises I briefly, that
suppresses E, and the lost recurrent excitation onto I outweighs what was injected. A merely
inhibition-DOMINATED network shows I rising with the injection.

FINAL_BLUEPRINT §7.4 requires this ("paradoxical-effect-positive"); Gate B B1-B8 does not cover it.
It is the one blueprint clause that can FALSIFY a claim this project makes implicitly.

Design notes carried over from two failed attempts (see SESSION_LOG):
  * WITHIN-RUN ONLY. Adding the injection branch perturbs codegen and a chaotic balanced network
    diverges within seconds, so two builds are not the same realisation and cannot be compared at
    a fixed wall step. Every comparison here is a trial against its OWN preceding baseline.
  * TRIAL-AVERAGED. The network wanders between near-silence and ~6 Hz on a sub-second timescale;
    a single pulse is swamped. 200 paired trials, SEM over trials.
  * SMALL PERTURBATION. The effect is a linear-response property. Any trial whose excitatory rate
    collapses below half its baseline is VOIDED -- with E knocked out the network is in a
    different regime and the inhibitory rate merely tracks the injection.

Usage:  python tools/isn.py [label ...]
"""
import sys, os, re
import numpy as np

BASE   = r"C:\3D-BRAIN\run"
DT_MS  = 0.1
PRE_MS = 150.0          # per-trial baseline: the 150 ms immediately before onset
E_COLLAPSE_FRAC = 0.5


def knobs(rd):
    p = os.path.join(rd, "sim.log"); k = {}
    if os.path.exists(p):
        for ln in open(p, encoding="utf-8", errors="replace"):
            if ln.startswith("[knobs]"):
                k = dict(re.findall(r"(\w+)=([-\d.eE+]+)", ln)); break
    g = lambda n, d: float(k.get(n, d))
    return (int(g("PARADOX_START", 0)), int(g("PARADOX_LEN", 0)),
            int(g("PARADOX_PERIOD", 0)), int(g("PARADOX_TRIALS", 0)), g("PARADOX_INJ", 0.0))


def analyse(label, n_exc=160000, n_inh=40000):
    rd = os.path.join(BASE, label)
    p = os.path.join(rd, "ei_rate.csv")
    if not os.path.exists(p):
        print(f"{label:<12} NO ei_rate.csv (build with -DRATEDUMP_LEN=...)"); return None
    d = np.genfromtxt(p, delimiter=",", names=True)
    step = np.asarray(d["step"], np.int64)
    ae   = np.asarray(d["A_exc"], float)
    ai   = np.asarray(d["A_inh"], float)
    t0 = int(step.min())
    START, LEN, PERIOD, TRIALS, AMP = knobs(rd)

    def rate(arr, npop, lo, hi):          # mean per-neuron Hz over [lo,hi) in step units
        a, b = lo - t0, hi - t0
        if a < 0 or b > len(arr) or b <= a: return np.nan
        return arr[a:b].sum() / npop / ((b - a) * DT_MS * 1e-3)

    pre = int(PRE_MS / DT_MS)
    rows = []
    for t in range(TRIALS):
        on = START + t * PERIOD
        bE = rate(ae, n_exc, on - pre, on); bI = rate(ai, n_inh, on - pre, on)
        dE = rate(ae, n_exc, on + LEN // 2, on + LEN)
        dI = rate(ai, n_inh, on + LEN // 2, on + LEN)
        if np.isnan(bE) or np.isnan(dE) or bE <= 0: continue
        rows.append((bE, bI, dE, dI))
    if len(rows) < 5:
        print(f"{label:<12} only {len(rows)} usable trials"); return None
    a = np.array(rows)
    bE, bI, dE, dI = a.T
    ok = dE >= E_COLLAPSE_FRAC * bE
    n = int(ok.sum())
    ddE, ddI = (dE - bE)[ok], (dI - bI)[ok]
    semE = ddE.std(ddof=1) / np.sqrt(n); semI = ddI.std(ddof=1) / np.sqrt(n)
    print(f"\n===== {label}   PARADOX_INJ={AMP:g}   {len(rows)} trials, {n} usable "
          f"({len(rows)-n} voided by exc collapse) =====")
    print(f"  baseline           exc {bE[ok].mean():6.3f} Hz   inh {bI[ok].mean():6.3f} Hz")
    print(f"  during injection   exc {dE[ok].mean():6.3f} Hz   inh {dI[ok].mean():6.3f} Hz")
    print(f"  paired delta       exc {ddE.mean():+6.3f} +/- {semE:.3f}   "
          f"inh {ddI.mean():+6.3f} +/- {semI:.3f}  Hz")
    return dict(label=label, amp=AMP, n=n, dE=ddE.mean(), dI=ddI.mean(), semE=semE, semI=semI)


if __name__ == "__main__":
    labels = sys.argv[1:] or ["i_inj0", "i_inj0p05", "i_inj0p15"]
    print("ISN paradoxical-effect test (paired, trial-averaged, from ei_rate.csv).")
    print("PARADOXICAL (ISN) => inhibitory rate FALLS under excitatory injection INTO inhibitory")
    print("neurons. Rising => inhibition-dominated but NOT inhibition-stabilized.")
    out = [r for r in (analyse(L) for L in labels) if r]
    if len(out) > 1:
        c = out[0]
        print("\n--------------------------- verdict ---------------------------")
        print(f"  control (INJ=0): inh {c['dI']:+.3f} +/- {c['semI']:.3f} Hz over {c['n']} trials")
        if abs(c["dI"]) > 3 * c["semI"]:
            print("  [!] the CONTROL has a significant paired delta -- the design is biased and")
            print("      nothing below is readable. Check the baseline/injection window alignment.")
        for r in out[1:]:
            net = r["dI"] - c["dI"]
            sig = np.hypot(r["semI"], c["semI"])
            z = net / sig if sig > 0 else 0.0
            v = ("PARADOXICAL (ISN)" if (z <= -2) else
                 "non-paradoxical, I rate rises" if (z >= 2) else "no significant change")
            print(f"  {r['label']:<12} inj {r['amp']:<6g} n={r['n']:3d}  inh {net:+.3f} +/- {sig:.3f} Hz"
                  f"  z={z:+5.1f}   exc {r['dE']:+.3f}   -> {v}")
