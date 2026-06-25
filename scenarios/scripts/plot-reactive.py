#!/usr/bin/env python3
# Headline figure: victim commanded DL MCS over time, reactive jammer, OLLA off vs on.
import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = os.path.expanduser("~/projects/5glena/reactive")
OUT = "/mnt/c/Users/simo1/Desktop/charlie/paper-figs/commanded-mcs-5glena-reactive.png"
THRESHOLD = 10
NBINS = 100  # time bins
CELLID = "1"


def load(tag):
    """Return (times, mcs) for victim DL rows (cellId==1)."""
    f = os.path.join(BASE, tag, "RxPacketTrace.txt")
    ts, ms = [], []
    with open(f) as fh:
        header = fh.readline().split("\t")
        # columns: 1=Time 2=dir 8=cellId 12=mcs (1-based)
        for line in fh:
            c = line.rstrip("\n").split("\t")
            if len(c) < 18:
                continue
            if c[1] == "DL" and c[7] == CELLID:
                ts.append(float(c[0]))
                ms.append(float(c[11]))
    return ts, ms


def binned(ts, ms, nbins):
    if not ts:
        return [], []
    tmin, tmax = min(ts), max(ts)
    width = (tmax - tmin) / nbins if tmax > tmin else 1.0
    sums = [0.0] * nbins
    cnts = [0] * nbins
    for t, m in zip(ts, ms):
        i = min(int((t - tmin) / width), nbins - 1)
        sums[i] += m
        cnts[i] += 1
    xs, ys = [], []
    for i in range(nbins):
        if cnts[i]:
            xs.append(tmin + (i + 0.5) * width)
            ys.append(sums[i] / cnts[i])
    return xs, ys


def duty(tag):
    f = os.path.join(BASE, tag, "run.log")
    try:
        for line in open(f):
            if "reactive jammer:" in line and "dutyCycle=" in line:
                return float(line.split("dutyCycle=")[1].split()[0])
    except FileNotFoundError:
        pass
    return None


fig, ax = plt.subplots(figsize=(8, 4.5))

for tag, label, color in [
    ("reactive-olla-off", "OLLA off", "tab:blue"),
    ("reactive-olla-on", "OLLA on", "tab:red"),
]:
    ts, ms = load(tag)
    xs, ys = binned(ts, ms, NBINS)
    d = duty(tag)
    lbl = f"{label} (duty={d:.2f})" if d is not None else label
    ax.plot(xs, ys, color=color, lw=1.8, label=lbl)

ax.axhline(THRESHOLD, color="gray", ls="--", lw=1.0, label=f"jammer threshold (MCS {THRESHOLD})")
ax.set_xlabel("Time (s)")
ax.set_ylabel("Victim commanded DL MCS")
ax.set_title("Reactive MCS-downgrade attack in 5G-LENA: commanded MCS over time")
ax.set_ylim(0, 29)
ax.grid(True, alpha=0.3)
ax.legend(loc="upper right")
fig.tight_layout()
os.makedirs(os.path.dirname(OUT), exist_ok=True)
fig.savefig(OUT, dpi=150)
print("wrote", OUT)
