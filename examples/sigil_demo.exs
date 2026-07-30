#!/usr/bin/env elixir

# Demo script showing the ~X sigil in action

import Xeger, only: [sigil_X: 2]

IO.puts("=== Xeger ~X Sigil Demo ===\n")

# Example 1: A single random match
IO.puts("1. A single random match (no modifier):")
match = ~X/[A-Z][a-z]{3}[0-9]{2}/
IO.inspect(match, label: "Match")
IO.puts("")

# Example 2: Reproducible output via Xeger.random/2's :seed
IO.puts("2. Reproducible output with a seed:")
seeded = Xeger.random("[A-Z][a-z]{3}[0-9]{2}", seed: 42)
IO.inspect(seeded, label: "Seeded match")
IO.puts("")

# Example 3: Stream mode
IO.puts("3. Stream mode with 's' modifier:")
results = ~X/[a-c]/s |> Enum.take(5)
IO.inspect(results, label: "Results")
IO.puts("")

# Example 4: Generate passwords
IO.puts("4. Generate simple passwords:")
passwords = ~X/[A-Z][a-z]{3}[0-9]{2}/s |> Enum.take(10)
IO.inspect(passwords, label: "Passwords")
IO.puts("")

# Example 5: Phone numbers
IO.puts("5. Generate phone number patterns:")
phones = ~X/555-[0-9]{4}/s |> Enum.take(5)
IO.inspect(phones, label: "Phone numbers")
IO.puts("")

# Example 6: Hex colors
IO.puts("6. Generate hex color codes:")
colors = ~X/#[0-9A-F]{6}/s |> Enum.take(10)
IO.inspect(colors, label: "Colors")
IO.puts("")

# Example 7: Using take with a compiled pattern ('c' modifier)
IO.puts("7. Using take with a compiled pattern:")
pattern = ~X/v[0-9]\.[0-9]/c
versions = Xeger.take(pattern, 20)
IO.inspect(versions, label: "Versions")
IO.puts("")

# Example 8: Repetition patterns
IO.puts("8. Repetition patterns:")
results = ~X/x+/s |> Enum.take(5)
IO.inspect(results, label: "x+")
IO.puts("")

IO.puts("=== Demo Complete ===")
