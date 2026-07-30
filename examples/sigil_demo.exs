#!/usr/bin/env elixir

# Demo script showing the new ~G sigil in action

import Xeger, only: [sigil_G: 2]

IO.puts("=== Xeger ~G Sigil Demo ===\n")

# Example 1: Simple pattern compilation
IO.puts("1. Compile a simple pattern:")
pattern = ~G/hello/
IO.inspect(pattern, label: "Pattern")
IO.puts("")

# Example 2: Stream mode
IO.puts("2. Stream mode with 's' modifier:")
results = ~G/[a-c]/s |> Enum.take(5)
IO.inspect(results, label: "Results")
IO.puts("")

# Example 3: Generate passwords
IO.puts("3. Generate simple passwords:")
passwords = ~G/[A-Z][a-z]{3}[0-9]{2}/s |> Enum.take(10)
IO.inspect(passwords, label: "Passwords")
IO.puts("")

# Example 4: Phone numbers
IO.puts("4. Generate phone number patterns:")
phones = ~G/555-[0-9]{4}/s |> Enum.take(5)
IO.inspect(phones, label: "Phone numbers")
IO.puts("")

# Example 5: Hex colors
IO.puts("5. Generate hex color codes:")
colors = ~G/#[0-9A-F]{6}/s |> Enum.take(10)
IO.inspect(colors, label: "Colors")
IO.puts("")

# Example 6: Using compiled pattern with take
IO.puts("6. Using take with compiled pattern:")
pattern = ~G/v[0-9]\.[0-9]/
versions = Xeger.take(pattern, 20)
IO.inspect(versions, label: "Versions")
IO.puts("")

# Example 7: Repetition patterns
IO.puts("7. Repetition patterns:")
results = ~G/x+/s |> Enum.take(5)
IO.inspect(results, label: "x+")
IO.puts("")

IO.puts("=== Demo Complete ===")
