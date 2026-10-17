#!/bin/sh
# Keep at most SCOUT_MAX scouts alive (default 8), launching from var/scouts/queue.txt
# (lines: "<name> <brief-path> [max-turns]"), one every SCOUT_STAGGER seconds (default 60).
# A scout that exits with a Z.AI rate-limit error (429) is requeued up to 3 times; its
# worktree, branch and SCOUT_REPORT.md carry its progress across lives.
#   nohup tools/scout/queue.sh > var/scouts/queue.log 2>&1 & echo $! > var/scouts/queue.pid
set -u
MAIN=/Users/ember/dev/o7vn; Q=$MAIN/var/scouts/queue.txt; MAX=${SCOUT_MAX:-8}; STAGGER=${SCOUT_STAGGER:-60}
cd "$MAIN"; touch "$Q"
while :; do
  alive=0
  for d in var/scouts/*/; do
    n=$(basename "$d"); p=$(cat "$d/scout.pid" 2>/dev/null) || continue
    if kill -0 "$p" 2>/dev/null; then alive=$((alive+1)); continue; fi
    # exited: requeue on rate limit, once per exit
    if [ -f "$d/stdout.md" ] && grep -q "Rate limit\|(429)\|Prompt is too long" "$d/stdout.md" 2>/dev/null; then
      tries=$(cat "$d/requeues" 2>/dev/null || echo 0)
      if [ "$tries" -lt 3 ] && ! grep -q "^$n " "$Q"; then
        echo $((tries+1)) > "$d/requeues"; mv "$d/stdout.md" "$d/stdout.died-$tries.md"
        echo "$n $(cat "$d/brief.path" 2>/dev/null || echo project/scouts/briefs/$n.md) 200" >> "$Q"
        echo "$(date +%H:%M:%S) requeued $n (died, try $((tries+1)))"
      fi
    fi
  done
  if [ "$alive" -lt "$MAX" ] && [ -s "$Q" ]; then
    line=$(head -1 "$Q"); sed -i '' '1d' "$Q"
    set -- $line; name=$1; brief=$2; turns=${3:-200}
    echo "$brief" > "var/scouts/$name/brief.path" 2>/dev/null || { mkdir -p "var/scouts/$name"; echo "$brief" > "var/scouts/$name/brief.path"; }
    echo "$(date +%H:%M:%S) launching $name (alive $alive/$MAX)"; tools/scout/launch.sh "$name" "$brief" "$turns"
    sleep "$STAGGER"
  else
    sleep 30
  fi
done
