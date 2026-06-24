#!/usr/bin/env bash
# 128 B campaign: (D) R3 efficiency vs broadband, (C2) resonance steps 0.05/0.20.
set -u
NS3=/home/simo1/projects/5glena/ns-3-dev
BASE=/home/simo1/projects/5glena/campaign128
WINOUT=/mnt/c/Users/simo1/Desktop/charlie
cd "$NS3" || { echo NO_NS3; exit 1; }
rm -rf "$BASE"; mkdir -p "$BASE"
PKT=128
BASECOMMON="--plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0 --channelCondition=LOS --urllcPacketSize=$PKT"

parse() { # $1=logfile ; echoes "failed spills violPct duty"
  local f="$1" tx rx late ml pl sp vp du
  ml=$(grep -E '^METRICS' "$f" | head -1)
  tx=$(echo "$ml" | grep -oE 'tx=[0-9]+' | cut -d= -f2)
  rx=$(echo "$ml" | grep -oE ' rx=[0-9]+' | cut -d= -f2)
  late=$(echo "$ml" | grep -oE 'late=[0-9]+' | cut -d= -f2)
  local failed="NA"
  [ -n "${tx:-}" ] && [ "${tx:-0}" -gt 0 ] && failed=$(awk -v t="$tx" -v r="$rx" -v l="$late" 'BEGIN{printf "%.3f",(t-(r-l))*100.0/t}')
  pl=$(grep -E '^PLANT' "$f" | head -1)
  sp=$(echo "$pl" | grep -oE 'spills=[0-9]+' | cut -d= -f2)
  vp=$(echo "$pl" | grep -oE 'violationPct=[0-9.]+' | cut -d= -f2)
  du=$(grep -oE 'dutyCycle=[0-9.]+' "$f" | head -1 | cut -d= -f2)
  echo "${failed} ${sp:-NA} ${vp:-NA} ${du:-NA}"
}

###################### Study D : R3 efficiency (5 seeds) ######################
SEEDS_D="1 2 3 4 5"
CSVD="$BASE/studyD-R3-128.csv"
echo "scenario,seed,onairPct,failedPct,spills,violPct" > "$CSVD"
declare -A ARGS=(
  [baseline]="--jammerEnabled=false --useOlla=true"
  [broadband40]="--jammerTxPowerDbm=40 --useOlla=true"
  [broadband50]="--jammerTxPowerDbm=50 --useOlla=true"
  [reactive_d0]="--reactive=true --mcsThreshold=10 --useOlla=true --reactionDelayMs=0"
  [reactive_d05]="--reactive=true --mcsThreshold=10 --useOlla=true --reactionDelayMs=0.5"
  [reactive_d1]="--reactive=true --mcsThreshold=10 --useOlla=true --reactionDelayMs=1.0"
  [reactive_off_d05]="--reactive=true --mcsThreshold=10 --useOlla=false --reactionDelayMs=0.5"
)
declare -A FIXON=( [baseline]="0" [broadband40]="100" [broadband50]="100" )
for sc in baseline broadband40 broadband50 reactive_d0 reactive_d05 reactive_d1 reactive_off_d05; do
  for seed in $SEEDS_D; do
    out="$BASE/D_${sc}_s${seed}"; mkdir -p "$out"
    ./ns3 run "mcs-downgrade $BASECOMMON ${ARGS[$sc]} --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
    read failed sp vp du <<<"$(parse "$out/run.log")"
    onair="${FIXON[$sc]:-}"; [ -z "$onair" ] && onair=$(awk -v d="${du:-0}" 'BEGIN{printf "%.1f",d*100}')
    echo "$sc,$seed,$onair,$failed,$sp,$vp" >> "$CSVD"
    printf "[D] %-18s s=%s onair=%-6s fail%%=%-7s spills=%-4s\n" "$sc" "$seed" "$onair" "$failed" "$sp"
  done
done

###################### Study C2 : resonance steps 0.05/0.20 (3 seeds) ##########
SEEDS_C="1 2 3"
DELAYS="0 0.5 1.0 1.5 2.0"
CSVC="$BASE/studyC2-resonance-128.csv"
echo "ollaStep,delayMs,seed,duty,failedPct,spills,violPct" > "$CSVC"
for s in 0.05 0.20; do
  for d in $DELAYS; do
    for seed in $SEEDS_C; do
      out="$BASE/C2_s${s}_d${d}_seed${seed}"; mkdir -p "$out"
      ./ns3 run "mcs-downgrade $BASECOMMON --reactive=true --mcsThreshold=10 --useOlla=true --ollaStep=$s --reactionDelayMs=$d --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
      read failed sp vp du <<<"$(parse "$out/run.log")"
      echo "$s,$d,$seed,${du:-NA},$failed,$sp,$vp" >> "$CSVC"
      printf "[C2] step=%s d=%-4s s=%s fail%%=%-7s spills=%-4s\n" "$s" "$d" "$seed" "$failed" "$sp"
    done
  done
done

cp "$CSVD" "$WINOUT/studyD-R3-128.csv"
cp "$CSVC" "$WINOUT/studyC2-resonance-128.csv"
echo "DONE  -> $WINOUT/studyD-R3-128.csv , studyC2-resonance-128.csv"
