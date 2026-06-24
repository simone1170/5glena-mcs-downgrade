#!/usr/bin/env python3
# Random-channel (Default LOS/NLOS) regime as a separate result behind the
# LOS-conditioned headline. Classify each reactive seed as SUCCESS (low duty,
# victim damaged) vs FAILURE (jammer link draws NLOS -> duty ~1.0, victim spared),
# and show the bimodal duty distribution next to broadband/baseline.
import csv, os
from collections import defaultdict
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = os.path.expanduser("~/projects/5glena/regime")
CSV = os.path.join(BASE, "regime-raw.csv")
OUT = "/mnt/c/Users/simo1/Desktop/charlie/paper-figs/channel-regime-5glena.png"

rows = defaultdict(list)
with open(CSV) as fh:
    for r in csv.DictReader(fh):
        try:
            rows[r["scenario"]].append((int(r["seed"]), float(r["duty"]),
                                        float(r["failedPct"]), float(r["spills"])))
        except ValueError:
            pass

react = rows["reactive_on"]
# A reactive run "fails" when the jammer cannot trap the MCS: duty saturates high.
FAIL_DUTY = 0.6
succ = [r for r in react if r[1] < FAIL_DUTY]
fail = [r for r in react if r[1] >= FAIL_DUTY]

def summ(name, rs):
    if not rs:
        print(f"  {name}: (none)"); return
    d=[r[1] for r in rs]; f=[r[2] for r in rs]; s=[r[3] for r in rs]
    print(f"  {name} (n={len(rs)}): duty {min(d):.2f}-{max(d):.2f} "
          f"failed% {sum(f)/len(f):.1f} spills {sum(s)/len(s):.0f} "
          f"seeds={[r[0] for r in rs]}")

print("Random-channel (Default) reactive_on regime:")
print(f"  total seeds: {len(react)}  | success: {len(succ)}  fail: {len(fail)}")
summ("SUCCESS (duty<0.6)", succ)
summ("FAILURE (duty>=0.6)", fail)
print("broadband40:")
b=rows["broadband40"]
print(f"  failed% {sum(r[2] for r in b)/len(b):.1f}  "
      f"spills range {min(r[3] for r in b):.0f}-{max(r[3] for r in b):.0f}  "
      f"(spills>0 in {sum(1 for r in b if r[3]>0)}/{len(b)} seeds)")

# figure: per-seed duty (reactive) colored by success/failure, with broadband ref
fig, ax = plt.subplots(figsize=(8,5))
sd=[r[0] for r in succ]; sy=[r[1]*100 for r in succ]
fd=[r[0] for r in fail]; fy=[r[1]*100 for r in fail]
ax.scatter(sd, sy, c="tab:red", s=80, zorder=3,
           label=f"reactive: attack succeeds ({len(succ)} seeds)")
ax.scatter(fd, fy, c="tab:gray", s=80, marker="x", zorder=3,
           label=f"reactive: attack fails, jammer link NLOS ({len(fail)} seeds)")
ax.axhline(100, color="tab:blue", ls="--", lw=1.2, label="broadband (on-air time=100%)")
ax.axhline(60, color="black", ls=":", lw=0.8, alpha=0.6)
ax.set_xlabel("Channel realization (RNG seed)")
ax.set_ylabel("Reactive jammer on-air time (%)")
ax.set_ylim(-5, 110)
ax.set_title("Random-channel regime (5G-LENA, Default 3GPP LOS/NLOS)\n"
             "the reactive attack is bimodal: it succeeds at low on-air time on LOS-ish jammer\n"
             "links and collapses (on-air time->100%) when the jammer link draws an NLOS fade")
ax.legend(loc="center right", fontsize=8)
ax.grid(True, alpha=0.3)
fig.tight_layout()
os.makedirs(os.path.dirname(OUT), exist_ok=True)
fig.savefig(OUT, dpi=150)
print("wrote", OUT)
