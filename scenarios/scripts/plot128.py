#!/usr/bin/env python3
import os, math
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

WIN = "/mnt/c/Users/simo1/Desktop/charlie"
FIGS = os.path.join(WIN, "paper-figs")
os.makedirs(FIGS, exist_ok=True)

def ci95(x):
    x = np.asarray(x, float); n = len(x)
    if n < 2: return 0.0
    sd = x.std(ddof=1)
    t = {2:12.71,3:4.303,4:3.182,5:2.776,6:2.571}.get(n, 1.96)
    return t*sd/math.sqrt(n)

# ---------- R3 tradeoff: failed% vs on-air% (study D, 128 B) ----------
d = pd.read_csv(os.path.join(WIN, "studyD-R3-128.csv"))
order = ["baseline","broadband40","broadband50","reactive_d0","reactive_d05","reactive_d1","reactive_off_d05"]
label = {"baseline":"baseline","broadband40":"broadband 40 dBm","broadband50":"broadband 50 dBm",
         "reactive_d0":"reactive (OLLA, $\\delta$=0, oracle)","reactive_d05":"reactive (OLLA, $\\delta$=0.5 ms)",
         "reactive_d1":"reactive (OLLA, $\\delta$=1.0 ms)","reactive_off_d05":"reactive (OLLA off, $\\delta$=0.5 ms)"}
color = {"baseline":"green","broadband40":"#888","broadband50":"black",
         "reactive_d0":"#d62728","reactive_d05":"#1f77b4","reactive_d1":"#9467bd","reactive_off_d05":"#ff7f0e"}
mark  = {"baseline":"o","broadband40":"s","broadband50":"s",
         "reactive_d0":"D","reactive_d05":"*","reactive_d1":"^","reactive_off_d05":"v"}
fig, ax = plt.subplots(figsize=(5.2,3.4))
for sc in order:
    g = d[d.scenario==sc]
    xm, xe = g.onairPct.mean(), ci95(g.onairPct)
    ym, ye = g.failedPct.mean(), ci95(g.failedPct)
    ms = 16 if mark[sc]=="*" else 9
    ax.errorbar(xm, ym, xerr=xe, yerr=ye, fmt=mark[sc], color=color[sc],
                ms=ms, capsize=3, label=label[sc])
ax.set_xlabel("attacker on-air time (% of time)")
ax.set_ylabel("URLLC deadline failure (%)")
ax.set_title("Reactive vs broadband on industrial 5G (128 B URLLC, LOS)\nmean $\\pm$ 95% CI over 5 seeds", fontsize=9)
ax.set_xlim(-5,108); ax.set_ylim(-5,108)
ax.grid(alpha=0.3); ax.legend(fontsize=6.5, loc="center right")
fig.tight_layout(); fig.savefig(os.path.join(FIGS,"tradeoff-ci-5glena.png"), dpi=150)
print("wrote tradeoff-ci-5glena.png")

# ---------- Resonance: plant faults + per-packet failure vs delay (128 B, step 0.1) ----------
c = pd.read_csv(os.path.join(WIN, "studyC-payload128.csv"))
delays = sorted(c.delayMs.unique())
sp_m  = [c[c.delayMs==x].spills.mean() for x in delays]
sp_e  = [ci95(c[c.delayMs==x].spills) for x in delays]
f_m   = [c[c.delayMs==x].failedPct.mean() for x in delays]
f_e   = [ci95(c[c.delayMs==x].failedPct) for x in delays]
fig, ax1 = plt.subplots(figsize=(5.2,3.4))
l1 = ax1.errorbar(delays, sp_m, yerr=sp_e, fmt="o-", color="#d62728", capsize=3, label="plant spills (safety events)")
ax1.set_xlabel("jammer sensing/reaction delay (ms)")
ax1.set_ylabel("plant spills / 2 s", color="#d62728")
ax1.tick_params(axis="y", labelcolor="#d62728")
ax2 = ax1.twinx()
l2 = ax2.errorbar(delays, f_m, yerr=f_e, fmt="s--", color="#1f77b4", capsize=3, label="URLLC per-packet failure %")
ax2.set_ylabel("URLLC deadline failure (%)", color="#1f77b4")
ax2.tick_params(axis="y", labelcolor="#1f77b4"); ax2.set_ylim(0,105)
ax1.set_title("Delayed-feedback resonance (128 B URLLC, LOS)\nper-packet failure now tracks physical damage", fontsize=9)
ax1.grid(alpha=0.3)
lns = [l1, l2]; ax1.legend(lns, [l.get_label() for l in lns], fontsize=7, loc="center right")
fig.tight_layout(); fig.savefig(os.path.join(FIGS,"delay-resonance-5glena.png"), dpi=150)
print("wrote delay-resonance-5glena.png")
