#!/usr/bin/env python3
"""Stealth/effectiveness trade-off from the 2D power x threshold grid.
Panel (a): failure vs on-air time (duty detectability), colour=peak power
           (energy detectability); Pareto frontier drawn. Panel (b): the same
           cells in the dual-detectability plane (on-air x, power y), colour=failure."""
import math
import pandas as pd, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
WIN="/mnt/c/Users/simo1/Desktop/charlie"; FIGS=f"{WIN}/paper-figs"
d=pd.read_csv(f"{WIN}/studyJ-grid100.csv")
g=d.groupby(["jammerHighPowerDbm","mcsThreshold"]).agg(
    onair=("onairPct","mean"), failed=("failedPct","mean"), spills=("spills","mean")).reset_index()
print(g.to_string(index=False))

# Pareto frontier: minimise on-air, maximise failed
pts=g.sort_values("onair").reset_index(drop=True)
front=[]; best=-1
for _,r in pts.iterrows():
    if r.failed>best: front.append((r.onair,r.failed)); best=r.failed
front=np.array(front)

thr_marks={6:"o",10:"s",14:"^",18:"D"}
fig,(ax1,ax2)=plt.subplots(1,2,figsize=(7.0,3.0))

# (a) failure vs on-air, colour = peak power
for thr,mk in thr_marks.items():
    gg=g[g.mcsThreshold==thr]
    sc=ax1.scatter(gg.onair,gg.failed,c=gg.jammerHighPowerDbm,cmap="autumn_r",
                   vmin=40,vmax=55,marker=mk,s=60,edgecolors="k",linewidths=0.4,label=f"thr {thr}")
ax1.plot(front[:,0],front[:,1],"--",color="#333",lw=1,label="Pareto frontier")
ax1.set_xlabel("attacker on-air time (%)\n(duty-cycle detectability)",fontsize=8)
ax1.set_ylabel("URLLC failure (%)  (effectiveness)",fontsize=8)
ax1.set_title("(a) effectiveness vs duty, colour = peak power",fontsize=8)
cb=plt.colorbar(sc,ax=ax1,pad=0.02); cb.set_label("jammer power (dBm)",fontsize=7); cb.ax.tick_params(labelsize=6)
ax1.grid(alpha=0.3); ax1.legend(fontsize=6,loc="lower left",ncol=2)

# (b) dual-detectability plane: x=on-air, y=power, colour=failure
sc2=ax2.scatter(g.onair,g.jammerHighPowerDbm,c=g.failed,cmap="viridis",s=70,edgecolors="k",linewidths=0.4)
ax2.set_xlabel("on-air time (%)  (duty detectability)",fontsize=8)
ax2.set_ylabel("peak power (dBm)\n(energy detectability)",fontsize=8)
ax2.set_title("(b) the two detectability axes",fontsize=8)
cb2=plt.colorbar(sc2,ax=ax2,pad=0.02); cb2.set_label("URLLC failure (%)",fontsize=7); cb2.ax.tick_params(labelsize=6)
ax2.grid(alpha=0.3)

fig.tight_layout(); fig.savefig(f"{FIGS}/tradeoff-frontier-5glena.png",dpi=150)
print("wrote tradeoff-frontier-5glena.png")
