#!/usr/bin/env python3
# Aggregate the reaction-delay sweep. Key question: does delay raise spills by
# CLUSTERING losses (higher spills per violation) rather than by raising the
# average failure rate? Report per-delay mean +/- 95% CI for duty, failed%,
# violationPct, spills, and the clustering ratio spills/violations.
import csv, math, os
from collections import defaultdict

BASE = os.path.expanduser("~/projects/5glena/delaysweep")
CSV = os.path.join(BASE, "delay-raw.csv")
T975 = {1:12.71,2:4.303,3:3.182,4:2.776,5:2.571,6:2.447,7:2.365,8:2.306,9:2.262}

rows = defaultdict(lambda: defaultdict(list))
with open(CSV) as fh:
    for r in csv.DictReader(fh):
        d = r["delayMs"]
        for k in ("duty","failedPct","spills","violations","violPct","thrMbps"):
            try: rows[d][k].append(float(r[k]))
            except (ValueError, KeyError): pass

def stat(v):
    n=len(v)
    if n==0: return (float('nan'),float('nan'),0)
    m=sum(v)/n
    if n==1: return (m,0.0,1)
    sd=math.sqrt(sum((x-m)**2 for x in v)/(n-1))
    return (m, T975.get(n-1,2.0)*sd/math.sqrt(n), n)

print(f"{'delay':>6} {'n':>2} {'duty':>14} {'failed%':>13} {'violPct':>14} "
      f"{'spills':>15} {'spills/viol(x1e3)':>18}")
for d in sorted(rows, key=float):
    du=stat(rows[d]["duty"]); fa=stat(rows[d]["failedPct"])
    vp=stat(rows[d]["violPct"]); sp=stat(rows[d]["spills"])
    # clustering ratio per run, then aggregate
    ratios=[s/v for s,v in zip(rows[d]["spills"],rows[d]["violations"]) if v>0]
    cl=stat([r*1000 for r in ratios])
    print(f"{d:>6} {du[2]:>2} {du[0]:>6.3f}+/-{du[1]:<5.3f} "
          f"{fa[0]:>5.1f}+/-{fa[1]:<5.1f} {vp[0]:>6.2f}+/-{vp[1]:<5.2f} "
          f"{sp[0]:>7.1f}+/-{sp[1]:<6.1f} {cl[0]:>9.2f}+/-{cl[1]:<6.2f}")
print("\nPer-run detail (spills | violations | duty):")
for d in sorted(rows, key=float):
    s=",".join(f"{int(x)}" for x in rows[d]["spills"])
    v=",".join(f"{int(x)}" for x in rows[d]["violations"])
    print(f"  d={d}: spills=[{s}]  viol=[{v}]")
