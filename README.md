# template

**Sandboxed templating languages** implemented in
[AQL](https://github.com/aql-lang/aql). One common interface renders
templates against a data context across **four engines** — `mustache`,
`handlebars`, `liquid`, and `jinja` — all on the same parse → compile →
sandboxed-run pipeline, selected by the `engine` field with identical
config and context data.

```aql
import "./template.aql"

# one-shot
print ({engine:'mustache' source:'Hi {{name}}!' context:{name:'Ada'}} Template.render)
# => Hi Ada!

# or compile once, render many contexts
def tpl ({engine:'mustache' source:'{{#xs}}[{{.}}]{{/xs}}'} Template.compile)
print (tpl Template.render {xs:['a' 'b' 'c']})   # => [a][b][c]

# same interface, different engine
print ({engine:'liquid' source:'{% for x in xs %}{{ x | upcase }} {% endfor %}' context:{xs:['a' 'b']}} Template.render)
# => A B
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
| `Template.engines` | the engines this build implements (`['mustache' 'handlebars' 'liquid' 'jinja']`) |

Per-engine support at a glance:

- **mustache** — `{{var}}` (HTML-escaped), `{{{var}}}`/`{{& var}}` (raw),
  `{{#section}}` (list/object/boolean), `{{^inv}}`, `{{! comment }}`, dotted, `{{.}}`
- **handlebars** — the above plus block helpers `{{#if}}{{else}}`,
  `{{#unless}}`, `{{#each}}` (`{{this}}`/`{{@index}}`), `{{#with}}`
- **liquid** — `{{ x | filter: arg }}`, `{% if/elsif/else %}`,
  `{% unless %}`, `{% for x in xs %}` (`forloop.*`), `{% assign %}`, `{% comment %}`
- **jinja** — `{{ x | filter }}`, `{% if/elif/else %}`,
  `{% for %}` (`loop.*`), `{% set %}`, `{# comments #}`

Full details, the filter list, and the calling convention are in
**[AGENTS.md](AGENTS.md)**.

## Project layout

```
template.aql                    the library (the Template namespace, 4 engines)
AGENTS.md                       agent guide: how to call this library correctly
CLAUDE.md                       Claude Code entrypoint; @-imports AGENTS.md
test/template_*_test|spec.aql   mustache unit/prop suites + smoke (the spine)
test/handlebars_unit_test.aql   handlebars engine unit tests
test/liquid_unit_test.aql       liquid engine unit tests
test/jinja_unit_test.aql        jinja engine unit tests
dx-report.md                    developer-experience notes (pin: aql @ b849948)
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
for f in test/*.aql; do aql "$f"; done
```

In Claude Code web sessions the SessionStart hook
(`.claude/hooks/session-start.sh`) builds aql automatically.

## Status

This is the **library + tests first** pass: `template.aql` (all four
engines) plus the test suites are complete and green against aql
`b849948`. The Diátaxis docs in `docs/`, the bundled skill/plugin, and the
CI workflow still describe the bloom-filter template this repo was forked
from and are pending a rewrite for `Template`.

## License

See [LICENSE](LICENSE).
