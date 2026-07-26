#!/usr/bin/env python3
"""real_check.py -- Step-1 confirmation: does the fixed branching estimator discriminate on the
REAL sim traces (dead baseline vs alive operating points)? Also prints the dead-vs-alive summary
the web instance asked for. Reuses the validated estimators from bp_validate.py.
Run:  python tools/real_check.py"""
import sys, numpy as np
sys.path.insert(0, r"C:\3D-BRAIN\tools")
from bp_validate import mr_current, mr_fixed

BASE = r"C:\3D-BRAIN\run"
TRACES = [
    ("r00_baseline (default)", r"r00_baseline\activity.csv"),
    ("r01_drive (drive-only)", r"r01_drive\activity.csv"),
    ("p1_nu10 (low drive)",    r"p1_nu10\activity.csv"),
    ("dec_nu8 (alive)",        r"dec_nu8\activity.csv"),
    ("u3_long (alive)",        r"u3_long\activity.csv"),
    ("u4_long (alive)",        r"u4_long\activity.csv"),
]
print(f"{'trace':>26} | {'nbins':>7} {'meanA':>9} {'act%':>6} | {'cur':>7} {'fix':>7}")
print("-" * 74)
for label, rel in TRACES:
    try:
        d = np.genfromtxt(BASE + "\\" + rel, delimiter=",", names=True)
        A = np.asarray(d["A"], dtype=float)
    except Exception as e:
        print(f"{label:>26} | (load failed: {type(e).__name__})")
        continue
    act = 100.0 * float(np.mean(A > 0))
    mc = mr_current(A); mf = mr_fixed(A)
    print(f"{label:>26} | {len(A):7d} {A.mean():9.2f} {act:6.1f} | {mc:7.3f} {mf:7.3f}")
print("-" * 74)
print("want: fix ~0 on dead/drive-only rows, fix > 0 (and meaningful) on alive rows;")
print("      cur ~1 everywhere (the contamination we just diagnosed).")
