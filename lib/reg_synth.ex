defmodule RegSynth do
  @moduledoc """
  RegSynth turns a *regex-like* pattern into a stream of strings that match it.

  This library is intentionally focused on a **generatable subset** of regular expressions.
  In particular, it does **not** support lookarounds or backreferences.

  ## Supported syntax (subset)

  * Literals: `abc`
  * Escapes: `\\(`, `\\]`, `\\{`, etc.
  * Dot: `.` (matches one codepoint from `:alphabet`)
  * Alternation: `a|b|c`
  * Grouping: `(ab|c)`
  * Character classes: `[abc]`, `[a-z]`, `[^0-9]`
  * Shorthands: `\\d` (0-9), `\\w` (A-Z a-z 0-9 _), `\\s` (whitespace)
  * Repetition: `*`, `+`, `?`, `{m}`, `{m,}`, `{m,n}`

  Quantifiers that are unbounded (`*`, `+`, `{m,}`) are capped by `:max_repeat`.

  ## Ordering

  `stream/2` enumerates matches in **shortlex** order:
  shortest strings first, then (within the same length) a deterministic order.

  ## Options

  * `:max_repeat` (default: `5`) - cap for unbounded repetition
  * `:alphabet` (default: printable ASCII) - set used for `.` and negated classes

  ## Examples

      iex> RegSynth.take("a(b|c){2}\\d", 6)
      ["abb0", "abb1", "abb2", "abb3", "abb4", "abb5"]

      iex> RegSynth.take("a*", 6, max_repeat: 5)
      ["", "a", "aa", "aaa", "aaaa", "aaaaa"]

  """

  alias RegSynth.{Generator, Parser}

  defmodule Pattern do
    @moduledoc """
    A compiled RegSynth pattern, as returned by `RegSynth.compile/2` and
    `RegSynth.compile!/2`.

    Treat it as an opaque token to pass to `RegSynth.stream/2` or
    `RegSynth.take/3` -- the compiled AST it carries is meant for this
    library's own internal use, not for callers to pattern-match on.
    """

    defstruct [:ast, :opts]

    @type t :: %__MODULE__{ast: RegSynth.AST.t(), opts: keyword()}
  end

  @type option ::
          {:max_repeat, non_neg_integer()}
          | {:alphabet, [non_neg_integer()]}

  @doc """
  Compile a pattern into a `%RegSynth.Pattern{}`.

  Returns `{:ok, pattern}` or `{:error, message}`.
  """
  @spec compile(binary(), [option()]) :: {:ok, Pattern.t()} | {:error, binary()}
  def compile(pattern, opts \\ []) when is_binary(pattern) do
    with {:ok, ast} <- Parser.parse(pattern) do
      {:ok, %Pattern{ast: ast, opts: opts}}
    end
  end

  @doc """
  Compile a pattern into a `%RegSynth.Pattern{}` or raise.
  """
  @spec compile!(binary(), [option()]) :: Pattern.t()
  def compile!(pattern, opts \\ []) do
    case compile(pattern, opts) do
      {:ok, compiled} ->
        compiled

      {:error, msg} ->
        raise ArgumentError, "invalid pattern: #{msg}"
    end
  end

  @doc """
  Create an (often infinite) stream of matches.
  """
  @spec stream(Pattern.t() | binary(), [option()]) :: Enumerable.t()
  def stream(pattern_or_compiled, opts \\ [])

  def stream(%Pattern{ast: ast, opts: base_opts}, opts) do
    Generator.stream(ast, Keyword.merge(base_opts, opts))
  end

  def stream(pattern, opts) when is_binary(pattern) do
    compile!(pattern, opts) |> stream([])
  end

  @doc """
  Convenience: take `n` matches from a pattern.

  Accepts either a binary pattern string or a compiled `Pattern.t()`.
  """
  @spec take(Pattern.t() | binary(), pos_integer(), [option()]) :: [binary()]
  def take(pattern, n, opts \\ [])

  def take(pattern, n, opts) when is_binary(pattern) and is_integer(n) and n >= 0 do
    stream(pattern, opts) |> Enum.take(n)
  end

  def take(%Pattern{} = pattern, n, opts) when is_integer(n) and n >= 0 do
    stream(pattern, opts) |> Enum.take(n)
  end

  @doc """
  Sanity helper: test a string against Elixir's `Regex`.

  This is useful for tests and debugging (not used in generation).
  """
  @spec matches?(binary(), binary()) :: boolean()
  def matches?(pattern, string) when is_binary(pattern) and is_binary(string) do
    Regex.match?(Regex.compile!(pattern), string)
  rescue
    _ -> false
  end

  @doc ~S"""
  Custom sigil for creating RegSynth patterns.

  The `~G` sigil (for "generate") provides a convenient way to create compiled RegSynth patterns.

  ## Modifiers

  * `c` - compile only (returns `Pattern.t()`)
  * `s` - stream mode (returns `Enumerable.t()`)

  Without modifiers, returns a compiled `Pattern.t()`.

  ## Examples

      iex> ~G/a+/
      %RegSynth.Pattern{ast: {:rep, {:lit, "a"}, 1, :infty}, opts: []}

      iex> ~G/a+/s |> Enum.take(3)
      ["a", "aa", "aaa"]

      iex> pattern = ~G/[0-9]{3}/c
      iex> RegSynth.take(pattern, 5)
      ["000", "001", "002", "003", "004"]

  """
  @spec sigil_G(binary(), charlist()) :: Pattern.t() | Enumerable.t()
  def sigil_G(pattern, modifiers \\ [])

  def sigil_G(pattern, [?s]) when is_binary(pattern) do
    compile!(pattern) |> stream([])
  end

  def sigil_G(pattern, [?c]) when is_binary(pattern) do
    compile!(pattern)
  end

  def sigil_G(pattern, []) when is_binary(pattern) do
    compile!(pattern)
  end
end
