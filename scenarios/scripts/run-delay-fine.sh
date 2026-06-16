#!/usr/bin/env bash
# Finer reaction-delay grid to map the delayed-feedback resonance in plant spills.
set -u
NS3="$HOME/projects/5glena/ns-3-dev"
BASE="$HOME/projects/5glena/delayfine"
cd "$NS3"
rm -rf "$BASE"; mkdir -p "$BASE"
SEEDS="1 2 3 4 5"
DELAYS="0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 3.0"
COMMON="--plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0 --channelCondition=LOS --reactive=true --mcsThreshold=10 --useOlla=true"
CSV="$BASE/delayfine-raw.csv"
echo "delayMs,seed,duty,failedPct,spills,violations,violPct,steps" > "$CSV"
for d in $DELAYS; do
  for seed in $SEEDS; do
    out="$BASE/d${d}_s${seed}"; mkdir -p "$out"
    ./ns3 run "mcs-downgrade $COMMON --reactionDelayMs=$d --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
    duty=$(grep -oE 'dutyCycle=[0-9.]+' "$out/run.log" | head -1 | cut -d= -f2)
    mline=$(grep -E '^METRICS' "$out/run.log" | head -1)
    tx=$(echo "$mline" | grep -oE 'tx=[0-9]+' | cut -d= -f2)
    rx=$(echo "$mline" | grep -oE ' rx=[0-9]+' | cut -d= -f2)
    late=$(echo "$mline" | grep -oE 'late=[0-9]+' | cut -d= -f2)
    failed="NA"
    if [ -n "${tx:-}" ] && [ "${tx:-0}" -gt 0 ]; then
      failed=$(awk -v t="$tx" -v r="$rx" -v l="$late" 'BEGIN{printf "%.3f",(t-(r-l))*100.0/t}')
    fi
    pline=$(grep -E '^PLANT' "$out/run.log" | head -1)
    spills=$(echo "$pline" | grep -oE 'spills=[0-9]+' | cut -d= -f2)
    viol=$(echo "$pline" | grep -oE 'violations=[0-9]+' | cut -d= -f2)
    steps=$(echo "$pline" | grep -oE 'steps=[0-9]+' | cut -d= -f2)
    vpct=$(echo "$pline" | grep -oE 'violationPct=[0-9.]+' | cut -d= -f2)
    echo "$d,$seed,${duty:-NA},$failed,${spills:-NA},${viol:-NA},${vpct:-NA},${steps:-NA}" >> "$CSV"
    printf "d=%-5s s=%s duty=%-8s spills=%-4s violPct=%-6s\n" "$d" "$seed" "${duty:-NA}" "${spills:-NA}" "${vpct:-NA}"
  done
done
echo; echo "raw CSV: $CSV"
