#!/usr/bin/env bash
# The skill's scripts: syntax, bash 3.2 (macOS), conventions, shellcheck, preflight's keys, pinned versions.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); D=$ROOT/skills/signadot-trial/scripts; fail=0
bad() { echo "FAIL $*"; fail=1; }
for s in preflight install-cli install-operator ride; do
  f=$D/$s.sh
  [ -x "$f" ] || { bad "$s: missing or not executable"; continue; }
  bash -n "$f" || bad "$s: syntax"
  [ "$(head -1 "$f")" = "#!/usr/bin/env bash" ] || bad "$s: shebang"
  grep -q '^set -eu' "$f" || bad "$s: set -eu"
  out=$(bash "$f" --help 2>&1) || bad "$s: --help exit"
  echo "$out" | grep -q '^Usage:' || bad "$s: no Usage line"
  grep -nE 'declare -A|mapfile|readarray|\$\{[A-Za-z_]+,,\}|\|&' "$f" && bad "$s: bash 4 construct"
  n=$(wc -l < "$f"); [ "$n" -lt 130 ] || bad "$s: $n lines; keep scripts short"
  if command -v shellcheck >/dev/null 2>&1; then shellcheck -S warning "$f" || bad "$s: shellcheck"; fi
done
grep -qE '^VERSION=[0-9]+\.[0-9]+\.[0-9]+$' "$D/install-cli.sh" || bad "install-cli.sh: CLI version not pinned"
grep -qE '^OPERATOR_VERSION=[0-9]+\.[0-9]+\.[0-9]+( |$)' "$D/install-operator.sh" || bad "install-operator.sh: operator chart not pinned"
grep -q -- '--version "\$OPERATOR_VERSION"' "$D/install-operator.sh" || bad "install-operator.sh: helm doesn't use OPERATOR_VERSION"
pf=$(bash "$D/preflight.sh")
for k in os arch docker docker_mem_gb kubectl kind helm git curl go lsof unzip signadot signadot_config \
         signadot_login local_connect kube_context kube_contexts port_8083 apparmor_userns trial_log; do
  echo "$pf" | grep -q "^$k: " || bad "preflight: no key $k"
done
[ $fail = 0 ] && echo "scripts OK"; exit $fail
