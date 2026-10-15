#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
.venv/bin/python tools/build_kernels.py
mkdir -p var/native
cc -O3 -fno-fast-math -ffp-contract=off -dynamiclib generated/springs.c -o var/native/springs.dylib
"$ISABELLE_APP/bin/isabelle" build -D isabelle -j 1 -o threads=2 Veri7vn
"$ISABELLE_APP/bin/isabelle" export -n -d isabelle -O generated -x '*:code/checker.ML' Veri7vn
.venv/bin/python -m unittest discover -s tests -v
