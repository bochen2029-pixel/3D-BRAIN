#!/usr/bin/env python3
"""
animate.py -- "watch it think": render the firing dynamics into a rotating GIF.
Each neuron flashes and fades (decaying glow) when it fires, so you SEE avalanches
sweep through the 3D volume and up-states ignite -- the criticality, made visible.
Needs (in cwd): spikes_window.csv (run built with -DDUMP_LEN>0) + neurons.csv.
Usage:  python animate.py [--frames 140] [--n 20000] [--out firing.gif]
"""
import sys, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter

frames_target, npts, out = 140, 20000, "firing.gif"
a = sys.argv[1:]; sk = set()
for i, t in enumerate(a):
    if i in sk: continue
    if   t == "--frames" and i+1 < len(a): frames_target = int(a[i+1]); sk.add(i+1)
    elif t == "--n"      and i+1 < len(a): npts = int(a[i+1]);          sk.add(i+1)
    elif t == "--out"    and i+1 < len(a): out = a[i+1];                sk.add(i+1)

nd = np.genfromtxt("neurons.csv", delimiter=",", names=True)
X, Y, Z = nd["x"], nd["y"], nd["z"]; N = len(X)
# Fast path: genfromtxt takes many minutes on the multi-million-spike dumps the 100 s
# certification runs produce (Session 4). Same loader as tools/airegime.py.
try:
    import pandas as pd
    _sd = pd.read_csv("spikes_window.csv", engine="c")
    sstep = _sd["step"].to_numpy(np.int64); sid = _sd["neuron"].to_numpy(np.int64)
except ImportError:
    sd = np.genfromtxt("spikes_window.csv", delimiter=",", names=True)
    sstep = np.asarray(sd["step"], dtype=np.int64); sid = np.asarray(sd["neuron"], dtype=np.int64)
s0, s1 = int(sstep.min()), int(sstep.max())
fstep = max(1, (s1 - s0) // frames_target)                 # steps per frame
nframes = max(1, (s1 - s0) // fstep)

sub = np.random.default_rng(0).choice(N, size=min(npts, N), replace=False)
in_sub = -np.ones(N, dtype=np.int64); in_sub[sub] = np.arange(len(sub))
xs, ys, zs = X[sub], Y[sub], Z[sub]
keep = in_sub[sid] >= 0
fr_of = (sstep[keep] - s0) // fstep
p_of  = in_sub[sid[keep]]
by_frame = [[] for _ in range(nframes + 1)]
for fr, p in zip(fr_of, p_of):
    if 0 <= fr <= nframes: by_frame[fr].append(p)

glow = np.zeros(len(sub)); DECAY = float(np.exp(-fstep / 500.0))   # fade ~50 ms
fig = plt.figure(figsize=(7, 7)); fig.patch.set_facecolor("black")
ax = fig.add_subplot(111, projection="3d")

def draw(fr):
    global glow
    glow *= DECAY
    idx = by_frame[fr] if fr < len(by_frame) else []
    if idx: np.add.at(glow, np.asarray(idx, dtype=np.int64), 1.0)
    ax.clear(); ax.set_facecolor("black")
    g = np.clip(glow, 0.0, 3.0); order = np.argsort(g)          # bright drawn last
    ax.scatter(xs[order], ys[order], zs[order], c=g[order], cmap="inferno",
               vmin=0, vmax=3, s=2 + 9 * g[order], alpha=0.9, linewidths=0)
    ax.set_axis_off(); ax.view_init(elev=18, azim=(fr * 1.3) % 360)
    ax.set_xlim(0, 3500); ax.set_ylim(0, 3500); ax.set_zlim(0, 3500)
    ax.set_title(f"watch it think   t = {(s0 + fr*fstep)*0.1:.0f} ms", color="white")
    return []

FuncAnimation(fig, draw, frames=nframes, blit=False).save(out, writer=PillowWriter(fps=20))
print(f"wrote {out}  ({nframes} frames, {len(sub):,} neurons, {len(sstep):,} spikes)")
