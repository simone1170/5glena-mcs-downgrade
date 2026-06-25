#!/usr/bin/env python3
import os, math
import pandas as pd, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
WIN="/mnt/c/Users/simo1/Desktop/charlie"; FIGS=f"{WIN}/paper-figs"
TCRIT={5:2.776,10:2.262,11:2.201,12:2.201}
def ci(x):
    x=np.asarray(x,float); x=x[~np.isnan(x)]; n=len(x)
    if n<2: return 0.0
    return TCRIT.get(n,1.96)*x.std(ddof=1)/math.sqrt(n)

# Fig 4: R3 tradeoff (pooled 10 seeds)
d=pd.read_csv(f"{WIN}/studyD10-R3-128.csv")
order=["baseline","broadband40","broadband50","reactive_d0","reactive_d05","reactive_d1","reactive_off_d05"]
label={"baseline":"baseline","broadband40":"broadband 40 dBm","broadband50":"broadband 50 dBm",
       "reactive_d0":"reactive (OLLA, $\\delta$=0, oracle)","reactive_d05":"reactive (OLLA, $\\delta$=0.5 ms)",
       "reactive_d1":"reactive (OLLA, $\\delta$=1.0 ms)","reactive_off_d05":"reactive (OLLA off, $\\delta$=0.5 ms)"}
color={"baseline":"green","broadband40":"#888","broadband50":"black","reactive_d0":"#d62728",
       "reactive_d05":"#1f77b4","reactive_d1":"#9467bd","reactive_off_d05":"#ff7f0e"}
mark={"baseline":"o","broadband40":"s","broadband50":"s","reactive_d0":"D",
      "reactive_d05":"*","reactive_d1":"^","reactive_off_d05":"v"}
fig,ax=plt.subplots(figsize=(5.2,3.4))
for sc in order:
    g=d[d.scenario==sc]
    ms=16 if mark[sc]=="*" else 9
    ax.errorbar(g.onairPct.mean(),g.failedPct.mean(),xerr=ci(g.onairPct),yerr=ci(g.failedPct),
                fmt=mark[sc],color=color[sc],ms=ms,capsize=3,label=label[sc])
ax.set_xlabel("attacker on-air time (% of time)"); ax.set_ylabel("URLLC deadline failure (%)")
ax.set_title("Reactive vs broadband on industrial 5G (128 B URLLC, LOS)\nmean $\\pm$ 95% CI over 10 seeds",fontsize=9)
ax.set_xlim(-5,108); ax.set_ylim(-5,108); ax.grid(alpha=0.3); ax.legend(fontsize=6.5,loc="center right")
fig.tight_layout(); fig.savefig(f"{FIGS}/tradeoff-ci-5glena.png",dpi=150); print("wrote tradeoff (n=10)")

# Fig 6: resonance (pooled 10 seeds, step 0.10)
r=pd.read_csv(f"{WIN}/studyF10-resonance-128.csv")
r=r[np.isclose(r.ollaStep,0.10)]
delays=sorted(r.delayMs.unique())
sp_m=[r[np.isclose(r.delayMs,x)].spills.mean() for x in delays]
sp_e=[ci(r[np.isclose(r.delayMs,x)].spills) for x in delays]
f_m=[r[np.isclose(r.delayMs,x)].failedPct.mean() for x in delays]
f_e=[ci(r[np.isclose(r.delayMs,x)].failedPct) for x in delays]
fig,ax1=plt.subplots(figsize=(5.2,3.4))
l1=ax1.errorbar(delays,sp_m,yerr=sp_e,fmt="o-",color="#d62728",capsize=3,label="plant spills (safety events)")
ax1.set_xlabel("jammer sensing/reaction delay (ms)"); ax1.set_ylabel("plant spills / 2 s",color="#d62728")
ax1.tick_params(axis="y",labelcolor="#d62728")
ax2=ax1.twinx()
l2=ax2.errorbar(delays,f_m,yerr=f_e,fmt="s--",color="#1f77b4",capsize=3,label="URLLC per-packet failure %")
ax2.set_ylabel("URLLC deadline failure (%)",color="#1f77b4"); ax2.tick_params(axis="y",labelcolor="#1f77b4"); ax2.set_ylim(0,105)
ax1.set_title("Delayed-feedback resonance (128 B URLLC, LOS)\nper-packet failure tracks physical damage (10 seeds)",fontsize=9)
ax1.grid(alpha=0.3); ax1.legend([l1,l2],[l.get_label() for l in [l1,l2]],fontsize=7,loc="center right")
fig.tight_layout(); fig.savefig(f"{FIGS}/delay-resonance-5glena.png",dpi=150); print("wrote resonance (n=10)")
