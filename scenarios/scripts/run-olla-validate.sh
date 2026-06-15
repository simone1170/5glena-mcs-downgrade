#!/usr/bin/env bash
# Phase 2 OLLA validation: compare OLLA off vs on, clean and under interference.
# Victim = cellId 1. Reports victim DL: rows, mean SINR, mean MCS, corrupt%, mean TBler.
set -u
NS3="$HOME/projects/5glena/ns-3-dev"
BASE="$HOME/projects/5glena/olla"
cd "$NS3"
rm -rf "$BASE"; mkdir -p "$BASE"

run() {
  local tag="$1"; shift
  local out="$BASE/$tag"; mkdir -p "$out"
  ./ns3 run "mcs-downgrade $*" --cwd "$out" >"$out/run.log" 2>&1
  local F="$out/RxPacketTrace.txt"
  if [ ! -f "$F" ]; then printf "%-22s NO TRACE\n" "$tag"; return; fi
  awk -F'\t' -v tag="$tag" '
    $2=="DL" && $8==1 { n++; s+=$15; m+=$12; if($17==1)c++; tb+=$18; }
    END{ if(n==0){printf "%-22s no DL rows\n",tag}
         else printf "%-22s DLrows=%-5d meanSINR=%.1f meanMCS=%.2f corrupt=%.2f%% meanTBler=%.4f\n",
               tag,n,s/n,m/n,(c+0)*100.0/n,tb/n; }' "$F"
}

echo "=== clean channel (regression: OLLA must not hurt) ==="
run clean-olla-off  --jammerEnabled=false --useOlla=false
run clean-olla-on   --jammerEnabled=false --useOlla=true

echo
echo "=== under interference @40 dBm ==="
run jam40-olla-off  --jammerTxPowerDbm=40 --useOlla=false
run jam40-olla-on   --jammerTxPowerDbm=40 --useOlla=true

echo
echo "=== under interference @45 dBm ==="
run jam45-olla-off  --jammerTxPowerDbm=45 --useOlla=false
run jam45-olla-on   --jammerTxPowerDbm=45 --useOlla=true
