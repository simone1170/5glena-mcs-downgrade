#!/usr/bin/env bash
# Confidence-interval campaign: repeat key scenarios over RNG seeds.
# Plant ON so each run yields PLANT (spills) + METRICS (failed%) + duty.
set -u
NS3="$HOME/projects/5glena/ns-3-dev"
BASE="$HOME/projects/5glena/ci"
cd "$NS3"
rm -rf "$BASE"; mkdir -p "$BASE"
SEEDS="1 2 3 4 5"
COMMON="--plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0 --channelCondition=LOS"
CSV="$BASE/ci-raw.csv"
echo "scenario,seed,duty,failedPct,spills,thrMbps" > "$CSV"

# scenario name | fixed duty (or auto) | extra args
declare -A ARGS=(
  [baseline]="--jammerEnabled=false --useOlla=true"
  [broadband40]="--jammerTxPowerDbm=40 --useOlla=true"
  [reactive_on]="--reactive=true --mcsThreshold=10 --useOlla=true"
  [reactive_on_d1]="--reactive=true --mcsThreshold=10 --useOlla=true --reactionDelayMs=1.0"
  [reactive_off]="--reactive=true --mcsThreshold=10 --useOlla=false"
)
declare -A FIXDUTY=( [baseline]="0" [broadband40]="1.0" )
ORDER="baseline broadband40 reactive_on reactive_on_d1 reactive_off"

for sc in $ORDER; do
  for seed in $SEEDS; do
    out="$BASE/${sc}_s${seed}"; mkdir -p "$out"
    ./ns3 run "mcs-downgrade $COMMON ${ARGS[$sc]} --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
    duty="${FIXDUTY[$sc]:-}"
    if [ -z "$duty" ]; then
      duty=$(grep -oE 'dutyCycle=[0-9.]+' "$out/run.log" | head -1 | cut -d= -f2)
    fi
    line=$(grep -E '^METRICS' "$out/run.log" | head -1)
    tx=$(echo "$line" | grep -oE 'tx=[0-9]+' | cut -d= -f2)
    rx=$(echo "$line" | grep -oE ' rx=[0-9]+' | cut -d= -f2)
    late=$(echo "$line" | grep -oE 'late=[0-9]+' | cut -d= -f2)
    thr=$(echo "$line" | grep -oE 'thrMbps=[0-9.]+' | cut -d= -f2)
    failed="NA"
    if [ -n "${tx:-}" ] && [ "${tx:-0}" -gt 0 ]; then
      failed=$(awk -v t="$tx" -v r="$rx" -v l="$late" 'BEGIN{printf "%.3f",(t-(r-l))*100.0/t}')
    fi
    spills=$(grep -oE 'spills=[0-9]+' "$out/run.log" | head -1 | cut -d= -f2)
    echo "$sc,$seed,${duty:-NA},$failed,${spills:-NA},${thr:-NA}" >> "$CSV"
    printf "%-16s seed=%s duty=%-9s failed%%=%-7s spills=%-4s thr=%s\n" "$sc" "$seed" "${duty:-NA}" "$failed" "${spills:-NA}" "${thr:-NA}"
  done
done
echo
echo "raw CSV: $CSV"
