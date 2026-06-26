# CLAUDE.md

This repository is the `Template` library: sandboxed templating languages
written in AQL. The `mustache` engine is implemented end-to-end; the
common interface is designed so `handlebars`, `liquid`, and `jinja` slot
onto the same pipeline.

## Using the library

See @AGENTS.md for how to call the `Template` API correctly from AQL — the
calling convention, the full API, copy-paste idioms, and the common
mistakes to avoid. Every example there is verified against the pinned
`aql` build.

## How it works

Each engine follows one pipeline (see the header of `template.aql`):

1. **Parse** — `aql:parse` defines the template grammar. A custom lex
   matcher segments the source into a typed token stream and a declarative
   `Parse.rule` recognizes it, registered as a `parse <engine>` kind.
2. **Compile** — the token stream is lowered to an AQL program: a fixed
   runtime prelude of custom `tpl_*` words plus a `__render` function that
   builds the output by calling only those words.
3. **Run** — the program executes through `aql:vm` in a fresh sub-engine
   under a totally restricted policy (every capability scope uninstalled),
   so a template can never do I/O or escape the sandbox.

## Working on this repository

- A SessionStart hook (`.claude/settings.json` →
  `.claude/hooks/session-start.sh`) builds `aql` from the pinned commit in
  remote sessions, so a fresh session can run the suites. It fetches via
  the codeload tarball (the `aql-lang/aql` git remote is egress-blocked
  behind the agent proxy) and falls back to `git clone`. Locally, build
  once from source — see [docs/how-to.md](docs/how-to.md#install-and-run-aql).
- The pinned aql commit is **latest main** (`b849948…`), single-sourced in
  the SessionStart hook's `AQL_REF`. Several fixes this module relies on
  (notably `get` evaluating a dynamic key argument) landed after the older
  `407feda` pin the template was forked from.
- Tests live in `test/`, named `<subject>_<unit|prop>_<test|spec>.aql` plus
  a `template_smoke_test.aql`: `_test` = imperative (`Test.test` /
  `Test.check-prop`), `_spec` = declarative spec; `unit` = example-based,
  `prop` = property-based. Each assertion-bearing suite ends by asserting
  `Test.fail-count` is `0` and prints `all green`. Run them all with
  `for f in test/template_*.aql; do aql "$f"; done`.
- Known AQL-runtime gotchas observed building this module are in
  `dx-report.md` (the `fn`-body def-time trace, mixed argument-order
  conventions, map-literal scoping, and the unenforced `aql:vm` step
  budget).
- Status: this is the **library + tests first** pass. The full Diátaxis
  docs, the bundled skill/plugin, and the CI workflow still describe the
  bloom-filter template and are pending a rewrite for `Template`.
