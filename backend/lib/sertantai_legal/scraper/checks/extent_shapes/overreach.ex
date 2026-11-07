defmodule SertantaiLegal.Scraper.Checks.ExtentShapes.Overreach do
  @moduledoc """
  Over-reach in the list items the extent reader holds (CV-S05c step 3,
  `overreach.exs`, #192). For each item of a sentence the reader classes
  as a list, against the stored lists of the item's kind and place:

  - `excluded`: a provision the item excludes ("other than", "except",
    "excluding", "apart from", "with the exception of") is held;
  - `qualified`: a provision named only in a qualified chunk ("section 73
    so far as relating to those Parts") is held as plain;
  - `scope`: "in Part N, sections …": every section of Part N is held,
    though the item names only some.

  `run/1` writes `overreach.tsv` from `items.tsv`. Reads the CLML store
  and the extent reader's cache.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Parts
  alias SertantaiLegal.Scraper.AmendingLaw.RefList
  alias SertantaiLegal.Scraper.Checks.ExtentShapes.{LawReading, Verdicts}

  @excl ~r/\b(?:other\s+than|except(?:\s+for)?|excluding|apart\s+from|with\s+the\s+exception\s+of)\s+(?<ex>(?:[^()]|\([^()]*\))*?)(?:\)|$|;|,\s*(?:and|but)\b)/iu
  @mention ~r/\b(?:this\s+(?:section|article|regulation|rule|Part)\b|(?:sections?|articles?|regulations?|rules?|paragraphs?|Parts?|Chapters?|Schedules?)\s+[\dIVXLC]+[A-Z]*\b)/iu
  @qual ~r/\b(?:so\s+far|in\s*so\s*far|insofar|to\s+the\s+extent)\b/iu
  @in_scope ~r/^\s*in\s+(?<scope>(?:Chapter\s+\S+\s+of\s+)?Part\s+[\dIVXLC]+[A-Z]*)\b[^,]*,\s*(?<rest>sections?\b.*)$/iu

  @doc "`overreach.tsv` for `items.tsv`, and the counts of laws and findings."
  @spec run(String.t()) :: {String.t(), non_neg_integer(), non_neg_integer()}
  def run(items_tsv) do
    by_law = LawReading.sentences(items_tsv, &String.starts_with?(&1.class, "list"))
    lines = LawReading.per_law(by_law, &law_lines/2)

    {LawReading.tsv("items_line\tlaw\tref\tclass\trule\theld_refs\tn\tshape\ttext", lines),
     map_size(by_law), length(lines)}
  end

  defp law_lines(law, sents) do
    {doc, e} = LawReading.load(law)

    for [_ | items] = s <- sents,
        it <- items,
        it.kind in ["item", "other_item"],
        {:list, kind, place} <- [Verdicts.statement(it.text, LawReading.whole(s), doc)],
        held = for({^kind, ^place, rs} <- e.lists, r <- rs, do: r),
        {rule, rs} <- checks(it.text, it.ref, doc, held) do
      Enum.join(
        [
          it.line,
          law,
          it.ref,
          it.class,
          rule,
          Enum.join(Enum.take(rs, 12), " "),
          length(rs),
          it.shape,
          String.slice(it.text, 0, 250)
        ],
        "\t"
      )
    end
  end

  defp checks(item, ref, doc, held) do
    for {rule, rs} <- [
          excluded: excluded(item, ref, doc, held),
          qualified: qualified(item, ref, doc, held),
          scope: scope(item, ref, doc, held)
        ],
        rs != [],
        do: {rule, rs}
  end

  defp refs(text, ref, doc),
    do: Enum.uniq(RefList.parse(text, ref) ++ Parts.parts(Parts.qualify_chapters(text), doc, ref))

  defp excluded(item, ref, doc, held) do
    for [e] <- Regex.scan(@excl, item, capture: ["ex"]),
        r <- refs(e, ref, doc),
        Verdicts.covered?(held, r),
        uniq: true,
        do: r
  end

  # chunks cut at each provision named; a chunk with a qualifier, and the
  # provisions named only there
  defp qualified(item, ref, doc, held) do
    starts = for [{at, _}] <- Regex.scan(@mention, item, return: :index), do: at
    ends = Enum.drop(starts, 1) ++ [byte_size(item)]
    chunks = for {a, b} <- Enum.zip(starts, ends), do: binary_part(item, a, b - a)
    {q, plain} = Enum.split_with(chunks, &Regex.match?(@qual, &1))
    plain_refs = Enum.flat_map(plain, &refs(&1, ref, doc))

    for c <- q,
        r <- refs(c, ref, doc),
        r not in plain_refs,
        Verdicts.covered?(held, r),
        not Enum.any?(plain_refs, &RefList.covers?(&1, r)),
        uniq: true,
        do: r
  end

  defp scope(item, ref, doc, held) do
    case Regex.named_captures(@in_scope, item) do
      %{"scope" => s, "rest" => rest} ->
        named = refs(rest, ref, doc)

        extra =
          s |> Parts.qualify_chapters() |> Parts.parts(doc, ref) |> Enum.reject(&(&1 in named))

        if extra != [] and Enum.all?(extra, &Verdicts.covered?(held, &1)), do: extra, else: []

      _ ->
        []
    end
  end
end
