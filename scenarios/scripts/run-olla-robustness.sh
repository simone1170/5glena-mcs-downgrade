#!/usr/bin/env bash
# Review item #4: robustness of the OLLA-dependence claim and the delay-resonance
# to the OLLA tuning (step s, target BLER B). Two studies, both LOS.
#
#  Study A  -- OLLA-dependence robustness. Reactive jammer, saturating DL.
#              For each (s,B) does the victim still get TRAPPED at low MCS and
#              does the duty stay well below the OLLA-off reference (~0.61)?
#  Study B  -- resonance robustness. Reactive jammer, URLLC + plant.
#              For each OLLA step, sweep sensing delay; does the non-monotonic
#              plant-fault resonance persist (i.e. it is structural, not a
#              s=0.1/B=0.1 artifact)?
set -u
STUDY="${STUDY:-AB}"   # A, B, or AB
NS3="$HOME/projects/5glena/ns-3-dev"
BASE="$HOME/projects/5glena/olla-robust"
cd "$NS3"
mkdir -p "$BASE"
SEEDS="1 2 3"
THR=10
SIM=2.0
COMMON="--channelCondition=LOS --mcsThreshold=10 --simTime=$SIM --reactive=true"

# --- trace reducer: mean victim DL MCS, corrupt%, rows ---
reduce_trace() {
  awk -F'\t' '$2=="DL" && $8==1 { n++; m+=$12; if($17==1)c++ }
    END{ if(n) printf "%d %.2f %.2f", n, m/n, (c+0)*100/n; else printf "0 NA NA" }' "$1"
}
metrics_failed() {
  # failed% = (tx-(rx-late))/tx*100 from METRICS line
  local line; line=$(grep -E '^METRICS' "$1" | head -1)
  local tx rx late
  tx=$(echo "$line" | grep -oE 'tx=[0-9]+' | cut -d= -f2)
  rx=$(echo "$line" | grep -oE ' rx=[0-9]+' | cut -d= -f2)
  late=$(echo "$line" | grep -oE 'late=[0-9]+' | cut -d= -f2)
  if [ -n "${tx:-}" ] && [ "${tx:-0}" -gt 0 ]; then
    awk -v t="$tx" -v r="$rx" -v l="$late" 'BEGIN{printf "%.2f",(t-(r-l))*100.0/t}'
  else echo "NA"; fi
}
get_duty() { grep -oE 'dutyCycle=[0-9.]+' "$1" | head -1 | cut -d= -f2; }

############################ Study A ############################
if [[ "$STUDY" == *A* ]]; then
A="$BASE/studyA-olla-dependence.csv"
echo "step,targetBler,seed,duty,meanMCS,corruptPct,rows" > "$A"
echo "===== Study A: OLLA-dependence robustness (reactive, saturating, LOS) ====="
# OLLA-off reference (param-independent)
for seed in $SEEDS; do
  out="$BASE/A_off_s${seed}"; mkdir -p "$out"
  ./ns3 run "mcs-downgrade $COMMON --useOlla=false --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
  read rows mcs cor < <(reduce_trace "$out/RxPacketTrace.txt")
  duty=$(get_duty "$out/run.log")
  echo "OLLAoff,-,$seed,${duty:-NA},$mcs,$cor,$rows" >> "$A"
  printf "  OLLA off          seed=%s duty=%-8s meanMCS=%-6s\n" "$seed" "${duty:-NA}" "$mcs"
done
for s in 0.05 0.1 0.2; do
  for B in 0.05 0.1 0.2; do
    for seed in $SEEDS; do
      out="$BASE/A_s${s}_B${B}_s${seed}"; mkdir -p "$out"
      ./ns3 run "mcs-downgrade $COMMON --useOlla=true --ollaStep=$s --ollaTargetBler=$B --RngRun=$seed" \
        --cwd "$out" >"$out/run.log" 2>&1
      read rows mcs cor < <(reduce_trace "$out/RxPacketTrace.txt")
      duty=$(get_duty "$out/run.log")
      echo "$s,$B,$seed,${duty:-NA},$mcs,$cor,$rows" >> "$A"
      printf "  step=%-4s B=%-4s seed=%s duty=%-8s meanMCS=%-6s corrupt=%s%%\n" "$s" "$B" "$seed" "${duty:-NA}" "$mcs" "$cor"
    done
  done
done

fi
############################ Study B ############################
if [[ "$STUDY" == *B* ]]; then
Bcsv="$BASE/studyB-resonance.csv"
echo "step,delayMs,seed,duty,failedPct,spills,violPct" > "$Bcsv"
echo "===== Study B: resonance robustness (reactive, URLLC+plant, LOS) ====="
for s in 0.05 0.1 0.2; do
  for d in 0.0 0.5 1.0 1.5 2.0; do
    for seed in $SEEDS; do
      out="$BASE/B_s${s}_d${d}_s${seed}"; mkdir -p "$out"
      ./ns3 run "mcs-downgrade $COMMON --useOlla=true --ollaStep=$s --ollaTargetBler=0.1 --plant=true --reactionDelayMs=$d --RngRun=$seed" \
        --cwd "$out" >"$out/run.log" 2>&1
      duty=$(get_duty "$out/run.log")
      failed=$(metrics_failed "$out/run.log")
      spills=$(grep -oE 'spills=[0-9]+' "$out/run.log" | head -1 | cut -d= -f2)
      viol=$(grep -oE 'violationPct=[0-9.]+' "$out/run.log" | head -1 | cut -d= -f2)
      echo "$s,$d,$seed,${duty:-NA},$failed,${spills:-NA},${viol:-NA}" >> "$Bcsv"
      printf "  step=%-4s delay=%-4s seed=%s duty=%-8s failed%%=%-6s spills=%-4s viol%%=%s\n" "$s" "$d" "$seed" "${duty:-NA}" "$failed" "${spills:-NA}" "${viol:-NA}"
    done
  done
done

fi
echo
echo "DONE study=$STUDY"
