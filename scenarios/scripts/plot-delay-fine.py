#!/usr/bin/env python3
# Plot the delayed-feedback resonance: plant spills and plant-stale fraction vs
# the jammer's reaction (sensing) delay. mean +/- 95% CI over seeds. Shows that
# plant damage is NON-MONOTONIC in delay (a feedback resonance), while the
# per-packet URLLC failure stays saturated.
import csv, math, os
from collections import defaultdict
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = os.path.expanduser("~/projects/5glena/delayfine")
CSV = os.path.join(BASE, "delayfine-raw.csv")
OUT = "/mnt/c/Users/simo1/Desktop/charlie/paper-figs/delay-resonance-5glena.png"
T975 = {1:12.71,2:4.303,3:3.182,4:2.776,5:2.571,6:2.447,7:2.365,8:2.306,9:2.262}

rows = defaultdict(lambda: defaultdict(list))
with open(CSV) as fh:
    for r in csv.DictReader(fh):
        for k in ("spills","violPct","failedPct","duty"):
            try: rows[float(r["delayMs"])][k].append(float(r[k]))
            except (ValueError,KeyError): pass

def stat(v):
    n=len(v)
    if n==0: return (float('nan'),0.0)
    m=sum(v)/n
    if n==1: return (m,0.0)
    sd=math.sqrt(sum((x-m)**2 for x in v)/(n-1))
    return (m, T975.get(n-1,2.0)*sd/math.sqrt(n))

xs=sorted(rows)
sp=[stat(rows[d]["spills"]) for d in xs]
vp=[stat(rows[d]["violPct"]) for d in xs]
fa=[stat(rows[d]["failedPct"]) for d in xs]

print(f"{'delay':>6}{'spills':>16}{'violPct':>16}{'failed%':>14}")
for d,s,v,f in zip(xs,sp,vp,fa):
    print(f"{d:>6.2f}{s[0]:>9.1f}+/-{s[1]:<5.1f}{v[0]:>9.1f}+/-{v[1]:<5.1f}{f[0]:>8.1f}+/-{f[1]:<4.1f}")

fig, ax1 = plt.subplots(figsize=(8,5))
ax1.errorbar(xs,[s[0] for s in sp],yerr=[s[1] for s in sp],fmt="o-",color="tab:red",
             capsize=3,label="plant spills (safety events)")
ax1.set_xlabel("Jammer sensing/reaction delay (ms)")
ax1.set_ylabel("Plant spills / 2 s", color="tab:red")
ax1.tick_params(axis="y",labelcolor="tab:red")
ax1.set_ylim(0,185)
ax1.grid(True,alpha=0.3)

ax2=ax1.twinx()
ax2.errorbar(xs,[f[0] for f in fa],yerr=[f[1] for f in fa],fmt="s--",color="tab:blue",
             capsize=3,label="URLLC deadline failure %")
ax2.set_ylabel("URLLC deadline failure (%)",color="tab:blue")
ax2.tick_params(axis="y",labelcolor="tab:blue")
ax2.set_ylim(0,105)

ax1.set_title("Delayed-feedback resonance in reactive jamming (5G-LENA, LOS)\n"
              "physical-plant damage is non-monotonic in sensing delay; "
              "per-packet failure stays saturated")
l1,la1=ax1.get_legend_handles_labels(); l2,la2=ax2.get_legend_handles_labels()
ax1.legend(l1+l2,la1+la2,loc="center right",fontsize=9)
fig.tight_layout()
os.makedirs(os.path.dirname(OUT),exist_ok=True)
fig.savefig(OUT,dpi=150)
print("wrote",OUT)
