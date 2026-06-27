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
ref="$(tr -d '[:space:]' < ci/aql-ref)"
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

# 3. pinned aql ref consistent vs ci/aql-ref --------------------------------
# (ci/test.yml reads ci/aql-ref directly, so it can't drift and isn't checked.)
check_ref() { # <found> <file>
  if [ "$1" != "$ref" ]; then
    echo "::error file=$2::pinned ref '$1' != ci/aql-ref '$ref'"
    fail=1
  else
    echo "ok: $2 ref matches"
  fi
}
hook_ref=$(grep -oE 'AQL_REF=[0-9a-f]{7,40}' .claude/hooks/session-start.sh | head -1 | cut -d= -f2)
check_ref "$hook_ref" .claude/hooks/session-start.sh
div_ref=$(grep -oE 'AQL_BYTECODE_REF=[0-9a-f]{7,40}' test/divergence/run.sh | head -1 | cut -d= -f2)
check_ref "$div_ref" test/divergence/run.sh
api_ref=$(python3 -c "import json;print(json.load(open('api.json'))['aql_ref'])")
if [ "${ref:0:${#api_ref}}" = "$api_ref" ]; then
  echo "ok: api.json aql_ref prefix matches"
else
  echo "::error file=api.json::aql_ref='$api_ref' is not a prefix of ci/aql-ref '$ref'"
  fail=1
fi

[ "$fail" = 0 ] && echo "[ci] consistency OK (ref $ref)" || echo "[ci] consistency FAILED"
exit $fail
