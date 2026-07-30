# Cheatsheet

Quick lookups. See the [Reference](REFERENCE.md) if anything here needs more
explanation, or the [Tutorial](TUTORIAL.md) for a walkthrough.

## Operators

| Syntax | Meaning |
| --- | --- |
| `abc` | literal sequence |
| `\x` | literal `x` (needed for parens, brackets, braces, the alternation bar, `*`, `+`, `?`, `.`; harmless elsewhere) |
| `.` | any codepoint from `:alphabet` |
| `a\|b\|c` | alternation |
| `(...)` | grouping (`()` matches the empty string) |
| `[abc]` | character class |
| `[a-z]` | character range |
| `[^abc]` | negated class (any `:alphabet` codepoint not listed) |
| `\d` | `0-9` |
| `\w` | `0-9`, `A-Z`, `a-z`, `_` |
| `\s` | space, `\t`, `\n`, `\r` |
| `a*` | zero or more (capped by `:max_repeat`) |
| `a+` | one or more (capped by `:max_repeat`) |
| `a?` | zero or one |
| `a{m}` | exactly `m` |
| `a{m,}` | `m` or more (capped by `:max_repeat`) |
| `a{m,n}` | `m` to `n` |

## Not supported

| Syntax | Why |
| --- | --- |
| `\1`, `\2`, ... | backreferences -- no finite string set represents "whatever group 1 matched" |
| `(?=)` `(?!)` `(?<=)` `(?<!)` | lookarounds -- constrain without consuming, meaningless for generation |
| `^` `$` | anchors -- every generated string already matches the whole pattern; `^`/`$` are just literal characters here |
| `(?<name>...)` | named/unnamed captures -- nothing to capture when generating |

## Literal without escaping

`^`, `-`, `,` need no escaping outside a character class / `{m,n}` -- they're
plain literal characters everywhere else.

## Options

| Option | Default | Affects |
| --- | --- | --- |
| `:max_repeat` | `5` | `*`, `+`, `{m,}` |
| `:alphabet` | printable ASCII (`32..126`) | `.`, `[^...]` |

## API quick reference

```elixir
RegSynth.compile(pattern, opts \\ [])    #=> {:ok, pattern} | {:error, msg}
RegSynth.compile!(pattern, opts \\ [])   #=> pattern | raises ArgumentError
RegSynth.stream(pattern_or_compiled, opts \\ [])  #=> Enumerable.t()
RegSynth.take(pattern_or_compiled, n, opts \\ []) #=> [binary()]
RegSynth.matches?(pattern, string)       #=> boolean()

# ~G sigil (import RegSynth, only: [sigil_G: 2])
~G/pattern/     # compile (default)
~G/pattern/c    # compile (explicit)
~G/pattern/s    # stream
```

## Common gotchas

* `\n`, `\r`, `\t` are **not** interpreted as control characters -- they're
  just the escaped literal letters `n`, `r`, `t`. Use `\s` (whitespace
  shorthand) or the actual control character in your source if you need one.
* `a{3,2}` (max less than min) is a compile error, not a silently-empty
  match.
* A leading `^` inside `[...]` always negates the class -- to include a
  literal leading `^`, escape it: `[\^abc]`.
* Enumeration order is shortlex (shortest first), not lexicographic overall
  -- don't expect `Enum.take/2` output to be alphabetically sorted across
  different lengths.
