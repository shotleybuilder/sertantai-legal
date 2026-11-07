defmodule SertantaiLegal.Scraper.Checks.ExtentShapes.Defaults do
  @moduledoc """
  Default sentences carrying lettered items that state their own extent
  (CV-S05c, `defaults.exs`, run-03, #192): "In this Act— (a) … extend to
  Scotland; … but save as aforesaid, this Act extends to England and Wales
  only". Each such item's provisions (`Credit.own_refs/3`) must be in some
  list the reader holds (any kind, unread included); one in none is a
  silent drop. `run/1` writes `defaults.tsv` from `sentences.tsv`. Reads
  the CLML store and the extent reader's cache.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Credit, Units}
  alias SertantaiLegal.Scraper.Checks.ExtentShapes.{LawReading, Verdicts}

  @doc "`defaults.tsv` for `sentences.tsv`, and the counts of sentences and items."
  @spec run(String.t()) :: {String.t(), non_neg_integer(), non_neg_integer()}
  def run(sentences_tsv) do
    rows =
      sentences_tsv
      |> String.split("\n")
      |> Enum.drop(1)
      |> Enum.reject(&(&1 == ""))
      # each field its own binary, not a slice of the file (`LawReading`)
      |> Enum.map(&(&1 |> String.split("\t") |> Enum.map(fn f -> :binary.copy(f) end)))
      |> Enum.filter(fn [_, _, class, s] ->
        String.starts_with?(class, "default") and s =~ ~r/[—–]/u
      end)

    lines = rows |> Enum.group_by(&hd/1) |> LawReading.per_law(&law_lines/2)
    {LawReading.tsv("law\tref\tclass\tmissing\titem", lines), length(rows), length(lines)}
  end

  defp law_lines(law, sents) do
    {doc, e} = LawReading.load(law)
    held = for {_, _, refs} <- e.lists, r <- refs, do: r

    for [_, ref, class, s] <- sents,
        item <- s |> Units.statements() |> tl(),
        item =~ ~r/\b(?:extends?|extend|same\s+extent)\b/u,
        own = Credit.own_refs(item, ref, doc),
        is_list(own) and own != [],
        missing = Enum.reject(own, &Verdicts.covered?(held, &1)),
        missing != [] do
      Enum.join([law, ref, class, Enum.join(missing, " "), String.slice(item, 0, 200)], "\t")
    end
  end
end
