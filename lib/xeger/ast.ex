defmodule Xeger.AST do
  @moduledoc """
  Internal AST for Xeger patterns.

  `Xeger.Parser.Actions` builds this tree from a parse of
  `priv/grammar/xeger.aether`; `Xeger.Generator` and `Xeger.Random` are its
  consumers.
  """

  @type t ::
          {:lit, binary()}
          | {:dot}
          | {:class, [class_item()], boolean()}
          | {:seq, [t()]}
          | {:alt, [t()]}
          | {:rep, t(), non_neg_integer(), non_neg_integer() | :infty}

  @type class_item :: {:char, non_neg_integer()} | {:range, non_neg_integer(), non_neg_integer()}

  @doc """
  Resolves a `:class` node's `items`/`neg?` (as matched against `alphabet`)
  to the concrete list of codepoints it allows. Shared by `Xeger.Generator`
  (which enumerates all of them) and `Xeger.Random` (which picks one).
  """
  @spec class_codepoints([class_item()], boolean(), [non_neg_integer()]) :: [non_neg_integer()]
  def class_codepoints(items, neg?, alphabet) do
    allowed =
      items
      |> Enum.flat_map(fn
        {:char, cp} -> [cp]
        {:range, a, b} when a <= b -> Enum.to_list(a..b)
        {:range, a, b} -> Enum.to_list(b..a)
      end)
      |> Enum.uniq()

    if neg? do
      MapSet.new(alphabet) |> MapSet.difference(MapSet.new(allowed)) |> MapSet.to_list()
    else
      allowed
    end
  end
end
