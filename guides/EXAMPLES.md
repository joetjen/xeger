# Examples

Realistic patterns, worked out. See the [Reference](REFERENCE.md) for the
full syntax and the [Cheatsheet](CHEATSHEET.md) for a quick lookup.

## Usernames

```elixir
Xeger.take("[a-z][a-z0-9_]{2,5}", 10)
#=> ["a00", "a01", "a02", ...]
```

## Version strings

```elixir
Xeger.take("v\\d{1,2}\\.\\d{1,2}", 10)
#=> ["v0.0", "v0.1", "v0.2", ...]
```

## Simple passwords

```elixir
Xeger.take("[A-Z][a-z]{3}\\d{2}", 10)
#=> ["Aaaa00", "Aaaa01", "Aaaa02", ...]
```

## US-style phone numbers

```elixir
Xeger.take("555-\\d{4}", 10)
#=> ["555-0000", "555-0001", "555-0002", ...]
```

## Hex color codes

```elixir
Xeger.take("#[0-9A-F]{6}", 10)
#=> ["#000000", "#000001", "#000002", ...]
```

## ZIP codes (optional +4)

```elixir
Xeger.take("\\d{5}(-\\d{4})?", 10)
#=> ["00000", "00001", "00002", ...]
```

## URL-style slugs

```elixir
Xeger.take("[a-z0-9]+(-[a-z0-9]+)*", 10, max_repeat: 3)
#=> ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
```

## Email-ish addresses

```elixir
Xeger.stream("[a-z0-9]{3,8}@(gmail|yahoo|outlook)\\.com")
|> Enum.take(5)
#=> ["000@gmail.com", "000@yahoo.com", "001@gmail.com", "001@yahoo.com", "002@gmail.com"]
```

## An unbounded pattern, streamed lazily

```elixir
Xeger.stream("[0-9a-f]+")
|> Enum.take(5)
#=> ["0", "1", "2", "3", "4"]
```

No `:max_repeat` here -- `[0-9a-f]+` is genuinely infinite, but `stream/2`
enumerates it lazily one length at a time, so `Enum.take/2` only does as
much work as it needs to.

## One random test fixture value

```elixir
Xeger.random("[A-Z]{2}-\\d{6}")
#=> "QK-482017" -- a different match on every call

Xeger.random("[A-Z]{2}-\\d{6}", seed: 123)
#=> reproducible -- pin a seed in a test for a stable fixture value
```

`random/2` picks one match directly instead of enumerating, so it stays
cheap even for a pattern like this one where the full match set is huge.

## Reusing a compiled pattern with the `~X` sigil

```elixir
import Xeger, only: [sigil_X: 2]

~X/[A-Z]{2}\\d{6}/s |> Enum.take(5)
#=> ["AA000000", "AA000001", "AA000002", "AA000003", "AA000004"]
```

## A runnable demo script

`examples/sigil_demo.exs` in this repo walks through several of the
patterns above (plus a couple more) end to end:

```sh
elixir examples/sigil_demo.exs
```
