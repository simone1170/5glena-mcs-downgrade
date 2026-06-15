#!/usr/bin/env bash
# Analyze Phase 1 sweep outputs already produced under ~/projects/5glena/phase1.
set -u
BASE="$HOME/projects/5glena/phase1"

stat() {
  local tag="$1"
  local F="$BASE/$tag/RxPacketTrace.txt"
  if [ ! -f "$F" ]; then printf "%-16s  NO TRACE\n" "$tag"; return; fi
  awk -F'\t' -v tag="$tag" '
    $2=="DL" && $8==1 {
      n++; s+=$15;
      if (n==1||$15<mn) mn=$15; if ($15>mx) mx=$15;
      m+=$12; if ($17==1) c++; tb+=$18;
    }
    END{
      if(n==0){ printf "%-16s  no victim DL rows\n", tag; }
      else { printf "%-16s  DLrows=%-5d  SINR[min/mean/max]=%.1f/%.1f/%.1f  meanMCS=%.1f  corrupt=%.2f%%  meanTBler=%.4f\n",
        tag, n, mn, s/n, mx, m/n, (c+0)*100.0/n, tb/n; }
    }' "$F"
}

echo "=== Phase 1 interferer power sweep (victim cellId=1) ==="
for t in baseline-off jam-0dBm jam-20dBm jam-30dBm jam-40dBm jam-50dBm; do stat "$t"; done
