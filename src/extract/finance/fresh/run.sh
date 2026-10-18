#!/bin/sh
# usage: run.sh <tag> <binary>  -> var/finance/fresh/out/<tag>/{shipped,F1,F2}; then: python3 tab.py <tag>
set -eu
cd /Users/ember/dev/o7vn
export PYTHONDONTWRITEBYTECODE=1
TAG=$1; BIN="$2 --specialist {id}"
O=var/finance/fresh/out/$TAG; rm -rf $O; mkdir -p $O
for N in F1 F2; do
  python3 tools/parity/harness.py --answerer "$BIN" --specialist finance,finance-v2,finance-v2-r2,economics --split both \
    --specialists-dir var/finance/fresh/$N/specialists --out $O/$N >/dev/null 2>$O/$N.err
done
python3 tools/parity/harness.py --answerer "$BIN" --specialist finance,finance-v2,finance-v2-r2,economics,retail --split both --out $O/shipped >/dev/null 2>$O/shipped.err
