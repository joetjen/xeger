defmodule Xeger.Parser do
  @moduledoc """
  Parser for Xeger pattern syntax.

  Converts a regex-like pattern string into an internal AST representation.

  A thin adapter over the generated parser at `lib/xeger/grammar.ex`
  (compiled from `priv/grammar/xeger.aether` by `mix ichor.gen` -- see
  that file's own banner comment to regenerate it after editing the
  grammar), translating its `Ichor.Error` results to the plain error
  message this module's own callers expect.
  """

  alias Xeger.AST

  @spec parse(binary()) :: {:ok, AST.t()} | {:error, binary()}
  def parse(""), do: {:ok, {:lit, ""}}

  def parse(pattern) when is_binary(pattern) do
    case Xeger.Grammar.run(pattern) do
      {:ok, ast} -> {:ok, ast}
      {:error, error} -> {:error, format_error(error)}
    end
  end

  defp format_error(errors) when is_list(errors), do: Enum.map_join(errors, "\n", &Ichor.Error.format/1)
  defp format_error(error), do: Ichor.Error.format(error)
end
