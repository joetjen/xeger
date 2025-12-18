# Quickstart

## Generate a few matches

```elixir
RegSynth.take("hello( |-)world", 10)
```

## Using the ~G sigil

```elixir
# Compile a pattern
pattern = ~G/[a-z]{3}/

# Stream mode with 's' modifier
~G/a+/s |> Enum.take(5)
#=> ["a", "aa", "aaa", "aaaa", "aaaaa"]

# Take from a compiled pattern
~G/[0-9]{2}/ |> RegSynth.take(10)
#=> ["00", "01", "02", ...]
```

## Use a custom alphabet

```elixir
alphabet = Enum.to_list(?a..?z)
RegSynth.take(".[^a]*", 20, alphabet: alphabet, max_repeat: 4)
```
