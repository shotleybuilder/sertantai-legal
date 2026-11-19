defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAffectingSiblings do
  @moduledoc """
  The provisions a number's bracketed parts name in a changes-feed effect's
  affecting provisions: a part after a part of its own form is its sibling
  ("52(8)(9)" → 52(8), 52(9), as the feed's own `Section` children name
  them), a part of another form is nested ("1(1)(a)") (`FeedAffecting`).
  Pure.
  """

  @doc ~S"""
  Each provision's number in a number written with its parts together:
  "52(8)(9)" → ["52(8)", "52(9)"]; "12(2)(3)(a)(4)" → ["12(2)", "12(3)(a)",
  "12(4)"]; "1(1)(a)" → ["1(1)(a)"]. A number takes the place of the number
  before it, or stands at the top with none ("2(a)(3)" → 2(a), 2(3)); any
  other part takes the place of the part just before it when that is of
  its own form ("27(2)(a)(c)" → 27(2)(a), 27(2)(c)) and is nested
  otherwise. The same part again is nested ("3(i)(i)"), and a number with
  a bracket that is no part ("5(1)(1 to 3)") is left whole.
  """
  @spec split(String.t()) :: [String.t()]
  def split(n) do
    [head | parts] = parts(n)
    if Enum.all?(parts, &part?/1), do: walk(head, [], parts), else: [n]
  end

  @doc ~S"""
  The numbers a bare bracketed number names after the number `last`:
  "10(2)(a)" continued by "(4)" → ["10(4)"], by "(b)" → ["10(2)(b)"], by
  "(A)" → ["10(2)(a)(A)"], by "(4)(5)" → ["10(4)", "10(5)"]. `last` itself
  is never among them.
  """
  @spec continued(String.t(), String.t()) :: [String.t()]
  def continued(last, sub) do
    [head | path] = parts(last)
    [first | rest] = parts(sub)
    walk(head, under(path, first, :apart) ++ [first], rest)
  end

  defp parts(n), do: String.split(n, ~r/(?=\()/u, trim: true)

  defp part?(part), do: part =~ ~r/^\([A-Za-z0-9]+\)$/

  # the numbers named, walking the parts: the path so far is a number of
  # its own whenever a part stands in place of one of its parts
  defp walk(head, path, parts) do
    {path, done} = Enum.reduce(parts, {path, []}, &step(head, &1, &2))
    Enum.reverse([head <> Enum.join(path) | done])
  end

  defp step(head, part, {path, done}) do
    case under(path, part, :together) do
      ^path -> {path ++ [part], done}
      kept -> {kept ++ [part], [head <> Enum.join(path) | done]}
    end
  end

  # the parts of the path a part written with it stands under. A number
  # stands in place of the first number, or at the top with none
  # ("2(1)(a)(2)": 2(2)). Any other stands in place of the part just before
  # it when that is of its own form ("(a)(c)", "(i)(ii)", "(aa)(bb)"), and
  # is under it otherwise ("(1)(a)", "(b)(viii)(c)", and "(h)(i)": an "(i)"
  # written with a letter is a roman numeral, as the feed's children read it)
  defp under(path, part, :together) do
    if form(inner(part)) == :number, do: above_number(path), else: beside(path, part)
  end

  # written apart, a part stands in place of the first part of its own
  # kind ("10(2)(a)" by "(4)": 10(4); "26(2)(a)(i)" by "(a)": 26(2)(a));
  # with none, a number stands at the top and a letter under the whole path
  defp under(path, part, :apart) do
    case Enum.split_while(path, &(not alike?(inner(&1), inner(part)))) do
      {before, [_ | _]} -> before
      {all, []} -> if form(inner(part)) == :number, do: [], else: all
    end
  end

  defp above_number(path) do
    case Enum.split_while(path, &(form(inner(&1)) != :number)) do
      {before, [_ | _]} -> before
      {_all, []} -> []
    end
  end

  defp beside(path, part) do
    {before, last} = Enum.split(path, -1)
    if Enum.any?(last, &sibling?(inner(&1), inner(part))), do: before, else: path
  end

  # the same part again is under the first ("3(i)(i)")
  defp sibling?(same, same), do: false
  defp sibling?(a, b), do: same_form?({form(a), a}, {form(b), b})

  # "(i)(v)" count up; "(x)(i)" is a letter with a roman numeral under it
  defp same_form?({:roman, a}, {:roman, b}) when a in ~w(i v x) and b in ~w(i v x),
    do: numeral(a) < numeral(b)

  defp same_form?({form, _}, {form, _}), do: true
  defp same_form?(_, _), do: false

  defp numeral("i"), do: 1
  defp numeral("v"), do: 5
  defp numeral("x"), do: 10

  # "(4)" and "(4A)" are numbers, "(A)" a capital, "(i)", "(ii)" and "(xx)"
  # roman numerals, "(aa)" and "(cc)" doubled letters, "(c)" a letter
  defp form(part) do
    cond do
      part =~ ~r/^\d/ -> :number
      part =~ ~r/^[A-Z]/ -> :capital
      part =~ ~r/^[ivx]+$/ -> :roman
      part =~ ~r/^([a-z])\1+$/ -> :doubled
      part =~ ~r/^[ivxlc]{2,}$/ -> :roman
      true -> :letter
    end
  end

  # parts written apart are alike as numbers, capitals or small letters,
  # and small letters as roman numerals or not: "(ii)" is a roman numeral,
  # "(c)" a letter, "(i)" either
  defp alike?(a, b) do
    case {kind(a), kind(b)} do
      {:letter, :letter} -> roman?(a) == roman?(b) or either?(a) or either?(b)
      {kind, kind} -> true
      _ -> false
    end
  end

  defp kind(part) do
    cond do
      part =~ ~r/^\d/ -> :number
      part =~ ~r/^[A-Z]/ -> :capital
      true -> :letter
    end
  end

  defp roman?(part), do: String.length(part) > 1 and part =~ ~r/^[ivxlc]+$/
  defp either?(part), do: part in ~w(i v x)

  defp inner(part), do: part |> String.trim_leading("(") |> String.trim_trailing(")")
end
