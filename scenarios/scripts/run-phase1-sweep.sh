#!/usr/bin/env bash
# Phase 1 validation gate: sweep interferer Tx power, report victim-cell DL stats.
# Victim UE is served by gNB0 -> cellId 1. Columns in RxPacketTrace.txt:
# 1=Time 2=dir 8=cellId 10=rnti 11=tbSize 12=mcs 15=SINR(dB) 17=corrupt 18=TBler
set -u
NS3="$HOME/projects/5glena/ns-3-dev"
BASE="$HOME/projects/5glena/phase1"
cd "$NS3"
rm -rf "$BASE"; mkdir -p "$BASE"

run() {
  local tag="$1"; shift
  local out="$BASE/$tag"
  mkdir -p "$out"
  ./ns3 run "mcs-downgrade $*" --cwd "$out" >"$out/run.log" 2>&1
  local F="$out/RxPacketTrace.txt"
  if [ ! -f "$F" ]; then echo "$tag: NO TRACE"; return; fi
  awk -F'\t' -v tag="$tag" '
    $2=="DL" && $8==1 {
      n++; s+=$15;
      if (n==1||$15<mn) mn=$15; if ($15>mx) mx=$15;
      m+=$12; if ($17==1) c++; tb+=$18;
    }
    END{
      if(n==0){printf "%-16s  no victim DL rows\n",tag; next}
      printf "%-16s  DLrows=%-5d  SINR[min/mean/max]=%.1f/%.1f/%.1f  meanMCS=%.1f  corrupt=%.2f%%  meanTBler=%.4f\n",
        tag, n, mn, s/n, mx, m/n, (c+0)*100.0/n, tb/n;
    }' "$F"
}

echo "=== Phase 1 interferer power sweep (victim cellId=1) ==="
run baseline-off   --jammerEnabled=false
run jam-0dBm       --jammerTxPowerDbm=0
run jam-20dBm      --jammerTxPowerDbm=20
run jam-30dBm      --jammerTxPowerDbm=30
run jam-40dBm      --jammerTxPowerDbm=40
run jam-50dBm      --jammerTxPowerDbm=50
