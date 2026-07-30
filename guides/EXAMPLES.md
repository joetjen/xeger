# Examples

Realistic patterns, worked out. See the [Reference](REFERENCE.md) for the
full syntax and the [Cheatsheet](CHEATSHEET.md) for a quick lookup.

## Usernames

```elixir
RegSynth.take("[a-z][a-z0-9_]{2,5}", 10)
#=> ["a00", "a01", "a02", ...]
```

## Version strings

```elixir
RegSynth.take("v\\d{1,2}\\.\\d{1,2}", 10)
#=> ["v0.0", "v0.1", "v0.2", ...]
```

## Simple passwords

```elixir
RegSynth.take("[A-Z][a-z]{3}\\d{2}", 10)
#=> ["Aaaa00", "Aaaa01", "Aaaa02", ...]
```

## US-style phone numbers

```elixir
RegSynth.take("555-\\d{4}", 10)
#=> ["555-0000", "555-0001", "555-0002", ...]
```

## Hex color codes

```elixir
RegSynth.take("#[0-9A-F]{6}", 10)
#=> ["#000000", "#000001", "#000002", ...]
```

## ZIP codes (optional +4)

```elixir
RegSynth.take("\\d{5}(-\\d{4})?", 10)
#=> ["00000", "00001", "00002", ...]
```

## URL-style slugs

```elixir
RegSynth.take("[a-z0-9]+(-[a-z0-9]+)*", 10, max_repeat: 3)
#=> ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
```

## Email-ish addresses

```elixir
RegSynth.stream("[a-z0-9]{3,8}@(gmail|yahoo|outlook)\\.com")
|> Enum.take(5)
#=> ["000@gmail.com", "000@yahoo.com", "001@gmail.com", "001@yahoo.com", "002@gmail.com"]
```

## Reusing a compiled pattern with the `~G` sigil

```elixir
import RegSynth, only: [sigil_G: 2]

~G/[A-Z]{2}\\d{6}/s |> Enum.take(5)
#=> ["AA000000", "AA000001", "AA000002", "AA000003", "AA000004"]
```

## A runnable demo script

`examples/sigil_demo.exs` in this repo walks through several of the
patterns above (plus a couple more) end to end:

```sh
elixir examples/sigil_demo.exs
```
