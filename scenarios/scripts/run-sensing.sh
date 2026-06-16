#!/usr/bin/env bash
# 2b: reactive jammer with sensing/reaction delay sweep (OLLA on, URLLC victim).
set -u
NS3="$HOME/projects/5glena/ns-3-dev"
BASE="$HOME/projects/5glena/sensing"
cd "$NS3"
rm -rf "$BASE"; mkdir -p "$BASE"
COMMON="--reactive=true --useOlla=true --mcsThreshold=10 --urllc=true --simTime=2.0"

run() {
  local tag="$1"; local delay="$2"
  local out="$BASE/$tag"; mkdir -p "$out"
  ./ns3 run "mcs-downgrade $COMMON --reactionDelayMs=$delay" --cwd "$out" >"$out/run.log" 2>&1
  local duty miss thr line
  duty=$(grep -oE 'dutyCycle=[0-9.]+' "$out/run.log" | head -1 | cut -d= -f2)
  line=$(grep -E '^METRICS' "$out/run.log" | head -1)
  local tx rx late
  tx=$(echo "$line" | grep -oE 'tx=[0-9]+' | cut -d= -f2)
  rx=$(echo "$line" | grep -oE ' rx=[0-9]+' | cut -d= -f2)
  late=$(echo "$line" | grep -oE 'late=[0-9]+' | cut -d= -f2)
  thr=$(echo "$line" | grep -oE 'thrMbps=[0-9.]+' | cut -d= -f2)
  local failed="NA"
  if [ -n "${tx:-}" ] && [ "${tx:-0}" -gt 0 ]; then
    failed=$(awk -v t="$tx" -v r="$rx" -v l="$late" 'BEGIN{printf "%.1f",(t-(r-l))*100.0/t}')
  fi
  # victim commanded MCS (cellId 1) mean from trace
  local mcs="NA" F="$out/RxPacketTrace.txt"
  [ -f "$F" ] && mcs=$(awk -F'\t' '$2=="DL"&&$8==1{n++;m+=$12}END{if(n)printf "%.2f",m/n}' "$F")
  printf "delay=%-5sms  duty=%-8s  meanMCS=%-6s  failed%%=%-6s  thrMbps=%s\n" "$delay" "${duty:-NA}" "${mcs:-NA}" "$failed" "${thr:-NA}"
}

echo "=== reactive jammer sensing-delay sweep (thr=10, OLLA on, URLLC) ==="
run d0.0 0.0
run d0.5 0.5
run d1.0 1.0
run d2.0 2.0
