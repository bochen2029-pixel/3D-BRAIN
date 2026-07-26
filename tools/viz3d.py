#!/usr/bin/env python3
"""
viz3d.py -- interactive 3D view of the volumetric brain from neurons.csv.
Writes a self-contained HTML you can open in any browser and rotate / zoom / pan,
with a dropdown to colour by MODULE (the hierarchical-modular structure), FIRING
RATE (the dynamics), or E/I type. Offline -- the Phase-0 "offline 3D view".
Usage:  python viz3d.py [neurons.csv] [--n 30000] [--out brain3d.html]
"""
import sys, numpy as np
try:
    import plotly.graph_objects as go
except ImportError:
    print("need: python -m pip install plotly"); sys.exit(1)

# mirror config.h defaults so module = pure function of position
VOL, MODG, AREAG = 3500.0, 8, 2

path, nmax, out = "neurons.csv", 30000, "brain3d.html"
a = sys.argv[1:]; skip = set()
for i, t in enumerate(a):
    if i in skip: continue
    if   t == "--n"   and i+1 < len(a): nmax = int(a[i+1]); skip.add(i+1)
    elif t == "--out" and i+1 < len(a): out  = a[i+1];      skip.add(i+1)
    elif not t.startswith("--"):        path = t

d = np.genfromtxt(path, delimiter=",", names=True)
x, y, z = d["x"], d["y"], d["z"]
inh, rate = d["is_inh"].astype(int), d["rate_hz"]
N = len(x)
sub = np.random.default_rng(0).choice(N, size=min(nmax, N), replace=False)
x, y, z, inh, rate = x[sub], y[sub], z[sub], inh[sub], rate[sub]

mc  = VOL / MODG
col = (((z // mc) * MODG + (y // mc)) * MODG + (x // mc)).astype(int)

common = dict(x=x, y=y, z=z, mode="markers", hoverinfo="skip")
tr_mod  = go.Scatter3d(**common, name="module", visible=True,
            marker=dict(size=1.6, color=(col % 12), colorscale="HSV", opacity=0.75))
tr_rate = go.Scatter3d(**common, name="rate", visible=False,
            marker=dict(size=1.6, color=rate, colorscale="Inferno", opacity=0.8,
                        cmin=0, cmax=float(np.percentile(rate, 99) or 1),
                        colorbar=dict(title="Hz")))
tr_ei   = go.Scatter3d(**common, name="E/I", visible=False,
            marker=dict(size=1.6, color=inh, colorscale=[[0, "#ff6a3d"], [1, "#3d9bff"]], opacity=0.75))

fig = go.Figure([tr_mod, tr_rate, tr_ei])
btn = lambda lbl, vis: dict(label=lbl, method="update",
                            args=[{"visible": vis}, {"title": f"Volumetric Brain ({len(sub):,} neurons) — {lbl}"}])
fig.update_layout(
    title=f"Volumetric Brain ({len(sub):,} neurons) — module structure",
    updatemenus=[dict(x=0.02, y=0.98, bgcolor="#222", font=dict(color="white"), buttons=[
        btn("module structure", [True, False, False]),
        btn("firing rate",      [False, True, False]),
        btn("E / I (warm/cool)",[False, False, True])])],
    scene=dict(aspectmode="cube", bgcolor="black",
               xaxis=dict(visible=False), yaxis=dict(visible=False), zaxis=dict(visible=False)),
    paper_bgcolor="black", font_color="white", margin=dict(l=0, r=0, t=40, b=0))
fig.write_html(out, include_plotlyjs=True)
print(f"wrote {out}  ({len(sub):,} of {N:,} neurons)")
