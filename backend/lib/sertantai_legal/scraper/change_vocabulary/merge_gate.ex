defmodule SertantaiLegal.Scraper.ChangeVocabulary.MergeGate do
  @moduledoc """
  The merge's family gate (Decision 1, Jason 2026-11-06, Maritime Safety:
  Merge): every merge decision a family's changes hold, grouped by a cause
  from code and the amending law. Causes come from the change, never from
  reading:

  - joined (`MergeStrata` J), by how it joined:
    - `same effect id`: legislation.gov.uk's feed and markup, one id;
    - `same amending provision, same operation`: the law's text names the
      amending provision legislation.gov.uk names (the feed's, or a legacy
      markup note's citation);
    - `legacy note names the feed's amending provision`: a legacy markup id
      joined to the feed effect its note's citation names;
    - `related amending provision`, `legislation.gov.uk names no amending
      provision`, `law text names no provision`, `legacy markup id`: the
      partner rule's weaker joins (`Merge.Partner`);
    - with `, dates differ` when legislation.gov.uk's date is none of the
      law's own commencement dates (Gemini, Decision 1): one record per
      source, so a date conflict on one event, unless the basis is weak;
  - over-join tell-tales, before those (Gemini, Decision 1):
    - `two law-text records`, `several markup records`, `two feed effects`:
      one source's several records in one change (`several markup records
      of one effect` when every markup note names the change's effect id:
      words changed in each place, by design);
    - `operation differs`: a value conflict on the operation, the
      amending-law reader's (its status can come from that gate);
    - `operations differ in legislation.gov.uk`: the feed and markup
      unlike;
  - split risk: `unjoined` (U), `candidate` (C), `markup alone` (a
    markup-only text change no stratum holds) and `law-text copy apart
    from its joined event` (a law-text record's copy on a provision below
    the one where its key joined an effect: the agent pass);
  - each spread key (`MergeStrata.spread/2`): `spread: legislation.gov.uk's
    own effect` when the feed states every change under it (one effect over
    a range), else `spread: joined across provisions`.

  Statuses are reviewed in `test/fixtures/merge/merges.json` (`"<cause> @
  <amending law>"`, else `"<cause>"`), with the commencement gate's
  semantics (`Commencement.Leftovers`). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Merge, MergeStrata}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Merge.{Candidates, Partner}
  alias SertantaiLegal.Scraper.Commencement.Leftovers
  alias SertantaiLegal.Scraper.LatRef

  @type entry :: %{
          law: String.t(),
          cause: String.t(),
          by: String.t(),
          target: String.t() | nil,
          words: String.t(),
          change: Change.t() | nil
        }

  @type item :: %{
          law: String.t(),
          shape: String.t(),
          words: [String.t()],
          reach: pos_integer(),
          status: String.t() | nil
        }

  # one operation the sources say alike (`Conflicts`: the markup shows a
  # substitution as an insertion)
  @alike [:inserted, :substituted]

  # named by cause alone in merges.json, never reviewed by law
  @by_design [
    "same effect id",
    "same amending provision, same operation",
    "same amending provision, same operation, dates differ",
    "legacy note names the feed's amending provision",
    "several markup records of one effect",
    "two law-text records the feed names together",
    "operations differ in legislation.gov.uk: inserted/renumbered",
    "spread: legislation.gov.uk's own effect"
  ]

  @doc "The causes named by cause alone, never by law (the agent pass's population, Decision 1)."
  @spec by_design() :: [String.t()]
  def by_design, do: @by_design

  @doc "One amended law's entries: each change in a stratum, each markup-only change, each spread key."
  @spec entries(String.t(), [Change.t()]) :: [entry()]
  def entries(law, changes) do
    classified = MergeStrata.classify(changes)
    held = MapSet.new(classified, fn {c, _} -> {c.key, c.target} end)

    strata = for {c, s} <- classified, do: entry(law, c, cause(c, s))

    alone =
      for c <- changes,
          MergeStrata.sources(c) == [:markup],
          Merge.family(Change.value(c, :markup, :operation)) in [:text, :removal],
          not MapSet.member?(held, {c.key, c.target}),
          do: entry(law, c, "markup alone")

    spread =
      for {key, tops} <- MergeStrata.spread(changes) do
        under = Enum.filter(changes, &(Candidates.base(&1.key) == key))

        %{
          law: law,
          cause: spread_cause(under),
          by: by(hd(under)),
          target: nil,
          words:
            "#{law} #{short(key)}: #{length(tops)} top provisions (#{Enum.join(Enum.take(tops, 5), ", ")}…)",
          change: nil
        }
      end

    strata ++ alone ++ copies(law, changes) ++ spread
  end

  # a law-text record's copy on a provision below the one its key joined an
  # effect on, left apart (the agent pass, 2026-11-06: 2009 c.25 Sch.21
  # para.34 on MSA 1995 s.271(6) and its new paragraphs (a)-(c))
  defp copies(law, changes) do
    joined =
      for c <- changes,
          String.starts_with?(c.key, "key-"),
          a <- c.aliases,
          law_text_key?(a),
          reduce: %{},
          do: (acc -> Map.update(acc, a, [c.target], &[c.target | &1]))

    for c <- changes,
        law_text_key?(c.key),
        targets = Map.get(joined, c.key, []),
        Enum.any?(targets, &(&1 in LatRef.ancestors(c.target))),
        do: entry(law, c, "law-text copy apart from its joined event")
  end

  @doc "One change's cause, from its stratum and claims."
  @spec cause(Change.t(), MergeStrata.stratum()) :: String.t()
  def cause(_c, :U), do: "unjoined"
  def cause(_c, :C), do: "candidate"
  def cause(c, :J), do: tell_tale(c) || dated(basis(c), c)

  defp tell_tale(c) do
    cond do
      records(c, :law_text) > 1 -> law_text_records(c)
      records(c, :markup) > 1 -> markup_records(c)
      records(c, :feed) > 1 -> "two feed effects"
      operation_conflict?(c) -> "operation differs"
      legislation_gov_uk_unlike?(c) -> "operations differ in legislation.gov.uk: " <> ops(c)
      true -> nil
    end
  end

  # the law's text stating one change twice (an operative section and the
  # repeals Schedule: 2003 c.20 s.87 and Sch.8), each named by the feed's
  # one effect
  defp law_text_records(c) do
    named = affecting(c, :feed)
    refs = c.aliases |> Enum.filter(&law_text_key?/1) |> Enum.flat_map(&Partner.key_refs/1)

    if refs != [] and Enum.all?(refs, &(&1 in named)),
      do: "two law-text records the feed names together",
      else: "two law-text records"
  end

  defp ops(c),
    do:
      (Change.values(c, :feed, :operation) ++ Change.values(c, :markup, :operation))
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.join("/")

  # several markup elements whose notes all name the change's own effect
  # (words changed in each place: one event, legislation.gov.uk's own)
  defp markup_records(c) do
    notes =
      for %Claim{source: :markup, attribute: :operation, ref: ref} <- c.claims,
          uniq: true,
          do: note(c, ref)

    if Enum.all?(notes, &(&1 == c.key)),
      do: "several markup records of one effect",
      else: "several markup records"
  end

  defp note(c, ref),
    do:
      Enum.find_value(c.claims, fn
        %Claim{source: :markup, attribute: :note, ref: ^ref, value: v} -> v
        _ -> nil
      end)

  # one record per source whose dates differ: a date conflict on one event
  defp dated(basis, c), do: if(dates_differ?(c), do: basis <> ", dates differ", else: basis)

  defp basis(c) do
    case Enum.find(c.aliases, &law_text_key?/1) do
      nil -> legislation_gov_uk_basis(c)
      key -> provision_basis(Partner.key_refs(key), affecting(c, :feed) ++ affecting(c, :markup))
    end
  end

  defp legislation_gov_uk_basis(c) do
    cond do
      not Enum.any?(c.aliases, &legacy?/1) ->
        "same effect id"

      Enum.any?(affecting(c, :markup), &(&1 in affecting(c, :feed))) ->
        "legacy note names the feed's amending provision"

      true ->
        "legacy markup id"
    end
  end

  defp provision_basis([], _named), do: "law text names no provision"
  defp provision_basis(_refs, []), do: "legislation.gov.uk names no amending provision"

  defp provision_basis(refs, named) do
    if Enum.any?(refs, &(&1 in named)),
      do: "same amending provision, same operation",
      else: "related amending provision"
  end

  defp spread_cause(under) do
    # (a new paragraph carrying the event, `Merge.Copies`, is the feed's too)
    if Enum.all?(
         under,
         &(:feed in MergeStrata.sources(&1) or Change.values(&1, :feed, :placed) != [])
       ),
       do: "spread: legislation.gov.uk's own effect",
       else: "spread: joined across provisions"
  end

  @doc """
  The entries grouped by cause and amending law, each with its status:
  reviewed by law, else by cause, else `inherited.(entry)` (an operation
  conflict the amending-law reader's gate named).
  """
  @spec items([entry()], map(), (entry() -> String.t() | nil)) :: [item()]
  def items(entries, reviewed, inherited \\ fn _ -> nil end) do
    entries
    |> Enum.group_by(&{&1.cause, &1.by})
    |> Enum.map(fn {{cause, by}, group} ->
      %{
        law: by,
        shape: cause,
        words: group |> Enum.map(& &1.words) |> Enum.sort(),
        reach: length(group),
        status: Leftovers.status(cause, reviewed, by) || common(group, inherited)
      }
    end)
  end

  # a status every entry of the group inherits alike, or named in each of
  # several ways (each `known:`, their words kept)
  defp common(group, inherited) do
    case group |> Enum.map(inherited) |> Enum.uniq() do
      [status] -> status
      statuses -> if Enum.all?(statuses, &Leftovers.named?/1), do: Enum.join(statuses, " | ")
    end
  end

  @doc "The gate: `pass?` when every group is named `known:`; the rest, widest reach first."
  @spec gate([item()]) :: %{pass?: boolean(), failing: [item()], counts: map()}
  def gate(items) do
    failing =
      items
      |> Enum.reject(&Leftovers.named?(&1.status))
      |> Enum.sort_by(&{-&1.reach, &1.law, &1.shape})

    %{
      pass?: failing == [],
      failing: failing,
      counts: Enum.frequencies_by(items, &kind(&1.status))
    }
  end

  defp kind(nil), do: :unreviewed
  defp kind(status), do: status |> String.split(":", parts: 2) |> hd() |> String.to_atom()

  defp entry(law, c, cause),
    do: %{law: law, cause: cause, by: by(c), target: c.target, words: words(law, c), change: c}

  # one source's records of the change (its operation claims' refs)
  defp records(c, source),
    do:
      c.claims
      |> Enum.filter(&match?(%Claim{source: ^source, attribute: :operation}, &1))
      |> Enum.uniq_by(& &1.ref)
      |> length()

  defp dates_differ?(c) do
    {feed, own} = {Change.values(c, :feed, :date), Change.values(c, :commencement, :date)}
    feed != [] and own != [] and Enum.all?(feed, &(&1 not in own))
  end

  defp operation_conflict?(%Change{resolved: %{conflicts: conflicts}}),
    do: Enum.any?(conflicts, &match?({:operation, _, _}, &1))

  defp operation_conflict?(_c), do: false

  defp legislation_gov_uk_unlike?(c) do
    ops = Enum.uniq(Change.values(c, :feed, :operation) ++ Change.values(c, :markup, :operation))
    length(ops) > 1 and not Enum.all?(ops, &(&1 in @alike))
  end

  # the amending provisions a source of legislation.gov.uk's names (the
  # feed's affecting provisions, a markup note's citation)
  defp affecting(c, source), do: List.flatten(Change.values(c, source, :affecting))

  defp law_text_key?(id), do: String.starts_with?(id, "UK_") and String.contains?(id, ":")

  # a markup ChangeId with no effect id ("d29p11431")
  defp legacy?(id), do: not String.starts_with?(id, "key-") and not law_text_key?(id)

  defp by(c),
    do:
      Change.value(c, :feed, :by) || Change.value(c, :law_text, :by) ||
        Change.value(c, :markup, :cited) || "-"

  defp words(law, c) do
    refs =
      c.aliases
      |> Enum.filter(&law_text_key?/1)
      |> Enum.map(&(&1 |> String.split(":", parts: 2) |> List.last()))

    "#{law} #{c.target}#{if refs != [], do: " (#{Enum.join(refs, ", ")})"}"
  end

  # an effect id's last six characters (never written whole)
  defp short("key-" <> rest), do: "key-…" <> String.slice(rest, -6, 6)
  defp short(key), do: key
end
