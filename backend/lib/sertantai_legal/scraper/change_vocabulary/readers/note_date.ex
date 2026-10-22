defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.NoteDate do
  @moduledoc """
  A gap filled from the amending law (CV-07; Jason 2026-10-22: "Use Notes
  as pointers when we have a gap. We can always get a date from the actual
  amending law."). A change no source dates, typically an older change
  legislation.gov.uk records only as markup (before its changes feed),
  takes its date from the amending law's own commencement text, at the
  amending provision its feed record names (`:feed :affecting`), else its
  note (`:markup :affecting`): pointers both.

  The date is the law's (source `:commencement`, primary), with a `:via`
  claim (`:feed` or `:note`) saying what pointed where to read. The deepest
  provisions named decide (a Schedule paragraph over the section
  introducing the Schedule); if they disagree, no date (a visible gap).

  Pure: the amending laws' commencement rules come in as data.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw
  alias SertantaiLegal.Scraper.Commencement.Rule
  alias SertantaiLegal.Scraper.LatRef

  @dated [{:feed, :date}, {:feed, :date_first}, {:commencement, :date}, {:law_text, :date}]

  @doc "The date claims for `change` when it has a gap and a pointer; else []."
  @spec claims(Change.t(), %{String.t() => [Rule.t()]}) :: [Claim.t()]
  def claims(%Change{} = c, commencement) do
    law = Change.value(c, :feed, :by) || Change.value(c, :markup, :cited)

    # the feed's named provisions, else the note's
    {refs, via} =
      case Change.values(c, :feed, :affecting) |> List.flatten() do
        [] -> {Change.values(c, :markup, :affecting) |> List.flatten(), :note}
        feed -> {feed, :feed}
      end

    with true <- undated?(c),
         true <- refs != [],
         [_ | _] = rules <- Map.get(commencement, law, []),
         %Date{} = date <- date(rules, deepest(refs)) do
      Claim.new(:commencement, :date, date, c.key) ++ Claim.new(:commencement, :via, via, c.key)
    else
      _ -> []
    end
  end

  @doc """
  The amending law's extent for a change no feed record carries it for
  (the feed reader claims it there): the law the note cites, at the
  provisions it names (`AmendingLaw.Extent`), else its own extent. A
  competence alone doesn't confine an insertion (V1-04). [] where a source
  claims it already, or the law's extent isn't read.
  """
  @spec extent_claims(Change.t(), %{String.t() => SertantaiLegal.Scraper.AmendingLaw.Extent.t()}) ::
          [Claim.t()]
  def extent_claims(%Change{} = c, extents) do
    alias SertantaiLegal.Scraper.AmendingLaw.Extent

    law = Change.value(c, :markup, :cited) || Change.value(c, :feed, :by)
    refs = Change.values(c, :markup, :affecting) |> List.flatten()
    op = Change.value(c, :markup, :operation) || Change.value(c, :law_text, :operation)

    with [] <- Change.values(c, :law_text, :extent),
         %Extent{} = e <- Map.get(extents, law),
         false <- Extent.competence_only?(e) and op == :inserted,
         code when is_binary(code) <- of(e, refs) do
      Claim.new(:law_text, :extent, code, c.key)
    else
      _ -> []
    end
  end

  # no provision named: the law's own extent (its clause, else its powers,
  # else its legislature's competence)
  defp of(e, []), do: e.default || e.powers || e.competence

  defp of(e, refs) do
    case SertantaiLegal.Scraper.AmendingLaw.Extent.of_change(e, deepest(refs)) do
      code when is_binary(code) -> code
      _ -> nil
    end
  end

  defp undated?(c), do: Enum.all?(@dated, fn {s, a} -> Change.values(c, s, a) == [] end)

  # the most specific provisions named (a paragraph, not its Schedule's
  # introducing section)
  defp deepest(refs) do
    depth = &length(LatRef.ancestors(&1))
    max = refs |> Enum.map(depth) |> Enum.max()
    Enum.filter(refs, &(depth.(&1) == max))
  end

  defp date(rules, refs) do
    case refs |> Enum.map(&AmendingLaw.commenced_on(rules, &1)) |> Enum.uniq() do
      [%Date{} = d] -> d
      _ -> nil
    end
  end
end
