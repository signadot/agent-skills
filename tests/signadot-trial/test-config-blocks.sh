#!/usr/bin/env bash
# Runs the connection-config snippet from cluster.md §4 and the removal snippet from teardown.md against a sample
# config: the trial's local: block replaces any old one, names the trial's kubeconfig, keeps every other key, and
# teardown removes it only when it's the trial's.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); S=$ROOT/skills/signadot-trial; fail=0
bad() { echo "FAIL $*"; fail=1; }
X=$(mktemp -d); trap 'rm -rf "$X"' EXIT
T=$X/trial; mkdir -p "$T"
# Bash blocks may be indented inside a list item.
# Strip exactly the fence's indentation, so heredoc YAML keeps its own.
block() { awk -v want="$2" '/^ *```bash$/ {b=""; f=1; ind=index($0, "`") - 1; next} /^ *```$/ {if (f && index(b, want)) print b; f=0; next}
  f {if (ind > 0 && substr($0, 1, ind) ~ /^ *$/) $0 = substr($0, ind + 1); b = b $0 "\n"}' "$1"; }

write=$(block "$S/references/setup/cluster.md" 'local:' | grep -v '"$T/bin/sd"' | sed "s|^CFG=.*|CFG=\"$X/config.yaml\"|; s|<suffix>|-abcd|g")
[ -n "$write" ] || bad "cluster.md: no bash block that writes the local: block"
printf 'org: acme\nlocal:\n  connections:\n  - cluster: old\n    type: ControlPlaneProxy\napi_url: https://example\n' > "$X/config.yaml"
( T=$T; eval "$write" ) || bad "cluster.md: the config snippet failed"
c=$(cat "$X/config.yaml")
echo "$c" | grep -q '^org: acme$' && echo "$c" | grep -q '^api_url: https://example$' || bad "other config keys were lost"
echo "$c" | grep -q 'cluster: old' && bad "the old local: block was kept"
[ "$(echo "$c" | grep -c '^local:')" = 1 ] || bad "not exactly one local: block"
echo "$c" | grep -q "^    kubeConfig: $T/kubeconfig$" || bad "the block doesn't name the trial's kubeconfig"
echo "$c" | grep -q '^    kubeContext: kind-signadot-trial$' || bad "the block doesn't name the trial's kube context"
echo "$c" | grep -q '^  - cluster: signadot-trial-abcd$' || bad "the block doesn't name the trial's cluster"

remove=$(block "$S/references/finish/teardown.md" 'local_config' | sed "s|^ *CFG=.*|CFG=\"$X/config.yaml\"|; s|<suffix>|-abcd|g")
[ -n "$remove" ] || bad "teardown.md: no bash block that removes the trial's local: block"
cp "$X/config.yaml" "$X/before.yaml"
( T=$T; eval "$remove" ) || true
c=$(cat "$X/config.yaml")
echo "$c" | grep -q '^local:' && bad "teardown left the trial's local: block"
echo "$c" | grep -q '^org: acme$' || bad "teardown removed other keys"
printf 'org: acme\nlocal:\n  connections:\n  - cluster: theirs\n' > "$X/config.yaml"
( T=$T; eval "$remove" ) || true
grep -q 'cluster: theirs' "$X/config.yaml" || bad "teardown removed a local: block that isn't the trial's"
[ $fail = 0 ] && echo "config blocks OK"; exit $fail
