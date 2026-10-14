defmodule SertantaiLegal.Scraper.AmendingLaw.CommencingOrder do
  @moduledoc """
  When a commencement order brought an amending provision into force
  (lat-refactor LR-08, hop 2). Only when the order commences the amending
  law ("“the Act” means the Utilities Act 2000", or its title and year in
  the order) and lists the provision:

  - in a Schedule table (provision | purpose; a nested row "subsections (1)
    to (9)" under "Section 5 —"), dated by the Schedule's title ("… COMING
    INTO FORCE ON 1ST OCTOBER 2001"), else by the article bringing the
    Schedule into force (its single date, or its defined "appointed day");
  - in an article's own list ("… shall come into force on 1st March
    1996—" (a) section 10; …), dated by that article.

  "For all (remaining) purposes" (or no purpose) is in force; "save …",
  "so far as …", "for the purpose …" is partly in force. A Part reference
  can't be checked here: no match. Returns `[%{date, qualification, ref}]`
  ([] when the order doesn't date it). Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.{Commencement, DefinedTerms, Doc, Text}

  @type act :: %{law: String.t(), title: String.t() | nil, year: String.t()}
  @type entry :: %{date: Date.t(), qualification: String.t() | nil, ref: String.t()}

  @partial ~r/\bsave\b|\bexcept\b|so far as|for the purposes? of|in so far|in relation to/i

  @doc "The order's commencement entries for the amending provision `id` of `act`."
  @spec dates(Doc.t(), act(), String.t()) :: [entry()]
  def dates(doc, act, id) do
    if commences?(doc, act) do
      target = parse_id(id)

      (schedule_entries(doc) ++ article_entries(doc))
      |> Enum.filter(fn {text, _purpose, _date, _ref} -> covers?(text, target) end)
      |> Enum.map(fn {text, purpose, date, ref} ->
        %{date: date, qualification: qualification(text, purpose), ref: ref}
      end)
      |> Enum.uniq()
    else
      []
    end
  end

  # the order commences the act: its "the Act", else the act's title and year in its text
  defp commences?(doc, act) do
    case DefinedTerms.of(doc)["the act"] do
      %{law: law} when is_binary(law) -> law == act.law
      %{title: t} when is_binary(t) -> named?(t, act)
      _ -> Enum.any?(doc.ids, &named?(Text.words_of(doc, &1), act))
    end
  end

  defp named?(text, %{title: title, year: year}) when is_binary(title),
    do: String.contains?(norm(text), norm("#{title} #{year}"))

  defp named?(_text, _act), do: false

  defp norm(t), do: t |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, " ") |> String.trim()

  # {entry text, purpose, date, ref} from Schedule tables
  defp schedule_entries(doc) do
    for id <- doc.ids,
        String.match?(id, ~r/^schedule(-\d+[A-Z]*)?$/),
        el = Doc.element(doc, id),
        date = schedule_date(doc, el),
        date != nil,
        {text, purpose} <- rows(el),
        do: {text, purpose, date, id}
  end

  defp rows(el) do
    el
    |> xpath(~x".//*[local-name()='tbody']/*[local-name()='tr']"l)
    |> Enum.map(fn tr -> tr |> xpath(~x"./*[local-name()='td']"l) |> Enum.map(&Doc.text/1) end)
    |> Enum.reduce({[], nil}, fn
      [first | rest], {acc, parent} ->
        purpose = List.first(rest)

        cond do
          purpose in [nil, ""] ->
            {acc, first}

          parent && first =~ ~r/^(sub)?(sections?|paragraphs?)\b/ ->
            {[{"#{parent} #{first}", purpose} | acc], parent}

          true ->
            {[{first, purpose} | acc], nil}
        end

      _, acc ->
        acc
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp schedule_date(doc, el) do
    title = el |> xpath(~x"./TitleBlock/Title | ./Title"l) |> Enum.map_join(" ", &Doc.text/1)

    case Commencement.parse_dates(title) do
      [d] -> d
      _ -> article_date(doc, el)
    end
  end

  # the article the Schedule refers to: its single date, or the appointed day
  defp article_date(doc, el) do
    with ref when ref != nil <- xpath(el, ~x"./Reference"),
         [_, n] <- Regex.run(~r/Article (\d+)/i, Doc.text(ref)),
         words = Text.words_of(doc, "article-#{n}") do
      case Commencement.parse_dates(words) do
        [d] -> d
        [] -> if words =~ ~r/appointed day/i, do: appointed_day(doc)
        _ -> nil
      end
    else
      _ -> nil
    end
  end

  defp appointed_day(doc) do
    with %{title: t} when is_binary(t) <- DefinedTerms.of(doc)["the appointed day"],
         [d] <- Commencement.parse_dates(t) do
      d
    else
      _ -> nil
    end
  end

  # an article dating its own list: "… shall come into force on 1st March 1996—"
  defp article_entries(doc) do
    for id <- doc.ids,
        String.match?(id, ~r/^(article|regulation)-\d+[A-Z]*$/),
        words = Text.words_of(doc, id),
        words =~ ~r/come into force on/i,
        [date] <- [Commencement.parse_dates(words)],
        child <- doc.ids,
        String.starts_with?(child, id <> "-"),
        do: {Text.words_of(doc, child), nil, date, id}
  end

  defp qualification(text, purpose) do
    complete? =
      (purpose in [nil, ""] or purpose =~ ~r/^for all (?:remaining )?purposes\.?$/i) and
        not (text =~ @partial)

    if complete?, do: nil, else: "for specified purposes"
  end

  # the amending provision: {:section, n, subs} | {:schedule, s, para, subs}
  defp parse_id(id) do
    case String.split(id, "-") do
      ["schedule", s, "paragraph", p | subs] -> {:schedule, s, p, subs}
      ["schedule", s | _] -> {:schedule, s, nil, []}
      ["schedule"] -> {:schedule, nil, nil, []}
      [kind, n | subs] when kind in ~w(section regulation article) -> {:section, n, subs}
      _ -> :other
    end
  end

  # headings in brackets ("(annual reports)") are not provision refs
  defp clean(text), do: String.replace(text, ~r/\([^)]*\s[^)]*\)/, "")

  defp covers?(text, {:section, n, subs}) do
    t = clean(text)

    case Regex.run(~r/^\s*[Ss]ections? (\d+[A-Z]*)(?: to (\d+[A-Z]*))?(.*)$/, t) do
      [_, a, b, rest] -> section_covers?(n, subs, a, b, rest)
      _ -> false
    end
  end

  defp covers?(text, {:schedule, s, para, subs}) do
    t = clean(text)

    case Regex.run(
           ~r/^\s*Schedules? (\d+[A-Z]*)(,? (?:Part|Pt\.?) [IVXLC0-9]+)?(?:,? paragraphs? (\d+[A-Z]*)(?: to (\d+[A-Z]*))?((?:\([^)]*\))*))?/,
           t
         ) do
      [_, ^s | rest] -> schedule_covers?(para, subs, rest)
      _ -> false
    end
  end

  defp covers?(_text, _target), do: false

  defp section_covers?(n, subs, a, b, rest) do
    cond do
      b != "" -> in_range?(n, a, b) and brackets(rest) == []
      a != n -> false
      true -> paths_cover?(rest, subs)
    end
  end

  # no brackets: the whole section; else the provision's path starts with a
  # listed path, or its first bracket is in a listed range ("(1) to (9)")
  defp paths_cover?(rest, subs) do
    listed = brackets(rest)

    cond do
      listed == [] -> true
      subs == [] -> false
      Enum.any?(listed, &List.starts_with?(subs, &1)) -> true
      true -> ranges(rest) |> Enum.any?(fn {x, y} -> in_range?(hd(subs), x, y) end)
    end
  end

  defp schedule_covers?(_para, _subs, []), do: true
  defp schedule_covers?(_para, _subs, [part | _]) when part != "", do: false
  defp schedule_covers?(_para, _subs, ["", ""]), do: true
  defp schedule_covers?(nil, _subs, _rest), do: false
  defp schedule_covers?(para, _subs, ["", p, "" | _]), do: p == para
  defp schedule_covers?(para, _subs, ["", p, q | _]), do: in_range?(para, p, q)

  # "(1), (2), (3)(b)" → [["1"], ["2"], ["3", "b"]]
  defp brackets(rest) do
    for [group] <- Regex.scan(~r/((?:\([0-9A-Za-z]+\))+)/, rest, capture: :all_but_first),
        do:
          for(
            [b] <- Regex.scan(~r/\(([0-9A-Za-z]+)\)/, group, capture: :all_but_first),
            do: String.downcase(b)
          )
  end

  defp ranges(rest),
    do:
      for(
        [a, b] <- Regex.scan(~r/\((\d+)\) to \((\d+)\)/, rest, capture: :all_but_first),
        do: {a, b}
      )

  defp in_range?(n, a, b) do
    with {n, ""} <- Integer.parse(n), {a, ""} <- Integer.parse(a), {b, ""} <- Integer.parse(b) do
      n >= a and n <= b
    else
      _ -> false
    end
  end
end
