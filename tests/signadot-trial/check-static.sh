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
for p in $(cd "$S" && grep -rhoE '(references|assets|scripts)/[A-Za-z0-9_./-]+\.(md|sh|yaml|html|css|patch)' SKILL.md references | sort -u); do
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
for f in references/core/local-development.md references/infra/add-mesh.md assets/specs/testing/playwright-job.yaml \
         assets/specs/testing/hotrod-e2e-plan.yaml; do
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
for k in trial_dir os arch docker docker_mem_gb kubectl kind helm git curl go lsof unzip signadot signadot_login \
         local_connect kube_context kube_contexts port_8083 apparmor_userns wsl trial_log; do
  echo "$pf" | grep -q "^$k: " || bad "preflight: no key $k"
done

# 6. Report templates: every slot report.md fills, the stylesheet and copy script next to the pages, and nothing
#    that loads from the network.
R=$S/assets/report
for k in title summary overview fit scenarios urls; do
  grep -q "<!-- FILL:$k" "$R/index.html" || bad "overview template: no FILL:$k slot"
done
for k in verdict stack solves effort questions; do
  grep -q "<!-- FILL:$k" "$R/fit.html" || bad "fit template: no FILL:$k slot"
done
for k in title status headline app change sandbox routing tryit; do
  grep -q "<!-- FILL:$k" "$R/scenario.html" || bad "scenario template: no FILL:$k slot"
done
# Every scenario page has the same four sections, in order.
[ "$(grep -oE '<section id="[a-z]+"' "$R/scenario.html" | tr '\n' ' ')" = '<section id="app" <section id="change" <section id="sandbox" <section id="test" ' ] \
  || bad "scenario template: the sections must be app, change, sandbox, test, in that order"
# Each scenario file feeds those sections and a try-it list with a check of which version handled each flow.
for f in core/isolated-change core/multi-service-preview core/local-development data/sandbox-database async/kafka \
         async/temporal async/rabbitmq async/redis-streams testing/jobs testing/plans; do
  w=$(sed -n '/^## What it shows/,/^## /p' "$S/references/$f.md")
  for b in 'The demo app' 'The change' 'The sandbox' 'Routing'; do
    echo "$w" | grep -q "^- \*\*$b" || bad "$f.md: What it shows has no '$b' part"
  done
  t=$(sed -n '/^## Try it yourself/,/^## /p' "$S/references/$f.md")
  echo "$t" | grep -q '^- \*\*Sandbox:' || bad "$f.md: Try it yourself has no Sandbox step"
  echo "$t" | grep -q '^- \*\*Check:' || bad "$f.md: Try it yourself has no Check step"
done
for f in "$R/index.html" "$R/scenario.html" "$R/fit.html"; do
  grep -q '<link rel="stylesheet" href="report.css">' "$f" || bad "${f#"$S"/}: must use report.css next to it"
  grep -q '<script src="report.js" defer></script>' "$f" || bad "${f#"$S"/}: must load report.js (the Copy buttons)"
  grep -iE '<script' "$f" | grep -vq '<script src="report.js" defer></script>' && bad "${f#"$S"/}: runs a script other than report.js"
  grep -qiE '(src|href)="https?://[^"]*\.(js|css)|src="https?://' "$f" && bad "${f#"$S"/} loads something from the network"
done
grep -qE 'fetch\(|XMLHttpRequest|https?://' "$R/report.js" && bad "report.js must not reach the network"
grep -nE 'curl -s ' "$R/scenario.html" && bad "scenario template: use curl -sS, not -s, so the user sees errors instead of a blank line"
# DevMesh decides at the destination: the template draws the sidecar inside the normal route's pod.
grep -q 'class="pod"' "$R/scenario.html" || bad "scenario template: draw the sidecar inside the normal route's pod (DevMesh routes at the destination)"
grep -q '\.pod' "$R/report.css" || bad "report.css: no style for the diagram's pod outline"
has references/finish/report.md 'destination side' "the diagram rules must place DevMesh's decision at the destination pod"
has references/finish/report.md 'source side' "the diagram rules must place Istio's decision at the caller's sidecar"

# 7. Snippets: no ${x:+…}, which zsh and bash expand differently.
grep -rnE '\$\{[A-Za-z_]+:\+' "$S/SKILL.md" "$S/references" && bad "a snippet uses \${x:+…}"

