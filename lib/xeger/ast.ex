defmodule Xeger.AST do
  @moduledoc """
  Internal AST for Xeger patterns.

  `Xeger.Parser.Actions` builds this tree from a parse of
  `priv/grammar/xeger.aether`; `Xeger.Generator` is its only
  consumer.
  """

  @type t ::
          {:lit, binary()}
          | {:dot}
          | {:class, [class_item()], boolean()}
          | {:seq, [t()]}
          | {:alt, [t()]}
          | {:rep, t(), non_neg_integer(), non_neg_integer() | :infty}

  @type class_item :: {:char, non_neg_integer()} | {:range, non_neg_integer(), non_neg_integer()}
end
