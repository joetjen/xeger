defmodule Xeger.Random do
  @moduledoc """
  Generates a single random string matching an AST, without enumerating the
  full match set: makes one random choice at each node (which alternative,
  how many repeats, which codepoint) instead of walking every possibility.

  Threads an explicit `:rand` state through generation rather than touching
  the process's global `:rand` state, so `Xeger.random/2`'s `:seed` option
  is reproducible without side-affecting unrelated code sharing the same
  process.

  An unbounded `:rep` node (`*`, `+`, `{m,}`) draws its repeat count
  uniformly from `min..opts[:max_repeat]` when given. Without `:max_repeat`
  there's no upper bound to draw uniformly from, so each repeat beyond the
  pattern's own minimum is instead a coin flip (`p = 0.5`) on whether to
  continue -- unbounded in principle, geometrically distributed (so almost
  surely short) in practice.
  """

  alias Xeger.AST

  @default_alphabet Enum.to_list(32..126)
  @continue_probability 0.5

  @spec generate(AST.t(), keyword(), :rand.state()) :: {binary(), :rand.state()}
  def generate(ast, opts, rand_state)

  def generate({:lit, s}, _opts, rand_state), do: {s, rand_state}

  def generate({:dot}, opts, rand_state) do
    alphabet = Keyword.get(opts, :alphabet, @default_alphabet)
    random_char(alphabet, rand_state)
  end

  def generate({:class, items, neg?}, opts, rand_state) do
    alphabet = Keyword.get(opts, :alphabet, @default_alphabet)
    random_char(AST.class_codepoints(items, neg?, alphabet), rand_state)
  end

  def generate({:alt, alts}, opts, rand_state) do
    {alt, rand_state} = random_elem(alts, rand_state)
    generate(alt, opts, rand_state)
  end

  def generate({:seq, parts}, opts, rand_state) do
    {strings, rand_state} = Enum.map_reduce(parts, rand_state, &generate(&1, opts, &2))
    {IO.iodata_to_binary(strings), rand_state}
  end

  def generate({:rep, node, min, max}, opts, rand_state) do
    ceiling = repeat_ceiling(max, opts)
    {count, rand_state} = random_repeat_count(min, ceiling, rand_state)
    {strings, rand_state} = Enum.map_reduce(1..count//1, rand_state, fn _, rs -> generate(node, opts, rs) end)
    {IO.iodata_to_binary(strings), rand_state}
  end

  # ---- helpers ----

  # Bounded quantifiers (`{m}`/`{m,n}`) already have their own explicit
  # ceiling. An unbounded one (`*`, `+`, `{m,}`) is capped by `:max_repeat`
  # only if given -- otherwise `random_repeat_count/3` falls back to a
  # coin-flip continuation instead of a uniform draw.
  defp repeat_ceiling(max, _opts) when is_integer(max), do: max
  defp repeat_ceiling(:infty, opts), do: Keyword.get(opts, :max_repeat, :infty)

  defp random_repeat_count(min, max, rand_state) when is_integer(max) and max <= min do
    {min, rand_state}
  end

  defp random_repeat_count(min, max, rand_state) when is_integer(max) do
    {x, rand_state} = :rand.uniform_s(max - min + 1, rand_state)
    {min + x - 1, rand_state}
  end

  defp random_repeat_count(min, :infty, rand_state), do: geometric_count(min, rand_state)

  defp geometric_count(count, rand_state) do
    {x, rand_state} = :rand.uniform_s(rand_state)

    if x < @continue_probability do
      geometric_count(count + 1, rand_state)
    else
      {count, rand_state}
    end
  end

  defp random_elem([], _rand_state) do
    raise ArgumentError, "pattern has no possible matches (empty character class / alphabet)"
  end

  defp random_elem(list, rand_state) do
    {idx, rand_state} = :rand.uniform_s(length(list), rand_state)
    {Enum.at(list, idx - 1), rand_state}
  end

  defp random_char(codepoints, rand_state) do
    {cp, rand_state} = random_elem(codepoints, rand_state)
    {<<cp::utf8>>, rand_state}
  end
end
