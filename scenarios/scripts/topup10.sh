#!/usr/bin/env bash
# Top up R3 + R5(tuning) + R5(resonance) to 10 seeds. New seeds only; existing
# seeds (1-3 / 1-5) are reused at analysis time. Configs mirror the originals
# (campaign128.sh Study D, run-olla-robustness.sh Study A, payload-sweep/studyC2).
set -u
NS3=/home/simo1/projects/5glena/ns-3-dev
BASE=/home/simo1/projects/5glena/topup10
WIN=/mnt/c/Users/simo1/Desktop/charlie
cd "$NS3" || { echo NO_NS3; exit 1; }
mkdir -p "$BASE"

# ---- shared parsers ----
get_duty() { grep -oE 'dutyCycle=[0-9.]+' "$1" | head -1 | cut -d= -f2; }
failed_of() { local f="$1" ml tx rx late
  ml=$(grep -E '^METRICS' "$f" | head -1)
  tx=$(echo "$ml" | grep -oE 'tx=[0-9]+' | cut -d= -f2)
  rx=$(echo "$ml" | grep -oE ' rx=[0-9]+' | cut -d= -f2)
  late=$(echo "$ml" | grep -oE 'late=[0-9]+' | cut -d= -f2)
  if [ -n "${tx:-}" ] && [ "${tx:-0}" -gt 0 ]; then
    awk -v t="$tx" -v r="$rx" -v l="$late" 'BEGIN{printf "%.3f",(t-(r-l))*100.0/t}'
  else echo NA; fi; }
spills_of(){ grep -oE 'spills=[0-9]+' "$1" | head -1 | cut -d= -f2; }
viol_of(){ grep -oE 'violationPct=[0-9.]+' "$1" | head -1 | cut -d= -f2; }
# victim (cellId 1) DL mean MCS, corrupt%, rows from RxPacketTrace.txt
reduce_trace(){ awk -F'\t' '$2=="DL"&&$8==1{n++;m+=$12;if($17==1)c++}
  END{if(n)printf "%d %.2f %.2f",n,m/n,(c+0)*100/n; else printf "0 NA NA"}' "$1"; }

############### Section 1: R3 (Study D) seeds 6-10 ###############
echo "=== R3 top-up (seeds 6-10) ==="
BC3="--plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0 --channelCondition=LOS --urllcPacketSize=128"
declare -A A3=(
  [baseline]="--jammerEnabled=false --useOlla=true"
  [broadband40]="--jammerTxPowerDbm=40 --useOlla=true"
  [broadband50]="--jammerTxPowerDbm=50 --useOlla=true"
  [reactive_d0]="--reactive=true --mcsThreshold=10 --useOlla=true --reactionDelayMs=0"
  [reactive_d05]="--reactive=true --mcsThreshold=10 --useOlla=true --reactionDelayMs=0.5"
  [reactive_d1]="--reactive=true --mcsThreshold=10 --useOlla=true --reactionDelayMs=1.0"
  [reactive_off_d05]="--reactive=true --mcsThreshold=10 --useOlla=false --reactionDelayMs=0.5"
)
declare -A FIXON=( [baseline]="0" [broadband40]="100" [broadband50]="100" )
C3="$BASE/studyD-R3-128-s6_10.csv"
echo "scenario,seed,onairPct,failedPct,spills,violPct" > "$C3"
for sc in baseline broadband40 broadband50 reactive_d0 reactive_d05 reactive_d1 reactive_off_d05; do
  for seed in 6 7 8 9 10; do
    out="$BASE/D_${sc}_s${seed}"; mkdir -p "$out"
    ./ns3 run "mcs-downgrade $BC3 ${A3[$sc]} --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
    failed=$(failed_of "$out/run.log"); sp=$(spills_of "$out/run.log"); vp=$(viol_of "$out/run.log"); du=$(get_duty "$out/run.log")
    onair="${FIXON[$sc]:-}"; [ -z "$onair" ] && onair=$(awk -v d="${du:-0}" 'BEGIN{printf "%.1f",d*100}')
    echo "$sc,$seed,$onair,$failed,${sp:-NA},${vp:-NA}" >> "$C3"
    printf "[D] %-18s s=%s onair=%-6s fail%%=%-7s\n" "$sc" "$seed" "$onair" "$failed"
  done
done

############### Section 2: R5 Table V (Study A) seeds 4-10 ###############
echo "=== R5 tuning top-up (seeds 4-10) ==="
CA="--channelCondition=LOS --mcsThreshold=10 --simTime=2.0 --reactive=true"
C5="$BASE/studyA-tuning-s4_10.csv"
echo "step,targetBler,seed,duty,meanMCS,corruptPct,rows" > "$C5"
for seed in 4 5 6 7 8 9 10; do
  out="$BASE/A_off_s${seed}"; mkdir -p "$out"
  ./ns3 run "mcs-downgrade $CA --useOlla=false --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
  read rows mcs cor < <(reduce_trace "$out/RxPacketTrace.txt"); du=$(get_duty "$out/run.log")
  echo "OLLAoff,-,$seed,${du:-NA},$mcs,$cor,$rows" >> "$C5"
  printf "[A] OLLAoff s=%s meanMCS=%s duty=%s\n" "$seed" "$mcs" "${du:-NA}"
done
for s in 0.05 0.1 0.2; do for B in 0.05 0.1 0.2; do for seed in 4 5 6 7 8 9 10; do
  out="$BASE/A_s${s}_B${B}_s${seed}"; mkdir -p "$out"
  ./ns3 run "mcs-downgrade $CA --useOlla=true --ollaStep=$s --ollaTargetBler=$B --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
  read rows mcs cor < <(reduce_trace "$out/RxPacketTrace.txt"); du=$(get_duty "$out/run.log")
  echo "$s,$B,$seed,${du:-NA},$mcs,$cor,$rows" >> "$C5"
  printf "[A] s=%-4s B=%-4s seed=%s meanMCS=%-6s duty=%s\n" "$s" "$B" "$seed" "$mcs" "${du:-NA}"
done; done; done

############### Section 3: R5 resonance (Study F) seeds 4-10 ###############
echo "=== R5 resonance top-up (seeds 4-10, 3 steps x 5 delays) ==="
BCF="--plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0 --channelCondition=LOS --urllcPacketSize=128 --reactive=true --mcsThreshold=10 --useOlla=true"
CF="$BASE/studyF-resonance-s4_10.csv"
echo "ollaStep,delayMs,seed,duty,failedPct,spills,violPct" > "$CF"
for s in 0.05 0.10 0.20; do for d in 0 0.5 1.0 1.5 2.0; do for seed in 4 5 6 7 8 9 10; do
  out="$BASE/F_s${s}_d${d}_s${seed}"; mkdir -p "$out"
  ./ns3 run "mcs-downgrade $BCF --ollaStep=$s --ollaTargetBler=0.1 --reactionDelayMs=$d --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
  failed=$(failed_of "$out/run.log"); sp=$(spills_of "$out/run.log"); vp=$(viol_of "$out/run.log"); du=$(get_duty "$out/run.log")
  echo "$s,$d,$seed,${du:-NA},$failed,${sp:-NA},${vp:-NA}" >> "$CF"
  printf "[F] step=%s d=%-4s s=%s fail%%=%-7s spills=%-4s\n" "$s" "$d" "$seed" "$failed" "${sp:-NA}"
done; done; done

cp "$C3" "$C5" "$CF" "$WIN/"
echo "TOPUP_DONE -> $WIN/studyD-R3-128-s6_10.csv , studyA-tuning-s4_10.csv , studyF-resonance-s4_10.csv"
