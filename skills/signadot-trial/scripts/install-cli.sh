#!/usr/bin/env bash
# Install (or reuse) the Signadot CLI for a trial and write the trial's two wrappers:
#   <trial-dir>/bin/sd  runs signadot with the trial's kubeconfig, and its own HOME when isolated
#   <trial-dir>/bin/kc  runs kubectl with the trial's kubeconfig
# A download is verified against the release's checksums.txt before it is extracted.
# Safe to re-run. Prints one "key: value" line per fact.
set -eu

VERSION=1.9.1
BASE="https://github.com/signadot/cli/releases/download/v$VERSION"
usage() { echo "Usage: install-cli.sh --trial-dir <dir> --isolate yes|no [--reuse <path to signadot>]"; }

T="" ISO="" REUSE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --trial-dir) T=$2; shift 2 ;;
    --isolate) ISO=$2; shift 2 ;;
    --reuse) REUSE=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
if [ -z "$T" ] || { [ "$ISO" != yes ] && [ "$ISO" != no ]; }; then usage >&2; exit 2; fi
mkdir -p "$T/bin" "$T/logs"

ver_of() { "$1" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1; }
# at_least A B: true when dotted version A >= B.
at_least() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" = "$2" ]; }

CLI=""
if [ -n "$REUSE" ] && [ -x "$REUSE" ]; then
  v=$(ver_of "$REUSE" || true)
  if [ -n "$v" ] && at_least "$v" "$VERSION"; then CLI=$REUSE; fi
fi
if [ -z "$CLI" ] && [ -x "$T/bin/signadot" ]; then
  v=$(ver_of "$T/bin/signadot" || true)
  if [ -n "$v" ] && at_least "$v" "$VERSION"; then CLI="$T/bin/signadot"; fi
fi
if [ -z "$CLI" ]; then
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; *) arch=unknown ;; esac
  case "$os/$arch" in darwin/amd64|darwin/arm64|linux/amd64|linux/arm64) ;;
    *) echo "error: no Signadot CLI build for $os/$arch" >&2; exit 3 ;; esac
  asset="signadot-cli_mcp_${os}_${arch}.tar.gz"
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  curl -fsSL -o "$tmp/$asset" "$BASE/$asset"
  curl -fsSL -o "$tmp/checksums.txt" "$BASE/checksums.txt"
  grep " $asset\$" "$tmp/checksums.txt" > "$tmp/expected.txt" || { echo "error: $asset not in checksums.txt" >&2; exit 4; }
  if command -v sha256sum >/dev/null 2>&1; then check="sha256sum -c"; else check="shasum -a 256 -c"; fi
  (cd "$tmp" && $check expected.txt >/dev/null) || { echo "error: checksum mismatch for $asset; not installing" >&2; exit 4; }
  member=$(tar -tzf "$tmp/$asset" | grep -E '(^|/)signadot$' | head -1)
  [ -n "$member" ] || { echo "error: no signadot binary in $asset" >&2; exit 4; }
  case "$member" in /*|*..*) echo "error: unsafe path in archive: $member" >&2; exit 4 ;; esac
  tar -xzf "$tmp/$asset" -C "$tmp" "$member"
  cp "$tmp/$member" "$T/bin/signadot"; chmod 755 "$T/bin/signadot"
  CLI="$T/bin/signadot"
fi

# The sd wrapper: never inherit an API key or org from the environment; isolate HOME when asked.
{
  echo '#!/bin/sh'
  echo 'unset SIGNADOT_API_KEY SIGNADOT_ORG'
  echo "export KUBECONFIG=\"$T/kubeconfig\""
  if [ "$ISO" = yes ]; then mkdir -p "$T/home"; echo "export HOME=\"$T/home\""; fi
  echo "exec \"$CLI\" \"\$@\""
} > "$T/bin/sd"
printf '#!/bin/sh\nexec kubectl --kubeconfig "%s/kubeconfig" "$@"\n' "$T" > "$T/bin/kc"
chmod 755 "$T/bin/sd" "$T/bin/kc"

on_path=no
if [ "$(command -v signadot 2>/dev/null || true)" = "$CLI" ]; then on_path=yes; fi
printf 'cli_path: %s\ncli_version: %s\ncli_on_path: %s\nisolated: %s\nsd: %s\nkc: %s\n' \
  "$CLI" "$(ver_of "$CLI")" "$on_path" "$ISO" "$T/bin/sd" "$T/bin/kc"
