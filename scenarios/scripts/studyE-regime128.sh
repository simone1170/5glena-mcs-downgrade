#!/usr/bin/env bash
# R4 re-run at 128 B: random LOS/NLOS channel, 12 seeds. Reactive at realistic
# delay 0.5 ms; broadband baseline at 50 dBm (the effective broadband at 128 B).
set -u
NS3=/home/simo1/projects/5glena/ns-3-dev
BASE=/home/simo1/projects/5glena/regime128
WINOUT=/mnt/c/Users/simo1/Desktop/charlie
cd "$NS3" || { echo NO_NS3; exit 1; }
rm -rf "$BASE"; mkdir -p "$BASE"
PKT=128
SEEDS="1 2 3 4 5 6 7 8 9 10 11 12"
COMMON="--plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0 --channelCondition=Default --urllcPacketSize=$PKT"
declare -A ARGS=(
  [baseline]="--jammerEnabled=false --useOlla=true"
  [broadband50]="--jammerTxPowerDbm=50 --useOlla=true"
  [reactive_d05]="--reactive=true --mcsThreshold=10 --useOlla=true --reactionDelayMs=0.5"
)
declare -A FIXON=( [baseline]="0" [broadband50]="100" )
CSV="$BASE/studyE-regime-128.csv"
echo "scenario,seed,onairPct,failedPct,spills,violPct" > "$CSV"
for sc in baseline broadband50 reactive_d05; do
  for seed in $SEEDS; do
    out="$BASE/${sc}_s${seed}"; mkdir -p "$out"
    ./ns3 run "mcs-downgrade $COMMON ${ARGS[$sc]} --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
    ml=$(grep -E '^METRICS' "$out/run.log" | head -1)
    tx=$(echo "$ml" | grep -oE 'tx=[0-9]+' | cut -d= -f2)
    rx=$(echo "$ml" | grep -oE ' rx=[0-9]+' | cut -d= -f2)
    late=$(echo "$ml" | grep -oE 'late=[0-9]+' | cut -d= -f2)
    failed="NA"
    [ -n "${tx:-}" ] && [ "${tx:-0}" -gt 0 ] && failed=$(awk -v t="$tx" -v r="$rx" -v l="$late" 'BEGIN{printf "%.3f",(t-(r-l))*100.0/t}')
    sp=$(grep -oE 'spills=[0-9]+' "$out/run.log" | head -1 | cut -d= -f2)
    vp=$(grep -oE 'violationPct=[0-9.]+' "$out/run.log" | head -1 | cut -d= -f2)
    du=$(grep -oE 'dutyCycle=[0-9.]+' "$out/run.log" | head -1 | cut -d= -f2)
    onair="${FIXON[$sc]:-}"; [ -z "$onair" ] && onair=$(awk -v d="${du:-0}" 'BEGIN{printf "%.1f",d*100}')
    echo "$sc,$seed,$onair,$failed,${sp:-NA},${vp:-NA}" >> "$CSV"
    printf "[E] %-14s seed=%-2s onair=%-6s fail%%=%-7s spills=%-4s\n" "$sc" "$seed" "$onair" "$failed" "${sp:-NA}"
  done
done
cp "$CSV" "$WINOUT/studyE-regime-128.csv"
echo "DONE -> $WINOUT/studyE-regime-128.csv"
