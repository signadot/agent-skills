#!/usr/bin/env bash
# install-operator.sh with stubbed CLI, kubectl and helm: the cluster token never reaches a log or the output, helm
# gets the token `cluster add` printed, and no second token is created for a fresh registration.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); S=$ROOT/skills/signadot-trial; fail=0
X=$(mktemp -d); T=$X/t; mkdir -p "$T/bin" "$X/path"
trap 'rm -rf "$X"' EXIT
cat > "$T/bin/sd" <<'STUB'
#!/bin/sh
D=$(dirname "$0")/..
case "$1 $2" in
  "cluster list") if [ -f "$D/registered" ]; then echo '[{"name":"stubc","operator":{"version":"1.4.0"}}]'; else echo '[]'; fi ;;
  "cluster add") touch "$D/registered"   # like CLI 1.9.1: the token goes to stderr (internal/command/cluster/add.go)
    echo 'Ready to connect cluster "stubc". A token has been created for the cluster.' >&2
    echo "kubectl -n signadot create secret generic cluster-agent --from-literal=token='SECRETTOKEN123'" >&2 ;;
  "cluster token") touch "$D/token-created"; echo '{"token": "SECRETTOKEN456"}' ;;
esac
STUB
cat > "$T/bin/kc" <<'STUB'
#!/bin/sh
case "$*" in *"get pods"*) for w in driver frontend location route; do echo "$w-abc123-xyz12||hotrod sd-sidecar"; done ;; esac
exit 0
STUB
# helm stub: `status` says not installed; `upgrade` checks the values file carries the add-time token.
cat > "$X/path/helm" <<STUB
#!/bin/sh
[ "\$1" = status ] && exit 1
while [ \$# -gt 0 ]; do [ "\$1" = -f ] && grep -q 'clusterToken: "SECRETTOKEN123"' "\$2" && touch "$X/helm-got-add-token"; shift; done
exit 0
STUB
chmod +x "$T/bin/sd" "$T/bin/kc" "$X/path/helm"
out=$(PATH="$X/path:$PATH" bash "$S/scripts/install-operator.sh" --trial-dir "$T" --cluster stubc 2>&1)
if grep -rq SECRETTOKEN "$T/logs" 2>/dev/null || echo "$out" | grep -q SECRETTOKEN; then
  echo "FAIL a token was written to a log or printed"; fail=1
fi
echo "$out" | grep -q '^cluster_registered: added' || { echo "FAIL script didn't complete: $out"; fail=1; }
[ -f "$X/helm-got-add-token" ] || { echo "FAIL helm didn't get the token from cluster add"; fail=1; }
[ -f "$T/token-created" ] && { echo "FAIL a second token was created; the one from cluster add stays valid unused"; fail=1; }
[ $fail = 0 ] && echo "token handling OK"; exit $fail
