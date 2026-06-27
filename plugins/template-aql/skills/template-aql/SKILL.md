---
name: template-aql
description: Use when writing or editing AQL code that calls the Template library — Template.compile / Template.render / Template.engines, the Compiled type, or any file that does `import "./template.aql"`. Renders mustache / handlebars / liquid / jinja templates against a data context through one common, sandboxed interface. Provides the exact AQL calling convention (which is not C/Python/JS), the per-engine feature set, verified copy-paste idioms, and fixes for the mistakes agents most often make (foreign call syntax like `tpl.render(ctx)`, verb-first order, bare `e get code` instead of `e get "code"`, assuming `{{x}}` is raw, expecting parent-context fallback in mustache sections).
---

# Calling the Template library (AQL)

Render text templates against a data context, with one interface across
**four engines** — `mustache`, `handlebars`, `liquid`, `jinja` — selected
by the `engine` field. Every render is **sandboxed** (parsed via
`aql:parse`, compiled to custom `tpl_*` words, run through `aql:vm` with
all capabilities — network/fileops/process/env/sqlite — uninstalled), so a
template can never do I/O or escape. Public surface = the `Template`
namespace + the `Compiled` type. Verified against `aql @ b849948`.

## Import

```aql
import "./template.aql"
```

- Path resolves relative to the **working directory the script runs from**,
  not the importing file.
- Do **not** import `aql:parse` / `aql:parselang` / `aql:string-util` /
  `aql:vm` — the library imports its own dependencies.

## The one calling rule

AQL has no `f(a, b)` and no `obj.method(a)`. A call is **receiver-first,
arguments forward**:

```
receiver Template.verb arg
```

Receiver/data first, then the verb, then any extra args forward. Group the
call in parens to use its result as a value.

```aql
def tpl ({engine:'mustache' source:'Hi {{name}}!'} Template.compile)
print (tpl Template.render {name:'Ada'})   # => Hi Ada!
```

## API

| Call | Returns | Notes |
|------|---------|-------|
| `{engine:String, source:String} Template.compile` | `Compiled` | Parse + compile once. Bad args raise `bad_input`; an unimplemented engine raises `unknown_engine`. |
| `compiled Template.render context` | `String` | Render a compiled template against a context (any Map/value). |
| `{engine, source, context} Template.render` | `String` | One-shot: compile + render. |
| `Template.engines` | `List` | `['mustache' 'handlebars' 'liquid' 'jinja']`. |

`Compiled` has read-only fields `engine` / `program`; build only via
`Template.compile`. Catch errors with `do […] error […]` and read
`e get "code"` / `e get "message"` (a **quoted** key — `get` evaluates its
argument, so bare `e get code` is "undefined word: code"). Codes:
`bad_input`, `unknown_engine`, `template_syntax` (a truly unterminated tag
surfaces as `parse_syntax_error`).

## Engines

Escaping differs: **mustache & handlebars HTML-escape** `{{x}}` (use
`{{{x}}}` / `{{& x}}` for raw); **liquid & jinja are raw** by default (use
the `escape` filter). All share dotted lookups (`a.b.c`) and the same
context data.

- **mustache** — `{{v}}` / `{{{v}}}` / `{{& v}}`, `{{#s}}…{{/s}}` (list /
  map / boolean), `{{^s}}…{{/s}}`, `{{! comment }}`, `{{.}}`.
- **handlebars** — mustache plus `{{#if}}{{else}}{{/if}}`, `{{#unless}}`,
  `{{#each}}` (`{{this}}`, `{{@index}}`, `{{@first}}`, `{{@last}}`, item
  fields), `{{#with}}`.
- **liquid** — `{{ x | filter: arg }}`, `{% if/elsif/else/endif %}`,
  `{% unless %}`, `{% for x in xs %}…{% else %}…{% endfor %}` (`forloop.*`),
  `{% assign v = expr %}`, `{% comment %}`; conditions `== != < > <= >=`
  and `and` / `or`.
- **jinja** — `{{ x | filter }}`, `{% if/elif/else/endif %}`,
  `{% for %}…{% else %}…{% endfor %}` (`loop.*`), `{% set v = expr %}`,
  `{# comments #}`.

Built-in filters (liquid/jinja): `upcase`/`upper`, `downcase`/`lower`,
`capitalize`, `size`/`length`, `first`, `last`, `join`, `default`,
`append`, `prepend`, `replace`, `escape`, `strip`/`trim`.

Not implemented (any engine): partials/includes, template inheritance,
custom helpers/filters, set-delimiter tags, lambdas, and **parent-context
fallback in mustache/handlebars sections** (liquid/jinja `for` and
handlebars `each`/`with` *do* see the surrounding context).

## Idioms (verified)

```aql
import "./template.aql"

# one-shot
print ({engine:'mustache' source:'Hi {{name}}!' context:{name:'Ada'}} Template.render)
# => Hi Ada!

# compile once, render many
def li ({engine:'mustache' source:'<li>{{label}}</li>'} Template.compile)
print (li Template.render {label:'a'})
print (li Template.render {label:'b'})

# handlebars block helpers
print ({engine:'handlebars' source:'{{#each xs}}{{@index}}:{{this}} {{/each}}' context:{xs:['a' 'b']}} Template.render)
# => 0:a 1:b

# liquid filters + control
print ({engine:'liquid' source:'{% for x in xs %}{{ x | upcase }} {% endfor %}' context:{xs:['a' 'b']}} Template.render)
# => A B

# jinja loop metadata + comment
print ({engine:'jinja' source:'{% for x in xs %}{{ loop.index }}{% endfor %}{# c #}' context:{xs:['a' 'b' 'c']}} Template.render)
# => 123

# handle a bad engine ('erb' is not implemented) or template
def out (do [{engine:'erb' source:'x' context:{}} Template.render] error [ get "message" ])
```

## Common mistakes

| ✗ Don't | ✓ Do | Why |
|---------|------|-----|
| `Template.render(tpl, ctx)` / `tpl.render(ctx)` | `(tpl Template.render ctx)` | AQL has no call/method syntax. |
| `Template.render tpl ctx` (verb-first) | `tpl Template.render ctx` | Receiver comes first. |
| `e get code` | `e get "code"` | `get` evaluates its key; use a quoted String. |
| treat `{{x}}` as raw (mustache/handlebars) | `{{{x}}}` / `{{& x}}` for raw | `{{x}}` is HTML-escaped there. |
| rely on parent context in a mustache section | pass needed fields into the item | no parent-context fallback. |
| `make Compiled {…}` | `{engine, source} Template.compile` | Construct only via `Template.compile`. |
| `import "aql:parse"` in your script | nothing | the library imports its own deps. |

If the full repo is available, `AGENTS.md`, `api.json` (machine-readable
signatures), and `docs/reference.md` have the complete guide;
`test/template_smoke_test.aql` is a runnable example.
