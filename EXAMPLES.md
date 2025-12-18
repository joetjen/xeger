# Examples

## Email-ish usernames

```elixir
pattern = "[a-z][a-z0-9_]{2,5}"
RegSynth.take(pattern, 25)
```

## Version strings

```elixir
RegSynth.take("v\\d{1,2}\\.\\d{1,2}", 30)
```
