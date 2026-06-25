#!/usr/bin/env bash
# 100-seed sweeps: A victimTxPowerDbm {10..35}, B jammerHighPowerDbm {30..55}.
# Reactive d=0.5, 128B URLLC+plant, Default random channel. Parallel (xargs -P6),
# direct-binary invocation. Each job -> own out dir -> one .row file -> assembled CSVs.
set -u
NS3=/home/simo1/projects/5glena/ns-3-dev
export BIN="$NS3/build/scratch/ns3.47-mcs-downgrade-optimized"
export LD_LIBRARY_PATH="$NS3/build/lib"
export BASE=/home/simo1/projects/5glena/sweep100
WIN=/mnt/c/Users/simo1/Desktop/charlie
export FIXED="--reactive=true --reactionDelayMs=0.5 --mcsThreshold=10 --useOlla=true --urllcPacketSize=128 --plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0 --channelCondition=Default"
rm -rf "$BASE"; mkdir -p "$BASE/jobs" "$BASE/res"

# ---- per-job worker ----
cat > "$BASE/job.sh" <<'JOB'
sweep="$1"; flag="$2"; val="$3"; seed="$4"
out="$BASE/jobs/${sweep}_${val}_s${seed}"; mkdir -p "$out"; cd "$out" || exit 1
"$BIN" $FIXED --${flag}=${val} --RngRun=${seed} > run.log 2>&1
duty=$(grep -oE 'dutyCycle=[0-9.]+' run.log | head -1 | cut -d= -f2)
onair=$(awk -v d="${duty:-0}" 'BEGIN{printf "%.3f",d*100}')
ml=$(grep -E '^METRICS' run.log | head -1)
tx=$(echo "$ml" | grep -oE 'tx=[0-9]+' | cut -d= -f2)
rx=$(echo "$ml" | grep -oE ' rx=[0-9]+' | cut -d= -f2)
late=$(echo "$ml" | grep -oE 'late=[0-9]+' | cut -d= -f2)
failed=NA; { [ -n "${tx:-}" ] && [ "${tx:-0}" -gt 0 ]; } && failed=$(awk -v t="$tx" -v r="$rx" -v l="$late" 'BEGIN{printf "%.3f",(t-(r-l))*100/t}')
sp=$(grep -oE 'spills=[0-9]+' run.log | head -1 | cut -d= -f2)
sinr=NA; [ -f RxPacketTrace.txt ] && sinr=$(awk -F'\t' '$2=="DL"&&$8==1{n++;s+=$15}END{if(n)printf "%.2f",s/n; else print "NA"}' RxPacketTrace.txt)
echo "${val},${seed},${onair},${failed},${sp:-NA},${sinr}" > "$BASE/res/${sweep}_${val}_s${seed}.row"
JOB

# ---- job list ----
JOBS="$BASE/joblist.txt"; : > "$JOBS"
for v in 10 15 20 25 30 35; do for s in $(seq 1 100); do echo "victimpow victimTxPowerDbm $v $s" >> "$JOBS"; done; done
for v in 30 35 40 45 50 55; do for s in $(seq 1 100); do echo "jammerpow jammerHighPowerDbm $v $s" >> "$JOBS"; done; done
echo "total jobs: $(wc -l < "$JOBS")  ($(date))"

# ---- run 6-wide ----
xargs -P 6 -L1 bash "$BASE/job.sh" < "$JOBS"
echo "all jobs done ($(date))"

# ---- assemble ----
G="$BASE/studyG-sweep100-victimpow.csv"; H="$BASE/studyH-sweep100-jammerpow.csv"
echo "victimTxPowerDbm,seed,onairPct,failedPct,spills,meanSINR" > "$G"
cat "$BASE"/res/victimpow_*.row 2>/dev/null | sort -t, -k1,1n -k2,2n >> "$G"
echo "jammerHighPowerDbm,seed,onairPct,failedPct,spills,meanSINR" > "$H"
cat "$BASE"/res/jammerpow_*.row 2>/dev/null | sort -t, -k1,1n -k2,2n >> "$H"
cp "$G" "$H" "$WIN/"

# ---- per-point counts (verification) ----
echo "=== rows per victim-power point ==="; awk -F, 'NR>1{c[$1]++}END{for(k in c)print k": "c[k]}' "$G" | sort -n
echo "=== rows per jammer-power point ==="; awk -F, 'NR>1{c[$1]++}END{for(k in c)print k": "c[k]}' "$H" | sort -n
echo "G_rows=$(($(wc -l < "$G")-1))  H_rows=$(($(wc -l < "$H")-1))"
echo "SWEEP_DONE ($(date))"
