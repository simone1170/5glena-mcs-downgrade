#!/usr/bin/env bash
# Phase 2 reactive attack: reactive jammer, OLLA on vs off.
# Victim = cellId 1. Reports duty cycle (from stdout) + victim DL MCS trajectory.
set -u
NS3="$HOME/projects/5glena/ns-3-dev"
BASE="$HOME/projects/5glena/reactive"
cd "$NS3"
rm -rf "$BASE"; mkdir -p "$BASE"
SIM=2.0
THR=10

run() {
  local tag="$1"; shift
  local out="$BASE/$tag"; mkdir -p "$out"
  ./ns3 run "mcs-downgrade $*" --cwd "$out" >"$out/run.log" 2>&1
  echo "--- $tag ---"
  grep -E 'reactive jammer:' "$out/run.log"
  local F="$out/RxPacketTrace.txt"
  if [ ! -f "$F" ]; then echo "  NO TRACE"; return; fi
  awk -F'\t' '
    $2=="DL" && $8==1 {
      n++; m+=$12; if($17==1)c++; tb+=$18;
      t=$1+0;
      if(t<0.6){en++; em+=$12}
      if(t>1.5){ln++; lm+=$12; if($17==1)lc++}
    }
    END{
      printf "  victim DL rows=%d  meanMCS=%.2f  corrupt=%.2f%%  meanTBler=%.4f\n", n, m/n, (c+0)*100/n, tb/n;
      if(en) printf "  early(<0.6s) meanMCS=%.2f\n", em/en;
      if(ln) printf "  late(>1.5s)  meanMCS=%.2f  corrupt=%.2f%%\n", lm/ln, (lc+0)*100/ln;
    }' "$F"
}

echo "=== reactive jammer, threshold=$THR, simTime=$SIM ==="
run reactive-olla-off --reactive=true --useOlla=false --mcsThreshold=$THR --simTime=$SIM
run reactive-olla-on  --reactive=true --useOlla=true  --mcsThreshold=$THR --simTime=$SIM
