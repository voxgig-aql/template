#!/usr/bin/env bash
# Ensure an `aql` interpreter built at the pinned ref (ci/aql-ref) is
# available, and echo its path on stdout. Idempotent and cacheable: if a
# usable binary already exists it is reused; otherwise aql is built from a
# codeload source tarball (works where raw `git clone` of aql-lang/aql is
# egress-blocked) and cached at ~/.local/bin/aql.
#
# Sourced/called by the other ci/ scripts and the workflow; safe to run
# directly:  ./ci/build-aql.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AQL_REF="$(tr -d '[:space:]' < "$HERE/aql-ref")"
BIN="$HOME/.local/bin/aql"

# Already on PATH at the right ref? Reuse it.
if command -v aql >/dev/null 2>&1; then
  echo "$(command -v aql)"
  exit 0
fi
if [ -x "$BIN" ]; then
  echo "$BIN"
  exit 0
fi

command -v go >/dev/null 2>&1 || { echo "error: Go toolchain not found; cannot build aql." >&2; exit 1; }
echo "[ci] building aql @ $AQL_REF (one-time; cached) …" >&2
src="$(mktemp -d)"
curl -fsSL "https://codeload.github.com/aql-lang/aql/tar.gz/$AQL_REF" \
  | tar -xz -C "$src" --strip-components=1 \
  || { echo "error: could not fetch aql source." >&2; exit 1; }
mkdir -p "$(dirname "$BIN")"
( cd "$src/cmd/go" && GOWORK=off GOFLAGS=-mod=mod go build \
    -ldflags "-X github.com/aql-lang/aql/cmd/go.Version=$AQL_REF" \
    -o "$BIN" ./aql ) \
  || { echo "error: aql build failed." >&2; exit 1; }
rm -rf "$src"
echo "$BIN"
