#!/usr/bin/env bash
# Phase 3 campaign: URLLC victim (1000B/1ms, 2ms deadline). Compare attacker
# cost (duty cycle) vs damage (deadline-miss%, mean delay, throughput) for
# baseline / constant broadband (power sweep) / reactive (threshold sweep).
set -u
NS3="$HOME/projects/5glena/ns-3-dev"
BASE="$HOME/projects/5glena/phase3"
cd "$NS3"
rm -rf "$BASE"; mkdir -p "$BASE"
SIM=2.0
URLLC="--urllc=true --urllcPacketSize=1000 --urllcPeriodMs=1.0 --deadlineMs=2.0 --simTime=$SIM"
CSV="$BASE/summary.csv"
echo "scenario,duty,deadlineMissPct,meanDelayMs,thrMbps" > "$CSV"

run() {
  local tag="$1"; local duty="$2"; shift 2
  local out="$BASE/$tag"; mkdir -p "$out"
  ./ns3 run "mcs-downgrade $URLLC $*" --cwd "$out" >"$out/run.log" 2>&1
  # duty: if "auto", read from log (reactive); else use provided value
  local d="$duty"
  if [ "$duty" = "auto" ]; then
    d=$(grep -oE 'dutyCycle=[0-9.]+' "$out/run.log" | head -1 | cut -d= -f2)
  fi
  local line
  line=$(grep -E '^METRICS' "$out/run.log" | head -1)
  local miss delay thr
  miss=$(echo "$line" | grep -oE 'deadlineMissPct=[0-9.]+' | cut -d= -f2)
  delay=$(echo "$line" | grep -oE 'meanDelayMs=[0-9.]+' | cut -d= -f2)
  thr=$(echo "$line" | grep -oE 'thrMbps=[0-9.]+' | cut -d= -f2)
  printf "%-26s duty=%-6s missPct=%-7s meanDelayMs=%-9s thrMbps=%s\n" "$tag" "${d:-NA}" "${miss:-NA}" "${delay:-NA}" "${thr:-NA}"
  echo "$tag,${d:-NA},${miss:-NA},${delay:-NA},${thr:-NA}" >> "$CSV"
}

echo "=== baseline (no jammer) ==="
run baseline-olla-on   0    --jammerEnabled=false --useOlla=true

echo "=== constant broadband jammer (always on, duty=1.0), OLLA on ==="
run broadband-30dBm    1.0  --jammerTxPowerDbm=30 --useOlla=true
run broadband-40dBm    1.0  --jammerTxPowerDbm=40 --useOlla=true
run broadband-50dBm    1.0  --jammerTxPowerDbm=50 --useOlla=true

echo "=== reactive jammer (threshold sweep), OLLA on ==="
run reactive-thr8-on   auto --reactive=true --mcsThreshold=8  --useOlla=true
run reactive-thr10-on  auto --reactive=true --mcsThreshold=10 --useOlla=true
run reactive-thr14-on  auto --reactive=true --mcsThreshold=14 --useOlla=true

echo "=== reactive control: OLLA off (should not trap) ==="
run reactive-thr10-off auto --reactive=true --mcsThreshold=10 --useOlla=false

echo
echo "summary CSV: $CSV"
cat "$CSV"
