# Xeger

Xeger generates strings that match a regex-like pattern.

Think: **regex → strings**.

> This library focuses on a generatable subset of regex syntax (no backrefs/lookarounds).

[![Hex.pm](https://img.shields.io/hexpm/v/xeger.svg)](https://hex.pm/packages/xeger)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/xeger)
[![Docs (main)](https://img.shields.io/badge/docs-main-blue.svg)](https://joetjen.github.io/xeger/)
[![License](https://img.shields.io/hexpm/l/xeger.svg)](LICENSE)

## Installation

```elixir
def deps do
  [
    {:xeger, "~> 0.1.0"}
  ]
end
```

## Quick example

```elixir
Xeger.take("a(b|c){2}\\d", 10)
#=> ["abb0", "abb1", ...]

Xeger.random("a(b|c){2}\\d")
#=> "acb5" -- one random match, not the whole set; output varies each call

Xeger.stream("a*")
|> Enum.take(10)
#=> ["", "a", "aa", "aaa", "aaaa", "aaaaa", "aaaaaa", "aaaaaaa", "aaaaaaaa", "aaaaaaaaa"]
# unbounded quantifiers are infinite by default -- stream/2 is lazy either way

# Or use the ~X sigil for a more idiomatic API
~X/a(b|c){2}\d/
#=> "abc9" -- same as Xeger.random/1; add /c or /s for compile/stream instead
```

## Options

* `:max_repeat` - caps `*`, `+`, `{m,}` at this many repeats (default: none -- unbounded)
* `:alphabet` - codepoints used for `.` and negated classes (default: printable ASCII)
* `:seed` - makes `Xeger.random/2`'s output reproducible (default: none -- fresh randomness each call)

## Documentation

* [Tutorial](guides/TUTORIAL.md) - a step-by-step introduction
* [Reference](guides/REFERENCE.md) - full syntax, options, and API reference
* [Cheatsheet](guides/CHEATSHEET.md) - quick syntax lookup
* [Examples](guides/EXAMPLES.md) - worked, realistic patterns
* [Changelog](CHANGELOG.md)

Full API docs: [hexdocs.pm/xeger](https://hexdocs.pm/xeger) (latest release) or
[joetjen.github.io/xeger](https://joetjen.github.io/xeger/) (built from `main` on every push).

## License

[MIT](LICENSE)
