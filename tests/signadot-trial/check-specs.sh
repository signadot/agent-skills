#!/usr/bin/env bash
# Specs: no TTL (state stays until teardown), names fit with the suffix, cluster templated where the kind takes one.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); S=$ROOT/skills/signadot-trial; D=$S/assets/specs; fail=0
bad() { echo "FAIL $*"; fail=1; }
grep -rl ttl "$D" && bad "a spec sets a TTL"
for f in "$D"/*/*.yaml; do
  n=$(sed -n 's/^name: //p' "$f"); [ -z "$n" ] && continue
  r=$(echo "$n" | sed 's/@{suffix}/-abcd/'); [ ${#r} -le 30 ] || bad "${f#$S/}: name over 30 characters with a suffix"
  case "$n" in *'@{suffix}'*) ;; *) bad "${f#$S/}: name has no @{suffix}" ;; esac
  if python3 -c 'import yaml' 2>/dev/null; then
    python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$f" || bad "${f#$S/}: not valid YAML"
  fi
done
miss=$(cd "$D" && grep -rL 'cluster: "@{cluster}"' . | sort | tr '\n' ' ')
[ "$miss" = "./data/hotrod-trial-db-plugin.yaml ./testing/hotrod-e2e-plan.yaml ./testing/playwright-job.yaml " ] \
  || bad "cluster not templated in: $miss"
[ -s "$S/assets/patches/route-eta.patch" ] || bad "route-eta.patch missing"
[ $fail = 0 ] && echo "specs OK"; exit $fail
