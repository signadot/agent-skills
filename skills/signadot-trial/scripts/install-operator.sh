#!/usr/bin/env bash
# Register the trial cluster with Signadot, install the Signadot Operator, and restart the demo workloads
# so they get their routing proxy. The cluster token goes from the CLI to helm through a private temp file
# (mode 600, deleted on exit); it is never printed or passed on a command line. Safe to re-run.
set -eu

usage() {
  echo "Usage: install-operator.sh --trial-dir <dir> --cluster <name> [--values <file>] [--namespace hotrod]"
  echo "       [--workloads driver,frontend,location,route] [--proxy sd-sidecar|istio-proxy|linkerd-proxy|none]"
}
T="" CLUSTER="" VALUES="" NS=hotrod WORKLOADS=driver,frontend,location,route PROXY=sd-sidecar
while [ $# -gt 0 ]; do
  case "$1" in
    --trial-dir) T=$2; shift 2 ;;
    --cluster) CLUSTER=$2; shift 2 ;;
    --values) VALUES=$2; shift 2 ;;
    --namespace) NS=$2; shift 2 ;;
    --workloads) WORKLOADS=$2; shift 2 ;;
    --proxy) PROXY=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
if [ -z "$T" ] || [ -z "$CLUSTER" ]; then usage >&2; exit 2; fi
SD="$T/bin/sd" KC="$T/bin/kc" KCFG="$T/kubeconfig"
mkdir -p "$T/logs"

# 1. Register the cluster (once).
if "$SD" cluster list -o json | tr -d ' \n' | grep -q "\"name\":\"$CLUSTER\""; then
  registered=existing
else
  "$SD" cluster add --name "$CLUSTER" >"$T/logs/cluster-add.log" 2>&1; registered=added
fi

# 2. Install the operator (once).
if helm status signadot-operator -n signadot --kubeconfig "$KCFG" >/dev/null 2>&1; then
  operator=already-installed
else
  umask 077; tok=$(mktemp); trap 'rm -f "$tok"' EXIT
  printf 'controlPlane:\n  clusterToken: "%s"\n' \
    "$("$SD" cluster token create --cluster "$CLUSTER" -o json | sed -n 's/.*"token": *"\([^"]*\)".*/\1/p')" > "$tok"
  if ! grep -q 'clusterToken: ".' "$tok"; then echo "error: could not create a cluster token" >&2; exit 5; fi
  set -- -f "$tok"; if [ -n "$VALUES" ]; then set -- "$@" -f "$VALUES"; fi
  helm upgrade --install signadot-operator operator --repo https://charts.signadot.com \
    -n signadot --create-namespace --kubeconfig "$KCFG" "$@" >"$T/logs/operator-install.log" 2>&1 \
    || { echo "error: helm install failed; see $T/logs/operator-install.log" >&2; exit 6; }
  rm -f "$tok"; operator=installed
fi
"$KC" -n signadot wait --for=condition=available deploy --all --timeout=300s >/dev/null

# 3. Wait until the control plane sees the operator.
version="" deadline=$(( $(date +%s) + 180 ))
while [ -z "$version" ] && [ "$(date +%s)" -lt "$deadline" ]; do
  version=$("$SD" cluster list -o json | tr -d ' \n' | awk '{gsub(/\},\{"/, "}\n{\""); print}' | grep "\"name\":\"$CLUSTER\"" \
    | grep -oE '"operator":\{[^}]*"version":"[^"]*"' | grep -oE '[^"]+"$' | tr -d '"' | head -1 || true)
  [ -n "$version" ] || sleep 5
done
[ -n "$version" ] || { echo "error: $CLUSTER reported no operator version within 180 s" >&2; exit 7; }

# 4. Count the workloads whose pods have the proxy. Restart them (so new pods get it) only when the operator was
#    just installed or a proxy is missing, so a re-run on a healthy cluster restarts nothing.
count() {
  ok=0 total=0
  for w in $(echo "$WORKLOADS" | tr , ' '); do
    total=$((total + 1))
    if [ "$PROXY" = none ]; then ok=$((ok + 1)); continue; fi
    has=$("$KC" -n "$NS" get pods -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"|"}{.spec.initContainers[*].name}{" "}{.spec.containers[*].name}{"\n"}{end}' \
      | awk -F'|' -v w="$w" -v p="$PROXY" '$1 ~ "^" w "-[a-z0-9]+-[a-z0-9]+$" && $2 == "" { n++; k = split($3, c, " "); for (i = 1; i <= k; i++) if (c[i] == p) { h++; break } }
        END { print (n > 0 && h == n) ? "yes" : "no" }')
    if [ "$has" = yes ]; then ok=$((ok + 1)); fi
  done
}
count
if [ "$operator" = installed ] || [ "$ok" -lt "$total" ]; then
  for w in $(echo "$WORKLOADS" | tr , ' '); do "$KC" -n "$NS" rollout restart "deploy/$w" >/dev/null; done
  for w in $(echo "$WORKLOADS" | tr , ' '); do "$KC" -n "$NS" rollout status "deploy/$w" --timeout=300s >/dev/null; done
  count
fi

printf 'cluster_registered: %s\noperator: %s\noperator_version: %s\nsidecars: %s/%s\n' \
  "$registered" "$operator" "$version" "$ok" "$total"
