#!/usr/bin/env bash
# Layout and consistency: every reference file is linked from SKILL.md, every path mentioned exists, variation
# files follow their template, costs match the index, versions and commits agree across files.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); S=$ROOT/skills/signadot-trial; fail=0
bad() { echo "FAIL $*"; fail=1; }

# Frontmatter (Agent Skills spec): name matches the folder, description <= 1024, compatibility <= 500, a version.
fm=$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$S/SKILL.md")
echo "$fm" | grep -q '^name: signadot-trial$' || bad "frontmatter: name"
desc=$(echo "$fm" | awk '/^description:/ {f=1; next} f && /^[a-z]+:/ {f=0} f' | tr -s ' \n' ' ')
[ ${#desc} -gt 0 ] && [ ${#desc} -le 1024 ] || bad "frontmatter: description length ${#desc}"
comp=$(echo "$fm" | awk '/^compatibility:/ {f=1; sub(/^compatibility: *>? */, ""); print; next} f && /^[a-z]+:/ {f=0} f' | tr -s ' \n' ' ')
[ ${#comp} -gt 1 ] && [ ${#comp} -le 500 ] || bad "frontmatter: compatibility missing or over 500 chars"
echo "$fm" | grep -qE '^  version: "[0-9]+\.[0-9]+\.[0-9]+"' || bad "frontmatter: metadata.version"

# Every reference file is linked from SKILL.md; MAINTAINING.md exists and is not.
for f in $(cd "$S" && find references -name '*.md' | sort); do
  grep -q "($f)" "$S/SKILL.md" || bad "SKILL.md doesn't link $f"
done
[ -s "$S/MAINTAINING.md" ] || bad "MAINTAINING.md missing"
grep -q 'MAINTAINING' "$S/SKILL.md" && bad "SKILL.md links MAINTAINING.md (it's for maintainers, not agents)"

# Every skill-relative path mentioned in SKILL.md or a reference file exists.
for p in $(cd "$S" && grep -rhoE '(references|assets|scripts)/[A-Za-z0-9_./-]+\.(md|sh|yaml|html|patch)' SKILL.md references | sort -u); do
  [ -e "$S/$p" ] || bad "missing path $p"
done

# Variation files follow their template.
for f in "$S"/references/data/*.md "$S"/references/async/*.md "$S"/references/testing/*.md; do
  for h in "What it shows" "Costs" "Before you start" "Set up" "Run" "Prove it" "Record" "Try it yourself" \
           "Tear down" "Docs"; do
    grep -q "^## $h" "$f" || bad "${f#$S/}: no '## $h'"
  done
done
for f in "$S"/references/infra/*.md; do
  for h in "What it shows" "Install before HotROD" "Overlay and operator values" "Mesh check" "Tear down" "Docs"; do
    grep -q "^## $h" "$f" || bad "${f#$S/}: no '## $h'"
  done
done

# Each variation's minutes in the SKILL.md index match its file's Costs.
grep -E '^\| (Data|Async|Testing) \|' "$S/SKILL.md" | while IFS='|' read -r _ _ _ file time _; do
  path=$(echo "$file" | sed -n 's/.*(\(references[^)]*\)).*/\1/p'); min=$(echo "$time" | grep -oE '[0-9]+' | head -1)
  [ -n "$path" ] && [ -n "$min" ] || continue
  sed -n '/^## Costs/,/^## /p' "$S/$path" | grep -qE "About $min minutes" || echo "FAIL $path: Costs doesn't say About $min minutes"
done | grep . && fail=1

# One CLI version, one HotROD commit and one examples commit across the skill.
cli=$(sed -n 's/^VERSION=//p' "$S/scripts/install-cli.sh")
for v in $(grep -rhoE 'CLI (≥ )?[0-9]+\.[0-9]+\.[0-9]+' "$S/SKILL.md" "$S/references" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u); do
  [ "$v" = "$cli" ] || bad "CLI version $v doesn't match install-cli.sh ($cli)"
done
hot=$(sed -n 's/.*hotrod\/\/.*ref=\([0-9a-f]\{40\}\).*/\1/p' "$S/references/setup/cluster.md" | head -1)
[ -n "$hot" ] || bad "cluster.md: no pinned HotROD overlay commit"
for f in references/core/local-development.md assets/specs/testing/playwright-job.yaml assets/specs/testing/hotrod-e2e-plan.yaml; do
  grep -q "$hot" "$S/$f" || bad "$f doesn't use the HotROD commit from cluster.md ($hot)"
done
grep -rqE -- '-b main|default: main' "$S/assets" "$S/references" && bad "a HotROD clone follows main instead of the pinned commit"
ex=$(grep -A3 'signadot/examples.git' "$S/references/setup/cluster.md" | sed -n 's/.*origin \([0-9a-f]\{40\}\).*/\1/p' | head -1)
[ -n "$ex" ] || bad "cluster.md: no pinned signadot/examples fetch (the async files share it)"
grep -l 'signadot/examples.git' "$S"/references/async/*.md 2>/dev/null | grep . && bad "an async file fetches signadot/examples itself"

# Shell snippets avoid constructs that behave differently in zsh.
grep -rnF '${' "$S/references" "$S/SKILL.md" | grep -E '\$\{[A-Za-z_]+:\+' && bad "zsh-unsafe \${x:+…} in a snippet"

# OSS-only: no variation that needs a cloud account.
grep -rniE '\b(sqs|localstack|neon|xata)\b' "$S/SKILL.md" "$S/references" && bad "account-bound service mentioned"

[ $fail = 0 ] && echo "structure OK"; exit $fail
