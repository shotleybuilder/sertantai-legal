defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedPatterns.LawScan do
  @moduledoc """
  One law's part of the feed catalogue (#195): the law's effects classed
  alone (`scan/4`), and the catalogue's choice of examples made law by law
  in order (`select/3`). Pure.

  The catalogue holds up to three examples a pattern, from different laws,
  first come in law order. A law scanned alone always finds room, so the
  examples it computes alone (`outcomes`) hold every one the whole run asks
  of it: where the run's pattern has room, the law's steps for it are the
  same as alone, and where it is full the law takes nothing. So the scans
  run in parallel and are cached (`CatalogueCache`), and `select/3` over
  them in law order gives the catalogue a serial run gives.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{FeedPatterns, Ref}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @per_pattern 3
  @eu ~w(eur eudr eudn)

  @type event ::
          {:excluded, String.t()}
          | {:error, String.t()}
          | {:classified, non_neg_integer(), String.t(), [String.t()]}
  @type outcome ::
          {:ok, %{json: map(), outcome: list(), mismatch: boolean()}} | {:raise, String.t()}
  @type unit ::
          %{events: [event()], outcomes: %{non_neg_integer() => outcome()}} | %{error: String.t()}

  @doc "An empty catalogue."
  @spec new_acc() :: map()
  def new_acc,
    do: %{
      effects: 0,
      excluded: %{},
      unclassified: [],
      patterns: %{},
      examples: %{},
      mismatch: [],
      outcomes: %{}
    }

  @doc """
  The law's effects classed alone, with the examples it computes alone:
  `unit/0`. `rows` are its `[section_id, source_xml_id]` rows, `order` its
  text's document order (only read when an effect has a range). Raises
  where the serial run gave up on the whole law.
  """
  @spec scan(String.t(), [Effect.t()], [[String.t() | nil]], (-> [String.t()])) :: unit()
  def scan(law, effects, rows, order) do
    full = context(law, effects, rows, order)
    pairs = effects |> Enum.with_index() |> Enum.map(fn {e, i} -> event(e, i, full) end)
    examples = for {_, {i, fun}} <- pairs, into: %{}, do: {i, fun}
    events = Enum.map(pairs, &elem(&1, 0))

    solo = select(new_acc(), law, events, &Map.fetch!(examples, &1).())
    %{events: events, outcomes: solo.outcomes}
  end

  @doc """
  The law's scan taken into the catalogue `acc`, in law order: its
  examples are its scan's own (`outcomes`).
  """
  @spec select(map(), String.t(), unit()) :: map()
  def select(acc, law, %{error: why}),
    do: %{acc | unclassified: [{law, why} | acc.unclassified]}

  def select(acc, law, %{events: events, outcomes: outcomes}),
    do: select(acc, law, events, &Map.fetch!(outcomes, &1))

  @doc """
  The law's events taken into the catalogue `acc`, each example from
  `example` (the effect's place in the law → `outcome/0`).
  """
  @spec select(map(), String.t(), [event()], (non_neg_integer() -> outcome())) :: map()
  def select(acc, law, events, example) when is_list(events) do
    Enum.reduce(events, acc, fn event, acc ->
      take(%{acc | effects: acc.effects + 1}, law, event, example)
    end)
  end

  defp take(acc, _law, {:excluded, why}, _),
    do: %{acc | excluded: Map.update(acc.excluded, why, 1, &(&1 + 1))}

  defp take(acc, law, {:error, why}, _),
    do: %{acc | unclassified: [{law, why} | acc.unclassified]}

  defp take(acc, law, {:classified, i, id, patterns}, example) do
    {taken, wanted?} =
      Enum.reduce(patterns, {acc, false}, fn p, {acc, wanted?} ->
        entry = Map.get(acc.patterns, p, %{count: 0, examples: []})
        take? = take?(entry, id, law)
        {put_in(acc.patterns[p], count(entry, id, take?)), wanted? or take?}
      end)

    if wanted? and not Map.has_key?(taken.examples, id),
      do: held(taken, acc, law, i, id, example.(i)),
      else: taken
  end

  defp take?(entry, id, law),
    do:
      id in entry.examples or
        (length(entry.examples) < @per_pattern and law not in Enum.map(entry.examples, &law_of/1))

  defp count(entry, id, take?) do
    %{
      entry
      | count: entry.count + 1,
        examples:
          if(take? and id not in entry.examples, do: entry.examples ++ [id], else: entry.examples)
    }
  end

  # an example that raised leaves the effect unclassified, untaken
  defp held(taken, before, law, i, id, outcome) do
    case outcome do
      {:ok, x} ->
        taken = if x.mismatch, do: %{taken | mismatch: [id | taken.mismatch]}, else: taken
        taken = put_in(taken.outcomes[i], outcome)
        put_in(taken.examples[id], %{json: x.json, outcome: x.outcome})

      {:raise, why} ->
        before = put_in(before.outcomes[i], outcome)
        %{before | unclassified: [{law, why} | before.unclassified]}
    end
  end

  defp context(law, effects, rows, order) do
    eu? = law |> String.split("_") |> Enum.at(1) |> then(&(&1 in @eu))

    refs =
      Enum.map(rows, fn [sid, _] ->
        sid |> String.replace_prefix(law <> ":", "") |> Ref.canonical()
      end)

    %{
      law: law,
      xml_ids: Ref.xml_ids(law, rows),
      rows: if(eu?, do: refs, else: []),
      order: if(Enum.any?(effects, &(&1.affected_ranges != [])), do: order.(), else: [])
    }
  end

  # the effect's event, and its example's computation when classified
  defp event(e, i, full) do
    case FeedPatterns.excluded(e) do
      nil -> classify(e, i, full)
      why -> {{:excluded, why}, nil}
    end
  end

  defp classify(e, i, full) do
    ctx = if e.affected_ranges == [], do: %{full | order: []}, else: full
    sets = FeedPatterns.read(e, ctx)
    patterns = Enum.map(FeedPatterns.patterns(e, sets, full), &FeedPatterns.key/1)
    id = example_id(full.law, e.effect_id)
    {{:classified, i, id, patterns}, {i, fn -> example(e, ctx, sets) end}}
  rescue
    error -> {{:error, Exception.message(error)}, nil}
  end

  # the example with only the context its effect needs, checked to read the same
  defp example(e, full, sets) do
    ctx = minimal(e, full)
    e = %{e | effect_id: FeedPatterns.id()}
    expected = sets |> FeedPatterns.outcome() |> rekey(sets)
    same? = FeedPatterns.outcome(FeedPatterns.read(e, ctx)) == expected
    ctx = if same?, do: ctx, else: full

    {:ok, %{json: FeedPatterns.encode(e, ctx), outcome: expected, mismatch: not same?}}
  rescue
    error -> {:raise, Exception.message(error)}
  end

  # the reader's keys name the effect "E", as the example does
  defp rekey(outcome, [{key, _, _} | _]) do
    real = key |> String.split("@") |> hd()

    Enum.map(outcome, fn o ->
      %{o | "key" => String.replace_prefix(o["key"], real, FeedPatterns.id())}
    end)
  end

  defp rekey(outcome, []), do: outcome

  defp minimal(e, full) do
    order = span(full.order, e.affected_ranges)
    ids = MapSet.new(List.wrap(e.affected_refs) ++ order)
    xml_ids = Map.filter(full.xml_ids, fn {x, _} -> MapSet.member?(ids, x) end)

    articles =
      for r <- List.wrap(e.affected_refs),
          t = Map.get(full.xml_ids, r) || Ref.from_clml(r, full.law),
          t != nil,
          do: t

    rows =
      Enum.filter(full.rows, fn r ->
        Enum.any?(articles, &(r == &1 or String.starts_with?(r, &1 <> "(")))
      end)

    %{full | order: order, xml_ids: xml_ids, rows: rows}
  end

  # the stretch of document order from a range's first end to its last
  defp span(_order, []), do: []

  defp span(order, ranges) do
    indexed = Enum.with_index(order)
    ends = MapSet.new(Enum.flat_map(ranges, fn {a, b} -> [a, b] end))
    at = for {id, i} <- indexed, MapSet.member?(ends, id), do: i

    case at do
      [] -> []
      at -> Enum.slice(order, Enum.min(at)..Enum.max(at))
    end
  end

  # a short hash of the effect id: never the id itself (push protection)
  defp example_id(law, effect_id),
    do:
      law <>
        "/" <>
        (:crypto.hash(:sha256, effect_id) |> Base.encode16(case: :lower) |> binary_part(0, 10))

  defp law_of(id), do: id |> String.split("/") |> hd()
end
