#!/usr/bin/env python3
# Convert the two trade-off figures from duty-cycle (0-1) to on-air time (%).
import os
SC = os.path.expanduser("~/projects/5glena/ns-3-dev/contrib/nr/scenarios/scripts")


def patch(fn, reps):
    p = os.path.join(SC, fn)
    s = open(p).read()
    for a, b in reps:
        if a not in s:
            raise SystemExit(f"NOT FOUND in {fn}: {a!r}")
        s = s.replace(a, b)
    open(p, "w").write(s)
    print("patched", fn)


patch("plot-ci.py", [
    ("ax.errorbar(dm, fm, xerr=dci, yerr=fci,",
     "ax.errorbar(dm*100, fm, xerr=dci*100, yerr=fci,"),
    ("ax.annotate(LABELS[sc], (dm, fm), xytext=(dm + 0.02, fm - 4), fontsize=8.5)",
     "ax.annotate(LABELS[sc], (dm*100, fm), xytext=(dm*100 + 2, fm - 4), fontsize=8.5)"),
    ('ax.set_xlabel("Attacker cost: jammer duty cycle (on-time fraction)")',
     'ax.set_xlabel("Attacker cost: on-air time (% of time)")'),
    ("ax.set_xlim(-0.05, 1.1)", "ax.set_xlim(-5, 110)"),
])

patch("plot-regime.py", [
    ("sd=[r[0] for r in succ]; sy=[r[1] for r in succ]",
     "sd=[r[0] for r in succ]; sy=[r[1]*100 for r in succ]"),
    ("fd=[r[0] for r in fail]; fy=[r[1] for r in fail]",
     "fd=[r[0] for r in fail]; fy=[r[1]*100 for r in fail]"),
    ('ax.axhline(1.0, color="tab:blue", ls="--", lw=1.2, label="broadband (duty=1.0 always)")',
     'ax.axhline(100, color="tab:blue", ls="--", lw=1.2, label="broadband (on-air time=100%)")'),
    ('ax.axhline(0.6, color="black", ls=":", lw=0.8, alpha=0.6)',
     'ax.axhline(60, color="black", ls=":", lw=0.8, alpha=0.6)'),
    ('ax.set_ylabel("Reactive jammer duty cycle")',
     'ax.set_ylabel("Reactive jammer on-air time (%)")'),
    ("ax.set_ylim(-0.05, 1.1)", "ax.set_ylim(-5, 110)"),
    ("low duty on LOS-ish jammer", "low on-air time on LOS-ish jammer"),
    ("(duty->1) when the jammer", "(on-air time->100%) when the jammer"),
])
print("done")
