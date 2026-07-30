# Reference

The complete syntax, options, and API reference for Xeger.

## Scope

Xeger supports a **generatable subset** of regex syntax: everything that
can be turned into a stream of matching strings -- finite for a bounded
pattern, and by default genuinely infinite (enumerated lazily) for one with
an unbounded quantifier (`*`, `+`, `{m,}`) at the top level, unless you cap
it with `:max_repeat`. It deliberately does **not** support:

* Backreferences (`\1`, `\2`, ...) -- no fixed set of strings can represent
  "whatever the first group matched."
* Lookarounds (`(?=...)`, `(?!...)`, `(?<=...)`, `(?<!...)`) -- these
  constrain matching without consuming input, which doesn't map onto
  "generate a string."
* Anchors (`^`, `$`) -- every generated string already matches the whole
  pattern, start to end; anchors are meaningless in a generator context. (A
  bare `^`/`-`/`,` in a pattern is a **literal** character in Xeger, not
  an anchor or operator -- see [Characters that don't need escaping](#characters-that-dont-need-escaping).)
* Named/unnamed capture groups (`(?<name>...)`) -- there's nothing to
  capture when generating; `(...)` is grouping only.

## Syntax

### Literals

Any character not listed under [Escaping](#escaping) matches itself:

```elixir
Xeger.take("hello", 5)      #=> ["hello"]
```

### Escaping

Backslash-escape a character to match it literally when it would otherwise
be read as an operator: `\(`, `\)`, `\[`, `\]`, `\{`, `\}`, `\|`, `\*`,
`\+`, `\?`, `\.`. Any other escaped character (`\x`) is simply that
character, literally -- Xeger does **not** interpret `\n`, `\r`, `\t` as
control characters; `\n` matches a literal `n`.

```elixir
Xeger.take("\\(a\\)", 5)    #=> ["(a)"]
```

### Characters that don't need escaping

`^`, `-`, and `,` are ordinary literal characters everywhere **outside** a
character class / `{m,n}` -- they only take on special meaning in those two
specific contexts (a leading `^` inside `[...]`, a mid-class `-`, and the
separator comma inside `{m,n}`):

```elixir
Xeger.take("a-b,c^d", 5)    #=> ["a-b,c^d"]
```

### Dot

`.` matches any one codepoint from the `:alphabet` option (default:
printable ASCII, `32..126`):

```elixir
Xeger.take(".", 3)                          #=> [" ", "!", "\""]
Xeger.take(".", 3, alphabet: ?a..?c)         #=> ["a", "b", "c"]
```

### Alternation

`a|b|c` matches any one of its alternatives:

```elixir
Xeger.take("cat|dog", 5)    #=> ["cat", "dog"]
```

### Grouping

`(...)` groups a subpattern, e.g. to apply a quantifier to more than one
character, or to nest alternation. An empty group `()` matches the empty
string:

```elixir
Xeger.take("(ab|c){2}", 4)  #=> ["cc", "cab", "abc", "abab"]
Xeger.take("()", 5)         #=> [""]
```

### Character classes

`[...]` matches any one character from the class; `[^...]` negates it
(matches any character from `:alphabet` **not** in the class). A class can
mix literal characters, ranges (`a-z`), and shorthands (`\d`, `\w`, `\s`):

```elixir
Xeger.take("[abc]", 5)      #=> ["a", "b", "c"]
Xeger.take("[a-z]", 3)      #=> ["a", "b", "c"]
Xeger.take("[^0-9]", 3, alphabet: [?0, ?1, ?a, ?b])  #=> ["a", "b"]
Xeger.take("[\\d_]", 3)     #=> ["0", "1", "2"]
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
| `a*` | zero or more (unbounded unless capped by `:max_repeat`) |
| `a+` | one or more (unbounded unless capped by `:max_repeat`) |
| `a?` | zero or one |
| `a{m}` | exactly `m` |
| `a{m,}` | `m` or more (unbounded unless capped by `:max_repeat`) |
| `a{m,n}` | between `m` and `n`, inclusive |

`m`/`n` must be non-negative integers, and `n >= m` -- `Xeger.compile/2`
returns `{:error, message}` for a pattern like `a{3,2}`.

## Options

Accepted wherever a `keyword()` options list appears (`compile/2`,
`stream/2`, `take/3`, `random/2`, and the pattern struct's own stored
options, merged with whatever's passed at each call):

* `:max_repeat` (default: none -- unbounded) -- caps every unbounded
  quantifier (`*`, `+`, `{m,}`) at this many repeats. Without it, `stream/2`
  on such a pattern is a genuinely infinite stream (fine to pipe into
  `Enum.take/2`; don't pipe it into something that consumes a stream
  eagerly, like `Enum.to_list/1` or `Enum.count/1`), and `random/2` draws
  each repeat beyond the quantifier's minimum via a coin flip instead of a
  uniform range (see [Random generation](#random-generation)). Doesn't
  affect `{m}`/`{m,n}`, which already have an explicit ceiling.
* `:alphabet` (default: printable ASCII, `Enum.to_list(32..126)`) -- the
  set of codepoints `.` and a negated class (`[^...]`) draw from.
* `:seed` (default: none -- fresh randomness each call) -- `random/2`-only;
  makes its output reproducible. Ignored by `compile/2`, `stream/2`, and
  `take/3`.

## API reference

| Function | Returns | Notes |
| --- | --- | --- |
| `Xeger.compile(pattern, opts \\ [])` | `{:ok, %Xeger.Pattern{}} \| {:error, binary()}` | Parses once; reuse the result across many `stream/take` calls. |
| `Xeger.compile!(pattern, opts \\ [])` | `%Xeger.Pattern{}` | Same, raises `ArgumentError` on an invalid pattern. |
| `Xeger.stream(pattern_or_compiled, opts \\ [])` | `Enumerable.t()` | Lazy; accepts either a binary pattern or a compiled `Pattern`. |
| `Xeger.take(pattern_or_compiled, n, opts \\ [])` | `[binary()]` | `stream/2 \|> Enum.take(n)`. |
| `Xeger.random(pattern_or_compiled, opts \\ [])` | `binary()` | One random match, without enumerating the rest. Raises `ArgumentError` if the pattern has no possible matches. |
| `Xeger.matches?(pattern, string)` | `boolean()` | Wraps Elixir's own `Regex`; `false` (not an exception) on an invalid pattern. |
| `Xeger.sigil_X(pattern, modifiers)` | `binary()` (no modifier), `%Xeger.Pattern{}` (`c`), or `Enumerable.t()` (`s`) | The `~X/pattern/[cs]` sigil. |

## Random generation

`Xeger.random/2` walks the pattern making one random choice at each node
(which alternative, how many repeats, which codepoint) instead of
enumerating every match and picking one -- so it stays fast even for a
pattern whose full match set would be huge or infinite.

For a bounded quantifier (`{m}`/`{m,n}`, or an unbounded one capped by
`:max_repeat`), the repeat count is drawn **uniformly** from its valid
range. For an unbounded quantifier with no `:max_repeat`, there's no finite
range to draw from uniformly, so each repeat beyond the quantifier's own
minimum is instead a coin flip (50/50) on whether to add another --
unbounded in principle, geometrically distributed (so almost surely short)
in practice.

Pass `:seed` (any integer) for reproducible output: the same pattern,
options, and seed always produce the same string. Without it, each call
draws fresh randomness. Seeding is local to the call -- it doesn't affect
`:rand` state elsewhere in your program.

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
* A repeated unit that can itself match the empty string (e.g. `(a?)*`)
  produces the same string multiple times, once per redundant way of
  splitting it across repeats -- harmless for `take/3` with a small `n`, but
  a reason to prefer `:max_repeat` (or rewriting the pattern, e.g. `a*`
  instead of `(a?)*`) over `Enum.take/2` on a large `n` for such patterns.

## How parsing works internally

`Xeger.Parser.parse/1` is a thin adapter over a parser module generated
ahead-of-time (via `mix ichor.gen`, from
[Ichor](https://hex.pm/packages/ichor)) from the declarative PEG grammar at
`priv/grammar/xeger.aether`. `Xeger.Parser.Actions` builds this
library's own `Xeger.AST.t()` tree directly from that grammar's parse
tree. None of this is public API -- see the moduledocs on those three
modules if you're modifying the grammar itself.
