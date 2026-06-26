# template

**Sandboxed templating languages** implemented in
[AQL](https://github.com/aql-lang/aql). One common interface renders
templates against a data context; the `mustache` engine is implemented
end-to-end, and the interface is designed so `handlebars`, `liquid`, and
`jinja` slot onto the same pipeline.

```aql
import "./template.aql"

# one-shot
print ({engine:'mustache' source:'Hi {{name}}!' context:{name:'Ada'}} Template.render)
# => Hi Ada!

# or compile once, render many contexts
def tpl ({engine:'mustache' source:'{{#xs}}[{{.}}]{{/xs}}'} Template.compile)
print (tpl Template.render {xs:['a' 'b' 'c']})   # => [a][b][c]
```

> **Calling this library from an AI coding agent?** Read
> **[AGENTS.md](AGENTS.md)** first — the exact AQL calling convention,
> verified idioms, and common mistakes. Claude Code auto-loads it via
> `CLAUDE.md`.

## How it works

Every engine shares one pipeline, and every render is **sandboxed**:

1. **Parse** — `aql:parse` defines the template grammar (a custom lex
   matcher segments the source; a declarative `Parse.rule` recognizes the
   token stream), registered as a `parse <engine>` kind.
2. **Compile** — the tokens are lowered to an AQL program built from a
   fixed set of custom `tpl_*` words plus a `__render` function.
3. **Run** — the program executes through `aql:vm` in a fresh sub-engine
   under a totally restricted policy: every capability (network, fileops,
   process, env, sqlite) is uninstalled, so a template can never perform
   I/O or escape the sandbox.

See the header of [`template.aql`](template.aql) for the full design.

## The `Template` API at a glance

| Call | Purpose |
|------|---------|
| `{engine, source} Template.compile` | parse + compile a template → `Compiled` |
| `compiled Template.render context`  | render a compiled template against a context → String |
| `{engine, source, context} Template.render` | one-shot: compile + render |
| `Template.engines` | the engines this build implements (`['mustache']`) |

Mustache support: `{{var}}` (HTML-escaped), `{{{var}}}` / `{{& var}}`
(raw), `{{#section}}…{{/section}}` (list / object / boolean), `{{^inv}}…{{/inv}}`,
`{{! comment }}`, dotted `{{a.b}}`, and the implicit `{{.}}`. Full details
and the calling convention are in **[AGENTS.md](AGENTS.md)**.

## Project layout

```
template.aql                  the library (the Template namespace)
AGENTS.md                     agent guide: how to call this library correctly
CLAUDE.md                     Claude Code entrypoint; @-imports AGENTS.md
test/template_unit_test.aql   example-based unit tests — direct (Test.test)
test/template_unit_spec.aql   example-based unit tests — declarative spec
test/template_prop_test.aql   property-based tests — direct (Test.check-prop)
test/template_prop_spec.aql   property-based tests — declarative spec
test/template_smoke_test.aql  end-to-end smoke run over the public surface
dx-report.md                  developer-experience notes (pin: aql @ b849948)
```

## Running it

Build the `aql` interpreter from source (latest `main`), then run any
script or test:

```bash
# build aql (the template pins aql-lang/aql @ b849948…)
mkdir -p /tmp/aql && curl -fsSL \
  "https://codeload.github.com/aql-lang/aql/tar.gz/main" \
  | tar -xz -C /tmp/aql --strip-components=1
( cd /tmp/aql/cmd/go && GOFLAGS=-mod=mod go build -o "$HOME/.local/bin/aql" ./aql )

# run every suite (each ends with `all green`)
for f in test/template_*.aql; do aql "$f"; done
```

In Claude Code web sessions the SessionStart hook
(`.claude/hooks/session-start.sh`) builds aql automatically.

## Status

This is the **library + tests first** pass: `template.aql` plus the five
test suites are complete and green against aql `b849948`. The Diátaxis
docs in `docs/`, the bundled skill/plugin, and the CI workflow still
describe the bloom-filter template this repo was forked from and are
pending a rewrite for `Template`.

## License

See [LICENSE](LICENSE).
