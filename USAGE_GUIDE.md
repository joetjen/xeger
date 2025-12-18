# Usage Guide

## Supported syntax (subset)

* Literals: `abc`
* Escapes: `\\(`, `\\]`, `\\{`, etc.
* Dot: `.` (one codepoint from `:alphabet`)
* Alternation: `a|b|c`
* Grouping: `(ab|c)`
* Character classes: `[abc]`, `[a-z]`, `[^0-9]`
* Shorthands: `\\d`, `\\w`, `\\s`
* Repetition: `*`, `+`, `?`, `{m}`, `{m,}`, `{m,n}`

## Using the ~G sigil

RegSynth provides a custom `~G` sigil (for "generate") for more ergonomic pattern creation:

```elixir
# Default: compile pattern
pattern = ~G/a+/

# Stream modifier: get enumerable directly
~G/[0-9]/s |> Enum.take(10)

# Compile modifier (explicit, same as default)
~G/abc/c
```

The sigil makes your code more readable and follows Elixir conventions (similar to `~r` for regular expressions).

## Notes on enumeration

RegSynth enumerates matches in **shortlex** order: shortest strings first.

Unbounded repetition is capped via `:max_repeat`.
