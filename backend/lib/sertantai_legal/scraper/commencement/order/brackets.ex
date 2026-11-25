defmodule SertantaiLegal.Scraper.Commencement.Order.Brackets do
  @moduledoc """
  A commencement order item's bracketed asides: its own qualifier, and the
  item without it.

  Pure; part of the order reader (`Commencement.Order`).
  """

  alias SertantaiLegal.Scraper.Commencement.Order.{
    Items,
    Purposes,
    Territory
  }

  alias SertantaiLegal.Scraper.Commencement.Text.Sibling
  alias SertantaiLegal.Scraper.Commencement.TextRefs

  # "Sections 1, 2, 4 to 28, 100 to 104, 105 (in so far as it is not already
  # in force), 159 and 162(2) (in so far as it relates to Part V of Schedule
  # 16)": each item its own bracketed qualifier, the rest fully (SI 1990/2635
  # reg.3, CV-S04 round 4); nil for any other line
  @relating_tail ~r/\b(?:(?:in\s*)?so\s*far|insofar)\s+as\s+(?:it|they)\s+relates?\s+to\s+(.*)$/is

  # (after "both paragraphs", "each Article": "Article 3(3)(a) and 3(6)
  # (both paragraphs for the purposes of Article 40(5))", NISR 1999/325 Sch.1)
  # … or opening with its own exception: "83(1) (except in so far as it
  # relates to section 24 of the Act), (3) (except as already in operation),
  # (6) and (7)" (SI 1964/191 Sch.1 Pt III: s.83(1) partly, the rest fully)
  @bracket_qualifier ~r/\(\s*(?:(?:both|each|all)\s+(?:(?:sub-?)?paragraphs?|articles?|(?:sub-?)?sections?|regulations?|provisions?)\s+)?(?:except\s+)?(?:(?:in\s*)?so\s*far|insofar|to\s+the\s+extent|for\s+the\s+purposes?\s+of|as\s+already\s+in\s+(?:operation|force))\b/i

  @doc "A line's items each with its own bracketed qualifier, as items; nil when the line has none."
  @spec bracket_items(String.t()) :: [tuple()] | nil
  def bracket_items(line) do
    with true <- Regex.match?(@bracket_qualifier, line),
         [_, list | tail] <- list_and_tail(line),
         false <-
           String.replace(list, ~r/\((?:[^()]|\([^()]*\))*\)/u, "") =~
             ~r/\b(?:Schedule|paragraph|Part)s?\b/,
         true <- bare_list?(list),
         items =
           list
           |> Items.split_items()
           |> Enum.flat_map(&String.split(&1, ~r/\s+and\s+(?![^()]*\))/u))
           |> bare_brackets(),
         true <- length(items) > 1 do
      # "… of the Landfill Tax (Scotland) Act 2014 (so far as not then in
      # force)": the list's own qualifier, for items without theirs (SSI 2015/17)
      list_qualifier = tail |> List.first("") |> String.trim() |> bracket_of()

      for item <- items,
          {qualifier} = {bracket_of(item) || list_qualifier},
          plain =
            item
            |> String.replace(~r/\s*\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/u, "")
            |> String.trim(),
          refs = TextRefs.list_refs(plain, "s."),
          refs != [] do
        [{refs, Purposes.of_qualifier(qualifier), Territory.of(line)} | related(qualifier, line)]
      end
      |> List.flatten()
    else
      _ -> nil
    end
  end

  # a list of items and their brackets only: refs, numbers, "and", "to",
  # commas — never an item's own words outside its brackets ("section 35
  # (…), but only for the purpose of making regulations, and in relation to
  # England and Wales (except so far as …)": SI 2017/765 reg.3)
  @bare_list ~r/^(?:[\s,;]|\d+[A-Z]*|\([0-9A-Za-z]+\)|\b(?:and|or|to|sub-?sections?|sections?)\b)*$/i

  defp bare_list?(list), do: list |> without_qualifiers() |> String.match?(@bare_list)

  @list ~r/^\W*(?:the\s+)?sections?\s+(\d.*?)(?:,?\s+of\s+the\s+(?:Act|[A-Z](?:[^()]|\([^()]*\))*?\s+Act\s+\d{4})\b(.*))?$/is
  @worded ~r/\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/u

  # the list and what follows its Act, matched with the worded brackets
  # masked: "of the Act" inside an item's own exception is no end of the
  # list ("83(1) (except in so far as it relates to section 24 of the Act),
  # (3) …": SI 1964/191)
  defp list_and_tail(line) do
    masked =
      Regex.replace(@worded, line, fn m ->
        "(" <> String.duplicate("x", byte_size(m) - 2) <> ")"
      end)

    case Regex.run(@list, masked, return: :index) do
      nil -> nil
      [whole | parts] -> [slice(line, whole) | Enum.map(parts, &slice(line, &1))]
    end
  end

  defp slice(_line, {-1, _}), do: ""
  defp slice(line, {at, len}), do: binary_part(line, at, len)

  # "162(2) (in so far as it relates to Part V of Schedule 16)": the
  # section partly, the Schedule's provisions it relates to fully
  defp related(qualifier, line) do
    with q when is_binary(q) <- qualifier,
         [_, rel] <- Regex.run(@relating_tail, q),
         [_ | _] = rs <-
           rel |> TextRefs.refs(nil) |> Enum.filter(&String.starts_with?(&1, "sch.")) do
      [{rs, nil, Territory.of(line)}]
    else
      _ -> []
    end
  end

  # a bare "(7)" after an item: one item with it where that has no qualifier
  # of its own ("10(6) and (7) (so far as aforesaid)", its qualifier both's:
  # SI 1974/1439), else its section's own ("83(1) (so far as it relates to
  # …) and (2)": s.83(2) fully, SI 1964/1045)
  defp bare_brackets(items), do: items |> Enum.reduce([], &bare_bracket/2) |> Enum.reverse()

  defp bare_bracket(item, [prev | rest] = acc) do
    with [_, number] <- Regex.run(~r/^(\d+[A-Z]*)/u, prev),
         true <- item =~ ~r/^\(\w+\)/u do
      if bracket_of(prev),
        do: [after_qualified(prev, number, item) | acc],
        else: [prev <> " and " <> item | rest]
    else
      _ -> [item | acc]
    end
  end

  defp bare_bracket(item, []), do: [item]

  # the bare bracket at its own level after the qualified item's last
  # designator: "118(1)(a), …, (m) (in so far as it relates to section 111),
  # (n)" → 118(1)(n) (SI 1992/3253 art.3)
  defp after_qualified(prev, number, item) do
    [_, bracket, rest] = Regex.run(~r/^((?:\(\w+\))+)(.*)$/su, item)

    case prev |> without_qualifiers() |> TextRefs.list_refs("") |> List.last() do
      nil -> number <> item
      last -> Sibling.of(last |> String.split("..") |> List.last(), bracket) <> rest
    end
  end

  @doc "The item with its worded brackets taken out."
  @spec without_qualifiers(String.t()) :: String.t()
  def without_qualifiers(item),
    do: String.replace(item, ~r/\s*\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/u, "")

  # an item's own qualifier: its bracket with words in it
  @doc "An item's own qualifier: its last bracket with words in it; nil when none qualifies."
  @spec bracket_of(String.t()) :: String.t() | nil
  def bracket_of(item) do
    case Regex.run(~r/\(((?=[^()]*\s)(?:[^()]|\([^()]*\))*)\)\s*$/u, item) do
      [_, q] -> if Regex.match?(@bracket_qualifier, "(" <> q), do: q
      nil -> nil
    end
  end
end
