defmodule SertantaiLegal.Scraper.AmendingLaw.Target do
  @moduledoc """
  Does an amending instruction name a LAT row — its law AND its provision?
  (lat-refactor LR-08, the strict rule: no match unless both are named.)

  - **Law:** the nearest text naming any law decides — the instruction,
    then its context nearest first, then the container's title ("Part II
    Electricity Act 1989"), then the text before the provision (LR-41: its
    Schedule's earlier paragraphs and the body's words naming the Schedule,
    or the body's earlier provisions — "of that Act"). It must name the row's law (its title and year,
    "1989 c. 29", or a defined term meaning it); a nearer text naming only
    another law is no match.
  - **Provision:** "section 25" (or regulation / article / rule) in the
    instruction, else its context nearest first ("that section"); each of
    the row's brackets must be named — "subsection (5)", "paragraphs (b)
    and (c)", or the number of an inserted provision ("5A"). Old words in
    quotes and "after / before subsection (5)" positions don't count. A
    whole-provision instruction (no brackets) on a sub-provision row
    targets the provision's own row.

  Returns `{:ok, section_id}` (the row it targets) or `:no_match`. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Operation, RowRef, Text}

  @kind_words %{
    section: "sections?",
    regulation: "regulations?",
    article: "articles?",
    rule: "rules?"
  }
  @prefix %{section: "s", regulation: "reg", article: "art", rule: "rule"}

  @doc "The row the instruction targets, if it names the row's law and provision."
  @spec match(Text.t() | nil, String.t() | nil, map(), RowRef.t()) ::
          {:ok, String.t()} | :no_match
  def match(text, title, terms, row) do
    case explain(text, title, terms, row) do
      {:ok, sid} -> {:ok, sid}
      {:no_match, _stage} -> :no_match
    end
  end

  @doc """
  `match/4` with the stage that fails (LR-40: why a row is not reached):
  `:law` (the nearest law named isn't the row's), `:number` (no provision
  number named), `:provision_number` (named, not the row's), `:brackets`
  (the row's brackets not all named) or `:other` (not a provision row).
  """
  @spec explain(Text.t() | nil, String.t() | nil, map(), RowRef.t()) ::
          {:ok, String.t()} | {:no_match, :law | :number | :provision_number | :brackets | :other}
  def explain(nil, _title, _terms, _row), do: {:no_match, :other}
  def explain(_text, _title, _terms, %RowRef{kind: :other}), do: {:no_match, :other}

  def explain(%Text{} = text, title, terms, %RowRef{} = row) do
    # quoted old words ("for “Explosives Act 1875” substitute") name nothing
    texts = Enum.map([text.instruction | Enum.reverse(text.context)], &unquote_words/1)

    # LR-41: then the text before the provision (its Schedule, the body
    # naming the Schedule, earlier provisions: "of that Act"), nearest first
    before = Stream.map(text.before, &unquote_words/1)

    with {:law, true} <-
           {:law, law?(Stream.concat(texts ++ List.wrap(title), before), terms, row)},
         {:number, {:ok, numbers}} <- {:number, numbers(texts, row.kind)},
         {:provision_number, true} <-
           {:provision_number, row.number_ref in numbers or inserted?(text, row.number_ref)} do
      case provision(text, row) do
        {:ok, sid} -> {:ok, sid}
        :no_match -> {:no_match, :brackets}
      end
    else
      {stage, _} -> {:no_match, stage}
    end
  end

  # the nearest text naming any law decides — a nearer text naming only
  # another law stops the search
  defp law?(texts, terms, row) do
    texts
    |> Enum.find_value({:named, false}, fn t ->
      case laws(t, terms) do
        [] -> nil
        refs -> {:named, Enum.any?(refs, &row_law?(&1, row))}
      end
    end)
    |> elem(1)
  end

  defp unquote_words(t), do: String.replace(t, ~r/[“"][^”"]*[”"]/u, "")

  defp laws(t, terms) do
    lower = String.downcase(t)
    # a defined term names a law only when it means one, and only as whole
    # words (LR-41: "a", "and", "authority" name no law)
    defined =
      for {term, law} <- terms,
          law.law != nil or law.title != nil,
          Regex.match?(~r/(?<![\w])#{Regex.escape(term)}(?![\w])/u, lower),
          do: law

    titled =
      for [x] <-
            Regex.scan(
              ~r/([A-Z][\w,'’()\- ]*? (?:Act|Regulations|Order|Rules)(?: \(Northern Ireland\))? \d{4})/u,
              t,
              capture: :all_but_first
            ),
          do: %{law: nil, title: x}

    chapters =
      for [y, n] <- Regex.scan(~r/\b(\d{4}) c\. (\d+)/, t, capture: :all_but_first),
          do: %{law: nil, chapter: {y, n}}

    defined ++ titled ++ chapters
  end

  defp row_law?(%{law: law}, row) when is_binary(law), do: law == row.law_name
  defp row_law?(%{chapter: {y, n}}, row), do: y == row.year and n == row.number

  # a title as written may carry the words before it ("In section 6 of the
  # Environmental Protection Act 1990"): it names the row's law when it
  # ends with the row's title and year
  defp row_law?(%{title: t}, row) when is_binary(t) and is_binary(row.title),
    do: String.ends_with?(norm(t), norm("#{row.title} #{row.year}"))

  defp row_law?(_ref, _row), do: false

  defp norm(t),
    do:
      t
      |> String.downcase()
      |> String.replace(~r/^the /, "")
      |> String.replace(~r/[^a-z0-9]+/, " ")
      |> String.trim()

  # the provision numbers the nearest text naming one names
  defp numbers(texts, kind) do
    re = ~r/\b#{@kind_words[kind]} (\d+[A-Z]*)(?:(?:,| and| or| to) (\d+[A-Z]*))*/u

    Enum.find_value(texts, :none, fn t ->
      case Regex.scan(re, t) do
        [] ->
          nil

        found ->
          {:ok,
           found
           |> List.flatten()
           |> Enum.flat_map(&Regex.scan(~r/\d+[A-Z]*/, &1))
           |> List.flatten()}
      end
    end)
  end

  # an inserted provision's own number: the top of a path in the quote
  defp inserted?(%Text{inserted: ins, instruction: i}, number),
    do: i =~ ~r/insert|substitut/i and Enum.any?(ins, &match?([^number | _], &1))

  # the row's brackets, all named by the instruction — or the row's path
  # inserted whole by the quote ([11A, 7, b], or [5A] into a named section)
  defp provision(text, row) do
    named = brackets(text)

    cond do
      quoted_path?(text, row) ->
        {:ok, row.section_id}

      inserted?(text, row.number_ref) ->
        :no_match

      # a provision inserted into the row (not words) doesn't insert the row:
      # only its own path in the quote, or its brackets named, do (LR-41:
      # PIDA 1998 s.15(2) "after subsection (2) insert— (2A)" isn't an
      # insertion of s.235; 1980/60 s.20(1)(b) "at the end of the subsection
      # there shall be added the following paragraph" isn't one of s.4)
      # (a quote numbering what it inserts names it by its own path; a
      # bracket after "In subsection" is where, not what: 1999/1820 "In
      # subsection (1) … insert—" isn't an insertion of 1984/26 s.9(1))
      Operation.of(text) == {"inserted", "inserted"} and
          (text.inserted != [] or
             not (row.subs != [] and Enum.all?(row.subs, &(&1 in inserted_named(text))))) ->
        :no_match

      row.subs != [] and Enum.all?(row.subs, &(&1 in named)) ->
        {:ok, row.section_id}

      row.subs == [] and named == [] ->
        {:ok, row.section_id}

      row.subs == [] ->
        :no_match

      named == [] ->
        {:ok, "#{row.law_name}:#{@prefix[row.kind]}.#{row.number_ref}"}

      true ->
        :no_match
    end
  end

  # the row's path inserted by the quote: the whole provision ([11A, 7]),
  # or the instruction's brackets then the inserted path ((2) + [ca])
  defp quoted_path?(%Text{inserted: ins, instruction: i} = text, row) do
    named = brackets(text)

    i =~ ~r/insert|substitut/i and
      Enum.any?(
        ins,
        &(&1 == [row.number_ref | row.subs] or (row.subs != [] and row.subs == named ++ &1))
      )
  end

  # the brackets an insertion names as what it inserts: those after "In
  # (sub)section / paragraph" are where
  defp inserted_named(%Text{instruction: i} = text),
    do:
      brackets(%{
        text
        | instruction:
            String.replace(
              i,
              ~r/\bIn (?:sub)?(?:section|paragraph|regulation|article) \([^)]*\)/i,
              ""
            )
      })

  defp brackets(%Text{instruction: i}) do
    plain =
      i
      |> String.replace(~r/[“"][^”"]*[”"]/u, "")
      |> String.replace(~r/\b(?:after|before) (?:sub)?(?:section|paragraph) \([^)]*\)/i, "")
      # a renumbering aside names no target (2008/32 Sch. 1 para. 8: "after
      # the existing provision (which becomes subsection (1)) insert—")
      |> String.replace(~r/\(which becomes [^()]*\([^)]*\)\)/i, "")

    own = for [b] <- Regex.scan(~r/\(([0-9A-Za-z]+)\)/, plain, capture: :all_but_first), do: b

    own
  end
end
