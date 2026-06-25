#!/usr/bin/env python3
import math
import pandas as pd, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
WIN="/mnt/c/Users/simo1/Desktop/charlie"; FIGS=f"{WIN}/paper-figs"
def ms(x):
    x=np.asarray(x,float); n=len(x); return x.mean(), 1.984*x.std(ddof=1)/math.sqrt(n)
def agg(df,key,col):
    xs=sorted(df[key].unique()); m=[]; e=[]
    for v in xs:
        mm,ee=ms(df[df[key]==v][col]); m.append(mm); e.append(ee)
    return xs,np.array(m),np.array(e)

g=pd.read_csv(f"{WIN}/studyG-sweep100-victimpow.csv")
h=pd.read_csv(f"{WIN}/studyH-sweep100-jammerpow.csv")

fig,(ax1,ax2)=plt.subplots(2,1,figsize=(3.5,4.6))

# (a) vs victim DL SINR
_,sinr,_=agg(g,"victimTxPowerDbm","meanSINR")     # x = realized mean SINR (means, not the knob)
_,oS,oE=agg(g,"victimTxPowerDbm","onairPct")
_,fS,fE=agg(g,"victimTxPowerDbm","failedPct")
ax1.errorbar(sinr,oS,yerr=oE,fmt="o-",color="#d62728",capsize=2,ms=4,label="attacker on-air time")
ax1.errorbar(sinr,fS,yerr=fE,fmt="s--",color="#1f77b4",capsize=2,ms=4,label="URLLC deadline failure")
ax1.set_xlabel("victim DL SINR (dB)"); ax1.set_ylabel("percent")
ax1.set_title("(a) vs victim channel SINR",fontsize=8.5); ax1.grid(alpha=0.3); ax1.set_ylim(0,105)
ax1.legend(fontsize=6.5,loc="center left")

# (b) vs jammer ON power
jp,oh,ohe=agg(h,"jammerHighPowerDbm","onairPct")
_,fh,fhe=agg(h,"jammerHighPowerDbm","failedPct")
ax2.errorbar(jp,oh,yerr=ohe,fmt="o-",color="#d62728",capsize=2,ms=4,label="attacker on-air time")
ax2.errorbar(jp,fh,yerr=fhe,fmt="s--",color="#1f77b4",capsize=2,ms=4,label="URLLC deadline failure")
ax2.set_xlabel("jammer per-pulse power (dBm)"); ax2.set_ylabel("percent")
ax2.set_title("(b) vs jammer strength",fontsize=8.5); ax2.grid(alpha=0.3); ax2.set_ylim(0,105)
ax2.legend(fontsize=6.5,loc="center left")

fig.tight_layout()
fig.savefig(f"{FIGS}/sweep100-5glena.png",dpi=150)
print("wrote sweep100-5glena.png")
