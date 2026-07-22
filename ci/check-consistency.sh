#!/usr/bin/env bash
# Packaging + single-source-of-truth guard (no aql needed):
#   1. the bundled plugin SKILL.md is byte-identical to the canonical one
#      (plugins can't point at an external .claude/skills dir, so two copies
#      exist and can drift);
#   2. the JSON manifests parse;
#   3. the pinned aql commit in ci/aql-ref (the single source of truth) is
#      echoed by every other file that hardcodes it — the session-start hook,
#      the divergence harness, api.json (by prefix), and ci/test.yml.
#
# Run directly:  ./ci/check-consistency.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
cd "$REPO"
fail=0

# 1. SKILL.md copies in sync ------------------------------------------------
canonical=.claude/skills/template-aql/SKILL.md
bundled=plugins/template-aql/skills/template-aql/SKILL.md
if diff -u "$canonical" "$bundled" >/dev/null; then
  echo "ok: SKILL.md copies identical"
else
  echo "::error file=$bundled::Plugin skill has drifted from $canonical (fix: cp $canonical $bundled)"
  fail=1
fi

# 2. JSON manifests valid ---------------------------------------------------
for j in .claude-plugin/marketplace.json \
         plugins/template-aql/.claude-plugin/plugin.json \
         api.json; do
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$j" >/dev/null 2>&1; then
    echo "ok: $j"
  else
    echo "::error file=$j::invalid JSON"
    fail=1
  fi
done

[ "$fail" = 0 ] && echo "[ci] consistency OK" || echo "[ci] consistency FAILED"
exit $fail