# 8. Safety commands an edit must not drop.
has references/finish/teardown.md 'trial-log.torn-down-' "teardown must retire the log, or the next trial resumes this one"
has references/finish/teardown.md 'delete namespace signadot' "teardown must remove the operator's namespace on an existing cluster"
has references/setup/account.md 'Always give the user the link and the code in chat' "the CLI login must show the user its sign-in link and code"
has references/setup/account.md 'end your turn' "the CLI login must wait for the user's reply, not poll before they've seen the link"
has references/finish/report.md "won't open in the user's browser yet" "a page whose main link is a cluster address must get the sudo connection asked for, and checked, in chat"
has references/setup/cluster.md 'kind export kubeconfig' "reusing a kind cluster must export its kubeconfig"
has references/setup/cluster.md 'get namespace <ns>' "an existing cluster's namespaces must be checked before use"
has references/infra/istio.md 'hm" status istiod -n istio-system' "an existing Istio must be detected, not reinstalled"
has references/infra/istio-ambient.md 'references/infra/istio.md' "Istio ambient must use Istio's install, which detects an existing Istio"
has references/infra/istio.md 'profile=ambient' "Istio must be installed with the ambient profile, so both Istio modes can run side by side"
has references/infra/istio.md 'global.hub=$H' "Istio's images must come from Docker Hub; registry.istio.io refuses anonymous pulls"
has scripts/install-operator.sh '--reuse-values' "upgrading the installed operator must keep its cluster token"
has references/infra/add-mesh.md 'docker stats' "adding a mesh must check Docker's memory first"
has references/infra/linkerd.md 'get namespace linkerd' "an existing Linkerd must be detected, not reinstalled"
has references/setup/customize.md "Never read the user's repos" "customizing must ask, never read the user's code, other projects or the agent's memory"
has references/finish/fit.md 'assets/fit/compatibility.md' "the fit page must take every status from the compatibility matrix"
has references/finish/fit.md 'Only when the user answered the stack questions' "only a user who answered the stack questions gets the fit page"
has references/finish/playground.md 'signadot-validate' "the closing message must give the next step on the user's own service"
has references/core/multi-service-preview.md 'Three rides, one app' "the two-service scenario must compare both scenarios' sandboxes on one app"
has references/core/local-development.md '(60-50) + 50' "the third scenario must change route's code and prove it"
has references/setup/account.md '--register-only' "the cluster must be registered right after login, so a cluster limit is caught early"
has references/finish/teardown.md 'app.signadot.com/cluster/signadot-trial<suffix>' "teardown must tell the user to delete the cluster registration, with its link"
has references/finish/fit.md 'about 80% or more' "a minority gap must still get a Yes verdict, with the gap named"
has SKILL.md 'never as a markdown numbered list' "non-consecutive menu numbers must be bullets, or chat apps renumber them"
has references/setup/account.md 'The connection completes only after you' "the login message must say the user signs in after confirming the code"
has SKILL.md 'step by step' "the plan must ask for the pace: step by step or all at once"
has references/finish/questions.md 'docs/llms.txt' "answers must come from the current docs, not the agent's training"
has references/finish/questions.md 'Cite every claim' "answers must cite their sources"
has references/async/rabbitmq.md 'orders_exchange' "the RabbitMQ demo's exchange is orders_exchange (orders is RabbitMQ's own routing key)"
grep -nE '`orders` exchange|exchange, `orders`' "$S/references/async/rabbitmq.md" "$S/references/finish/report.md" \
  && bad "RabbitMQ: the exchange is orders_exchange, not orders"
sed -n '/^## Set up/,/^## /p' "$S/references/data/sandbox-database.md" | grep -q 'resourceplugin get' \
  || bad "sandbox-database.md: re-applying the plugin fails; Set up must check it exists first"
sed -n '/^## Tear down/,/^## /p' "$S/references/testing/plans.md" | grep -q '^"$T/bin/sd" plan delete' \
  && bad "plans.md: Signadot refuses to delete an executed plan; teardown must only remove the tag"

# 9. Confinement: the trial folder is .signadot-trial in the agent's working folder, and the wrappers keep the CLI's
#    config and login and kubectl's and helm's caches inside it, so the agent never needs access outside it.
X=$(mktemp -d); trap 'rm -rf "$X"' EXIT; mkdir -p "$X/work" "$X/home" "$X/stub"
td=$(cd "$X/work" && env -u SIGNADOT_TRIAL_HOME bash "$S/scripts/preflight.sh" | sed -n 's/^trial_dir: //p')
[ "$td" = "$X/work/.signadot-trial" ] || bad "preflight: trial_dir must be .signadot-trial in the working folder, got $td"
printf '#!/bin/sh\necho "signadot 9.9.9"\n' > "$X/stub/signadot"; chmod +x "$X/stub/signadot"
HOME="$X/home" bash "$S/scripts/install-cli.sh" --trial-dir "$td" --reuse "$X/stub/signadot" >/dev/null \
  || bad "install-cli.sh failed with a reused CLI"
grep -qx "export HOME=\"$td/home\"" "$td/bin/sd" 2>/dev/null || bad "the sd wrapper must give the CLI the trial's own HOME"
grep -qF -- "--cache-dir \"$td/kube-cache\"" "$td/bin/kc" 2>/dev/null || bad "kc must keep kubectl's cache in the trial folder"
grep -qF "HELM_CACHE_HOME=\"$td/helm/cache\"" "$td/bin/hm" 2>/dev/null || bad "hm must keep helm's cache in the trial folder"
[ "$(cat "$td/.gitignore" 2>/dev/null)" = '*' ] || bad "the trial folder must keep itself out of git"
[ -z "$(ls -A "$X/home")" ] || bad "install-cli.sh wrote to HOME"
grep -rnE '\$HOME/\.signadot|~/\.signadot-trial' "$S/scripts" && bad "a script reads or writes a Signadot folder in HOME"
grep -rnE '^[[:space:]]*helm ' "$S/references" && bad "a helm command bypasses \$T/bin/hm, so its cache lands in HOME"
grep -q HELM_CACHE_HOME "$S/scripts/install-operator.sh" || bad "install-operator.sh must keep helm's cache in the trial folder"
grep -q 'GOPATH="$T/go" GOCACHE=' "$S/references/core/local-development.md" \
  || bad "local-development.md: the Go build must keep its caches in the trial folder"

[ $fail = 0 ] && echo "static OK"; exit $fail
