#!/bin/sh
# Build a veri7vn family binary on Linux and score it there, against a staged
# copy of the shipped panels, with the same parity harness as on macOS.
#
#   tools/deploy/linux-build.sh <slug> <session> [--specialists id,id,...]
#                               [--host hbox] [--skip-build] [--compare-to <dir>]
#
# <slug> is the family directory under src/extract/ (e.g. quantity), <session>
# its Isabelle session (e.g. Veri7vn_Quantity). Run from anywhere in the
# checkout; the script cd's to the repo root. Steps:
#
#   1. tools/dev/remote-build <host> src/extract/<slug> <session> --expect
#      '<SESSION> PASS' — proves the session builds on Linux and leaves the
#      exported SML on the host (and pulls a copy into var/<slug>/export-remote/).
#   2. on the host: assemble the .mlb (generated SML + regex.sml, or commons.sml for a ported family, + recognizer.sml
#      + main.sml from the tree remote-build rsynced there) and compile with the
#      MLton inside the host's Isabelle2026-RC1, under swarm-build.
#   3. stage the harness and the panels on the host (tools/parity, each
#      specialist folder, workbench/data/core_panel.json; a few hundred KB.
#      upstream itself is never written to, here or there).
#   4. run the harness on the host over every specialist and both splits, and
#      measure a cold start (process start to first reply, 5 runs).
#   5. pull verdicts and per-item replies into var/<slug>/deploy-linux/.
#   6. with --compare-to <dir>: diff every per-item reply against a local (macOS)
#      harness run in <dir>; replies must match byte for byte modulo the timing
#      fields rtt_ms and provenance.specialist_ms. Any divergence fails the run.
#
# Without --specialists the script stops after step 2 (binary built, not scored).
# Binaries land in ~/veri7vn-deploy/bin/<slug> on the host, results in
# ~/veri7vn-deploy/out/<slug>/; panels are read from $PARITY_UPSTREAM on this
# machine (default /Users/ember/dev/o7vn/upstream).
#
# Proved on 2026-10-17 for quantity and acoustics: identical verdict counts and
# 13,786/13,786 identical replies against the macOS binaries. See
# project/lanes/S-linux-binaries.md.
set -eu

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
[ $# -ge 2 ] || usage
slug=$1; session=$2; shift 2
specialists=""; host=hbox; skip_build=0; compare=""
while [ $# -gt 0 ]; do
  case $1 in
    --specialists) specialists=$2; shift 2;;
    --host) host=$2; shift 2;;
    --skip-build) skip_build=1; shift;;
    --compare-to) compare=$2; shift 2;;
    *) echo "linux-build.sh: unknown argument $1" >&2; usage;;
  esac
done

REPO=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$REPO"
SRC=src/extract/$slug
[ -f "$SRC/main.sml" ] || { echo "no family driver at $SRC/main.sml" >&2; exit 1; }
UPSTREAM=${PARITY_UPSTREAM:-/Users/ember/dev/o7vn/upstream}
[ -d "$UPSTREAM/root/specialists" ] || { echo "no upstream at $UPSTREAM (set PARITY_UPSTREAM)" >&2; exit 1; }
marker=$(printf '%s' "$session" | tr '[:lower:]-' '[:upper:]_')' PASS'
rroot="veri7vn-builds/$(basename "$REPO")"              # remote-build's tree name for this checkout
per_spec=0
grep -q -- '--specialist' "$SRC/main.sml" && per_spec=1 # the driver picks the manifest, like the lanes' receipts

# 1. build the session on the host (unless reusing its export)
commons=""                                              # families ported onto src/extract/commons
grep -q 'Veri7vn_Commons' "$SRC/ROOT" && commons="-d src/extract/commons"
if [ "$skip_build" -ne 1 ]; then
  tools/dev/remote-build "$host" "$SRC" "$session" --expect "$marker" $commons
fi

# 2. compile the binary on the host
ssh -o BatchMode=yes "$host" sh -s "$slug" "$session" "$rroot" <<'REMOTE'
set -eu
slug=$1; session=$2; R=$HOME/$3
MLTON=$(ls -d "$HOME"/tools/isabelle-rc1/Isabelle2026-RC1/contrib/mlton-*/x86_64-linux/bin/mlton | head -n 1)
D=$HOME/veri7vn-deploy
mkdir -p "$D/bin" "$D/build/$slug"
GEN=$(find "$R/export/$session" -type f -name "$slug*" | head -n 1)
[ -n "$GEN" ] || { echo "no exported SML under $R/export/$session; run without --skip-build" >&2; exit 1; }
cp "$GEN" "$D/build/$slug/${slug}_generated.sml"
LIB=$R/src/extract/$slug/regex.sml                      # a ported family takes Regex/Json from commons
[ -f "$LIB" ] || LIB=$R/src/extract/commons/commons.sml
cat > "$D/build/$slug/$slug.mlb" <<MLB
\$(SML_LIB)/basis/basis.mlb
${slug}_generated.sml
$LIB
$R/src/extract/$slug/recognizer.sml
$R/src/extract/$slug/main.sml
MLB
cd "$D/build/$slug"
swarm-build "$MLTON" -output "$D/bin/$slug" "$slug.mlb"
ls -l "$D/bin/$slug"
sha256sum "$D/bin/$slug"
REMOTE

