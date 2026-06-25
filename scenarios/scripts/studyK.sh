#!/usr/bin/env bash
# Resonance on the RANDOM channel: reaction-delay sweep, 100 seeds, Default LOS/NLOS.
# Tests whether the feedback resonance (R5, LOS-only) survives channel randomness.
set -u
NS3=/home/simo1/projects/5glena/ns-3-dev
export BIN="$NS3/build/scratch/ns3.47-mcs-downgrade-optimized"
export LD_LIBRARY_PATH="$NS3/build/lib"
export BASE=/home/simo1/projects/5glena/studyK
WIN=/mnt/c/Users/simo1/Desktop/charlie
export FIXED="--reactive=true --useOlla=true --ollaStep=0.10 --mcsThreshold=10 --urllcPacketSize=128 --plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0 --channelCondition=Default"
rm -rf "$BASE"; mkdir -p "$BASE/jobs" "$BASE/res"

cat > "$BASE/job.sh" <<'JOB'
d="$1"; seed="$2"
out="$BASE/jobs/d${d}_s${seed}"; mkdir -p "$out"; cd "$out" || exit 1
"$BIN" $FIXED --reactionDelayMs=${d} --RngRun=${seed} > run.log 2>&1
duty=$(grep -oE 'dutyCycle=[0-9.]+' run.log | head -1 | cut -d= -f2)
onair=$(awk -v x="${duty:-0}" 'BEGIN{printf "%.3f",x*100}')
ml=$(grep -E '^METRICS' run.log | head -1)
tx=$(echo "$ml" | grep -oE 'tx=[0-9]+' | cut -d= -f2)
rx=$(echo "$ml" | grep -oE ' rx=[0-9]+' | cut -d= -f2)
late=$(echo "$ml" | grep -oE 'late=[0-9]+' | cut -d= -f2)
failed=NA; { [ -n "${tx:-}" ] && [ "${tx:-0}" -gt 0 ]; } && failed=$(awk -v t="$tx" -v r="$rx" -v l="$late" 'BEGIN{printf "%.3f",(t-(r-l))*100/t}')
sp=$(grep -oE 'spills=[0-9]+' run.log | head -1 | cut -d= -f2)
sinr=NA; [ -f RxPacketTrace.txt ] && sinr=$(awk -F'\t' '$2=="DL"&&$8==1{n++;s+=$15}END{if(n)printf "%.2f",s/n; else print "NA"}' RxPacketTrace.txt)
echo "${d},${seed},${onair},${failed},${sp:-NA},${sinr}" > "$BASE/res/d${d}_s${seed}.row"
JOB

JOBS="$BASE/joblist.txt"; : > "$JOBS"
for d in 0 0.5 1.0 1.5 2.0; do for s in $(seq 1 100); do echo "$d $s" >> "$JOBS"; done; done
echo "total jobs: $(wc -l < "$JOBS")  ($(date))"
xargs -P 6 -L1 bash "$BASE/job.sh" < "$JOBS"
echo "all jobs done ($(date))"

CSV="$BASE/studyK-resonance-random100.csv"
echo "delayMs,seed,onairPct,failedPct,spills,meanSINR" > "$CSV"
cat "$BASE"/res/*.row 2>/dev/null | sort -t, -k1,1n -k2,2n >> "$CSV"
cp "$CSV" "$WIN/"
echo "=== rows per delay ==="; awk -F, 'NR>1{c[$1]++}END{for(k in c)print k": "c[k]}' "$CSV" | sort -n
echo "=== mean spills / failed per delay ==="
awk -F, 'NR>1{n[$1]++; sp[$1]+=$5; fa[$1]+=$4} END{for(k in n) printf "  d=%s  spills=%.0f  failed=%.1f  (n=%d)\n",k,sp[k]/n[k],fa[k]/n[k],n[k]}' "$CSV" | sort
echo "STUDYK_DONE ($(date))"
