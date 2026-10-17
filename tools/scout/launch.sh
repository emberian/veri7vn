#!/bin/sh
# Launch one GLM scout in its own worktree and branch.
#   tools/scout/launch.sh <name> <brief-file> [max-turns]
set -eu
name=$1; brief=$2; turns=${3:-150}
MAIN=/Users/ember/dev/o7vn
WT=$MAIN/var/scout-wt/$name
OUT=$MAIN/var/scouts/$name
mkdir -p "$OUT" "$MAIN/var/scout-wt"
if [ ! -d "$WT" ]; then
  git -C "$MAIN" worktree add -q -b "scout/$name" "$WT" dev
fi
cp "$brief" "$OUT/brief.md"; echo "$brief" > "$OUT/brief.path"
prompt="$(cat "$MAIN/project/scouts/SCOUT_BRIEF.md"; printf '\n\n## Your target (scout %s)\n\n' "$name"; cat "$brief")"
cd "$WT"
CLAUDE_CODE_AUTO_COMPACT_WINDOW=${SCOUT_COMPACT_WINDOW:-120000} CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80 PYTHONDONTWRITEBYTECODE=1 GLM_MODEL=${GLM_MODEL:-glm-5.3} nohup claude-glm -p "$prompt" --dangerously-skip-permissions \
  --mcp-config "$MAIN/project/scouts/nomcp.json" --strict-mcp-config --max-turns "$turns" --output-format text > "$OUT/stdout.md" 2> "$OUT/stderr.log" &
echo $! > "$OUT/scout.pid"
echo "scout $name: pid $(cat "$OUT/scout.pid"), worktree $WT, branch scout/$name"
