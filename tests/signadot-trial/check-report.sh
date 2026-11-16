#!/usr/bin/env bash
# Report template: every FILL slot and template block is there, nothing is loaded from the network, no comment text
# leaks into the page; the adoption tiles link the docs.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); S=$ROOT/skills/signadot-trial; T=$S/assets/report-template.html; fail=0
bad() { echo "FAIL $*"; fail=1; }
for k in title summary cards timeline running next-steps teardown run-details; do
  grep -q "<!-- FILL:$k" "$T" || bad "slot $k"
done
for b in '<!-- CARD' '/CARD -->' '<!-- NOT-RUN' '/NOT-RUN -->' 'id="hotrod"' 'class="flow"' 'hop sbx' 'id="running"'; do
  grep -q "$b" "$T" || bad "missing $b"
done
grep -qi '<script' "$T" && bad "script tag"
grep -oiE '(src="https?://|<link[^>]+href="https?://)' "$T" && bad "loads something from the network"
n=$(sed -n '/<section id="adoption">/,/<\/section>/p' "$T" | grep -c 'href="https://www.signadot.com/docs/')
[ "$n" -ge 5 ] || bad "adoption tiles: $n docs links, want one per tile"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$T" <<'PY' || fail=1
import html.parser, sys
class P(html.parser.HTMLParser):
    def __init__(s): super().__init__(); s.t = []; s.k = 0
    def handle_starttag(s, t, a): s.k += t in ('style', 'svg')
    def handle_endtag(s, t): s.k -= t in ('style', 'svg')
    def handle_data(s, d):
        if not s.k and d.strip(): s.t.append(d)
p = P(); p.feed(open(sys.argv[1]).read())
leak = [x for x in p.t if 'FILL' in x or '-->' in x or 'CARD' in x]
if leak: print("FAIL text leaks out of comments:", leak); sys.exit(1)
PY
fi
for s in "## The report" "## Screenshots"; do grep -q "$s" "$S/references/finish/report.md" || bad "report.md: $s"; done
[ $fail = 0 ] && echo "report OK"; exit $fail
