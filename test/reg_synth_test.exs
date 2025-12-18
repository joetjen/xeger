defmodule RegSynthTest do
  use ExUnit.Case, async: true

  test "enumerates simple literals" do
    assert RegSynth.take("ab", 10) == ["ab"]
  end

  test "alternation" do
    assert RegSynth.take("a|b", 10) == ["a", "b"]
  end

  test "repetition with cap" do
    assert RegSynth.take("a*", 6, max_repeat: 5) == ["", "a", "aa", "aaa", "aaaa", "aaaaa"]
  end

  test "class and digit" do
    xs = RegSynth.take("[ab]\\d", 6)
    assert Enum.all?(xs, &RegSynth.matches?("[ab]\\d", &1))
    assert length(xs) == 6
  end

  test "group + bounded repeat" do
    xs = RegSynth.take("(ab|c){2}", 20)
    assert Enum.all?(xs, &RegSynth.matches?("(ab|c){2}", &1))
    refute Enum.empty?(xs)
  end

  test "empty group matches empty string" do
    assert RegSynth.take("()", 10) == [""]
  end

  test "dot matches single characters" do
    xs = RegSynth.take(".", 10)
    assert length(xs) == 10
    assert Enum.all?(xs, &(String.length(&1) == 1))
  end

  test "character class range" do
    xs = RegSynth.take("[a-c]", 5)
    assert xs == ["a", "b", "c"]
  end

  test "negated character class" do
    xs = RegSynth.take("[^0-9]", 10, alphabet: Enum.to_list(?0..?9) ++ [?a, ?b])
    assert Enum.all?(xs, fn x -> x == "a" or x == "b" end)
  end

  test "plus quantifier" do
    xs = RegSynth.take("a+", 4, max_repeat: 3)
    assert xs == ["a", "aa", "aaa"]
  end

  test "question mark quantifier" do
    xs = RegSynth.take("a?", 5)
    assert xs == ["", "a"]
  end

  test "bounded repetition {m,n}" do
    xs = RegSynth.take("a{2,3}", 5)
    assert xs == ["aa", "aaa"]
  end

  test "exact repetition {m}" do
    xs = RegSynth.take("a{3}", 5)
    assert xs == ["aaa"]
  end

  test "unbounded repetition {m,}" do
    xs = RegSynth.take("a{2,}", 4, max_repeat: 4)
    assert xs == ["aa", "aaa", "aaaa"]
  end

  test "sequence of patterns" do
    xs = RegSynth.take("ab", 5)
    assert xs == ["ab"]
  end

  test "nested alternation" do
    xs = RegSynth.take("(a|b)(c|d)", 10)
    assert Enum.sort(xs) == ["ac", "ad", "bc", "bd"]
  end

  test "escaped characters" do
    xs = RegSynth.take("\\(a\\)", 5)
    assert xs == ["(a)"]
  end

  test "compile/1 returns ok tuple" do
    assert {:ok, %RegSynth.Pattern{}} = RegSynth.compile("abc")
  end

  test "compile/1 returns error for invalid pattern" do
    assert {:error, _msg} = RegSynth.compile("(abc")
  end

  test "compile!/1 raises on invalid pattern" do
    assert_raise ArgumentError, fn ->
      RegSynth.compile!("(abc")
    end
  end

  test "stream/1 with compiled pattern" do
    pattern = RegSynth.compile!("a|b")
    xs = pattern |> RegSynth.stream([]) |> Enum.take(5)
    assert xs == ["a", "b"]
  end

  test "matches?/2 validates correctly" do
    assert RegSynth.matches?("a+", "aaa")
    refute RegSynth.matches?("a+", "")
  end

  test "whitespace shorthand \\s" do
    xs = RegSynth.take("\\s", 10)
    assert Enum.all?(xs, &(&1 in [" ", "\t", "\n", "\r"]))
  end

  test "word shorthand \\w" do
    xs = RegSynth.take("\\w", 10)

    assert Enum.all?(xs, fn x ->
             ch = String.to_charlist(x) |> hd()
             ch in ?0..?9 or ch in ?A..?Z or ch in ?a..?z or ch == ?_
           end)
  end

  test "digit shorthand \\d" do
    xs = RegSynth.take("\\d", 10)
    assert xs == ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
  end

  test "complex pattern" do
    xs = RegSynth.take("[a-b]\\d{2}", 5)
    assert Enum.all?(xs, &RegSynth.matches?("[a-b]\\d{2}", &1))
    assert length(xs) == 5
  end

  test "empty pattern returns empty string" do
    {:ok, pattern} = RegSynth.compile("")
    xs = pattern |> RegSynth.stream([]) |> Enum.take(5)
    assert xs == [""]
  end

  describe "sigil_G" do
    import RegSynth, only: [sigil_G: 2]

    test "creates a compiled pattern without modifiers" do
      pattern = ~G/a+/
      assert %RegSynth.Pattern{} = pattern
      assert pattern.ast == {:rep, {:lit, "a"}, 1, :infty}
    end

    test "creates a compiled pattern with 'c' modifier" do
      pattern = ~G/a+/c
      assert %RegSynth.Pattern{} = pattern
    end

    test "creates a stream with 's' modifier" do
      stream = ~G/ab/s
      xs = Enum.take(stream, 2)
      assert xs == ["ab"]
    end

    test "works with character classes" do
      pattern = ~G/[a-c]/
      xs = RegSynth.stream(pattern) |> Enum.take(5)
      assert xs == ["a", "b", "c"]
    end

    test "works with alternation" do
      stream = ~G/x|y/s
      xs = Enum.take(stream, 5)
      assert xs == ["x", "y"]
    end

    test "works with repetition" do
      stream = ~G/z*/s
      xs = Enum.take(stream, 3)
      assert xs == ["", "z", "zz"]
    end

    test "works with complex patterns" do
      pattern = ~G/[0-9]{2}/
      xs = RegSynth.take(pattern, 5)
      assert xs == ["00", "01", "02", "03", "04"]
    end
  end
end
