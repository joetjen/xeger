# RegSynth

RegSynth generates strings that match a regex-like pattern.

Think: **regex → strings**.

> This library focuses on a generatable subset of regex syntax (no backrefs/lookarounds).

[![Hex.pm](https://img.shields.io/hexpm/v/regsynth.svg)](https://hex.pm/packages/regsynth)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/regsynth)
[![License](https://img.shields.io/hexpm/l/regsynth.svg)](LICENSE)

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

## Documentation

* [Tutorial](guides/TUTORIAL.md) - a step-by-step introduction
* [Reference](guides/REFERENCE.md) - full syntax, options, and API reference
* [Cheatsheet](guides/CHEATSHEET.md) - quick syntax lookup
* [Examples](guides/EXAMPLES.md) - worked, realistic patterns
* [Changelog](CHANGELOG.md)

Full API docs: [hexdocs.pm/regsynth](https://hexdocs.pm/regsynth).

## License

[MIT](LICENSE)
