#!/usr/bin/env bash
# 2D stealth/effectiveness grid: jammer power {40,45,50,55} x MCS threshold {6,10,14,18},
# random channel, 100 seeds. Two independent attacker levers -> detectability plane.
set -u
NS3=/home/simo1/projects/5glena/ns-3-dev
export BIN="$NS3/build/scratch/ns3.47-mcs-downgrade-optimized"
export LD_LIBRARY_PATH="$NS3/build/lib"
export BASE=/home/simo1/projects/5glena/grid100
WIN=/mnt/c/Users/simo1/Desktop/charlie
export FIXED="--reactive=true --reactionDelayMs=0.5 --useOlla=true --urllcPacketSize=128 --plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0 --channelCondition=Default"
rm -rf "$BASE"; mkdir -p "$BASE/jobs" "$BASE/res"

cat > "$BASE/job.sh" <<'JOB'
pw="$1"; thr="$2"; seed="$3"
out="$BASE/jobs/p${pw}_t${thr}_s${seed}"; mkdir -p "$out"; cd "$out" || exit 1
"$BIN" $FIXED --jammerHighPowerDbm=${pw} --mcsThreshold=${thr} --RngRun=${seed} > run.log 2>&1
duty=$(grep -oE 'dutyCycle=[0-9.]+' run.log | head -1 | cut -d= -f2)
onair=$(awk -v d="${duty:-0}" 'BEGIN{printf "%.3f",d*100}')
ml=$(grep -E '^METRICS' run.log | head -1)
tx=$(echo "$ml" | grep -oE 'tx=[0-9]+' | cut -d= -f2)
rx=$(echo "$ml" | grep -oE ' rx=[0-9]+' | cut -d= -f2)
late=$(echo "$ml" | grep -oE 'late=[0-9]+' | cut -d= -f2)
failed=NA; { [ -n "${tx:-}" ] && [ "${tx:-0}" -gt 0 ]; } && failed=$(awk -v t="$tx" -v r="$rx" -v l="$late" 'BEGIN{printf "%.3f",(t-(r-l))*100/t}')
sp=$(grep -oE 'spills=[0-9]+' run.log | head -1 | cut -d= -f2)
sinr=NA; [ -f RxPacketTrace.txt ] && sinr=$(awk -F'\t' '$2=="DL"&&$8==1{n++;s+=$15}END{if(n)printf "%.2f",s/n; else print "NA"}' RxPacketTrace.txt)
echo "${pw},${thr},${seed},${onair},${failed},${sp:-NA},${sinr}" > "$BASE/res/p${pw}_t${thr}_s${seed}.row"
JOB

JOBS="$BASE/joblist.txt"; : > "$JOBS"
for pw in 40 45 50 55; do for thr in 6 10 14 18; do for s in $(seq 1 100); do echo "$pw $thr $s" >> "$JOBS"; done; done; done
echo "total jobs: $(wc -l < "$JOBS")  ($(date))"
xargs -P 6 -L1 bash "$BASE/job.sh" < "$JOBS"
echo "all jobs done ($(date))"

CSV="$BASE/studyJ-grid100.csv"
echo "jammerHighPowerDbm,mcsThreshold,seed,onairPct,failedPct,spills,meanSINR" > "$CSV"
cat "$BASE"/res/*.row 2>/dev/null | sort -t, -k1,1n -k2,2n -k3,3n >> "$CSV"
cp "$CSV" "$WIN/"
echo "=== rows per (power,threshold) cell ==="
awk -F, 'NR>1{c[$1"_"$2]++}END{for(k in c)print k": "c[k]}' "$CSV" | sort
echo "grid_rows=$(($(wc -l < "$CSV")-1))"
echo "GRID_DONE ($(date))"
