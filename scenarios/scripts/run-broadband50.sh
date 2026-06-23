#!/usr/bin/env bash
# Matched-power broadband baseline: broadband jammer at 50 dBm (= reactive on-power),
# same LOS + URLLC + plant setup and seeds as the R3 CI campaign (run-ci.sh).
# Reports failed% per seed so we can compare on-air time AND energy at equal peak power.
set -u
NS3="$HOME/projects/5glena/ns-3-dev"
BASE="$HOME/projects/5glena/bb50"
cd "$NS3"
rm -rf "$BASE"; mkdir -p "$BASE"
SEEDS="1 2 3 4 5"
COMMON="--plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0 --channelCondition=LOS --useOlla=true"
CSV="$BASE/bb50.csv"
echo "power,seed,failedPct,spills,thrMbps" > "$CSV"

for pw in 50; do
  for seed in $SEEDS; do
    out="$BASE/bb${pw}_s${seed}"; mkdir -p "$out"
    ./ns3 run "mcs-downgrade $COMMON --jammerTxPowerDbm=$pw --RngRun=$seed" --cwd "$out" >"$out/run.log" 2>&1
    line=$(grep -E '^METRICS' "$out/run.log" | head -1)
    tx=$(echo "$line" | grep -oE 'tx=[0-9]+' | cut -d= -f2)
    rx=$(echo "$line" | grep -oE ' rx=[0-9]+' | cut -d= -f2)
    late=$(echo "$line" | grep -oE 'late=[0-9]+' | cut -d= -f2)
    thr=$(echo "$line" | grep -oE 'thrMbps=[0-9.]+' | cut -d= -f2)
    failed="NA"
    if [ -n "${tx:-}" ] && [ "${tx:-0}" -gt 0 ]; then
      failed=$(awk -v t="$tx" -v r="$rx" -v l="$late" 'BEGIN{printf "%.2f",(t-(r-l))*100.0/t}')
    fi
    spills=$(grep -oE 'spills=[0-9]+' "$out/run.log" | head -1 | cut -d= -f2)
    echo "$pw,$seed,$failed,${spills:-NA},${thr:-NA}" >> "$CSV"
    printf "  broadband %sdBm seed=%s failed%%=%-7s spills=%s\n" "$pw" "$seed" "$failed" "${spills:-NA}"
  done
done

echo "=== mean +/- 95%% CI (failed%) ==="
awk -F, 'NR>1{n++; s+=$3; ss+=$3*$3} END{m=s/n; sd=sqrt((ss-n*m*m)/(n-1)); ci=2.776*sd/sqrt(n); printf "broadband50: failed%%=%.2f +/- %.2f  (n=%d)\n", m, ci, n}' "$CSV"
echo "CSV: $CSV"
