#!/usr/bin/env bash
# Runs the signadot-trial checks. `--offline` skips the checks that need the network.
# The scheduled drift check (check-drift.sh) is separate: it fails when a newer CLI or operator is out.
set -u
D=$(cd "$(dirname "$0")" && pwd)
checks="check-static test-token-not-logged test-config-blocks test-stale-pid"
[ "${1:-}" = "--offline" ] || checks="$checks check-external"
n=0 p=0 failed=""
for c in $checks; do
  n=$((n + 1))
  if out=$(bash "$D/$c.sh" 2>&1); then
    p=$((p + 1)); echo "pass  $c"
  else
    failed="$failed $c"; echo "FAIL  $c"; echo "$out" | grep -E '^FAIL' | sed 's/^/        /'
  fi
done
echo "signadot-trial checks: $p/$n passed"
[ -z "$failed" ]
