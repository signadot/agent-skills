#!/usr/bin/env bash
# Offline checks. Each one guards something that breaks the trial when an edit gets it wrong. None check wording,
# so rewriting prose never fails a check.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); S=$ROOT/skills/signadot-trial; fail=0
bad() { echo "FAIL $*"; fail=1; }
has() { grep -qF -- "$2" "$S/$1" || bad "$1: $3"; }

# 1. Frontmatter that skill installers read.
fm=$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$S/SKILL.md")
echo "$fm" | grep -q '^name: signadot-trial$' || bad "frontmatter: name must match the folder"
desc=$(echo "$fm" | awk '/^description:/ {f=1; next} f && /^[a-z]+:/ {f=0} f' | tr -s ' \n' ' ')
[ ${#desc} -gt 0 ] && [ ${#desc} -le 1024 ] || bad "frontmatter: description is empty or over 1024 characters"

# 2. Every reference file is linked from SKILL.md, every path the files mention exists, and the skill folder holds
#    only what agents need (everything in it is installed for every user).
for f in $(cd "$S" && find references -name '*.md' | sort); do grep -q "($f)" "$S/SKILL.md" || bad "SKILL.md doesn't link $f"; done
for p in $(cd "$S" && grep -rhoE '(references|assets|scripts)/[A-Za-z0-9_./-]+\.(md|sh|yaml|html|patch)' SKILL.md references | sort -u); do
  [ -e "$S/$p" ] || bad "a file mentions $p, which doesn't exist"
done
extra=""
for f in "$S"/* "$S"/.[!.]*; do
  [ -e "$f" ] || continue
  case "${f##*/}" in SKILL.md|references|scripts|assets) ;; *) extra="$extra ${f##*/}" ;; esac
done
[ -z "$extra" ] || bad "skill folder has files users don't need (they belong in tests/signadot-trial): $extra"

# 3. Pins agree across files.
cli=$(sed -n 's/^VERSION=\([0-9.]*\).*/\1/p' "$S/scripts/install-cli.sh")
[ -n "$cli" ] || bad "install-cli.sh: no pinned VERSION"
for v in $(grep -rhoE 'CLI (≥ )?[0-9]+\.[0-9]+\.[0-9]+' "$S/SKILL.md" "$S/references" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u); do
  [ "$v" = "$cli" ] || bad "a file names CLI $v; install-cli.sh installs $cli"
done
grep -q -- '--version "$OPERATOR_VERSION"' "$S/scripts/install-operator.sh" || bad "install-operator.sh: chart version not pinned"
hot=$(sed -n 's/.*hotrod\/\/.*ref=\([0-9a-f]\{40\}\).*/\1/p' "$S/references/setup/cluster.md" | head -1)
[ -n "$hot" ] || bad "cluster.md: no pinned HotROD commit"
for f in references/core/local-development.md assets/specs/testing/playwright-job.yaml assets/specs/testing/hotrod-e2e-plan.yaml; do
  grep -q "$hot" "$S/$f" || bad "$f doesn't use HotROD commit $hot from cluster.md"
done
grep -rqE -- '-b main|default: main' "$S/assets" "$S/references" && bad "a HotROD fetch follows main, not the pinned commit"

# 4. Specs: valid YAML, no TTL (everything stays until teardown), names fit with a 5-character suffix.
if python3 -c 'import yaml' 2>/dev/null; then yaml_ok() { python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$1" 2>/dev/null; }
elif command -v ruby >/dev/null 2>&1; then yaml_ok() { ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$1" 2>/dev/null; }
else yaml_ok() { true; }; echo "note: no YAML parser (PyYAML or ruby); skipped YAML validation"; fi
for f in "$S"/assets/specs/*/*.yaml; do
  grep -q ttl "$f" && bad "${f#"$S"/} sets a TTL"
  n=$(sed -n 's/^name: //p' "$f" | sed 's/@{suffix}/-abcd/'); [ ${#n} -le 30 ] || bad "${f#"$S"/}: name too long with a suffix"
  yaml_ok "$f" || bad "${f#"$S"/}: invalid YAML"
done

# 5. Scripts: syntax, nothing macOS's bash 3.2 lacks, shellcheck when installed, and preflight still prints the keys
#    the files rely on.
for f in "$S"/scripts/*.sh; do
  bash -n "$f" || bad "${f#"$S"/}: syntax"
  grep -nE 'declare -A|mapfile|readarray|\$\{[A-Za-z_]+,,\}|\|&' "$f" && bad "${f#"$S"/}: needs bash 4"
  if command -v shellcheck >/dev/null 2>&1; then shellcheck -S warning "$f" || bad "${f#"$S"/}: shellcheck"; fi
done
pf=$(bash "$S/scripts/preflight.sh")
for k in os arch docker docker_mem_gb kubectl kind helm git curl go lsof unzip signadot signadot_config signadot_login \
         local_connect kube_context kube_contexts port_8083 apparmor_userns trial_log; do
  echo "$pf" | grep -q "^$k: " || bad "preflight: no key $k"
done

# 6. Report template: every slot report.md fills, and nothing that runs or loads from the network.
for k in title summary cards timeline running next-steps teardown run-details; do
  grep -q "<!-- FILL:$k" "$S/assets/report-template.html" || bad "report template: no FILL:$k slot"
done
grep -qiE '<script|src="https?://' "$S/assets/report-template.html" && bad "report template runs or loads something"

# 7. Snippets: no ${x:+…}, which zsh and bash expand differently.
grep -rnE '\$\{[A-Za-z_]+:\+' "$S/SKILL.md" "$S/references" && bad "a snippet uses \${x:+…}"

# 8. Safety commands an edit must not drop.
has references/finish/teardown.md 'trial-log.torn-down-' "teardown must retire the log, or the next trial resumes this one"
has references/finish/teardown.md 'delete namespace signadot' "teardown must remove the operator's namespace on an existing cluster"
has references/setup/cluster.md 'kind export kubeconfig' "reusing a kind cluster must export its kubeconfig"
has references/setup/cluster.md 'get namespace <ns>' "an existing cluster's namespaces must be checked before use"
has references/infra/istio.md 'helm status istiod -n istio-system' "an existing Istio must be detected, not reinstalled"
has references/infra/istio-ambient.md 'helm status istiod -n istio-system' "an existing Istio must be detected, not reinstalled"
has references/infra/linkerd.md 'get namespace linkerd' "an existing Linkerd must be detected, not reinstalled"
sed -n '/^## Set up/,/^## /p' "$S/references/data/sandbox-database.md" | grep -q 'resourceplugin get' \
  || bad "sandbox-database.md: re-applying the plugin fails; Set up must check it exists first"
sed -n '/^## Tear down/,/^## /p' "$S/references/testing/plans.md" | grep -q '^"$T/bin/sd" plan delete' \
  && bad "plans.md: Signadot refuses to delete an executed plan; teardown must only remove the tag"

[ $fail = 0 ] && echo "static OK"; exit $fail
