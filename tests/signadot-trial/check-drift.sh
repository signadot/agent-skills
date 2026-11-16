#!/usr/bin/env bash
# Needs the network. Fails when Signadot has shipped something newer than the skill pins, so a scheduled CI run
# tells maintainers to bump the pin and run the live acceptance checklist in MAINTAINING.md.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); S=$ROOT/skills/signadot-trial; fail=0
newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)" = "$2" ]; }

cli=$(sed -n 's/^VERSION=//p' "$S/scripts/install-cli.sh")
latest=$(curl -sL https://api.github.com/repos/signadot/cli/releases/latest | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')
if [ -z "$latest" ]; then echo "WARN couldn't read the latest CLI release"
elif newer "$cli" "$latest"; then echo "FAIL CLI $latest is out; the skill pins $cli"; fail=1
else echo "ok   CLI $cli is the latest"; fi

op=$(sed -n 's/^OPERATOR_VERSION=\([0-9.]*\).*/\1/p' "$S/scripts/install-operator.sh")
chart=$(curl -sL https://charts.signadot.com/index.yaml | grep -oE 'operator-[0-9]+\.[0-9]+\.[0-9]+\.tgz' \
  | sed 's/operator-//; s/\.tgz//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
if [ -z "$chart" ]; then echo "WARN couldn't read the operator chart index"
elif newer "$op" "$chart"; then echo "FAIL operator chart $chart is out; the skill pins $op"; fail=1
else echo "ok   operator $op is the latest"; fi

hot=$(sed -n 's/.*hotrod\/\/.*ref=\([0-9a-f]\{40\}\).*/\1/p' "$S/references/setup/cluster.md" | head -1)
main=$(curl -sL https://api.github.com/repos/signadot/hotrod/commits/main | sed -n 's/^  "sha": *"\([^"]*\)".*/\1/p' | head -1)
if [ -n "$main" ] && [ "$main" != "$hot" ]; then echo "info HotROD main is at ${main:0:12}; the skill pins ${hot:0:12}"; fi

echo "Release notes: https://www.signadot.com/docs/release-notes.md"
exit $fail
