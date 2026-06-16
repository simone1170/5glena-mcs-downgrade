#!/usr/bin/env python3
# Aggregate the CI campaign (mean +/- 95% CI over seeds) and plot the
# physical-impact trade-off (jammer duty vs plant spills) with error bars.
import csv
import math
import os
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = os.path.expanduser("~/projects/5glena/ci")
CSV = os.path.join(BASE, "ci-raw.csv")
OUT = "/mnt/c/Users/simo1/Desktop/charlie/paper-figs/tradeoff-ci-5glena.png"
T975 = {1: 12.71, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447}  # two-sided 95%

rows = defaultdict(lambda: defaultdict(list))
with open(CSV) as fh:
    for r in csv.DictReader(fh):
        sc = r["scenario"]
        for k in ("duty", "failedPct", "spills", "thrMbps"):
            try:
                rows[sc][k].append(float(r[k]))
            except (ValueError, KeyError):
                pass


def stat(vals):
    n = len(vals)
    if n == 0:
        return (float("nan"), float("nan"), 0)
    m = sum(vals) / n
    if n == 1:
        return (m, 0.0, 1)
    sd = math.sqrt(sum((v - m) ** 2 for v in vals) / (n - 1))
    ci = T975.get(n - 1, 2.0) * sd / math.sqrt(n)
    return (m, ci, n)


LABELS = {
    "baseline": "baseline",
    "broadband40": "broadband 40 dBm",
    "reactive_on": "reactive (OLLA on)",
    "reactive_on_d1": "reactive (OLLA on, 1 ms delay)",
    "reactive_off": "reactive (OLLA off)",
}
COLORS = {
    "baseline": "tab:green",
    "broadband40": "tab:blue",
    "reactive_on": "tab:red",
    "reactive_on_d1": "tab:purple",
    "reactive_off": "tab:orange",
}
ORDER = ["baseline", "broadband40", "reactive_on", "reactive_on_d1", "reactive_off"]

print(f"{'scenario':<32}{'duty':>16}{'failed%':>16}{'spills':>16}  n")
agg = {}
for sc in ORDER:
    if sc not in rows:
        continue
    d = stat(rows[sc]["duty"])
    f = stat(rows[sc]["failedPct"])
    s = stat(rows[sc]["spills"])
    agg[sc] = (d, f, s)
    print(f"{LABELS[sc]:<32}{d[0]:>7.3f}+/-{d[1]:<5.3f}{f[0]:>8.1f}+/-{f[1]:<5.1f}"
          f"{s[0]:>9.1f}+/-{s[1]:<5.1f}  {s[2]}")

fig, ax = plt.subplots(figsize=(8, 5))
for sc in ORDER:
    if sc not in agg:
        continue
    (dm, dci, _), (fm, fci, _), (sm, sci, _) = agg[sc]
    ax.errorbar(dm, fm, xerr=dci, yerr=fci, fmt="o", ms=11, capsize=4,
                color=COLORS[sc], ecolor="gray", elinewidth=1, mec="black",
                label=f"{LABELS[sc]} ({sm:.0f} spills)", zorder=3)
    ax.annotate(LABELS[sc], (dm, fm), xytext=(dm + 0.02, fm - 4), fontsize=8.5)

ax.set_xlabel("Attacker cost: jammer duty cycle (on-time fraction)")
ax.set_ylabel("URLLC deadline failure (% of control packets)")
ax.set_title("Reactive vs broadband jamming on industrial 5G (5G-LENA, LOS)\n"
             "mean +/- 95% CI over 5 seeds; legend shows mean plant spills / 2 s")
ax.grid(True, alpha=0.3)
ax.set_xlim(-0.05, 1.1)
ax.set_ylim(-5, 108)
ax.legend(loc="center right", fontsize=8)
fig.tight_layout()
os.makedirs(os.path.dirname(OUT), exist_ok=True)
fig.savefig(OUT, dpi=150)
print("wrote", OUT)
