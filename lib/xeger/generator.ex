defmodule Xeger.Generator do
  @moduledoc """
  Generator for string enumeration from AST patterns.

  Generates strings in shortlex order (shortest first, then lexicographic).

  An unbounded `:rep` node (`*`, `+`, `{m,}`) is capped at `opts[:max_repeat]`
  repeats when given; without it, `stream/2` returns a genuinely infinite
  stream, walking one length at a time forever. A repeated unit that can
  itself match the empty string (e.g. `(a?)*`) would make the per-length
  repeat count `k` unbounded too (`k * 0 <= len` for every `k`), so that case
  is capped at `len + 1` regardless of `:max_repeat` -- otherwise generation
  of that single length would never finish, let alone move on to the next.
  """

  # printable ASCII
  @default_alphabet Enum.to_list(32..126)

  @spec stream(Xeger.AST.t(), keyword()) :: Enumerable.t()
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
    rep_max_len(max_len(node, opts), repeat_ceiling(max, opts))
  end

  # A repeated unit that can only ever match the empty string contributes
  # nothing no matter how many times it repeats; a repeat ceiling of zero
  # (an explicit `{0}`) allows no copies at all -- both cases are finite
  # regardless of the other side, so they're checked before either :infty.
  defp rep_max_len(0, _ceiling), do: 0
  defp rep_max_len(_node_max, 0), do: 0
  defp rep_max_len(:infty, _ceiling), do: :infty
  defp rep_max_len(_node_max, :infty), do: :infty
  defp rep_max_len(node_max, ceiling), do: node_max * ceiling

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
    unit_min = min_len(node, opts)
    cap = repeat_cap(max, unit_min, len, opts)

    Stream.iterate(min, &(&1 + 1))
    |> Stream.take_while(&(&1 <= cap))
    |> Stream.filter(fn k -> k * unit_min <= len end)
    |> Stream.flat_map(fn k ->
      gen_len({:seq, List.duplicate(node, k)}, len, opts)
    end)
  end

  # ---- helpers ----

  # A bounded quantifier (`{m}`/`{m,n}`) already has its own explicit
  # ceiling, unaffected by `:max_repeat`. An unbounded one (`*`, `+`,
  # `{m,}`) is capped by `:max_repeat` only if the caller passed it --
  # otherwise it's genuinely unbounded (`:infty`), which `stream/2`
  # enumerates lazily forever rather than eagerly building a bound.
  defp repeat_ceiling(max, _opts) when is_integer(max), do: max
  defp repeat_ceiling(:infty, opts), do: Keyword.get(opts, :max_repeat, :infty)

  # The exact-length generator still needs *some* finite bound on how many
  # repeats to try for a single `len` even when uncapped, or it would never
  # finish that one length (let alone move on to the next). `len` itself
  # already bounds it when each repeat consumes at least one byte. When the
  # repeated unit can match the empty string (`unit_min == 0`, e.g. `(a?)*`),
  # `k * unit_min <= len` is trivially true for every `k`, so the count needs
  # its own cap instead -- `len + 1` is enough: with a non-empty unit_max,
  # no distinct string of length `len` needs more than `len` contributing
  # copies, and the "+1" is a harmless margin, not a correctness requirement.
  defp repeat_cap(max, _unit_min, _len, _opts) when is_integer(max), do: max

  defp repeat_cap(:infty, unit_min, len, opts) do
    case Keyword.fetch(opts, :max_repeat) do
      {:ok, cap} -> cap
      :error when unit_min > 0 -> div(len, unit_min)
      :error -> len + 1
    end
  end

  defp class_to_codepoints(items) do
    items
    |> Enum.flat_map(fn
      {:char, cp} -> [cp]
      {:range, a, b} when a <= b -> Enum.to_list(a..b)
      {:range, a, b} -> Enum.to_list(b..a)
    end)
    |> Enum.uniq()
  end

  # Each part's "add" (how much more than its own min it can take) is
  # capped by that part's own max_len, not just by the total `rem` left to
  # distribute -- without this, a part with a small fixed max (e.g. a
  # literal, always min == max) still gets offered every value up to `rem`
  # by nonneg_compositions/2, only to have gen_len reject nearly all of
  # them one by one. For a `{:seq, List.duplicate(node, k)}} (a `:rep`
  # unfolded for a given length -- see gen_len/3's `:rep` clause) with a
  # tightly-bounded node, that blind enumeration is combinatorially
  # explosive in `len` (e.g. `a+` at length 50: up to `C(49,24)` candidates
  # for a single length). Pruning by each part's own max keeps it linear
  # in the common case where most parts have a fixed size.
  defp distributions(len, parts, opts) do
    mins = Enum.map(parts, &min_len(&1, opts))
    maxs = Enum.map(parts, &max_len(&1, opts))
    rem = len - Enum.sum(mins)
    caps = Enum.zip(mins, maxs) |> Enum.map(fn {min, max} -> add_cap(min, max) end)

    bounded_compositions(rem, caps)
    |> Stream.map(fn adds ->
      Enum.zip(mins, adds) |> Enum.map(fn {m, a} -> m + a end)
    end)
  end

  defp add_cap(_min, :infty), do: :infty
  defp add_cap(min, max), do: max - min

  defp bounded_compositions(0, []), do: [[]]
  defp bounded_compositions(n, []) when n > 0, do: []
  defp bounded_compositions(n, [_cap | _rest]) when n < 0, do: []

  defp bounded_compositions(n, [cap | rest]) do
    upper = if cap == :infty, do: n, else: min(cap, n)

    Stream.flat_map(0..upper, fn x ->
      bounded_compositions(n - x, rest)
      |> Stream.map(fn r -> [x | r] end)
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
