defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.Re do
  @moduledoc """
  Python's `re` and string slicing as the census scripts used them
  (`finder.py`, `census.py`, #192): `re.match` (anchored at the start),
  `re.search`, `re.split(maxsplit=1)`, and slices by code-point counts
  over byte positions. Positions are bytes throughout; only a window of
  N characters, or a position carried from one string to another, is
  counted in code points, as Python counts it.
  """

  @type m :: [{integer(), integer()}] | nil

  @doc "`re.match`: captures as `{start, length}` byte pairs, or nil."
  @spec match(Regex.t(), String.t()) :: m()
  def match(re, s) do
    case :re.run(s, re.re_pattern, [:anchored, {:capture, :all, :index}]) do
      {:match, caps} -> caps
      :nomatch -> nil
    end
  end

  @doc "`re.search`: captures as `{start, length}` byte pairs, or nil."
  @spec search(Regex.t(), String.t()) :: m()
  def search(re, s), do: Regex.run(re, s, return: :index)

  @doc "Whether `re.match` matches."
  @spec match?(Regex.t(), String.t()) :: boolean()
  def match?(re, s), do: match(re, s) != nil

  @doc "Every match's captures, in order (`re.finditer`)."
  @spec all(Regex.t(), String.t()) :: [[{integer(), integer()}]]
  def all(re, s), do: Regex.scan(re, s, return: :index)

  @doc "The text of capture `k` (0 the whole match); nil when unset."
  @spec group(m(), String.t(), non_neg_integer()) :: String.t() | nil
  def group(nil, _s, _k), do: nil

  def group(caps, s, k) do
    case Enum.at(caps, k) do
      {start, len} when start >= 0 -> binary_part(s, start, len)
      _ -> nil
    end
  end

  @doc "Where the match (or capture `k`) starts."
  @spec start(m(), non_neg_integer()) :: integer()
  def start(caps, k \\ 0), do: caps |> Enum.at(k) |> elem(0)

  @doc "Where the match (or capture `k`) ends."
  @spec stop(m(), non_neg_integer()) :: integer()
  def stop(caps, k \\ 0) do
    {start, len} = Enum.at(caps, k)
    start + len
  end

  @doc "`s[pos:]` at a byte position."
  @spec from(String.t(), non_neg_integer()) :: String.t()
  def from(s, pos), do: binary_part(s, pos, byte_size(s) - pos)

  @doc "`s[:pos]` at a byte position."
  @spec upto(String.t(), non_neg_integer()) :: String.t()
  def upto(s, pos), do: binary_part(s, 0, pos)

  @doc "`re.split(pattern, s, maxsplit=1)`."
  @spec split1(Regex.t(), String.t()) :: [String.t()]
  def split1(re, s), do: Regex.split(re, s, parts: 2)

  @doc "`re.sub(pattern, repl, s, count=1)` with a literal or computed replacement."
  @spec sub1(Regex.t(), String.t(), String.t() | (String.t() -> String.t())) :: String.t()
  def sub1(re, s, repl) do
    case search(re, s) do
      nil ->
        s

      caps ->
        whole = group(caps, s, 0)
        new = if is_function(repl), do: repl.(whole), else: repl
        upto(s, start(caps)) <> new <> from(s, stop(caps))
    end
  end

  @doc "A match's text blanked to spaces, one per code point (`\" \" * len(m)`)."
  @spec blank(String.t()) :: String.t()
  def blank(text), do: String.duplicate(" ", len(text))

  @doc "`len(text)`: code points, not graphemes."
  @spec len(String.t()) :: non_neg_integer()
  def len(text), do: text |> String.codepoints() |> length()

  @doc "The code-point count of `s[:pos]` for a byte position."
  @spec cps(String.t(), non_neg_integer()) :: non_neg_integer()
  def cps(s, pos), do: s |> upto(pos) |> len()

  @doc "The byte position of code point `n` in `s` (the end when past it)."
  @spec at_cp(String.t(), non_neg_integer()) :: non_neg_integer()
  def at_cp(s, n),
    do: s |> String.codepoints() |> Enum.take(n) |> Enum.map(&byte_size/1) |> Enum.sum()

  @doc """
  `s[pos - n : pos]` in code points, `pos` a byte position: Python's slice,
  a negative start counted from the end (so it is empty but for a short
  string), unless `clamp` (`max(0, pos - n)`).
  """
  @spec window(String.t(), non_neg_integer(), pos_integer(), boolean()) :: String.t()
  def window(s, pos, n, clamp \\ true) do
    at = cps(s, pos)
    first = if at - n < 0 and not clamp, do: max(len(s) + at - n, 0), else: max(at - n, 0)
    if first >= at, do: "", else: from(upto(s, pos), at_cp(s, first))
  end

  @doc "`text[i:]` where `i` is `pos` (bytes in `other`) counted in code points."
  @spec carry_from(String.t(), String.t(), non_neg_integer()) :: String.t()
  def carry_from(text, other, pos), do: from(text, at_cp(text, cps(other, pos)))
end
