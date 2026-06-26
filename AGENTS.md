# AGENTS.md — using the `Template` library

Guidance for an AI coding agent calling this templating library from an
AQL project. Every code block below is verified to run against
`aql-lang/aql` @ `b849948`. If you read nothing else, read
[The one calling rule](#the-one-calling-rule) and
[Common mistakes](#common-mistakes).

## What it is

A templating engine that renders text templates against a data context,
with a **common interface across templating languages**. Today the
`mustache` engine is implemented end-to-end; `handlebars`, `liquid`, and
`jinja` share the same pipeline and are reserved (selecting one raises
`unknown_engine`). The public surface is the `Template` namespace plus the
`Compiled` type.

Every render runs inside a **sandbox**: the template is parsed (via
`aql:parse`), compiled to a small AQL program built from a fixed set of
custom `tpl_*` words, and executed through `aql:vm` under a policy that
uninstalls every capability (network, fileops, process, env, sqlite). A
template can therefore never perform I/O or escape the sandbox.

## Import

```aql
import "./template.aql"
```

- The path is resolved **relative to the working directory the script is
  run from**, not the importing file. Run scripts from where that path
  is valid (adjust otherwise).
- Do **not** import `aql:parse`, `aql:parselang`, `aql:string-util`, or
  `aql:vm` yourself — `template.aql` imports its own dependencies.

## The one calling rule

AQL is not C/Python/JS. There is no `f(a, b)` and no `obj.method(a)`.
A call is **receiver-first, arguments forward**:

```
receiver Template.verb arg1
```

— the **receiver/data comes first**, then the verb, then any extra
arguments after the verb. Group a call in parens to use its result:

```aql
def tpl ({engine:'mustache' source:'Hi {{name}}!'} Template.compile)
print (tpl Template.render {name:'Ada'})   # => Hi Ada!
```

## API reference (exact call shapes)

| Call | Returns | Notes |
|------|---------|-------|
| `{engine:String, source:String} Template.compile` | `Compiled` | Parse + compile a template once. Bad args raise `bad_input`; an unimplemented engine raises `unknown_engine`. |
| `compiled Template.render context` | `String` | Render a compiled template against a context (any Map/value). |
| `{engine, source, context} Template.render` | `String` | One-shot convenience: compile then render in one call. |
| `Template.engines` | `List` | The engines this build implements (`['mustache']`). |

`Compiled` has read-only fields `engine` (String) and `program` (the
generated AQL source). Build it only through `Template.compile`.

Errors carry a code and message: catch with `do […] error […]` and read
`e get "code"` / `e get "message"` in the handler. Codes: `bad_input`,
`unknown_engine`, `template_syntax` (malformed template — unbalanced or
mismatched section; a truly unterminated tag surfaces as
`parse_syntax_error` from the parser).

> **Reading an error code:** use `(e get "code")` with a **quoted String
> key**. On this build `get` evaluates its key argument, so a bare
> `e get code` is an "undefined word: code" error.

## Mustache features supported

- `{{name}}` — HTML-escaped interpolation (`& < > "`)
- `{{{name}}}` and `{{& name}}` — unescaped interpolation
- `{{#section}}…{{/section}}` — section: iterates a list (with `{{.}}` as
  the current item), enters a map as the new context, or renders once for
  a truthy scalar; renders nothing for a falsy value (`None`/`false`/`""`/`[]`)
- `{{^section}}…{{/section}}` — inverted section (renders iff falsy/empty)
- `{{! comment }}` — comment (renders nothing)
- `{{a.b.c}}` dotted lookup, `{{.}}` implicit current item

Not yet implemented: partials (`{{> name}}` renders empty), set-delimiter
tags, lambdas, and **parent-context fallback** — inside a section, lookups
see the section's own frame, not enclosing frames.

## Copy-paste idioms (all verified)

One-shot render:

```aql
import "./template.aql"
print ({engine:'mustache' source:'Hi {{name}}!' context:{name:'Ada'}} Template.render)
# => Hi Ada!
```

Compile once, render many contexts:

```aql
def tpl ({engine:'mustache' source:'<li>{{label}}</li>'} Template.compile)
print (tpl Template.render {label:'a'})
print (tpl Template.render {label:'b'})
```

List section with the implicit iterator:

```aql
print ({engine:'mustache' source:'{{#xs}}[{{.}}]{{/xs}}' context:{xs:['a' 'b' 'c']}} Template.render)
# => [a][b][c]
```

Sections, dotted lookups, inverted sections together:

```aql
def src '{{#user}}{{name}} likes {{#likes}}{{.}} {{/likes}}{{/user}}{{^user}}no user{{/user}}'
print ({engine:'mustache' source:src context:{user:{name:'Ada' likes:['x' 'y']}}} Template.render)
# => Ada likes x y
```

Handle a bad engine or template:

```aql
def result (do [{engine:'liquid' source:'x' context:{}} Template.render] error [
  get "message"                            # or: get "code", case […]
])
print (result)
```

In a test, assert the failure code:

```aql
import "aql:test"
def e (do [{engine:'mustache' source:'{{#a}}x{{/b}}' context:{}} Template.render])
template_syntax/q (e get "code") Assert.equal end
```

## Common mistakes

| ✗ Don't write | ✓ Write | Why |
|---------------|---------|-----|
| `Template.render(tpl, ctx)` | `(tpl Template.render ctx)` | No `f(a,b)` syntax in AQL. |
| `tpl.render(ctx)` | `(tpl Template.render ctx)` | No method-call syntax. |
| `Template.render tpl ctx` (verb-first) | `tpl Template.render ctx` (receiver first) | Receiver comes first. |
| `e get code` | `e get "code"` | `get` evaluates its key; use a quoted String. |
| treat `{{x}}` as raw | it is **HTML-escaped** | use `{{{x}}}` / `{{& x}}` for raw output. |
| rely on parent context in a section | pass needed fields into the item | no parent-context fallback yet. |
| `make Compiled {…}` | `{engine, source} Template.compile` | Construct only via `Template.compile`. |
| `import "aql:parse"` in your script | nothing | `template.aql` imports its own deps. |

## Where to look next

- `template.aql` — the module; its header documents the parse → compile →
  sandbox pipeline and the runtime word set.
- `api.json` — the same API as a machine-readable manifest.
- `test/template_smoke_test.aql` — a complete, runnable worked example.
- `dx-report.md` — AQL-runtime gotchas observed building this module.
