#!/usr/bin/env bash
# Phase 0: clone ns-3.47 + nr v4.2 and build (5G-LENA migration)
set -euo pipefail

ROOT="$HOME/projects/5glena"
mkdir -p "$ROOT"
cd "$ROOT"
rm -rf nr ns-3-dev

echo "[clone ns-3.47]"
git clone --depth 1 --branch ns-3.47 https://gitlab.com/nsnam/ns-3-dev.git

echo "[clone nr v4.2]"
git clone --depth 1 --branch 5g-lena-v4.2.y https://gitlab.com/cttc-lena/nr.git ns-3-dev/contrib/nr

cd ns-3-dev
echo "[configure]"
./ns3 configure --enable-examples -d optimized

echo "[build]"
./ns3 build

echo "BUILD_EXIT_OK"
