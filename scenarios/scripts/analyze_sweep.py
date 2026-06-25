#!/usr/bin/env python3
import math
import pandas as pd, numpy as np
WIN="/mnt/c/Users/simo1/Desktop/charlie"
def mci(x):
    x=np.asarray(x,float); x=x[~np.isnan(x)]; n=len(x)
    if n<2: return (float('nan'),float('nan'),n)
    t=1.984 if n>=80 else 2.0
    return (x.mean(), t*x.std(ddof=1)/math.sqrt(n), n)
for name,key,csv in [("G victim Tx power","victimTxPowerDbm","studyG-sweep100-victimpow.csv"),
                     ("H jammer ON power","jammerHighPowerDbm","studyH-sweep100-jammerpow.csv")]:
    d=pd.read_csv(f"{WIN}/{csv}")
    print("="*72); print(f"{name}   (NA rows: onair={d.onairPct.isna().sum()} fail={d.failedPct.isna().sum()} sinr={d.meanSINR.isna().sum()})")
    print(f"{key:>18} | meanSINR(dB)   | on-air %       | failed %       | spills")
    for v in sorted(d[key].unique()):
        g=d[d[key]==v]
        s=mci(g.meanSINR); o=mci(g.onairPct); f=mci(g.failedPct); sp=mci(g.spills)
        print(f"{v:18.0f} | {s[0]:6.1f}±{s[1]:4.1f}  | {o[0]:6.1f}±{o[1]:4.1f}  | {f[0]:6.1f}±{f[1]:4.1f}  | {sp[0]:5.0f}")
