#!/usr/bin/env python3
import os
import pandas as pd, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
WIN="/mnt/c/Users/simo1/Desktop/charlie"; FIGS=os.path.join(WIN,"paper-figs")
e=pd.read_csv(os.path.join(WIN,"studyE-regime-128.csv"))
r=e[e.scenario=="reactive_d05"].sort_values("seed")
succ = r.onairPct < 60
fig,ax=plt.subplots(figsize=(5.2,3.4))
ax.scatter(r.seed[succ], r.onairPct[succ], c="#d62728", s=55, marker="o",
           label="reactive attack succeeds (%d seeds)"%succ.sum(), zorder=3)
ax.scatter(r.seed[~succ], r.onairPct[~succ], facecolors="none", edgecolors="#d62728",
           s=80, marker="X", linewidths=2, label="reactive fails, jammer NLOS fade (%d seeds)"%(~succ).sum(), zorder=3)
ax.axhline(100, ls="--", color="gray", label="broadband (on-air time=100%)")
ax.set_xlabel("channel realization (RNG seed)")
ax.set_ylabel("reactive on-air time (%)")
ax.set_title("Random-channel regime (5G-LENA, Default 3GPP LOS/NLOS, 128 B)\nthe reactive attack is bimodal", fontsize=8.5)
ax.set_ylim(0,108); ax.grid(alpha=0.3); ax.legend(fontsize=7, loc="center right")
fig.tight_layout(); fig.savefig(os.path.join(FIGS,"channel-regime-5glena.png"),dpi=150)
print("wrote channel-regime-5glena.png  | succeed=%d fail=%d"%(succ.sum(),(~succ).sum()))
print("reactive mean fail=%.1f  median on-air=%.1f"%(r.failedPct.mean(), r.onairPct.median()))
bb=e[e.scenario=="broadband50"]
print("broadband50 mean fail=%.1f"%bb.failedPct.mean())
