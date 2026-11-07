defmodule SertantaiLegal.Scraper.Checks.ExtentShapes.Verdicts do
  @moduledoc """
  Whether the extent reader holds what each mined list item names (CV-S05c
  step 2, `verdicts.exs`, #192). The item's kind and place are its own
  statement's, else its sentence's; its provisions `Credit.own_refs/3`'s;
  held, the reader's lists of that kind and place. Verdicts:

  - `read`: every provision it names is held; `partial`: some are;
    `missing`: none, though a list of that kind and place exists;
  - `unread`: no list of that kind and place; `withheld`: not held, but
    every provision it names is in an unread list (deliberate);
  - `unparsed`: it names a provision the reader parses as none;
    `no_refs`: it names none the reader parses;
  - `no_list_statement`: neither it nor its sentence is a list statement;
    `other_law`: it names another law's provisions.

  `run/1` writes `verdicts.tsv` from `items.tsv`. Reads the CLML store and
  the extent reader's cache.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Extent, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Credit, Forms, Named, Places}
  alias SertantaiLegal.Scraper.Checks.ExtentShapes.LawReading

  @other_law ~r/\b(?:of|to|in)\s*,?\s+(?:the\s+[A-Z][^;]*?\b(?:Act|Order|Regulations|Rules|Measure)\b|that\s+Act)/u
  @excluded_at ~r/\b(?:excluding|other\s+than|except)\b/iu

  @doc "`verdicts.tsv` for `items.tsv`, and the counts of laws and items."
  @spec run(String.t()) :: {String.t(), non_neg_integer(), non_neg_integer()}
  def run(items_tsv) do
    by_law = LawReading.sentences(items_tsv)
    lines = LawReading.per_law(by_law, &law_lines/2)

    {LawReading.tsv("items_line\tlaw\tref\tkind\tverdict\town_refs", lines), map_size(by_law),
     length(lines)}
  end

  defp law_lines(law, sents) do
    {doc, e} = LawReading.load(law)

    for [_lead | items] = s <- sents, it <- items do
      {v, own, _held} = verdict(it.text, LawReading.whole(s), it.ref, doc, e)
      Enum.join([it.line, law, it.ref, it.kind, v, Enum.join(own, " ")], "\t")
    end
  end

  @doc "An item's verdict, the provisions it names and those held."
  @spec verdict(String.t(), String.t(), String.t(), map(), map()) ::
          {String.t(), [String.t()], [String.t()]}
  def verdict(item, sentence, ref, doc, e) do
    case statement(item, sentence, doc) do
      {:list, kind, place} -> list_verdict(item, ref, doc, e, kind, place)
      :other_law -> {"other_law", [], []}
      _ -> {"no_list_statement", [], []}
    end
  end

  @doc "An item's statement: its own list statement, else its sentence's; `:other_law` for another law's provisions."
  @spec statement(String.t(), String.t(), map()) :: {:list, term(), term()} | :other_law | term()
  def statement(item, sentence, doc) do
    cond do
      Regex.match?(@other_law, item) ->
        :other_law

      m = Regex.named_captures(Forms.named(), item) ->
        {:list, Named.named_kind(m), Places.places(m["places"])}

      true ->
        case Extent.statement(item, doc.type) do
          {:list, _, _} = s -> s
          _ -> Extent.statement(sentence, doc.type)
        end
    end
  end

  defp list_verdict(item, ref, doc, e, kind, place) do
    held = for {^kind, ^place, refs} <- e.lists, r <- refs, do: r
    withheld = for {:unread, _, refs} <- e.lists, r <- refs, do: r

    case Credit.own_refs(item, ref, doc) do
      :unparsed -> {"unparsed", [], held}
      [] -> {"no_refs", [], held}
      own when held == [] -> {unread_or_withheld(own, withheld), own, held}
      own -> named(drop_excluded(own, item, ref), held, withheld)
    end
  end

  # `own` is never empty here: an item naming no provision is `no_refs`
  defp unread_or_withheld(own, withheld) do
    if Enum.all?(own, &covered?(withheld, &1)), do: "withheld", else: "unread"
  end

  defp named(own, held, withheld) do
    hit = Enum.filter(own, &covered?(held, &1))

    verdict =
      cond do
        length(hit) == length(own) -> "read"
        Enum.all?(own -- hit, &covered?(withheld, &1)) -> "withheld"
        hit != [] -> "partial"
        true -> "missing"
      end

    {verdict, own, held}
  end

  # what the item excludes ("(excluding section 53)") is not counted as named
  defp drop_excluded(own, item, ref) do
    excluded =
      case Regex.split(@excluded_at, item, parts: 2) do
        [_, tail] -> RefList.parse(tail, ref)
        _ -> []
      end

    Enum.reject(own, fn r -> Enum.any?(excluded, &(&1 == r or RefList.covers?(&1, r))) end)
  end

  @doc "True when `r` is in `refs`, or under one of them, or `refs` holds the whole law."
  @spec covered?([String.t()], String.t()) :: boolean()
  def covered?(refs, r), do: "*" in refs or Enum.any?(refs, &(&1 == r or RefList.covers?(&1, r)))
end
