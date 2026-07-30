defmodule RegSynth.Parser.Actions do
  @moduledoc """
  Turns a parse of `priv/grammar/regsynth.aether` into a `RegSynth.AST.t()`
  directly -- unlike a typical `Ichor.Actions` module (which usually
  builds a `Grammar.IR` tree, an executable-grammar representation),
  this one targets RegSynth's own much smaller AST straight away, since
  that's the only thing `RegSynth.Generator` ever consumes.

  Only the rules/tokens that need to become something other than their
  own matched text implement a callback here; everything else falls
  back to `Ichor.Actions`' defaults (see its moduledoc).
  """

  alias Ichor.Error

  @behaviour Ichor.Actions

  # ---- leaf tokens ---------------------------------------------------

  @impl true
  def handle_token(:DOT, _text, _ctx), do: {:ok, {:dot}}
  def handle_token(:STAR, _text, _ctx), do: {:ok, {0, :infty}}
  def handle_token(:PLUS, _text, _ctx), do: {:ok, {1, :infty}}
  def handle_token(:QUESTION, _text, _ctx), do: {:ok, {0, 1}}
  def handle_token(:ESCAPED_CHAR, <<"\\", char::utf8>>, _ctx), do: {:ok, <<char::utf8>>}

  def handle_token(:SHORTHAND_CLASS, "\\d", _ctx) do
    {:ok, {:class, [{:range, ?0, ?9}], false}}
  end

  def handle_token(:SHORTHAND_CLASS, "\\w", _ctx) do
    {:ok,
     {:class,
      [
        {:range, ?0, ?9},
        {:range, ?A, ?Z},
        {:range, ?a, ?z},
        {:char, ?_}
      ], false}}
  end

  def handle_token(:SHORTHAND_CLASS, "\\s", _ctx) do
    {:ok, {:class, [{:char, ?\s}, {:char, ?\t}, {:char, ?\n}, {:char, ?\r}], false}}
  end

  # LITERAL_CHAR/CARET/DASH/COMMA/DIGIT need no override here -- the
  # default token handling (raw matched text, unchanged) is already
  # exactly the one-character string `handle_rule(:atom, ...)`/
  # `class_atom`'s callers below want to wrap or read a codepoint from.

  # ---- rules -----------------------------------------------------------

  # `atom`'s `group`/`char_class`/DOT/SHORTHAND_CLASS alternatives are
  # already `RegSynth.AST.t()` nodes by the time they get here (built
  # above, or by `group`/`char_class` themselves, below) -- only the
  # plain-character alternatives still need wrapping in `{:lit, _}`.
  # Anything else falls through to `Ichor.Actions`' single-capture
  # pass-through default.
  @impl true
  def handle_rule(:atom, %{LITERAL_CHAR: cap}, ctx), do: wrap_lit(cap, ctx)
  def handle_rule(:atom, %{ESCAPED_CHAR: cap}, ctx), do: wrap_lit(cap, ctx)
  def handle_rule(:atom, %{CARET: cap}, ctx), do: wrap_lit(cap, ctx)
  def handle_rule(:atom, %{DASH: cap}, ctx), do: wrap_lit(cap, ctx)
  def handle_rule(:atom, %{COMMA: cap}, ctx), do: wrap_lit(cap, ctx)
  def handle_rule(:atom, %{DIGIT: cap}, ctx), do: wrap_lit(cap, ctx)

  # `piece := atom quant?` -- `{:rep, atom, min, max}` when quantified,
  # the bare atom otherwise.
  def handle_rule(:piece, %{atom: atom_cap} = captures, ctx) do
    with {:ok, atom_ast, ctx} <- atom_cap.eval.(ctx) do
      case Map.fetch(captures, :quant) do
        {:ok, quant_cap} ->
          with {:ok, {min, max}, ctx} <- quant_cap.eval.(ctx) do
            {:ok, {:rep, atom_ast, min, max}, ctx}
          end

        :error ->
          {:ok, atom_ast, ctx}
      end
    end
  end

  # `bound := LBRACE min:(DIGIT+) (COMMA max:(DIGIT*))? RBRACE` -- `min`/
  # `max` each collapse to their own matched span's plain text (no
  # inner *named* captures under either), so `String.to_integer/1`
  # applies directly, exactly as `Ichor.ABNF.Actions`' own `:repeat`
  # rule (the same `min:(DIGIT*) ... max:(DIGIT*)` shape) already relies
  # on elsewhere in this same grammar-compiler.
  def handle_rule(:bound, captures, ctx) do
    with {:ok, min_text, ctx} <- captures.min.eval.(ctx) do
      min = String.to_integer(min_text)

      case Map.fetch(captures, :max) do
        {:ok, max_cap} ->
          with {:ok, max_text, ctx} <- max_cap.eval.(ctx) do
            resolve_bound(min, max_text, ctx)
          end

        :error ->
          {:ok, {min, min}, ctx}
      end
    end
  end

  # `group := LPAREN RPAREN | LPAREN body:expr RPAREN` -- an empty group
  # matches the empty string; a non-empty one is just its inner pattern.
  def handle_rule(:group, %{body: cap}, ctx), do: cap.eval.(ctx)
  def handle_rule(:group, _captures, ctx), do: {:ok, {:lit, ""}, ctx}

  # `char_class := LBRACKET CARET? class_item+ RBRACKET` -- each
  # `class_item` already evaluates to a *list* of class items (a
  # `SHORTHAND_CLASS` item expands to several at once), so the class's
  # own item list is their concatenation.
  def handle_rule(:char_class, captures, ctx) do
    with {:ok, %{class_item: item_lists}, ctx} <-
           Ichor.Actions.eval_all(%{class_item: captures.class_item}, ctx) do
      {:ok, {:class, Enum.concat(item_lists), Map.has_key?(captures, :CARET)}, ctx}
    end
  end

  # `class_item := range | SHORTHAND_CLASS | class_atom` -- normalized
  # to a list in every case so `char_class` above can just concatenate.
  def handle_rule(:class_item, %{range: cap}, ctx) do
    with {:ok, range_item, ctx} <- cap.eval.(ctx), do: {:ok, [range_item], ctx}
  end

  def handle_rule(:class_item, %{SHORTHAND_CLASS: cap}, ctx) do
    with {:ok, {:class, items, false}, ctx} <- cap.eval.(ctx), do: {:ok, items, ctx}
  end

  def handle_rule(:class_item, %{class_atom: cap}, ctx) do
    with {:ok, text, ctx} <- cap.eval.(ctx), do: {:ok, [{:char, codepoint(text)}], ctx}
  end

  # `range := from:class_atom DASH !RBRACKET to:class_atom`
  def handle_rule(:range, %{from: from_cap, to: to_cap}, ctx) do
    with {:ok, from_text, ctx} <- from_cap.eval.(ctx),
         {:ok, to_text, ctx} <- to_cap.eval.(ctx) do
      {:ok, {:range, codepoint(from_text), codepoint(to_text)}, ctx}
    end
  end

  # `concat := piece+` -- zero pieces never actually happens (`+`), but
  # `seq_of/1` stays total rather than assuming that invariant holds.
  def handle_rule(:concat, %{piece: pieces}, ctx) do
    with {:ok, %{piece: irs}, ctx} <- Ichor.Actions.eval_all(%{piece: pieces}, ctx) do
      {:ok, seq_of(irs), ctx}
    end
  end

  # `expr := concat (PIPE concat)*`
  def handle_rule(:expr, %{concat: concats}, ctx) do
    with {:ok, %{concat: irs}, ctx} <- Ichor.Actions.eval_all(%{concat: concats}, ctx) do
      {:ok, wrap_alts(irs), ctx}
    end
  end

  # ---- helpers -----------------------------------------------------------

  defp wrap_lit(cap, ctx) do
    with {:ok, text, ctx} <- cap.eval.(ctx), do: {:ok, {:lit, text}, ctx}
  end

  defp resolve_bound(min, "", ctx), do: {:ok, {min, :infty}, ctx}

  defp resolve_bound(min, max_text, ctx) do
    max = String.to_integer(max_text)

    if max < min do
      {:error, Error.new(message: "repetition max must be >= min", stage: :action)}
    else
      {:ok, {min, max}, ctx}
    end
  end

  defp seq_of([]), do: {:lit, ""}
  defp seq_of([one]), do: one
  defp seq_of(many), do: {:seq, many}

  defp wrap_alts([one]), do: one
  defp wrap_alts(many), do: {:alt, many}

  defp codepoint(<<cp::utf8>>), do: cp
end
