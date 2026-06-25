#!/usr/bin/env python3
"""Fig 7 rebuilt as LOS (10 seeds) vs random channel (100 seeds): the feedback
resonance keeps the same non-monotonic shape under channel randomness."""
import math
import pandas as pd, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
WIN="/mnt/c/Users/simo1/Desktop/charlie"; FIGS=f"{WIN}/paper-figs"
def ci(x,n_t):
    x=np.asarray(x,float); n=len(x)
    if n<2: return 0.0
    return n_t*x.std(ddof=1)/math.sqrt(n)

los=pd.read_csv(f"{WIN}/studyF10-resonance-128.csv"); los=los[np.isclose(los.ollaStep,0.10)]
rnd=pd.read_csv(f"{WIN}/studyK-resonance-random100.csv")
delays=[0.0,0.5,1.0,1.5,2.0]

def series(df,t):
    sp=[df[np.isclose(df.delayMs,d)].spills for d in delays]
    fa=[df[np.isclose(df.delayMs,d)].failedPct for d in delays]
    return ([s.mean() for s in sp],[ci(s,t) for s in sp],
            [f.mean() for f in fa],[ci(f,t) for f in fa])

fig,axes=plt.subplots(1,2,figsize=(7.0,3.0),sharey=False)
for ax,(df,t,tag,n) in zip(axes,[(los,2.262,"LOS",10),(rnd,1.984,"random LOS/NLOS",100)]):
    spm,spe,fam,fae=series(df,t)
    l1=ax.errorbar(delays,spm,yerr=spe,fmt="o-",color="#d62728",capsize=2,ms=4,label="plant spills")
    ax.set_xlabel("jammer reaction delay (ms)",fontsize=8)
    ax.set_ylabel("plant spills / 2 s",color="#d62728",fontsize=8); ax.tick_params(axis="y",labelcolor="#d62728")
    ax.set_ylim(0,185)
    ax2=ax.twinx()
    l2=ax2.errorbar(delays,fam,yerr=fae,fmt="s--",color="#1f77b4",capsize=2,ms=4,label="URLLC failure %")
    ax2.set_ylabel("URLLC failure (%)",color="#1f77b4",fontsize=8); ax2.tick_params(axis="y",labelcolor="#1f77b4")
    ax2.set_ylim(0,105)
    ax.set_title(f"{tag} ({n} seeds)",fontsize=8.5); ax.grid(alpha=0.3)
    if tag=="LOS": ax.legend([l1,l2],["plant spills","URLLC failure %"],fontsize=6.5,loc="upper right")
fig.tight_layout(); fig.savefig(f"{FIGS}/delay-resonance-5glena.png",dpi=150)
print("wrote delay-resonance-5glena.png (LOS vs random)")
