#!/usr/bin/env bash
# Rules that past reviews and live runs established. Each line names the failure it prevents.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); S=$ROOT/skills/signadot-trial; R=$S/references; fail=0
bad() { echo "FAIL $*"; fail=1; }
has() { grep -qF -- "$2" "$S/$1" || bad "$1: $3"; }
hasnt() { grep -qF -- "$2" "$S/$1" && bad "$1: $3"; }
section() { sed -n "/^## $2/,/^## /p" "$S/$1"; }

# Interaction model and guardrails.
has SKILL.md 'names `signadot-trial<suffix>`' "one rule decides whose local connection is running"
has SKILL.md 'even if the `signadot-validate`' "agents with signadot-validate installed must keep following the trial"
has SKILL.md 'https://www.signadot.com/docs/llms.txt' "failure loop: no docs fallback when the product has changed"
has SKILL.md 'existed before the trial' "guardrail must allow the ~/.signadot config the trial itself creates"
grep -E '^\| Testing \| Playwright suite as a Job' "$S/SKILL.md" | grep -qi 'org setting' && bad "SKILL.md: Jobs need no org setting"
has references/setup/prerequisites.md 'On resume, keep `isolated:` from the trial log' "resume must not re-derive isolation"
for t in lsof unzip; do has references/setup/prerequisites.md "$t" "prerequisites don't mention $t"; done

# Trial log lifecycle: teardown retires it, so a later trial doesn't resume a torn-down one.
has references/trial-log.md 'trial-log.torn-down-' "trial-log.md doesn't say how teardown retires the log"
has references/finish/teardown.md 'trial-log.torn-down-' "teardown leaves trial-log.md in place, so the next trial resumes it"

# Cluster and connection.
has references/setup/cluster.md 'kind export kubeconfig --name signadot-trial' "an existing kind cluster leaves \$T/kubeconfig unwritten"
has references/setup/cluster.md 'kubeConfig: $T/kubeconfig' "connection block relies on the wrapper's KUBECONFIG"
has references/setup/cluster.md 'local_config' "the trial doesn't record the local: block it writes into ~/.signadot"
has references/finish/teardown.md 'local_config' "teardown doesn't remove the local: block it wrote"
has references/finish/teardown.md 'delete namespace signadot' "teardown leaves the operator's namespace on an existing cluster"
ex=$(sed -n '/^### Using an existing local cluster instead/,/^## 2\./p' "$R/setup/cluster.md")
echo "$ex" | grep -q 'get namespace' || bad "cluster.md: no namespace-exists check on an existing cluster"
echo "$ex" | grep -qi 'only for namespaces the trial created' || bad "cluster.md: records namespaces it didn't create"
has references/infra/istio.md 'helm status istiod -n istio-system' "istio.md: no existing-mesh check"
has references/infra/istio-ambient.md 'helm status istiod -n istio-system' "istio-ambient.md: no existing-mesh check"
has references/infra/istio-ambient.md 'get crd gateways.gateway.networking.k8s.io' "istio-ambient.md: reapplies Gateway API CRDs"
has references/infra/linkerd.md 'get namespace linkerd' "linkerd.md: no existing-mesh check"

# Scenarios.
section references/data/sandbox-database.md 'Set up' | grep -q 'resourceplugin get' \
  || bad "sandbox-database.md: re-applying a published plugin is rejected; check it exists first"
has references/testing/plans.md 'Record `plan <plan id>`' "plans.md doesn't record the plan id"
has references/testing/plans.md 'skip `plan create`' "plans.md recreates the plan on resume"
has references/testing/plans.md 'exits non-zero' "plans.md: the broken run fails on purpose; say so"
section references/testing/plans.md 'Tear down' | grep -q '^"$T/bin/sd" plan delete' && bad "plans.md: Signadot refuses to delete an executed plan"

# Hand-off.
has references/finish/playground.md 'local proxy --sandbox' "playground: no plain localhost URL for viewing a sandbox in a browser"
has references/finish/playground.md '--skill signadot-validate' "hand-off doesn't point to signadot-validate"
has references/finish/playground.md 'isolated its config or the CLI' "playground and report disagree on which mcp command to show"
has references/finish/report.md 'isolated its config or the CLI' "playground and report disagree on which mcp command to show"
hasnt references/finish/playground.md 'offer to add it' "offering \$T/bin on PATH would shadow the sd find-and-replace tool"

# Troubleshooting.
has references/troubleshooting.md 'apparmor_restrict_unprivileged_userns' "no entry for plan steps failing on Ubuntu 23.10+"
has references/troubleshooting.md 'quotas-limits' "no entry for org limits"
has references/troubleshooting.md 'is Ready but keyed requests still reach the baseline' "no entry for an ambient sandbox that's Ready but unrouted"
has references/troubleshooting.md 'devmesh analyze' "sidecar entry doesn't use cluster devmesh analyze"

[ $fail = 0 ] && echo "invariants OK"; exit $fail
