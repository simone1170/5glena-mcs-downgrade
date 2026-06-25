#!/usr/bin/env python3
"""Pool existing + top-up seeds to 10 (R4=12), write merged CSVs, print every
paper number as mean +/- 95% CI. Drives the .tex edits."""
import os, math
import pandas as pd, numpy as np
WIN = "/mnt/c/Users/simo1/Desktop/charlie"

TCRIT = {2:12.706,3:4.303,4:3.182,5:2.776,6:2.571,7:2.447,8:2.365,9:2.306,
         10:2.262,11:2.201,12:2.201,13:2.179}
def mci(x):
    x = np.asarray(x, float); x = x[~np.isnan(x)]; n = len(x)
    if n == 0: return (float('nan'), float('nan'), 0)
    if n == 1: return (x[0], 0.0, 1)
    sd = x.std(ddof=1); t = TCRIT.get(n, 1.96)
    return (x.mean(), t*sd/math.sqrt(n), n)
def f(m, c): return f"{m:.1f} +/- {c:.1f}"

print("="*70)
print("R3  (Table IV) -- pooled studyD seeds 1-10")
d = pd.concat([pd.read_csv(f"{WIN}/studyD-R3-128.csv"),
               pd.read_csv(f"{WIN}/studyD-R3-128-s6_10.csv")], ignore_index=True)
d.to_csv(f"{WIN}/studyD10-R3-128.csv", index=False)
order = ["baseline","broadband40","broadband50","reactive_d0","reactive_d05","reactive_d1","reactive_off_d05"]
r3 = {}
for sc in order:
    g = d[d.scenario==sc]
    on = mci(g.onairPct); fa = mci(g.failedPct); r3[sc] = (on, fa)
    print(f"  {sc:18s} n={on[2]:2d}  on-air={f(on[0],on[1]):>14s}  failed={f(fa[0],fa[1]):>14s}")
ratio = r3['reactive_off_d05'][0][0] / r3['reactive_d05'][0][0]
print(f"  >> OLLA cost ratio (off/on on-air) = {ratio:.2f}x ; reactive d0.5 on-air ~ 1/{100/r3['reactive_d05'][0][0]:.1f} of broadband")

print("="*70)
print("R5  Table V -- pooled studyA seeds 1-10 (mean MCS, on-air%)")
a = pd.concat([pd.read_csv(f"{WIN}/studyA-olla-dependence.csv"),
               pd.read_csv(f"{WIN}/studyA-tuning-s4_10.csv")], ignore_index=True)
a.to_csv(f"{WIN}/studyA10-olla-dependence.csv", index=False)
a["onair"] = a.duty*100
off = a[a.step=="OLLAoff"]
m_off = mci(off.meanMCS); on_off = mci(off.onair)
print(f"  OLLA off (ref)  n={m_off[2]:2d}  meanMCS={m_off[0]:.1f}  on-air={on_off[0]:.0f}")
mcs_vals=[]; on_vals=[]
for s in ["0.05","0.1","0.2"]:
    for B in ["0.05","0.1","0.2"]:
        g = a[(a.step==s)&(a.targetBler==B)]
        mm = mci(g.meanMCS); oo = mci(g.onair); mcs_vals.append(mm[0]); on_vals.append(oo[0])
        print(f"  s={s:4s} B={B:4s}  n={mm[2]:2d}  meanMCS={mm[0]:.1f}  on-air={oo[0]:.0f}")
print(f"  >> trapped MCS range [{min(mcs_vals):.1f},{max(mcs_vals):.1f}]  on-air range [{min(on_vals):.0f},{max(on_vals):.0f}]  OLLA-off MCS={m_off[0]:.1f} on-air={on_off[0]:.0f}")

print("="*70)
print("R5  Table VI -- pooled resonance seeds 1-10 (spills + per-packet failure)")
sc1 = pd.read_csv(f"{WIN}/studyC-payload128.csv"); sc1["ollaStep"]=0.10
sc1 = sc1.rename(columns={})[["ollaStep","delayMs","seed","failedPct","spills"]]
sc2 = pd.read_csv(f"{WIN}/studyC2-resonance-128.csv")[["ollaStep","delayMs","seed","failedPct","spills"]]
sf  = pd.read_csv(f"{WIN}/studyF-resonance-s4_10.csv")[["ollaStep","delayMs","seed","failedPct","spills"]]
res = pd.concat([sc1, sc2, sf], ignore_index=True)
res["ollaStep"]=res.ollaStep.astype(float)
res.to_csv(f"{WIN}/studyF10-resonance-128.csv", index=False)
delays=[0.0,0.5,1.0,1.5,2.0]
print("  spills (mean):  step   " + "  ".join(f"d={x}" for x in delays))
for s in [0.05,0.10,0.20]:
    row=[]; ns=[]
    for x in delays:
        g=res[(np.isclose(res.ollaStep,s))&(np.isclose(res.delayMs,x))]
        mm=mci(g.spills); row.append(f"{mm[0]:5.0f}"); ns.append(mm[2])
    print(f"           s={s:<5}  " + "  ".join(row) + f"   (n={ns})")
print("  per-packet failure% (mean) at step 0.10:")
for x in delays:
    g=res[(np.isclose(res.ollaStep,0.10))&(np.isclose(res.delayMs,x))]
    mm=mci(g.failedPct); print(f"           d={x}: {mm[0]:.0f}%  (n={mm[2]})")

print("="*70)
print("R4  -- studyE 12 seeds (confirm)")
e = pd.read_csv(f"{WIN}/studyE-regime-128.csv")
r = e[e.scenario=="reactive_d05"]; succ = (r.onairPct<60).sum(); fail=(r.onairPct>=60).sum()
bb = e[e.scenario=="broadband50"]
print(f"  reactive: succeed={succ} fail={fail}  median on-air={r.onairPct.median():.1f}  mean fail={r.failedPct.mean():.1f}")
print(f"  broadband50 mean fail={bb.failedPct.mean():.1f}")
print("MERGED CSVs written: studyD10-R3-128, studyA10-olla-dependence, studyF10-resonance-128")
