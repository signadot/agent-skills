#!/usr/bin/env bash
# C3's snippets work in a fresh shell with only T and S set: the Redis port is kept in a file, and the start block
# reads it from there. With RUN_BUILD=1 (needs git and Go), it also fetches HotROD and runs the Go build from /.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); S=$ROOT/skills/signadot-trial; F=$S/references/core/local-development.md; fail=0
bad() { echo "FAIL $*"; fail=1; }
blocks=$(awk '/^```bash$/ {f=1; n++; next} /^```$/ {f=0; next} f {print n "\t" $0}' "$F")
grep -q 'redis-pf.port' "$F" || bad "the port isn't written to \$T/redis-pf.port"
n=$(echo "$blocks" | grep -F 'nohup "$T/bin/hotrod" route' | head -1 | cut -f1)
echo "$blocks" | awk -F'\t' -v n="$n" '$1==n {print $2}' | grep -q 'cat "$T/redis-pf.port"' \
  || bad "the start block relies on \$PORT from another block"
for i in $(echo "$blocks" | cut -f1 | sort -un); do
  b=$(echo "$blocks" | awk -F'\t' -v n="$i" '$1==n {print $2}')
  echo "$b" | grep -qE '^(go|docker) ' && bad "block $i builds without cd \"\$T/hotrod\" first"
done
if [ "${RUN_BUILD:-}" = 1 ]; then
  X=$(mktemp -d); T=$X/t; mkdir -p "$T/bin"
  fetch=$(echo "$blocks" | awk -F'\t' '$1==1 {print $2}'); build=$(echo "$blocks" | awk -F'\t' '$1==2 {print $2}')
  ( cd / && T=$T S=$S bash -c "$fetch" && cd / && T=$T S=$S bash -c "$build" ) >/dev/null 2>&1 && [ -x "$T/bin/hotrod" ] \
    || bad "fetch and Go build don't work from a fresh shell"
  rm -rf "$X"
fi
[ $fail = 0 ] && echo "c3 blocks OK"; exit $fail
