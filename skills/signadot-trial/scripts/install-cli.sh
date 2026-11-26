#!/usr/bin/env bash
# Install (or reuse) the Signadot CLI for a trial and write the trial's three wrappers, which keep everything the
# tools write inside the trial folder:
#   <trial-dir>/bin/sd  runs signadot with the trial's kubeconfig and its own HOME (its own config and login)
#   <trial-dir>/bin/kc  runs kubectl with the trial's kubeconfig and cache
#   <trial-dir>/bin/hm  runs helm with the trial's kubeconfig, cache and config
# A download is verified against the release's checksums.txt before it is extracted.
# Safe to re-run. Prints one "key: value" line per fact.
set -eu

VERSION=1.9.1
BASE="https://github.com/signadot/cli/releases/download/v$VERSION"
usage() { echo "Usage: install-cli.sh --trial-dir <dir> [--reuse <path to signadot>]"; }

T="" REUSE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --trial-dir) T=$2; shift 2 ;;
    --reuse) REUSE=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
if [ -z "$T" ]; then usage >&2; exit 2; fi
mkdir -p "$T/bin" "$T/logs" "$T/tmp" "$T/home"
# The folder may sit inside a git repository: keep all of it (logins, kubeconfig, builds) out of git.
[ -f "$T/.gitignore" ] || echo '*' > "$T/.gitignore"

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
  tmp=$(mktemp -d "$T/tmp/cli.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
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

# The sd wrapper: never inherit an API key or org from the environment, and give the CLI its own HOME, so its config,
# login and connection state live in the trial folder and ~/.signadot is never read or changed.
{
  echo '#!/bin/sh'
  echo 'unset SIGNADOT_API_KEY SIGNADOT_ORG'
  echo "export KUBECONFIG=\"$T/kubeconfig\""
  echo "export HOME=\"$T/home\""
  echo "exec \"$CLI\" \"\$@\""
} > "$T/bin/sd"
printf '#!/bin/sh\nexec kubectl --kubeconfig "%s/kubeconfig" --cache-dir "%s/kube-cache" "$@"\n' "$T" "$T" > "$T/bin/kc"
printf '#!/bin/sh\nexport HELM_CACHE_HOME="%s/helm/cache" HELM_CONFIG_HOME="%s/helm/config" HELM_DATA_HOME="%s/helm/data"\nexec helm --kubeconfig "%s/kubeconfig" "$@"\n' "$T" "$T" "$T" "$T" > "$T/bin/hm"
chmod 755 "$T/bin/sd" "$T/bin/kc" "$T/bin/hm"

on_path=no
if [ "$(command -v signadot 2>/dev/null || true)" = "$CLI" ]; then on_path=yes; fi
printf 'cli_path: %s\ncli_version: %s\ncli_on_path: %s\nsd: %s\nkc: %s\nhm: %s\n' \
  "$CLI" "$(ver_of "$CLI")" "$on_path" "$T/bin/sd" "$T/bin/kc" "$T/bin/hm"
