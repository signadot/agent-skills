#!/usr/bin/env bash
# Read-only checks before a Signadot trial. Changes nothing; always exits 0.
# Prints one "key: value" line per fact; the agent decides what to do with them.
set -eu

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: preflight.sh"
  echo "Prints trial_dir, os, arch, docker, docker_mem_gb, tool versions (kubectl kind helm git curl go), lsof, unzip,"
  echo "signadot, signadot_login, local_connect, kube_context, kube_contexts, port_8083, apparmor_userns, wsl, trial_log."
  exit 0
fi

# The trial folder: .signadot-trial inside the folder the agent was started in, unless SIGNADOT_TRIAL_HOME says otherwise.
T="${SIGNADOT_TRIAL_HOME:-$PWD/.signadot-trial}"
case "$T" in /*) ;; *) T="$PWD/$T" ;; esac
kv() { printf '%s: %s\n' "$1" "$2"; }

kv trial_dir "$T"
first_line() { head -1 | tr -d '\r'; }

kv os "$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in x86_64|amd64) kv arch amd64 ;; arm64|aarch64) kv arch arm64 ;; *) kv arch "$(uname -m)" ;; esac

# WSL: Linux inside Windows. Browsers run on the Windows side, so cluster names never resolve in them, and pages open
# with explorer.exe rather than xdg-open.
wsl=no; case "$(cat /proc/version 2>/dev/null)" in *[Mm]icrosoft*|*WSL*) wsl=yes ;; esac

# Docker: installed, running, and how much memory it can give the cluster. On WSL, Docker Desktop leaves a shim that
# says to turn on WSL integration; report that instead of "stopped".
if ! command -v docker >/dev/null 2>&1; then
  kv docker missing; kv docker_mem_gb unknown
elif mem=$(docker info --format '{{.MemTotal}}' 2>/dev/null) && [ -n "$mem" ]; then
  kv docker running; kv docker_mem_gb "$(awk -v b="$mem" 'BEGIN { printf "%.1f", b / 1073741824 }')"
elif [ "$wsl" = yes ] && docker info 2>&1 | grep -qi 'WSL integration'; then
  kv docker wsl-integration-off; kv docker_mem_gb unknown
else
  kv docker stopped; kv docker_mem_gb unknown
fi

# Tools: version or "missing".
ver() {
  if ! command -v "$1" >/dev/null 2>&1; then echo missing; return; fi
  case "$1" in
    kubectl) kubectl version --client 2>/dev/null | first_line | sed 's/^Client Version: //' ;;
    kind)    kind version 2>/dev/null | awk '{print $2}' ;;
    helm)    helm version --short 2>/dev/null | first_line ;;
    git)     git --version | awk '{print $3}' ;;
    curl)    curl --version | first_line | awk '{print $2}' ;;
    go)      go version 2>/dev/null | awk '{print $3}' | sed 's/^go//' ;;
  esac
}
for t in kubectl kind helm git curl go; do kv "$t" "$(ver "$t")"; done
for t in lsof unzip; do if command -v "$t" >/dev/null 2>&1; then kv "$t" present; else kv "$t" missing; fi; done

# Signadot CLI on PATH and the org it's logged in to (never read credentials). The trial never changes either.
if sd=$(command -v signadot 2>/dev/null); then
  kv signadot "$sd $("$sd" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
else
  kv signadot missing
fi
login=unknown
if [ -n "${sd:-}" ]; then
  status=$("$sd" auth status 2>&1 || true)
  org=$(echo "$status" | sed -n "s/^Organization: *//p" | head -1)
  case "$status" in
    *Organization:*) login=${org:-unknown} ;;
    *[Nn]ot\ authenticated*|*[Nn]ot\ logged*|*[Uu]nauthenticated*) login=none ;;
  esac
fi
kv signadot_login "$login"

# A running local connection (only one is possible per machine, across orgs and CLI installs).
# Ask the user's CLI, then the trial's own wrapper (a resumed trial), then fall back to the process list.
lc=none
for cli in ${sd:-} "$T/bin/sd"; do
  [ -x "$cli" ] || continue
  st=$("$cli" local status 2>&1 || true)
  case "$st" in *[Nn]ot\ connected*|*not\ running*) continue ;; *[Hh]ealthy*|*[Cc]onnected*)
    c=$(echo "$st" | sed -n "s/.*runtime config: cluster \([^ ,]*\).*/\1/p" | head -1); lc="running ${c:-unknown}"
    [ "$cli" = "$T/bin/sd" ] && lc="$lc (trial)"; break ;; esac
done
if [ "$lc" = none ]; then
  procs=$(ps -Ao args= 2>/dev/null | grep -v grep | grep 'signadot' | grep ' locald' || true)
  if [ -n "$procs" ]; then
    lc="running unknown"; case "$procs" in "$T"/*) lc="running unknown (trial)" ;; esac
  fi
fi
kv local_connect "$lc"

# Kube contexts.
if command -v kubectl >/dev/null 2>&1; then
  kv kube_context "$(kubectl config current-context 2>/dev/null || echo none)"
  kv kube_contexts "$(kubectl config get-contexts -o name 2>/dev/null | paste -sd, - || true)"
else
  kv kube_context none; kv kube_contexts ""
fi

# Port the local-development scenario needs, and whether a trial already ran here.
if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:8083 -sTCP:LISTEN >/dev/null 2>&1; then
  kv port_8083 busy
else
  kv port_8083 free
fi
# Linux hosts that restrict unprivileged user namespaces (Ubuntu 23.10+) break Plan steps on kind.
case "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" in
  1) kv apparmor_userns restricted ;; 0) kv apparmor_userns unrestricted ;; *) kv apparmor_userns n/a ;;
esac
kv wsl "$wsl"
if [ -f "$T/trial-log.md" ]; then kv trial_log present; else kv trial_log absent; fi
