defmodule SertantaiLegal.Scraper.Commencement.Text.Sibling do
  @moduledoc """
  Where a bare bracket in an order's list sits, given the designator before
  it: "33(1)(a)" then "(b)" is 33(1)(b). The bracket takes the level its
  own form names: a number climbs to the numbered level, roman numerals
  after a letter sit under that letter, and a letter after roman numerals
  goes back beside their letter. Pure text.
  """

  @roman ~r/^\([ivxl]{2,}\)$/
  @roman_letter ~r/^\([ivxl]\)$/
  @letter ~r/^\([a-z]+\)$/

  @doc """
  The designator `bracket` names after `last`.

      iex> Sibling.of("33(1)(a)", "(b)")
      "33(1)(b)"
      iex> Sibling.of("68(1)(c)", "(2)")
      "68(2)"
      iex> Sibling.of("100(2)(a)", "(iii)")
      "100(2)(a)(iii)"
      iex> Sibling.of("100(2)(b)(x)", "(g)")
      "100(2)(g)"
  """
  @spec of(String.t(), String.t()) :: String.t()
  def of(last, bracket) do
    depth = length(Regex.scan(~r/\(/, bracket))
    brackets = Regex.scan(~r/\([0-9A-Za-z]+\)/, last) |> List.flatten()
    number = String.replace(last, ~r/\(.*$/, "")
    at = max(length(brackets) - depth, 0)
    at = if depth == 1, do: level(brackets, at, bracket), else: at
    number <> Enum.join(Enum.take(brackets, at)) <> bracket
  end

  # the place of a single `bracket` among `brackets`; `at` is beside the last
  defp level(brackets, at, bracket) do
    cond do
      # "68(1)(c) and (2)" → 68(2), "43(9)(b) and (c) and (10)" → 43(10)
      # (OSRPA 1963 by SI 1964/191)
      numbered?(bracket) and at < length(brackets) and not numbered?(Enum.at(brackets, at)) ->
        numbered_at(Enum.take(brackets, at), at)

      # "(2)(a), (iii) to (vi)": the letter's own sub-items (SI 2005/2714)
      bracket =~ @roman and plain_letter?(List.last(brackets)) ->
        length(brackets)

      # "(b)(vi) and (x) and (g)": back beside the letter (SI 2005/2714)
      plain_letter?(bracket) and under_letter?(brackets) ->
        length(brackets) - 2

      true ->
        at
    end
  end

  defp numbered?(bracket), do: bracket =~ ~r/^\(\d/

  # a letter no roman numeral could be: "(a)", "(aa)", never "(i)" or "(vi)"
  defp plain_letter?(nil), do: false

  defp plain_letter?(bracket),
    do: bracket =~ @letter and not (bracket =~ @roman) and not (bracket =~ @roman_letter)

  # the last bracket a roman numeral under a letter: "(a)(ix)", "(b)(x)"
  defp under_letter?(brackets) do
    case Enum.take(brackets, -2) do
      [above, last] -> above =~ @letter and (last =~ @roman or last =~ @roman_letter)
      _ -> false
    end
  end

  # the last numbered bracket's place, else where it was
  defp numbered_at(brackets, at) do
    case brackets |> Enum.with_index() |> Enum.filter(&numbered?(elem(&1, 0))) do
      [] -> at
      found -> found |> List.last() |> elem(1)
    end
  end
end
