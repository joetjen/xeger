defmodule RegSynth.Generator do
  @moduledoc """
  Generator for string enumeration from AST patterns.

  Generates strings in shortlex order (shortest first, then lexicographic).
  """

  # printable ASCII
  @default_alphabet Enum.to_list(32..126)

  @spec stream(RegSynth.AST.t(), keyword()) :: Enumerable.t()
  def stream(ast, opts) do
    min = min_len(ast, opts)
    max = max_len(ast, opts)

    case max do
      :infty ->
        Stream.iterate(min, &(&1 + 1))
        |> Stream.flat_map(fn len -> gen_len(ast, len, opts) end)

      n when is_integer(n) ->
        Stream.unfold(min, fn
          len when len <= n -> {gen_len(ast, len, opts), len + 1}
          _ -> nil
        end)
        |> Stream.flat_map(& &1)
    end
  end

  # ---- min length ----
  defp min_len({:lit, s}, _opts), do: byte_size(s)
  defp min_len({:dot}, _opts), do: 1
  defp min_len({:class, _items, _neg?}, _opts), do: 1
  defp min_len({:alt, alts}, opts), do: alts |> Enum.map(&min_len(&1, opts)) |> Enum.min()
  defp min_len({:seq, parts}, opts), do: parts |> Enum.map(&min_len(&1, opts)) |> Enum.sum()

  defp min_len({:rep, node, min, _max}, opts) do
    min * min_len(node, opts)
  end

  # ---- max length ----
  defp max_len({:lit, s}, _opts), do: byte_size(s)
  defp max_len({:dot}, _opts), do: 1
  defp max_len({:class, _items, _neg?}, _opts), do: 1
  defp max_len({:alt, alts}, opts), do: alts |> Enum.map(&max_len(&1, opts)) |> Enum.max()

  defp max_len({:seq, parts}, opts) do
    parts
    |> Enum.map(&max_len(&1, opts))
    |> Enum.reduce(0, fn
      :infty, _acc -> :infty
      _n, :infty -> :infty
      n, acc -> n + acc
    end)
  end

  defp max_len({:rep, node, _min, max}, opts) do
    max_repeat = Keyword.get(opts, :max_repeat, 5)
    max2 = normalize_max(max, max_repeat)

    case max_len(node, opts) do
      :infty -> :infty
      node_max -> max2 * node_max
    end
  end

  # ---- exact-length generation ----
  defp gen_len(_ast, len, _opts) when len < 0, do: []

  defp gen_len({:lit, s}, len, _opts) do
    if byte_size(s) == len, do: [s], else: []
  end

  defp gen_len({:dot}, 1, opts) do
    alphabet = Keyword.get(opts, :alphabet, @default_alphabet)

    alphabet
    |> Enum.sort()
    |> Stream.map(fn cp -> <<cp::utf8>> end)
  end

  defp gen_len({:dot}, _len, _opts), do: []

  defp gen_len({:class, items, neg?}, 1, opts) do
    alphabet = Keyword.get(opts, :alphabet, @default_alphabet)
    allowed = class_to_codepoints(items)

    cps =
      if neg? do
        MapSet.new(alphabet)
        |> MapSet.difference(MapSet.new(allowed))
        |> MapSet.to_list()
      else
        allowed
      end

    cps
    |> Enum.sort()
    |> Stream.map(fn cp -> <<cp::utf8>> end)
  end

  defp gen_len({:class, _items, _neg?}, _len, _opts), do: []

  defp gen_len({:alt, alts}, len, opts) do
    alts
    |> Stream.flat_map(&gen_len(&1, len, opts))
  end

  defp gen_len({:seq, parts}, len, opts) do
    mins = Enum.map(parts, &min_len(&1, opts))

    if Enum.sum(mins) > len do
      []
    else
      distributions(len, parts, opts)
      |> Stream.flat_map(fn lens ->
        streams = Enum.zip(parts, lens) |> Enum.map(fn {p, l} -> gen_len(p, l, opts) end)
        cartesian_concat(streams)
      end)
    end
  end

  defp gen_len({:rep, node, min, max}, len, opts) do
    max_repeat = Keyword.get(opts, :max_repeat, 5)
    max2 = normalize_max(max, max_repeat)

    unit_min = min_len(node, opts)

    Stream.iterate(min, &(&1 + 1))
    |> Stream.take(max2 - min + 1)
    |> Stream.filter(fn k -> k * unit_min <= len end)
    |> Stream.flat_map(fn k ->
      gen_len({:seq, List.duplicate(node, k)}, len, opts)
    end)
  end

  # ---- helpers ----
  defp normalize_max(:infty, cap), do: cap
  defp normalize_max(n, _cap), do: n

  defp class_to_codepoints(items) do
    items
    |> Enum.flat_map(fn
      {:char, cp} -> [cp]
      {:range, a, b} when a <= b -> Enum.to_list(a..b)
      {:range, a, b} -> Enum.to_list(b..a)
    end)
    |> Enum.uniq()
  end

  defp distributions(len, parts, opts) do
    mins = Enum.map(parts, &min_len(&1, opts))
    rem = len - Enum.sum(mins)
    k = length(parts)

    nonneg_compositions(rem, k)
    |> Stream.map(fn adds ->
      Enum.zip(mins, adds) |> Enum.map(fn {m, a} -> m + a end)
    end)
  end

  defp nonneg_compositions(0, k), do: [List.duplicate(0, k)]
  defp nonneg_compositions(_n, 0), do: []
  defp nonneg_compositions(n, 1), do: [[n]]

  defp nonneg_compositions(n, k) do
    Stream.flat_map(0..n, fn x ->
      nonneg_compositions(n - x, k - 1)
      |> Stream.map(fn rest -> [x | rest] end)
    end)
  end

  defp cartesian_concat([]), do: Stream.map([""], & &1)

  defp cartesian_concat([s | rest]) do
    Stream.flat_map(s, fn left ->
      cartesian_concat(rest)
      |> Stream.map(fn right -> left <> right end)
    end)
  end
end
