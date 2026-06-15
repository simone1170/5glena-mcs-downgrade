#!/usr/bin/env bash
set -u
tr -d '\r' < /mnt/c/Users/simo1/Desktop/charlie/wsl-scripts/plot-phase3.py > "$HOME/plot-phase3.py"
for py in python3 "$HOME/venv-ardupilot/bin/python3"; do
  if "$py" -c 'import matplotlib' 2>/dev/null; then
    echo "Using $py"
    "$py" "$HOME/plot-phase3.py"
    exit $?
  fi
done
echo "matplotlib not found"
exit 1
