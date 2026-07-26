#!/usr/bin/env python3
"""paradox.py -- the ISN paradoxical-effect test (FINAL_BLUEPRINT §7.4), trial-averaged.

An inhibition-stabilized network is one whose recurrent excitation is strong enough to be
unstable alone, held stable by fast inhibition. Its defining, counter-intuitive signature:
inject EXTRA excitatory current into the INHIBITORY population and their steady-state rate
*falls*. The injection raises I briefly, that suppresses E, and the lost recurrent excitation
onto I outweighs the injected current. A merely inhibition-DOMINATED network shows I rising.

This is the one blueprint battery clause that is a genuine FALSIFICATION test of a claim this
project has been making implicitly, rather than another corroboration. Gate B B1-B7 omits it.

TWO DESIGN CORRECTIONS, both found by running the naive version (see SESSION_LOG):
 1. **Never compare across builds.** Adding the injection branch perturbs codegen; a chaotic
    balanced network then diverges completely within seconds, so two builds at the same wall
    step are NOT the same realisation. Observed: four runs that should have been bit-identical
    before the injection had baselines of 3.06 / 2.25 / 3.61 / 3.35 Hz. All comparisons must
    therefore be WITHIN a run.
 2. **Trial-average.** This network wanders between near-silence and ~6 Hz on a sub-second
    timescale, so a single pulse is swamped by its own fluctuation. The injection is periodic
    and each trial is compared against ITS OWN immediately-preceding baseline (a paired design),
    then averaged over trials with a SEM.

The perturbation must also stay SMALL -- the paradoxical effect is a linear-response property.
Any trial whose excitatory rate collapses is voided, not averaged in.

Usage:  python tools/paradox.py [label ...]
"""
import sys, os, re
import numpy as np

BASE   = r"C:\3D-BRAIN\run"
DT_MS  = 0.1
PRE_MS = 300.0          # per-trial baseline: the 300 ms immediately before onset
E_COLLAPSE_FRAC = 0.5   # a trial whose exc rate drops below this fraction is not interpretable


def load(rd):
    sp = os.path.join(rd, "spikes_window.csv")
    if not os.path.exists(sp): return None
    try:
        import pandas as pd
        df = pd.read_csv(sp, engine="c")
        step, nid = df["step"].to_numpy(np.int64), df["neuron"].to_numpy(np.int64)
    except ImportError:
        a = np.loadtxt(sp, delimiter=",", skiprows=1, dtype=np.int64)
        step, nid = a[:, 0], a[:, 1]
    d = np.genfromtxt(os.path.join(rd, "neurons.csv"), delimiter=",", names=True)
    return step, nid, np.asarray(d["is_inh"], int)


def knobs(rd):
    p = os.path.join(rd, "sim.log")
    k = {}
    if os.path.exists(p):
        for ln in open(p, encoding="utf-8", errors="replace"):
            if ln.startswith("[knobs]"):
                k = dict(re.findall(r"(\w+)=([-\d.eE+]+)", ln)); break
    g = lambda n, d: float(k.get(n, d))
    return (int(g("PARADOX_START", 600000)), int(g("PARADOX_LEN", 2000)),
            int(g("PARADOX_PERIOD", 10000)), int(g("PARADOX_TRIALS", 20)), g("PARADOX_INJ", 0.0))


def analyse(label):
    rd = os.path.join(BASE, label)
    got = load(rd)
    if got is None:
        print(f"{label:<12} NO spikes_window.csv"); return None
    step, nid, is_inh = got
    START, LEN, PERIOD, TRIALS, AMP = knobs(rd)
    nE, nI = int((is_inh == 0).sum()), int((is_inh == 1).sum())
    inh_spk = is_inh[nid] == 1
    pre_steps = int(PRE_MS / DT_MS)

    def rate(lo, hi):
        m = (step >= lo) & (step < hi)
        secs = (hi - lo) * DT_MS * 1e-3
        return float((~inh_spk[m]).sum()) / nE / secs, float(inh_spk[m].sum()) / nI / secs

    rows = []
    for t in range(TRIALS):
        on = START + t * PERIOD
        if on - pre_steps < step.min() or on + LEN > step.max(): continue
        bE, bI = rate(on - pre_steps, on)                 # this trial's own baseline
        dE, dI = rate(on + LEN // 2, on + LEN)            # steady part of the injection
        rows.append((bE, bI, dE, dI))
    if not rows:
        print(f"{label:<12} no usable trials in the dump window"); return None
    a = np.array(rows)
    bE, bI, dE, dI = a[:, 0], a[:, 1], a[:, 2], a[:, 3]
    ok = dE >= E_COLLAPSE_FRAC * np.maximum(bE, 1e-9)
    n = int(ok.sum())
    ddE, ddI = (dE - bE)[ok], (dI - bI)[ok]
    semE = ddE.std(ddof=1) / np.sqrt(n) if n > 1 else float("nan")
    semI = ddI.std(ddof=1) / np.sqrt(n) if n > 1 else float("nan")

    print(f"\n===== {label}   PARADOX_INJ={AMP:g}   {len(rows)} trials, {n} usable "
          f"({len(rows)-n} voided by exc collapse) =====")
    print(f"  per-trial baseline   exc {bE[ok].mean():6.3f} Hz   inh {bI[ok].mean():6.3f} Hz")
    print(f"  during injection     exc {dE[ok].mean():6.3f} Hz   inh {dI[ok].mean():6.3f} Hz")
    print(f"  paired delta         exc {ddE.mean():+6.3f} +/- {semE:.3f}    "
          f"inh {ddI.mean():+6.3f} +/- {semI:.3f}  Hz (mean +/- SEM over trials)")
    if n < 5:
        print("  [!] too few usable trials to conclude anything.")
    return dict(label=label, amp=AMP, n=n, dE=ddE.mean(), dI=ddI.mean(), semI=semI, semE=semE)


if __name__ == "__main__":
    labels = sys.argv[1:] or ["r_inj0", "r_inj0p1", "r_inj0p3"]
    print("ISN paradoxical-effect test (paired, trial-averaged).")
    print("PARADOXICAL (ISN) => inhibitory rate FALLS under an excitatory injection INTO the")
    print("inhibitory population. Rising => inhibition-dominated but NOT inhibition-stabilized.")
    out = [r for r in (analyse(L) for L in labels) if r]
    if len(out) > 1:
        ctrl = out[0]
        print("\n--------------------------- verdict ---------------------------")
        print(f"  control (INJ=0): inh {ctrl['dI']:+.3f} +/- {ctrl['semI']:.3f} Hz"
              f"  <- the fluctuation floor any effect must clear")
        for r in out[1:]:
            net = r["dI"] - ctrl["dI"]
            sig = np.sqrt(r["semI"] ** 2 + ctrl["semI"] ** 2)
            z = net / sig if sig > 0 else 0.0
            if r["n"] < 5:                       v = "INCONCLUSIVE (too few usable trials)"
            elif abs(z) < 2:                     v = f"no significant change (z={z:+.1f})"
            elif net < 0:                        v = f"PARADOXICAL (ISN)  z={z:+.1f}"
            else:                                v = f"non-paradoxical, I rate rises  z={z:+.1f}"
            print(f"  {r['label']:<12} inj {r['amp']:<5g} inh {net:+.3f} +/- {sig:.3f} Hz"
                  f"   exc {r['dE']:+.3f} Hz   -> {v}")
