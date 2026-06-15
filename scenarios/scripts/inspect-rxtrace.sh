#!/usr/bin/env bash
# Inspect a 5G-LENA RxPacketTrace.txt.
# Columns: 1=Time 2=dir 3=frame 4=subF 5=slot 6=1stSym 7=nSym 8=cellId
#          9=bwpId 10=rnti 11=tbSize 12=mcs 13=rank 14=rv 15=SINR(dB)
#          16=CQI 17=corrupt 18=TBler
set -u
F="${1:-$HOME/projects/5glena/nrdemo-out/RxPacketTrace.txt}"

echo "=== header (index : name) ==="
head -1 "$F" | tr '\t' '\n' | nl -ba

echo
echo "=== row counts by direction (col2) ==="
tail -n +2 "$F" | cut -f2 | sort | uniq -c

echo
echo "=== first 4 DL rows ==="
awk -F'\t' 'NR==1 || $2=="DL"' "$F" | head -5

echo
echo "=== DL stats (SINR=15, mcs=12, corrupt=17, TBler=18) ==="
awk -F'\t' '
  $2=="DL" {
    n++; s+=$15;
    if (n==1 || $15<mn) mn=$15;
    if ($15>mx) mx=$15;
    if (n==1 || $12<mnm) mnm=$12;
    if ($12>mxm) mxm=$12;
    if ($17==1) corr++;
    tb+=$18;
  }
  END {
    if (n==0) { print "no DL rows"; exit }
    printf "DL rows      = %d\n", n;
    printf "SINR(dB)     min=%.2f  mean=%.2f  max=%.2f\n", mn, s/n, mx;
    printf "MCS          min=%d  max=%d\n", mnm, mxm;
    printf "corrupt TBs  = %d  (%.3f%%)\n", corr+0, (corr+0)*100.0/n;
    printf "mean TBler   = %.4f\n", tb/n;
  }' "$F"
