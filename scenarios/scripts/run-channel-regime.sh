#!/usr/bin/env bash
# Characterize the random-channel (Default 3GPP LOS/NLOS) regime as a SEPARATE
# result behind the LOS-conditioned headline. For each channel realization (seed):
# does the reactive attack succeed (low duty, victim damaged) or fail (jammer link
# draws an NLOS fade -> cannot trap MCS -> duty runs to ~1.0, victim undamaged)?
# Compare against broadband (which also degrades on NLOS victim-link draws).
set -u
NS3="$HOME/projects/5glena/ns-3-dev"
BASE="$HOME/projects/5glena/regime"
cd "$NS3"
rm -rf "$BASE"; mkdir -p "$BASE"
SEEDS="1 2 3 4 5 6 7 8 9 10 11 12"
COMMON="--plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0 --channelCondition=Default"
CSV="$BASE/regime-raw.csv"
echo "scenario,seed,duty,failedPct,spills,thrMbps" > "$CSV"

declare -A ARGS=(
  [baseline]="--jammerEnabled=false --useOlla=true"
  [broadband40]="--jammerTxPowerDbm=40 --useOlla=true"
  [reactive_on]="--reactive=true --mcsThreshold=10 --useOlla=true"
)
declare -A FIXDUTY=( [baseline]="0" [broadband40]="1.0" )

for sc in baseline broadband40 reactive_on; do
  for seed in $SEEDS; do
    out="$BASE/${sc}_s${seed}"; mkdir -p "$out"
    ./ns3 run "mcs-downgrade $COMMON ${ARGS[$sc]} --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
    duty="${FIXDUTY[$sc]:-}"
    [ -z "$duty" ] && duty=$(grep -oE 'dutyCycle=[0-9.]+' "$out/run.log" | head -1 | cut -d= -f2)
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
    printf "%-12s s=%-2s duty=%-9s fail%%=%-8s spills=%s\n" "$sc" "$seed" "${duty:-NA}" "$failed" "${spills:-NA}"
  done
done
echo; echo "raw CSV: $CSV"