[ -n "$specialists" ] || { echo "linux-build.sh: built $host:~/veri7vn-deploy/bin/$slug (no --specialists given: not scored)" >&2; exit 0; }

# 3. stage the harness and the panels (idempotent)
ssh -o BatchMode=yes "$host" "mkdir -p ~/veri7vn-deploy/upstream/root/specialists ~/veri7vn-deploy/upstream/workbench/data"
rsync -a --exclude '__pycache__' --exclude '*.pyc' "$REPO/tools/parity/" "$host:veri7vn-deploy/parity/"
rsync -a "$REPO/tools/deploy/coldstart.py" "$host:veri7vn-deploy/"
oldifs=$IFS
IFS=,
for id in $specialists; do
  [ -d "$UPSTREAM/root/specialists/$id" ] || { echo "no specialist $id in $UPSTREAM" >&2; exit 1; }
  rsync -a --exclude '__pycache__' --exclude '*.pyc' "$UPSTREAM/root/specialists/$id/" "$host:veri7vn-deploy/upstream/root/specialists/$id/"
done
IFS=$oldifs
rsync -a "$UPSTREAM/workbench/data/core_panel.json" "$host:veri7vn-deploy/upstream/workbench/data/"

# 4. score on the host: every specialist, both splits, lane checks on, cold start
out=var/$slug/deploy-linux
mkdir -p "$out"
ssh -o BatchMode=yes "$host" sh -s "$slug" "$per_spec" "$specialists" <<'REMOTE' | tee "$out/harness.log"
set -eu
slug=$1; per_spec=$2; specialists=$3
D=$HOME/veri7vn-deploy
cd "$D"
export PARITY_UPSTREAM=$D/upstream PYTHONDONTWRITEBYTECODE=1
CMD="$D/bin/$slug"
[ "$per_spec" = 1 ] && CMD="$CMD --specialist {id}"
rm -rf "$D/out/$slug"
python3 -B parity/harness.py --answerer "$CMD" --lane-answerer "$CMD" \
  --specialist "$specialists" --split both --out "out/$slug"
python3 -B coldstart.py "$D/bin/$slug" "$D/upstream/root/specialists" "${specialists%%,*}"
REMOTE

# 5. pull the results back and summarise
rsync -a "$host:veri7vn-deploy/out/$slug/" "$out/"
python3 -B - "$out" <<'PY'
import glob, json, os, sys
for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.json"))):
    if os.path.basename(f) == "run.json":
        continue
    v = json.load(open(f, encoding="utf-8"))
    c = v.get("with_specialist") or {}
    print("%-12s %-8s n=%-3d ok=%-3d wrong=%d fy=%d" % (
        v.get("id"), v.get("split"), v.get("n"), c.get("ok", 0), c.get("wrong", 0), c.get("fy", 0)))
PY

# 6. per-item comparison against a local (macOS) harness run, if asked for
if [ -n "$compare" ]; then
  python3 -B - "$out" "$compare" <<'PY'
import glob, json, os, sys

def norm(path):
    out = []
    for line in open(path, encoding="utf-8"):
        r = json.loads(line)
        rep = r.get("reply", {})
        prov = rep.get("provenance")
        if isinstance(prov, dict) and "specialist_ms" in prov:
            prov = dict(prov)
            prov.pop("specialist_ms")
            rep = dict(rep)
            rep["provenance"] = prov
        out.append((r.get("id"), rep))
    return out

total = diffs = 0
for new in sorted(glob.glob(os.path.join(sys.argv[1], "*.items.jsonl"))
                  + glob.glob(os.path.join(sys.argv[1], "*.lane.jsonl"))):
    old = os.path.join(sys.argv[2], os.path.basename(new))
    if not os.path.exists(old):
        print("no counterpart for", os.path.basename(new))
        diffs += 1
        continue
    a, b = norm(new), norm(old)
    if len(a) != len(b):
        print("LENGTH MISMATCH:", os.path.basename(new), len(a), len(b))
        diffs += 1
        continue
    for (aid, arep), (bid, brep) in zip(a, b):
        total += 1
        if (aid, arep) != (bid, brep):
            diffs += 1
            if diffs <= 10:
                print("DIVERGE", os.path.basename(new), aid)
                print("  linux:", json.dumps(arep)[:240])
                print("  other:", json.dumps(brep)[:240])
print("compared %d replies (timing fields removed): %d diverging" % (total, diffs))
sys.exit(1 if diffs else 0)
PY
  echo "linux-build.sh: replies identical to $compare modulo rtt_ms and provenance.specialist_ms"
fi
echo "linux-build.sh: done; binary $host:~/veri7vn-deploy/bin/$slug; results $out"
