#!/usr/bin/env bash
# local-development and teardown kill a recorded PID only if its command line belongs to the trial folder (PIDs are reused).
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); R=$ROOT/skills/signadot-trial/references; fail=0
SNIP='for f in route-local redis-pf; do p=$(cat "$T/$f.pid" 2>/dev/null) && ps -p "$p" -o args= 2>/dev/null | grep -qF "$T/" && kill "$p"; done'
grep -rn 'kill "$(cat "$T/' "$R" && { echo "FAIL an unguarded kill is present"; fail=1; }
for f in finish/teardown.md core/local-development.md; do
  grep -qF "$SNIP" "$R/$f" || { echo "FAIL guarded stop missing in $f"; fail=1; }
done
T=$(mktemp -d)
sleep 300 >/dev/null 2>&1 & other=$!
echo "$other" > "$T/route-local.pid"
printf 'sleep 300\n' > "$T/trialproc.sh"; /bin/sh "$T/trialproc.sh" >/dev/null 2>&1 & mine=$!
echo "$mine" > "$T/redis-pf.pid"
bash -c "T='$T'; $SNIP"; sleep 1
kill -0 "$other" 2>/dev/null || { echo "FAIL an unrelated process was killed"; fail=1; }
kill -0 "$mine" 2>/dev/null && { echo "FAIL the trial's process survived"; fail=1; }
kill "$other" "$mine" 2>/dev/null; rm -rf "$T"
[ $fail = 0 ] && echo "stale pid OK"; exit $fail
