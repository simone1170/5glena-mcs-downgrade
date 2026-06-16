#!/usr/bin/env bash
set -u
cd "$HOME/projects/5glena/phase3"
for d in baseline-olla-on broadband-30dBm broadband-40dBm broadband-50dBm \
         reactive-thr8-on reactive-thr10-on reactive-thr14-on reactive-thr10-off; do
  duty=$(grep -oE 'dutyCycle=[0-9.]+' "$d/run.log" | head -1 | cut -d= -f2)
  printf "%-22s duty=%-9s " "$d" "${duty:-NA}"
  grep -hE '^METRICS' "$d/run.log"
done
