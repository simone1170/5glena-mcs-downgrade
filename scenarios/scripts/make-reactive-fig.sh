#!/usr/bin/env bash
set -u
tr -d '\r' < /mnt/c/Users/simo1/Desktop/charlie/wsl-scripts/plot-reactive.py > "$HOME/plot-reactive.py"
for py in python3 "$HOME/venv-ardupilot/bin/python3"; do
  if "$py" -c 'import matplotlib' 2>/dev/null; then
    echo "Using $py"
    "$py" "$HOME/plot-reactive.py"
    exit $?
  fi
done
echo "matplotlib not found in any python; attempting pip install into user site"
python3 -m pip install --user --quiet matplotlib && python3 "$HOME/plot-reactive.py"
