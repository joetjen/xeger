# Reference

The complete syntax, options, and API reference for RegSynth.

## Scope

RegSynth supports a **generatable subset** of regex syntax: everything that
can be turned into a finite (or capped-infinite) list of matching strings.
It deliberately does **not** support:

* Backreferences (`\1`, `\2`, ...) -- no fixed set of strings can represent
  "whatever the first group matched."
* Lookarounds (`(?=...)`, `(?!...)`, `(?<=...)`, `(?<!...)`) -- these
  constrain matching without consuming input, which doesn't map onto
  "generate a string."
* Anchors (`^`, `$`) -- every generated string already matches the whole
  pattern, start to end; anchors are meaningless in a generator context. (A
  bare `^`/`-`/`,` in a pattern is a **literal** character in RegSynth, not
  an anchor or operator -- see [Characters that don't need escaping](#characters-that-dont-need-escaping).)
* Named/unnamed capture groups (`(?<name>...)`) -- there's nothing to
  capture when generating; `(...)` is grouping only.

## Syntax

### Literals

Any character not listed under [Escaping](#escaping) matches itself:

```elixir
RegSynth.take("hello", 5)      #=> ["hello"]
```

### Escaping

Backslash-escape a character to match it literally when it would otherwise
be read as an operator: `\(`, `\)`, `\[`, `\]`, `\{`, `\}`, `\|`, `\*`,
`\+`, `\?`, `\.`. Any other escaped character (`\x`) is simply that
character, literally -- RegSynth does **not** interpret `\n`, `\r`, `\t` as
control characters; `\n` matches a literal `n`.

```elixir
RegSynth.take("\\(a\\)", 5)    #=> ["(a)"]
```

### Characters that don't need escaping

`^`, `-`, and `,` are ordinary literal characters everywhere **outside** a
character class / `{m,n}` -- they only take on special meaning in those two
specific contexts (a leading `^` inside `[...]`, a mid-class `-`, and the
separator comma inside `{m,n}`):

```elixir
RegSynth.take("a-b,c^d", 5)    #=> ["a-b,c^d"]
```

### Dot

`.` matches any one codepoint from the `:alphabet` option (default:
printable ASCII, `32..126`):

```elixir
RegSynth.take(".", 3)                          #=> [" ", "!", "\""]
RegSynth.take(".", 3, alphabet: ?a..?c)         #=> ["a", "b", "c"]
```

### Alternation

`a|b|c` matches any one of its alternatives:

```elixir
RegSynth.take("cat|dog", 5)    #=> ["cat", "dog"]
```

### Grouping

`(...)` groups a subpattern, e.g. to apply a quantifier to more than one
character, or to nest alternation. An empty group `()` matches the empty
string:

```elixir
RegSynth.take("(ab|c){2}", 20) |> Enum.take(3)  #=> ["abab", "abc", "cab"]
RegSynth.take("()", 5)                          #=> [""]
```

### Character classes

`[...]` matches any one character from the class; `[^...]` negates it
(matches any character from `:alphabet` **not** in the class). A class can
mix literal characters, ranges (`a-z`), and shorthands (`\d`, `\w`, `\s`):

```elixir
RegSynth.take("[abc]", 5)      #=> ["a", "b", "c"]
RegSynth.take("[a-z]", 3)      #=> ["a", "b", "c"]
RegSynth.take("[^0-9]", 3, alphabet: [?0, ?1, ?a, ?b])  #=> ["a", "b"]
RegSynth.take("[\\d_]", 3)     #=> ["0", "1", "2"]
```

A `-` that's the first or last character in the class (or right before the
closing `]`) is a literal dash rather than a range operator:
`[a-z-]`/`[-az]` both include a literal `-` in the class.

### Shorthand classes

| Shorthand | Matches |
| --- | --- |
| `\d` | `0-9` |
| `\w` | `0-9`, `A-Z`, `a-z`, `_` |
| `\s` | space, tab (`\t`), newline (`\n`), carriage return (`\r`) |

Usable standalone or inside a character class (`[\d_]`).

### Repetition

| Syntax | Meaning |
| --- | --- |
| `a*` | zero or more (capped by `:max_repeat`) |
| `a+` | one or more (capped by `:max_repeat`) |
| `a?` | zero or one |
| `a{m}` | exactly `m` |
| `a{m,}` | `m` or more (capped by `:max_repeat`) |
| `a{m,n}` | between `m` and `n`, inclusive |

`m`/`n` must be non-negative integers, and `n >= m` -- `RegSynth.compile/2`
returns `{:error, message}` for a pattern like `a{3,2}`.

## Options

Both accepted wherever a `keyword()` options list appears (`compile/2`,
`stream/2`, `take/3`, and the pattern struct's own stored options, merged
with whatever's passed at each call):

* `:max_repeat` (default `5`) -- the cap applied to every unbounded
  quantifier (`*`, `+`, `{m,}`). Doesn't affect `{m}`/`{m,n}`, which already
  have an explicit ceiling.
* `:alphabet` (default: printable ASCII, `Enum.to_list(32..126)`) -- the
  set of codepoints `.` and a negated class (`[^...]`) draw from.

## API reference

| Function | Returns | Notes |
| --- | --- | --- |
| `RegSynth.compile(pattern, opts \\ [])` | `{:ok, %RegSynth.Pattern{}} \| {:error, binary()}` | Parses once; reuse the result across many `stream/take` calls. |
| `RegSynth.compile!(pattern, opts \\ [])` | `%RegSynth.Pattern{}` | Same, raises `ArgumentError` on an invalid pattern. |
| `RegSynth.stream(pattern_or_compiled, opts \\ [])` | `Enumerable.t()` | Lazy; accepts either a binary pattern or a compiled `Pattern`. |
| `RegSynth.take(pattern_or_compiled, n, opts \\ [])` | `[binary()]` | `stream/2 \|> Enum.take(n)`. |
| `RegSynth.matches?(pattern, string)` | `boolean()` | Wraps Elixir's own `Regex`; `false` (not an exception) on an invalid pattern. |
| `RegSynth.sigil_G(pattern, modifiers)` | `%RegSynth.Pattern{}` (no modifier or `c`) or `Enumerable.t()` (`s`) | The `~G/pattern/[cs]` sigil. |

## Ordering

`stream/2` enumerates matches in **shortlex** order: all matches of length
`N` before any match of length `N + 1`, and within a given length,
generation walks the pattern structure left to right (alternatives in
declaration order, class codepoints in ascending order) -- a deterministic,
but not necessarily lexicographic, order.

## Performance notes

* A sequence (`ab`, `a(b|c)d`, ...) distributes each candidate total length
  across its parts and takes a Cartesian product of the per-part matches at
  each length -- this is where cost grows fastest: several unbounded or
  wide-alternation parts in the same sequence multiply together.
* Prefer tightening `:max_repeat` and `:alphabet` over relying on
  `Enum.take/2` to cut off an expensive stream early -- the earlier lengths
  still have to be enumerated (even if ultimately discarded) to preserve
  shortlex order.

## How parsing works internally

`RegSynth.Parser.parse/1` is a thin adapter over a parser module generated
ahead-of-time (via `mix ichor.gen`, from
[Ichor](https://hex.pm/packages/ichor)) from the declarative PEG grammar at
`priv/grammar/regsynth.aether`. `RegSynth.Parser.Actions` builds this
library's own `RegSynth.AST.t()` tree directly from that grammar's parse
tree. None of this is public API -- see the moduledocs on those three
modules if you're modifying the grammar itself.
