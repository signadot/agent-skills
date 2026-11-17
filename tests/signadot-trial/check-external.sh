#!/usr/bin/env bash
# Needs the network; run on pull requests and weekly. Every docs link resolves (markdown copy and web page), and everything the skill pins still
# exists: HotROD and examples commits, sandbox images, CLI release, operator and mesh charts, tool downloads.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); S=$ROOT/skills/signadot-trial; fail=0
bad() { echo "FAIL $*"; fail=1; }
code() { curl -sIL --retry 2 -o /dev/null -w '%{http_code}' --max-time 20 "$1"; }
get() { curl -sL --retry 2 --max-time 30 "$1"; }

for u in $(grep -rhoE 'https://www\.signadot\.com/docs/[A-Za-z0-9/._#-]+' "$S" | sed 's/[.,;:)]*$//; s/#.*//' | sort -u); do
  case "$u" in
    *.txt) [ "$(code "$u")" = 200 ] || bad "docs index $u"; continue ;;
    */docs/) continue ;;
    *.md) md=$u; page=${u%.md} ;;
    *) md=$u.md; page=$u ;;
  esac
  [ "$(code "$md")" = 200 ] || bad "docs page $md"
  [ "$(code "$page")" = 200 ] || bad "docs page $page"
done

hot=$(sed -n 's/.*hotrod\/\/.*ref=\([0-9a-f]\{40\}\).*/\1/p' "$S/references/setup/cluster.md" | head -1)
H=https://raw.githubusercontent.com/signadot/hotrod/$hot
for p in k8s/overlays/prod/devmesh k8s/overlays/prod/istio k8s/overlays/prod/istio-ambient k8s/overlays/prod/linkerd; do
  [ "$(code "$H/$p/kustomization.yaml")" = 200 ] || bad "HotROD $hot: $p"
done
[ "$(code "$H/playwright-tests/basic.spec.ts")" = 200 ] || bad "HotROD $hot: playwright-tests/basic.spec.ts"
gomod=$(get "$H/go.mod" | sed -n 's/^go //p')
grep -q "Go $gomod" "$S/SKILL.md" || bad "HotROD needs Go $gomod; SKILL.md's Go floor differs"
pw=$(get "$H/package.json" | sed -n 's/.*"@playwright\/test": *"[^0-9]*\([0-9.]*\)".*/\1/p')
grep -rq "playwright:v$pw-jammy" "$S/assets/specs/testing" || bad "HotROD uses Playwright $pw; the runner image differs"

ex=$(grep -A3 'signadot/examples.git' "$S/references/setup/cluster.md" | sed -n 's/.*origin \([0-9a-f]\{40\}\).*/\1/p' | head -1)
E=https://raw.githubusercontent.com/signadot/examples/$ex
for p in rabbitmq-signadot-demo/k8s/namespace.yaml temporal-tutorial/k8s/worker-deployment.yaml \
         selective-consumption-with-redis-streams/python/Dockerfile; do
  [ "$(code "$E/$p")" = 200 ] || bad "examples $ex: $p"
done

for img in $(grep -rhoE 'signadot/hotrod:[0-9a-f]{40}-linux-amd64' "$S" | sort -u); do
  [ "$(code "https://hub.docker.com/v2/repositories/signadot/hotrod/tags/${img#*:}")" = 200 ] || bad "image $img"
done

cli=$(sed -n 's/^VERSION=//p' "$S/scripts/install-cli.sh")
[ "$(code "https://github.com/signadot/cli/releases/download/v$cli/checksums.txt")" = 200 ] || bad "CLI $cli release"
op=$(sed -n 's/^OPERATOR_VERSION=\([0-9.]*\).*/\1/p' "$S/scripts/install-operator.sh")
get https://charts.signadot.com/index.yaml | grep -q "operator-$op.tgz" || bad "operator chart $op"
istio=$(sed -n 's/.*istiod --repo .* --version \([0-9.]*\).*/\1/p' "$S/references/infra/istio.md" | head -1)
[ "$(code "https://blob.istio.io/istio-release/charts/istiod-$istio.tgz")" = 200 ] || bad "istiod chart $istio"
# istio.md pulls Istio's images from Docker Hub (registry.istio.io refuses anonymous pulls).
for r in pilot:$istio-distroless proxyv2:$istio-distroless install-cni:$istio-distroless ztunnel:$istio; do
  [ "$(code "https://hub.docker.com/v2/repositories/istio/${r%%:*}/tags/${r#*:}")" = 200 ] || bad "Istio image istio/$r on Docker Hub"
done
lk=$(sed -n 's/.*--version \([0-9.]*\) -n linkerd --create.*/\1/p' "$S/references/infra/linkerd.md" | head -1)
get https://helm.linkerd.io/edge/index.yaml | grep -q "version: $lk" || bad "linkerd edge chart $lk"
for u in $(grep -rhoE 'https://(github\.com/kubernetes-sigs/gateway-api/releases|kind\.sigs\.k8s\.io/dl|get\.helm\.sh)/[^" ]+' "$S/references" | sed 's/\$ARCH/amd64/' | sort -u); do
  [ "$(code "$u")" = 200 ] || bad "download $u"
done
[ $fail = 0 ] && echo "links OK"; exit $fail
