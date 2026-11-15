#!/usr/bin/env bash
# Book one HotROD ride, optionally with a Signadot routing key, and print who served each step.
# Each HotROD notification says which workload handled it and, when a sandbox did, the sandbox's name.
# Exits 1 if no driver was assigned before the timeout.
set -eu

usage() {
  echo "Usage: ride.sh [--key <routing key>] [--proxy socks5h://<host:port>] [--frontend <url>] [--timeout <seconds>]"
  echo "Prints routing_key, session, completed, plate, eta, one 'hop: <service> <served-by>' per step, and hops."
}
KEY="" PROXY="" FRONTEND="http://frontend.hotrod.svc:8080" TIMEOUT=45
while [ $# -gt 0 ]; do
  case "$1" in
    --key) KEY=$2; shift 2 ;;
    --proxy) PROXY=$2; shift 2 ;;
    --frontend) FRONTEND=${2%/}; shift 2 ;;
    --timeout) TIMEOUT=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

opts=(-s --max-time 15)
if [ -n "$PROXY" ]; then opts+=(--proxy "$PROXY"); fi
if [ -n "$KEY" ]; then opts+=(-H "baggage: sd-routing-key=$KEY"); fi

session=$(( (RANDOM * 32768 + RANDOM) % 90000000 + 10000 ))
curl "${opts[@]}" -X POST -H 'Content-Type: application/json' \
  -d "{\"SessionID\":$session,\"RequestID\":1,\"PickupLocationID\":1,\"DropoffLocationID\":123}" \
  "$FRONTEND/dispatch" >/dev/null || true

notes="" arrival="" deadline=$(( $(date +%s) + TIMEOUT ))
while :; do
  notes=$(curl "${opts[@]}" "$FRONTEND/notifications?sessionID=$session&cursor=0" || true)
  arrival=$(echo "$notes" | grep -oE 'Driver [^ "]+ arriving in [^ "]+' | head -1 || true)
  if [ -n "$arrival" ] || [ "$(date +%s)" -ge "$deadline" ]; then break; fi
  sleep 1
done

# One hop per distinct (workload, served-by) pair, in the order the notifications arrived.
# Split the JSON so each notification is on its own line, then read its two context fields.
hops=$(echo "$notes" | awk '{ gsub(/\{"id":/, "\n{\"id\":"); print }' | grep '"baselineWorkload"' | while read -r n; do
  w=$(echo "$n" | sed -n 's/.*"baselineWorkload":"\([^"]*\)".*/\1/p')
  s=$(echo "$n" | sed -n 's/.*"sandboxName":"\([^"]*\)".*/\1/p')
  [ -n "$w" ] && echo "$w ${s:-baseline}"
done | awk '!seen[$0]++')

plate=$(echo "$arrival" | awk '{print $2}')
eta=$(echo "$arrival" | awk '{print $5}')
printf 'routing_key: %s\nsession: %s\n' "${KEY:-none}" "$session"
if [ -n "$arrival" ]; then echo "completed: yes"; else echo "completed: no"; fi
printf 'plate: %s\neta: %s\n' "${plate:-none}" "${eta:-none}"
if [ -n "$hops" ]; then
  echo "$hops" | sed 's/^/hop: /'
  printf 'hops: %s\n' "$(echo "$hops" | awk '{printf "%s%s(%s)", (NR > 1 ? " → " : ""), $1, $2}')"
fi
[ -n "$arrival" ]
