# RegSynth

RegSynth generates strings that match a regex-like pattern.

Think: **regex → strings**.

> This library focuses on a generatable subset of regex syntax (no backrefs/lookarounds).

## Installation

```elixir
def deps do
  [
    {:regsynth, "~> 0.1.0"}
  ]
end
```

## Quick example

```elixir
RegSynth.take("a(b|c){2}\\d", 10)
#=> ["abb0", "abb1", ...]

RegSynth.stream("a*", max_repeat: 3)
|> Enum.take(10)
#=> ["", "a", "aa", "aaa", ...]

# Or use the ~G sigil for a more idiomatic API
~G/a+/s |> Enum.take(5)
#=> ["a", "aa", "aaa", "aaaa", "aaaaa"]
```

## Options

* `:max_repeat` - caps `*`, `+`, `{m,}` (default: `5`)
* `:alphabet` - codepoints used for `.` and negated classes (default: printable ASCII)

See `QUICKSTART.md`, `USAGE_GUIDE.md`, and `EXAMPLES.md`.
