# Tutorial

A step-by-step introduction to RegSynth: turning a regex-like pattern into
the strings that match it.

## 1. Installation

Add `regsynth` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:regsynth, "~> 0.1.0"}
  ]
end
```

## 2. Your first pattern

`RegSynth.take/3` compiles a pattern and returns the first `n` matches, in
**shortlex** order (shortest strings first, then lexicographically within a
length):

```elixir
RegSynth.take("ab", 5)
#=> ["ab"]

RegSynth.take("a|b|c", 5)
#=> ["a", "b", "c"]
```

## 3. Repetition and the `:max_repeat` option

`*`, `+`, and `{m,}` are unbounded on paper, but RegSynth has to generate a
finite list, so every unbounded quantifier is capped by the `:max_repeat`
option (default `5`):

```elixir
RegSynth.take("a*", 10)
#=> ["", "a", "aa", "aaa", "aaaa", "aaaaa"]
# only 6 results: max_repeat defaults to 5, so "a*" tops out at 5 a's

RegSynth.take("a*", 10, max_repeat: 8)
#=> ["", "a", "aa", "aaa", "aaaa", "aaaaa", "aaaaaa", "aaaaaaa", "aaaaaaaa"]
```

Bounded repetition (`{2,4}`, `{3}`) isn't affected by `:max_repeat` -- it
already has its own explicit ceiling:

```elixir
RegSynth.take("a{2,4}", 10)
#=> ["aa", "aaa", "aaaa"]
```

## 4. Character classes and shorthands

```elixir
RegSynth.take("[a-c]", 5)
#=> ["a", "b", "c"]

RegSynth.take("[^0-9]", 5, alphabet: Enum.to_list(?0..?9) ++ [?x, ?y])
#=> ["x", "y"]

RegSynth.take("\\d", 5)
#=> ["0", "1", "2", "3", "4"]
```

See the [Reference](REFERENCE.md) for the full list of supported classes,
shorthands, and escapes.

## 5. Streaming instead of taking a fixed count

`RegSynth.stream/2` returns a lazy `Enumerable.t()` -- useful when a
pattern's match count is unbounded (any `*`/`+`/`{m,}` at the top level) and
you want to pull results incrementally instead of deciding a count up front:

```elixir
RegSynth.stream("a+", max_repeat: 100)
|> Enum.take(3)
#=> ["a", "aa", "aaa"]
```

`take/3` is really just `stream/2 |> Enum.take/2` under the hood.

## 6. Compiling a pattern once, reusing it many times

If you're going to draw from the same pattern repeatedly, compile it once
with `RegSynth.compile/2` (or the raising `compile!/2`) instead of
re-parsing the pattern string on every call:

```elixir
{:ok, pattern} = RegSynth.compile("[a-z]{3}-\\d{4}")

RegSynth.take(pattern, 5)
pattern |> RegSynth.stream() |> Enum.take(20)
```

`compile/2` returns `{:error, message}` for an invalid pattern instead of
raising, so it composes well with `with`:

```elixir
with {:ok, pattern} <- RegSynth.compile(user_supplied_pattern) do
  RegSynth.take(pattern, 10)
end
```

## 7. The `~G` sigil

For a more idiomatic, `~r`-like feel, import `sigil_G/2` and use the `~G`
sigil instead of calling `compile!/2`/`stream/2` directly:

```elixir
import RegSynth, only: [sigil_G: 2]

~G/a+/                     # compiles, same as RegSynth.compile!/1
~G/a+/c                    # same, explicit "compile" modifier
~G/a+/s |> Enum.take(5)    # "s" modifier: stream directly
#=> ["a", "aa", "aaa", "aaaa", "aaaaa"]
```

## 8. Validating a string against a pattern

`RegSynth.matches?/2` is a convenience wrapper around Elixir's own `Regex`,
handy in tests for checking that everything `take/3` produced really does
match the source pattern:

```elixir
xs = RegSynth.take("[a-b]\\d{2}", 10)
Enum.all?(xs, &RegSynth.matches?("[a-b]\\d{2}", &1))
#=> true
```

## Next steps

* [Reference](REFERENCE.md) -- full syntax, options, and API reference
* [Cheatsheet](CHEATSHEET.md) -- quick syntax lookup
* [Examples](EXAMPLES.md) -- worked, realistic patterns
