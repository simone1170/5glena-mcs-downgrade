#!/usr/bin/env bash
# Reconcile the 108-vs-53 reactive-on spill figures.
# Hypothesis: 108 = single run under the DEFAULT (probabilistic LOS/NLOS) channel
# at the default seed (RngRun=1); 53 = LOS-conditioned mean over seeds.
# Reproduce the default-seed run, then characterize Default vs LOS over 8 seeds.
set -u
NS3="$HOME/projects/5glena/ns-3-dev"
BASE="$HOME/projects/5glena/reconcile"
cd "$NS3"
rm -rf "$BASE"; mkdir -p "$BASE"
COMMON="--plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0 --reactive=true --mcsThreshold=10 --useOlla=true"

echo "=== exact run-plant.sh reactive-thr10-on (Default condition, default seed) ==="
out="$BASE/single_default"; mkdir -p "$out"
./ns3 run "mcs-downgrade $COMMON" --cwd "$out" >"$out/run.log" 2>&1
grep -oE 'dutyCycle=[0-9.]+' "$out/run.log" | head -1
grep -E '^PLANT' "$out/run.log" | head -1

echo
echo "=== Default vs LOS over seeds 1-8 ==="
printf "%-9s %-6s %-9s %-6s %s\n" cond seed duty spills violPct
for cond in Default LOS; do
  for seed in 1 2 3 4 5 6 7 8; do
    out="$BASE/${cond}_s${seed}"; mkdir -p "$out"
    ./ns3 run "mcs-downgrade $COMMON --channelCondition=$cond --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
    duty=$(grep -oE 'dutyCycle=[0-9.]+' "$out/run.log" | head -1 | cut -d= -f2)
    sp=$(grep -E '^PLANT' "$out/run.log" | grep -oE 'spills=[0-9]+' | cut -d= -f2)
    vp=$(grep -E '^PLANT' "$out/run.log" | grep -oE 'violationPct=[0-9.]+' | cut -d= -f2)
    printf "%-9s %-6s %-9s %-6s %s\n" "$cond" "$seed" "${duty:-NA}" "${sp:-NA}" "${vp:-NA}"
  done
done
