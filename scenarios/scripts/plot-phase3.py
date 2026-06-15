#!/usr/bin/env python3
# Phase 3 trade-off figure: attacker cost (jammer duty cycle) vs damage
# (URLLC packets that missed the deadline or were never delivered).
import os
import re

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = os.path.expanduser("~/projects/5glena/phase3")
OUT = "/mnt/c/Users/simo1/Desktop/charlie/paper-figs/tradeoff-5glena-phase3.png"

# (dir, family, fixed_duty_or_None, point label)
RUNS = [
    ("baseline-olla-on", "baseline", 0.0, "baseline"),
    ("broadband-30dBm", "broadband", 1.0, "30 dBm"),
    ("broadband-40dBm", "broadband", 1.0, "40 dBm"),
    ("broadband-50dBm", "broadband", 1.0, "50 dBm"),
    ("reactive-thr8-on", "reactive (OLLA on)", None, "thr 8"),
    ("reactive-thr10-on", "reactive (OLLA on)", None, "thr 10"),
    ("reactive-thr14-on", "reactive (OLLA on)", None, "thr 14"),
    ("reactive-thr10-off", "reactive (OLLA off)", None, "thr 10"),
]

COLORS = {
    "baseline": "tab:green",
    "broadband": "tab:blue",
    "reactive (OLLA on)": "tab:red",
    "reactive (OLLA off)": "tab:orange",
}
MARKERS = {
    "baseline": "*",
    "broadband": "s",
    "reactive (OLLA on)": "o",
    "reactive (OLLA off)": "^",
}


def parse(dirname, fixed_duty):
    log = os.path.join(BASE, dirname, "run.log")
    tx = rx = late = None
    duty = fixed_duty
    for line in open(log):
        if line.startswith("METRICS"):
            tx = int(re.search(r"tx=(\d+)", line).group(1))
            rx = int(re.search(r"rx=(\d+)", line).group(1))
            late = int(re.search(r"late=(\d+)", line).group(1))
        if fixed_duty is None:
            m = re.search(r"dutyCycle=([0-9.]+)", line)
            if m:
                duty = float(m.group(1))
    on_time = rx - late
    failed = (tx - on_time) / tx * 100.0
    return duty, failed


fig, ax = plt.subplots(figsize=(8, 5))
seen = set()
for dirname, family, fixed, label in RUNS:
    duty, failed = parse(dirname, fixed)
    lbl = family if family not in seen else None
    seen.add(family)
    ax.scatter(duty, failed, c=COLORS[family], marker=MARKERS[family], s=130,
               edgecolors="black", linewidths=0.5, zorder=3, label=lbl)
    dx = 0.012
    ax.annotate(label, (duty, failed), xytext=(duty + dx, failed - 3),
                fontsize=9, zorder=4)

ax.axhspan(90, 101, color="red", alpha=0.05)
ax.set_xlabel("Attacker cost: jammer duty cycle (on-time fraction)")
ax.set_ylabel("URLLC failure: packets missed deadline or undelivered (%)")
ax.set_title("Reactive vs broadband jamming on URLLC (5G-LENA, RF-emergent)\n"
             "upper-left = more damage per unit attacker effort")
ax.set_xlim(-0.05, 1.08)
ax.set_ylim(-5, 105)
ax.grid(True, alpha=0.3)
ax.legend(loc="center right")

# annotate the headline efficiency gap
ax.annotate("", xy=(0.21, 99), xytext=(1.0, 99),
            arrowprops=dict(arrowstyle="<->", color="gray", ls="--"))
ax.text(0.55, 92, "~same damage,\n~5x less on-air time", color="gray",
        fontsize=9, ha="center")

fig.tight_layout()
os.makedirs(os.path.dirname(OUT), exist_ok=True)
fig.savefig(OUT, dpi=150)
print("wrote", OUT)
