#!/usr/bin/env bash
# Plant validation: bottle-filling spills under baseline / broadband / reactive.
set -u
NS3="$HOME/projects/5glena/ns-3-dev"
BASE="$HOME/projects/5glena/plant"
cd "$NS3"
rm -rf "$BASE"; mkdir -p "$BASE"
COMMON="--plant=true --simTime=2.0 --deadlineMs=2.0 --urllcPeriodMs=1.0"

run() {
  local tag="$1"; shift
  local out="$BASE/$tag"; mkdir -p "$out"
  ./ns3 run "mcs-downgrade $COMMON $*" --cwd "$out" >"$out/run.log" 2>&1
  local plant duty
  plant=$(grep -E '^PLANT' "$out/run.log" | head -1)
  duty=$(grep -oE 'dutyCycle=[0-9.]+' "$out/run.log" | head -1 | cut -d= -f2)
  printf "%-26s duty=%-9s %s\n" "$tag" "${duty:-NA}" "${plant:-NO_PLANT_LINE}"
}

echo "=== plant: spills under each scenario (deadline 2ms) ==="
run baseline            --jammerEnabled=false --useOlla=true
run broadband-40dBm     --jammerTxPowerDbm=40 --useOlla=true
run reactive-thr10-on   --reactive=true --mcsThreshold=10 --useOlla=true
run reactive-thr10-off  --reactive=true --mcsThreshold=10 --useOlla=false
