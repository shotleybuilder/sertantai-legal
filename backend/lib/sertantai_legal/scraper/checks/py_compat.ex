defmodule SertantaiLegal.Scraper.Checks.PyCompat do
  @moduledoc """
  Python's ways, so a check ported from a Python script writes the same
  bytes (#192): `round` (half to even, exactly), `Counter.most_common`
  (ties in first-seen order), `json.dump(indent=N)` (keys in the order
  given, non-ASCII escaped), slicing by code points, and `csv` reading a
  tab-separated file with no quoting.
  """

  @typedoc "A JSON object as ordered pairs, as Python's dicts keep insertion order."
  @type object :: [{String.t(), json()}]
  @type json :: object() | [json()] | String.t() | number() | boolean() | nil

  @doc "Python's `round(x)`: the nearest integer, a tie to the even one."
  @spec round(number()) :: integer()
  def round(x) when is_integer(x), do: x

  def round(x) when is_float(x) do
    {num, den} = Float.ratio(x)
    half_even(num, den)
  end

  @doc "Python's `round(x, digits)`: exact on the float's binary value, a tie to the even digit."
  @spec round(float(), non_neg_integer()) :: float()
  def round(x, digits) when is_float(x) do
    {num, den} = Float.ratio(x)
    scale = Integer.pow(10, digits)
    half_even(num * scale, den) / scale
  end

  defp half_even(num, den) do
    q = Integer.floor_div(num, den)
    r = num - q * den

    cond do
      2 * r > den -> q + 1
      2 * r < den -> q
      rem(q, 2) == 0 -> q
      true -> q + 1
    end
  end

  @doc "`Counter.most_common()`: `{key, count}` pairs by count, ties in first-seen order."
  @spec most_common([{term(), integer()}]) :: [{term(), integer()}]
  def most_common(counts), do: Enum.sort_by(counts, fn {_, n} -> -n end)

  @doc "A counter as first-seen pairs: `key`'s count up by `by`."
  @spec count([{term(), integer()}], term(), integer()) :: [{term(), integer()}]
  def count(counts, key, by \\ 1) do
    case List.keyfind(counts, key, 0) do
      nil -> counts ++ [{key, by}]
      {_, n} -> List.keystore(counts, key, 0, {key, n + by})
    end
  end

  @doc "A counter's count for `key` (0 when absent, as a `Counter` reads)."
  @spec get([{term(), integer()}], term()) :: integer()
  def get(counts, key) do
    case List.keyfind(counts, key, 0) do
      nil -> 0
      {_, n} -> n
    end
  end

  # str.isspace(), as /usr/bin/python3 lists it
  @space [0x9, 0xA, 0xB, 0xC, 0xD, 0x1C, 0x1D, 0x1E, 0x1F, 0x20, 0x85, 0xA0, 0x1680] ++
           Enum.to_list(0x2000..0x200A) ++ [0x2028, 0x2029, 0x202F, 0x205F, 0x3000]

  @doc "`text.strip()`: Python's whitespace off both ends."
  @spec strip(String.t()) :: String.t()
  def strip(text), do: text |> lstrip_cps(@space) |> rstrip_cps(@space)

  @doc "`text.rstrip()`: Python's whitespace off the end."
  @spec rstrip(String.t()) :: String.t()
  def rstrip(text), do: rstrip_cps(text, @space)

  @doc "`text.rstrip(chars)`: any of `chars` off the end."
  @spec rstrip(String.t(), String.t()) :: String.t()
  def rstrip(text, chars), do: rstrip_cps(text, String.to_charlist(chars))

  defp lstrip_cps(text, set) do
    text |> String.to_charlist() |> Enum.drop_while(&(&1 in set)) |> List.to_string()
  end

  defp rstrip_cps(text, set) do
    text
    |> String.to_charlist()
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 in set))
    |> Enum.reverse()
    |> List.to_string()
  end

  @doc "`text[:n]`: the first `n` code points."
  @spec slice(String.t(), non_neg_integer()) :: String.t()
  def slice(text, n), do: text |> String.codepoints() |> Enum.take(n) |> Enum.join()

  @doc "`json.dump(term, indent=indent)`, as bytes."
  @spec json(json(), pos_integer()) :: String.t()
  def json(term, indent), do: IO.iodata_to_binary(value(term, indent, 0))

  defp value([{k, _} | _] = pairs, indent, level) when is_binary(k) do
    pad = String.duplicate(" ", indent * (level + 1))

    fields =
      Enum.map(pairs, fn {k, v} -> [pad, string(k), ": ", value(v, indent, level + 1)] end)

    ["{\n", Enum.intersperse(fields, ",\n"), "\n", String.duplicate(" ", indent * level), "}"]
  end

  defp value([], _indent, _level), do: "{}"
  defp value(nil, _, _), do: "null"
  defp value(true, _, _), do: "true"
  defp value(false, _, _), do: "false"
  defp value(n, _, _) when is_integer(n), do: Integer.to_string(n)
  defp value(x, _, _) when is_float(x), do: Float.to_string(x)
  defp value(s, _, _) when is_binary(s), do: string(s)

  defp string(s), do: [?", Enum.map(String.to_charlist(s), &char/1), ?"]

  defp char(?"), do: "\\\""
  defp char(?\\), do: "\\\\"
  defp char(?\n), do: "\\n"
  defp char(?\r), do: "\\r"
  defp char(?\t), do: "\\t"
  defp char(?\b), do: "\\b"
  defp char(?\f), do: "\\f"
  defp char(c) when c < 0x20 or (c > 0x7E and c <= 0xFFFF), do: u(c)

  defp char(c) when c > 0xFFFF do
    c = c - 0x10000
    [u(0xD800 + Bitwise.bsr(c, 10)), u(0xDC00 + Bitwise.band(c, 0x3FF))]
  end

  defp char(c), do: <<c>>

  defp u(c), do: "\\u" <> String.pad_leading(String.downcase(Integer.to_string(c, 16)), 4, "0")

  @doc """
  `csv.reader(f, delimiter="\\t", quoting=csv.QUOTE_NONE)`: each line's
  fields. Lines end at "\\n" (the dumps hold no "\\r"); blank lines are
  rows of no fields, as the reader gives them.
  """
  @spec rows(String.t()) :: [[String.t()]]
  def rows(text) do
    text
    |> String.split("\n")
    |> then(fn lines -> if List.last(lines) == "", do: Enum.drop(lines, -1), else: lines end)
    |> Enum.map(fn
      "" -> []
      line -> String.split(line, "\t")
    end)
  end

  @doc "`csv.DictReader` over `rows/1`: maps by the header's names, blank rows skipped."
  @spec dict_rows(String.t()) :: [%{String.t() => String.t() | nil}]
  def dict_rows(text) do
    [header | rows] = rows(text)

    for row <- rows, row != [] do
      header
      |> Enum.zip(row ++ List.duplicate(nil, max(length(header) - length(row), 0)))
      |> Map.new()
    end
  end
end
