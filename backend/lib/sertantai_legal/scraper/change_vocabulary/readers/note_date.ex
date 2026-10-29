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

  @type why ::
          :not_a_gap
          | {:dated, Date.t(), :feed | :note}
          | {:undated,
             :no_amending_law
             | :no_pointer
             | :rules_not_held
             | :no_text_rules
             | :appointed
             | :unread
             | :not_reached
             | :provisions_disagree}

  @doc "The date claims for `change` when it has a gap and a pointer; else []."
  @spec claims(Change.t(), %{String.t() => [Rule.t()]}) :: [Claim.t()]
  def claims(%Change{} = c, commencement) do
    case why(c, commencement) do
      {:dated, date, via} ->
        Claim.new(:commencement, :date, date, c.key) ++
          Claim.new(:commencement, :via, via, c.key) ++
          Claim.new(:commencement, :commenced_by, commenced_by(c, commencement), c.key)

      _ ->
        []
    end
  end

  @doc """
  What the gap-filler makes of `change` (CV-S04: every undated change
  accounted for): not a gap (a source dates it); dated, and by which
  pointer; or undated, and why —

  - `:no_amending_law`: neither the feed nor the note names the law;
  - `:no_pointer`: no amending provision named;
  - `:rules_not_held`: no commencement rules held for the amending law;
  - `:no_text_rules`: only rules that aren't its own text (its feed's
    records, a staged clause's start);
  - `:appointed`: left to a day fixed later that no rule held dates;
  - `:unread`: the amending law's own commencement words not read;
  - `:not_reached`: no rule reaches the provision named;
  - `:provisions_disagree`: the provisions named came in on different days.
  """
  @spec why(Change.t(), %{String.t() => [Rule.t()]}) :: why()
  def why(%Change{} = c, commencement) do
    {law, refs, via} = pointer(c)

    cond do
      not undated?(c) -> :not_a_gap
      law == nil -> {:undated, :no_amending_law}
      refs == [] -> {:undated, :no_pointer}
      Map.get(commencement, law, []) == [] -> {:undated, :rules_not_held}
      true -> at(Map.fetch!(commencement, law), deepest(refs), via)
    end
  end

  # the amending law and the provisions the feed names, else the note's
  defp pointer(c) do
    law = Change.value(c, :feed, :by) || Change.value(c, :markup, :cited)

    case Change.values(c, :feed, :affecting) |> List.flatten() do
      [] -> {law, Change.values(c, :markup, :affecting) |> List.flatten(), :note}
      feed -> {law, feed, :feed}
    end
  end

  # the law whose rule dated it (one date over every provision named)
  defp commenced_by(c, commencement) do
    {law, refs, _via} = pointer(c)
    rules = Map.get(commencement, law, [])

    refs
    |> deepest()
    |> Enum.map(&AmendingLaw.commenced_by(AmendingLaw.commencement(rules, &1)))
    |> Enum.uniq()
    |> case do
      [by] -> by
      _ -> nil
    end
  end

  defp at(rules, refs, via) do
    results = Enum.map(refs, &AmendingLaw.commencement(rules, &1))

    case results |> Enum.map(&(&1 && &1.full_from)) |> Enum.uniq() do
      _ when results == [nil] or hd(results) == nil -> {:undated, :no_text_rules}
      [%Date{} = d] -> {:dated, d, via}
      [nil] -> undated_why(results)
      _ -> {:undated, :provisions_disagree}
    end
  end

  defp undated_why(results) do
    cond do
      Enum.any?(results, fn r -> Enum.any?(r.undated, &match?({:appointed, _}, &1.when)) end) ->
        {:undated, :appointed}

      # the amending law's own commencement words not read (CV-S04 round 3)
      Enum.any?(results, fn r -> Enum.any?(r.undated, &(&1.when == :unread)) end) ->
        {:undated, :unread}

      true ->
        {:undated, :not_reached}
    end
  end

  @doc """
  The amending law's extent for a change no feed record carries it for
  (the feed reader claims it there): the law the note cites, at the
  provisions it names (`AmendingLaw.Extent`), else its own extent. A
  competence alone doesn't confine an insertion (V1-04). [] where a source
  claims it already, or the law's extent isn't read. `amended` (the
  amended law and its title) lets a statement naming the change's own
  target speak (`Extent.Targeted`, CV-S05f).
  """
  @spec extent_claims(
          Change.t(),
          %{String.t() => SertantaiLegal.Scraper.AmendingLaw.Extent.t()},
          %{law: String.t(), title: String.t() | nil} | nil
        ) :: [Claim.t()]
  def extent_claims(%Change{} = c, extents, amended \\ nil) do
    alias SertantaiLegal.Scraper.AmendingLaw.Extent

    # (a change only the amending law's text gives: its law, CV-S05 I)
    law =
      Change.value(c, :markup, :cited) || Change.value(c, :feed, :by) ||
        Change.value(c, :law_text, :by)

    # the amending provisions the markup names, else the feed's, else the
    # law text's own (keyed "law:ref": CV-S05 N16, I)
    refs =
      with [] <- Change.values(c, :markup, :affecting) |> List.flatten(),
           [] <- Change.values(c, :feed, :affecting) |> List.flatten() do
        own_ref(c.key, law)
      end

    # (the feed's too: an insertion only the feed records, nisr 2006/205 —
    # CV-S05 round 3 D)
    op =
      Change.value(c, :markup, :operation) || Change.value(c, :law_text, :operation) ||
        Change.value(c, :feed, :operation)

    with [] <- Change.values(c, :law_text, :extent),
         %Extent{} = e <- Map.get(extents, law),
         false <- Extent.competence_only?(e) and op == :inserted,
         code when is_binary(code) <- of(e, refs, amended && Map.put(amended, :target, c.target)) do
      Claim.new(:law_text, :extent, code, c.key)
    else
      _ -> []
    end
  end

  # no provision named: the law's own extent (its clause, else its powers,
  # else its legislature's competence) — never where its amendments follow
  # the enactments they change, nor where it names provisions' extents
  # without a default (which one isn't known): CV-S05 N16
  defp of(%{lists: lists} = e, [], _change) do
    cond do
      Enum.any?(lists, &match?({:same, _, _}, &1)) -> nil
      e.default == nil and e.powers == nil and e.competence == nil and lists != [] -> nil
      true -> e.default || e.powers || e.competence
    end
  end

  defp of(e, refs, change) do
    case SertantaiLegal.Scraper.AmendingLaw.Extent.of_change(e, deepest(refs), change) do
      code when is_binary(code) -> code
      _ -> nil
    end
  end

  # (the key holds the provision's CLML id, "schedule-7": as a ref, "sch.7",
  # the way extent lists name it — CV-S05 round 8 NEW-1)
  defp own_ref(key, law) when is_binary(key) and is_binary(law) do
    with [^law, id] <-
           String.split(
             SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw.provision_key(key),
             ":",
             parts: 2
           ),
         ref when is_binary(ref) <- SertantaiLegal.Scraper.Commencement.Order.ref(id) do
      [ref]
    else
      _ -> []
    end
  end

  defp own_ref(_key, _law), do: []

  defp undated?(c), do: Enum.all?(@dated, fn {s, a} -> Change.values(c, s, a) == [] end)

  # the most specific provisions named (a paragraph, not its Schedule's
  # introducing section)
  defp deepest(refs) do
    depth = &length(LatRef.ancestors(&1))
    max = refs |> Enum.map(depth) |> Enum.max()
    Enum.filter(refs, &(depth.(&1) == max))
  end
end
