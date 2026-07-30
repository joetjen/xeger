# Tutorial

A step-by-step introduction to Xeger: turning a regex-like pattern into
the strings that match it.

## 1. Installation

Add `xeger` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:xeger, "~> 0.1.0"}
  ]
end
```

## 2. Your first pattern

`Xeger.take/3` compiles a pattern and returns the first `n` matches, in
**shortlex** order (shortest strings first, then lexicographically within a
length):

```elixir
Xeger.take("ab", 5)
#=> ["ab"]

Xeger.take("a|b|c", 5)
#=> ["a", "b", "c"]
```

## 3. Repetition and the `:max_repeat` option

`*`, `+`, and `{m,}` are unbounded on paper, and by default Xeger keeps them
that way: `stream/2` (and `take/3`, which is just `stream/2 |> Enum.take/2`)
enumerates them lazily, one length at a time, forever if you let it:

```elixir
Xeger.take("a*", 10)
#=> ["", "a", "aa", "aaa", "aaaa", "aaaaa", "aaaaaa", "aaaaaaa", "aaaaaaaa", "aaaaaaaaa"]
# take/3 only pulls the first 10 -- the underlying stream never actually ends
```

Pass `:max_repeat` to cap unbounded quantifiers at a fixed number of repeats
instead, when you want the *pattern itself* to have only finitely many
matches (e.g. so `Enum.to_list/1` or `Enum.count/1` on the stream terminates):

```elixir
Xeger.take("a*", 10, max_repeat: 3)
#=> ["", "a", "aa", "aaa"]
# now there really are only 4 matches -- take/3 can't return more than exist
```

Bounded repetition (`{2,4}`, `{3}`) isn't affected by `:max_repeat` -- it
already has its own explicit ceiling:

```elixir
Xeger.take("a{2,4}", 10)
#=> ["aa", "aaa", "aaaa"]
```

## 4. Character classes and shorthands

```elixir
Xeger.take("[a-c]", 5)
#=> ["a", "b", "c"]

Xeger.take("[^0-9]", 5, alphabet: Enum.to_list(?0..?9) ++ [?x, ?y])
#=> ["x", "y"]

Xeger.take("\\d", 5)
#=> ["0", "1", "2", "3", "4"]
```

See the [Reference](REFERENCE.md) for the full list of supported classes,
shorthands, and escapes.

## 5. Streaming instead of taking a fixed count

`Xeger.stream/2` returns a lazy `Enumerable.t()` -- useful when a
pattern's match count is unbounded (any `*`/`+`/`{m,}` at the top level,
uncapped by `:max_repeat`) and you want to pull results incrementally
instead of deciding a count up front:

```elixir
Xeger.stream("a+")
|> Enum.take(3)
#=> ["a", "aa", "aaa"]
```

`take/3` is really just `stream/2 |> Enum.take/2` under the hood.

## 6. Compiling a pattern once, reusing it many times

If you're going to draw from the same pattern repeatedly, compile it once
with `Xeger.compile/2` (or the raising `compile!/2`) instead of
re-parsing the pattern string on every call:

```elixir
{:ok, pattern} = Xeger.compile("[a-z]{3}-\\d{4}")

Xeger.take(pattern, 5)
pattern |> Xeger.stream() |> Enum.take(20)
```

`compile/2` returns `{:error, message}` for an invalid pattern instead of
raising, so it composes well with `with`:

```elixir
with {:ok, pattern} <- Xeger.compile(user_supplied_pattern) do
  Xeger.take(pattern, 10)
end
```

## 7. A single random match

`Xeger.random/2` picks one random match directly, without enumerating
anything -- much cheaper than `Xeger.take(pattern, 1)` for a pattern with
a large or unbounded match set:

```elixir
Xeger.random("[a-z]{3}-\\d{4}")
#=> "wkl-6224" -- a different match on every call

Xeger.random("[a-z]{3}-\\d{4}", seed: 42)
#=> "dgo-7071" -- reproducible: same seed, same output, every time
```

For an unbounded quantifier (`*`, `+`, `{m,}`), `random/2` behaves a
little differently from `take/3`/`stream/2`: without `:max_repeat` there's
no finite range to draw a repeat count from uniformly, so each repeat
beyond the pattern's minimum is instead a coin flip on whether to
continue -- unbounded in principle, but almost surely short. Pass
`:max_repeat` for a uniform draw over a fixed range instead, same as
elsewhere:

```elixir
Xeger.random("a*", max_repeat: 4, seed: 1)
#=> "a" -- uniformly one of "", "a", "aa", "aaa", "aaaa"
```

`:alphabet` behaves exactly as it does for `take/3`/`stream/2`.

## 8. The `~X` sigil

For a more idiomatic, `~r`-like feel, import `sigil_X/2` and use the `~X`
sigil instead of calling `random/1`/`compile!/2`/`stream/2` directly:

```elixir
import Xeger, only: [sigil_X: 2]

~X/a+/                     # one random match, same as Xeger.random/1
~X/a+/c                    # compiles instead, same as Xeger.compile!/1
~X/a+/s |> Enum.take(5)    # "s" modifier: stream directly
#=> ["a", "aa", "aaa", "aaaa", "aaaaa"]
```

## 9. Validating a string against a pattern

`Xeger.matches?/2` is a convenience wrapper around Elixir's own `Regex`,
handy in tests for checking that everything `take/3` produced really does
match the source pattern:

```elixir
xs = Xeger.take("[a-b]\\d{2}", 10)
Enum.all?(xs, &Xeger.matches?("[a-b]\\d{2}", &1))
#=> true
```

## Next steps

* [Reference](REFERENCE.md) -- full syntax, options, and API reference
* [Cheatsheet](CHEATSHEET.md) -- quick syntax lookup
* [Examples](EXAMPLES.md) -- worked, realistic patterns
