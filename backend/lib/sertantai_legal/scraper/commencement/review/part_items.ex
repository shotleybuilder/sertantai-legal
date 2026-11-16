defmodule SertantaiLegal.Scraper.Commencement.Review.PartItems do
  @moduledoc """
  A review of the own-clause rules that name a Part or Chapter: each with
  the words of the law that name it, and whether those words limit it
  ("any provision of Parts 1 to 7 which— confers a power …", "so far as
  …") while the rule dates it in full — the Agriculture Act 2020 s.57(1)
  misreading. It reads rules, never shapes them: outside every version
  file's patterns (`Commencement.ReadVersion`, `ChangeVocabulary.Version`).
  Pure.
  """

  alias SertantaiLegal.Scraper.Commencement.Rule

  @type item :: %{
          law: String.t(),
          ref: String.t() | nil,
          treatment: atom(),
          qualified: boolean(),
          limited: boolean(),
          words: String.t()
        }

  @part ~r/^pt\./
  @names ~r/\b(?:Parts?|Chapters?)\b/
  # a completing form is no limit ("so far as not already in force")
  @completing ~r/\b(?:so\s+far\s+as|to\s+the\s+extent\s+that)\s+(?:(?:it|they)\s+(?:is|are|has|have)\s+)?not\s+(?:already|brought|yet|in\s+force)\b/i
  @limit ~r/\b(?:(?:in\s+)?so\s+far\s+as|insofar\s+as|for\s+the\s+purposes?\s+of|to\s+the\s+extent|only\s+(?:for|in)\b|(?:which|that)\s*[—–]|(?:which|that)\s+(?:confers?|modif(?:y|ies)|amends?|relates?|appl(?:y|ies)|makes?|inserts?|affects?|enables?)\b)/iu

  @doc "The rules whose scope or exceptions name a body Part or Chapter."
  @spec part_scoped([Rule.t()]) :: [Rule.t()]
  def part_scoped(rules),
    do: Enum.filter(rules, &(is_list(&1.scope) and Enum.any?(&1.scope, fn r -> r =~ @part end)))

  @doc "Whether `words` limit the provisions they name (a completing form is no limit)."
  @spec limited?(String.t()) :: boolean()
  def limited?(words), do: Regex.match?(@limit, Regex.replace(@completing, words, ""))

  @doc """
  The review items of a law's `rules` (read before `PartScope` writes the
  Parts out), each with its words from `rows` (`OwnClause.doc_rows/1`).
  """
  @spec items(String.t(), [Rule.t()], [map()]) :: [item()]
  def items(law, rules, rows) do
    for rule <- part_scoped(rules) do
      words = words(rule, rows)

      %{
        law: law,
        ref: rule.source.ref,
        treatment: rule.treatment,
        qualified: not Rule.full?(rule),
        limited: limited?(words),
        words: words
      }
    end
  end

  @doc "The items dated in full whose words carry a limit: the misreading."
  @spec full_with_limit([item()]) :: [item()]
  def full_with_limit(items),
    do:
      Enum.filter(items, &(&1.treatment == :provision_dated and not &1.qualified and &1.limited))

  @doc """
  The rules a fresh reading qualifies that the stored reading dated in
  full: `fresh` rules for some purposes or places, not stored, from a
  statement with a stored full rule the fresh reading no longer gives.
  """
  @spec newly_qualified([Rule.t()], [Rule.t()]) :: [Rule.t()]
  def newly_qualified(stored, fresh) do
    gone = for r <- stored -- fresh, r.treatment == :provision_dated, do: r.source.ref
    for r <- fresh -- stored, not Rule.full?(r), r.source.ref in gone, do: r
  end

  @doc "One line per item."
  @spec line(item()) :: String.t()
  def line(i) do
    reading = if i.qualified, do: "qualified", else: "full"
    flag = if i.limited, do: "LIMIT", else: "-"
    "#{i.law} | #{i.ref} | #{i.treatment} | #{reading} | #{flag} | #{i.words}"
  end

  # the statement's items that name one of the rule's Parts; a statement
  # with no such item, its own words
  defp words(%Rule{source: %{ref: ref}} = rule, rows) do
    parts = for "pt." <> rest <- rule.scope, do: rest |> String.split(".") |> hd()
    under = Enum.filter(rows, &under?(bare(&1.section_id), ref))

    case Enum.filter(under, &names?(&1, parts)) do
      [] -> under |> Enum.take(1) |> text()
      named -> text(named)
    end
  end

  defp text(rows), do: Enum.map_join(rows, " ¦ ", &String.trim(&1.text || ""))

  defp under?(_id, nil), do: false
  defp under?(id, ref), do: id == ref or String.starts_with?(id, ref <> "(")

  defp names?(%{text: text} = row, parts) when is_binary(text) do
    this = if text =~ ~r/\bthis\s+Part\b/i, do: [Map.get(row, :part)], else: []
    text =~ @names and Enum.any?(named(text) ++ this, &(&1 in parts))
  end

  defp names?(_row, _parts), do: false

  # the Part numbers the words name, a range written out ("Parts 1 to 7")
  defp named(text) do
    singles =
      for [_, n] <- Regex.scan(~r/\b(?:Parts?|and|to|,)\s+(\d+[A-Z]*|[IVXL]+)\b/, text), do: n

    ranges =
      for [_, a, b] <- Regex.scan(~r/\b(\d+)\s+to\s+(\d+)\b/, text),
          n <- String.to_integer(a)..String.to_integer(b)//1,
          do: Integer.to_string(n)

    singles ++ ranges
  end

  defp bare(id), do: id |> String.split(":") |> List.last()
end
