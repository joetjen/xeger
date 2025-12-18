defmodule RegSynth.Parser do
  @moduledoc """
  Parser for RegSynth pattern syntax.

  Converts a regex-like pattern string into an internal AST representation.
  """

  alias RegSynth.AST

  @type state :: %{bin: binary(), i: non_neg_integer(), len: non_neg_integer()}

  @spec parse(binary()) :: {:ok, AST.t()} | {:error, binary()}
  def parse(pattern) when is_binary(pattern) do
    st = %{bin: pattern, i: 0, len: byte_size(pattern)}

    if st.len == 0 do
      {:ok, {:lit, ""}}
    else
      case parse_expr(st) do
        {:ok, ast, st2} ->
          if st2.i == st2.len do
            {:ok, normalize(ast)}
          else
            {:error, "unexpected trailing input at byte #{st2.i}"}
          end

        {:error, msg, st2} ->
          {:error, "#{msg} at byte #{st2.i}"}
      end
    end
  end

  # expr := concat ('|' concat)*
  defp parse_expr(st) do
    with {:ok, left, st1} <- parse_concat(st) do
      parse_expr_rest(left, st1)
    end
  end

  defp parse_expr_rest(left, st) do
    case peek(st) do
      ?| ->
        st1 = bump(st, 1)

        with {:ok, right, st2} <- parse_concat(st1) do
          parse_expr_rest({:alt, [left, right]}, st2)
        end

      _ ->
        {:ok, left, st}
    end
  end

  # concat := piece+
  defp parse_concat(st) do
    case parse_piece(st) do
      {:ok, first, st1} ->
        parse_concat_rest([first], st1)

      {:error, _msg, _st} ->
        {:error, "expected term", st}
    end
  end

  defp parse_concat_rest(acc, st) do
    case peek(st) do
      nil ->
        {:ok, mk_seq(Enum.reverse(acc)), st}

      ch when ch in [?), ?|] ->
        {:ok, mk_seq(Enum.reverse(acc)), st}

      _ ->
        case parse_piece(st) do
          {:ok, node, st1} -> parse_concat_rest([node | acc], st1)
          {:error, _msg, _st1} -> {:ok, mk_seq(Enum.reverse(acc)), st}
        end
    end
  end

  # piece := atom quant?
  defp parse_piece(st) do
    with {:ok, atom, st1} <- parse_atom(st) do
      case parse_quant(st1) do
        {:ok, {min, max}, st2} -> {:ok, {:rep, atom, min, max}, st2}
        :none -> {:ok, atom, st1}
        {:error, msg, stx} -> {:error, msg, stx}
      end
    end
  end

  # atom := literal | '.' | class | group | escape
  defp parse_atom(st) do
    case peek(st) do
      nil ->
        {:error, "unexpected end of input", st}

      ?. ->
        {:ok, {:dot}, bump(st, 1)}

      ?( ->
        st1 = bump(st, 1)

        with {:ok, inner, st2} <- parse_group_body(st1) do
          case peek(st2) do
            ?) -> {:ok, inner, bump(st2, 1)}
            _ -> {:error, "missing closing ')'", st2}
          end
        end

      ?[ ->
        parse_class(st)

      ?\\ ->
        parse_escape(st)

      ch when ch in [?), ?|, ?*, ?+, ??, ?{] ->
        {:error, "unexpected character #{inspect(<<ch>>)}", st}

      _ ->
        parse_literal(st)
    end
  end

  # Allow empty group "()" as matching empty string.
  defp parse_group_body(st) do
    case peek(st) do
      ?) -> {:ok, {:lit, ""}, st}
      _ -> parse_expr(st)
    end
  end

  defp parse_literal(st) do
    {lit, st1} =
      take_while(st, fn ch ->
        ch not in [nil, ?\\, ?(, ?), ?[, ?|, ?*, ?+, ??, ?{, ?.]
      end)

    if lit == "" do
      {:error, "expected literal", st}
    else
      {:ok, {:lit, lit}, st1}
    end
  end

  defp parse_escape(st) do
    # consume backslash
    st1 = bump(st, 1)

    case peek(st1) do
      nil ->
        {:error, "dangling escape", st1}

      ?d ->
        {:ok, {:class, [{:range, ?0, ?9}], false}, bump(st1, 1)}

      ?w ->
        {:ok,
         {:class,
          [
            {:range, ?0, ?9},
            {:range, ?A, ?Z},
            {:range, ?a, ?z},
            {:char, ?_}
          ], false}, bump(st1, 1)}

      ?s ->
        {:ok, {:class, [{:char, ?\s}, {:char, ?\t}, {:char, ?\n}, {:char, ?\r}], false}, bump(st1, 1)}

      ch ->
        # escaped literal byte
        {:ok, {:lit, <<ch>>}, bump(st1, 1)}
    end
  end

  defp parse_class(st) do
    st1 = bump(st, 1)

    {neg?, st2} =
      case peek(st1) do
        ?^ -> {true, bump(st1, 1)}
        _ -> {false, st1}
      end

    with {:ok, items, st3} <- parse_class_items([], st2) do
      case peek(st3) do
        ?] -> {:ok, {:class, items, neg?}, bump(st3, 1)}
        _ -> {:error, "missing closing ']'", st3}
      end
    end
  end

  defp parse_class_items(acc, st) do
    case peek(st) do
      nil ->
        {:error, "unexpected end of class", st}

      ?] ->
        {:ok, Enum.reverse(acc), st}

      ?\\ ->
        with {:ok, node, st1} <- parse_escape(st) do
          acc2 =
            case node do
              {:class, items, false} -> Enum.reverse(items) ++ acc
              {:lit, <<cp>>} -> [{:char, cp} | acc]
              _ -> acc
            end

          parse_class_items(acc2, st1)
        end

      ch ->
        st1 = bump(st, 1)

        case peek(st1) do
          ?- ->
            st2 = bump(st1, 1)

            case peek(st2) do
              nil ->
                {:error, "unterminated range", st2}

              ?] ->
                # '-' treated as literal if it precedes closing bracket
                parse_class_items([{:char, ?-}, {:char, ch} | acc], st2)

              ch2 ->
                st3 = bump(st2, 1)
                parse_class_items([{:range, ch, ch2} | acc], st3)
            end

          _ ->
            parse_class_items([{:char, ch} | acc], st1)
        end
    end
  end

  # quant := '*' | '+' | '?' | '{m}' | '{m,}' | '{m,n}'
  defp parse_quant(st) do
    case peek(st) do
      ?* -> {:ok, {0, :infty}, bump(st, 1)}
      ?+ -> {:ok, {1, :infty}, bump(st, 1)}
      ?? -> {:ok, {0, 1}, bump(st, 1)}
      ?{ -> parse_braces(st)
      _ -> :none
    end
  end

  defp parse_braces(st) do
    st1 = bump(st, 1)

    with {:ok, m, st2} <- parse_int(st1),
         {:ok, bounds, st3} <- parse_braces_rest(m, st2) do
      {:ok, bounds, st3}
    else
      {:error, msg, stx} -> {:error, msg, stx}
    end
  end

  defp parse_braces_rest(m, st) do
    case peek(st) do
      ?} ->
        {:ok, {m, m}, bump(st, 1)}

      ?, ->
        st1 = bump(st, 1)

        case peek(st1) do
          ?} ->
            {:ok, {m, :infty}, bump(st1, 1)}

          _ ->
            with {:ok, n, st2} <- parse_int(st1) do
              cond do
                n < m ->
                  {:error, "repetition max must be >= min", st2}

                peek(st2) == ?} ->
                  {:ok, {m, n}, bump(st2, 1)}

                true ->
                  {:error, "missing closing '}'", st2}
              end
            end
        end

      _ ->
        {:error, "invalid repetition", st}
    end
  end

  defp parse_int(st) do
    {digits, st1} = take_while(st, fn ch -> ch in ?0..?9 end)

    if digits == "" do
      {:error, "expected integer", st}
    else
      {:ok, String.to_integer(digits), st1}
    end
  end

  # ---- normalization ----
  defp normalize({:seq, parts}) do
    parts
    |> Enum.map(&normalize/1)
    |> merge_lits()
    |> case do
      [] -> {:lit, ""}
      [one] -> one
      many -> {:seq, many}
    end
  end

  defp normalize({:alt, alts}) do
    alts
    |> Enum.flat_map(fn
      {:alt, xs} -> xs
      other -> [other]
    end)
    |> Enum.map(&normalize/1)
    |> case do
      [one] -> one
      many -> {:alt, many}
    end
  end

  defp normalize({:rep, node, min, max}), do: {:rep, normalize(node), min, max}
  defp normalize(other), do: other

  defp merge_lits(nodes) do
    Enum.reduce(nodes, [], fn
      {:lit, s}, [{:lit, prev} | rest] ->
        [{:lit, prev <> s} | rest]

      node, acc ->
        [node | acc]
    end)
    |> Enum.reverse()
  end

  defp mk_seq([]), do: {:lit, ""}
  defp mk_seq([one]), do: one
  defp mk_seq(many), do: {:seq, many}

  # ---- byte helpers ----
  defp peek(%{i: i, len: len}) when i >= len, do: nil
  defp peek(%{bin: bin, i: i}), do: :binary.at(bin, i)

  defp bump(st, n), do: %{st | i: st.i + n}

  defp take_while(st, fun) do
    start = st.i
    i = take_while_i(st, fun)
    {binary_part(st.bin, start, i - start), %{st | i: i}}
  end

  defp take_while_i(%{i: i, len: len}, _fun) when i >= len, do: i

  defp take_while_i(%{bin: bin, i: i} = st, fun) do
    ch = :binary.at(bin, i)

    if fun.(ch) do
      take_while_i(%{st | i: i + 1}, fun)
    else
      i
    end
  end
end
