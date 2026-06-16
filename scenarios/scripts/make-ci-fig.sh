#!/usr/bin/env bash
set -u
tr -d '\r' < /mnt/c/Users/simo1/Desktop/charlie/wsl-scripts/plot-ci.py > "$HOME/plot-ci.py"
for py in python3 "$HOME/venv-ardupilot/bin/python3"; do
  if "$py" -c 'import matplotlib' 2>/dev/null; then
    "$py" "$HOME/plot-ci.py"
    exit $?
  fi
done
echo "matplotlib not found"; exit 1
