defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns.LawScan do
  @moduledoc """
  One law's part of the markup catalogue (#195): the law's changes classed
  alone (`scan/3`), and the catalogue's choice of examples made law by law
  in order (`select/3`). Pure.

  The catalogue holds up to three examples a pattern, from different laws,
  first come in law order; an example too large to hold, or reading
  differently alone, leaves its patterns and a later change may take the
  place. A law scanned alone always finds room, so the examples it
  computes alone (`outcomes`) hold every one the whole run asks of it:
  where the run's pattern has room, the law's steps for it are the same as
  alone, and where it is full the law takes nothing. So the scans run in
  parallel and are cached (`CatalogueCache`), and `select/3` over them in
  law order gives the catalogue a serial run gives.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup

  @per_pattern 3

  @type event :: {:error, String.t()} | {:classified, non_neg_integer(), String.t(), [String.t()]}
  @type outcome ::
          {:ok, %{json: map(), outcome: list()}}
          | :too_large
          | :mismatch
          | {:raise, String.t()}
  @type unit ::
          %{events: [event()], outcomes: %{non_neg_integer() => outcome()}} | %{error: String.t()}

  @doc "An empty catalogue."
  @spec new_acc() :: map()
  def new_acc,
    do: %{
      laws: 0,
      changes: 0,
      unclassified: [],
      patterns: %{},
      examples: %{},
      mismatch: [],
      too_large: 0,
      outcomes: %{}
    }

  @doc """
  The law's changes classed alone, with the examples it computes alone:
  `unit/0`. `doc` is its parsed text, `xml_ids` its rows' XML ids
  (`Ref.xml_ids/2`). Raises where the serial run gave up on the whole law.
  """
  @spec scan(String.t(), term(), %{String.t() => String.t()}) :: unit()
  def scan(law, doc, xml_ids) do
    by_key = doc |> Markup.read(law, xml_ids) |> Enum.group_by(&elem(&1, 0))

    pairs =
      doc
      |> MarkupPatterns.changes()
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.with_index()
      |> Enum.map(fn {{key, change}, i} ->
        own = by_key |> Map.get(key, []) |> Enum.sort_by(fn {k, t, _} -> {k, t} end)
        event(law, doc, xml_ids, change, own, i)
      end)

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
  `example` (the change's place in the law → `outcome/0`).
  """
  @spec select(map(), String.t(), [event()], (non_neg_integer() -> outcome())) :: map()
  def select(acc, law, events, example) when is_list(events) do
    Enum.reduce(events, %{acc | laws: acc.laws + 1}, fn event, acc ->
      take(%{acc | changes: acc.changes + 1}, law, event, example)
    end)
  end

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

  # an example that raised leaves the change unclassified, untaken
  defp held(_taken, before, law, i, _id, {:raise, why} = outcome) do
    before = put_in(before.outcomes[i], outcome)
    %{before | unclassified: [{law, why} | before.unclassified]}
  end

  defp held(taken, _before, _law, i, id, outcome) do
    taken = put_in(taken.outcomes[i], outcome)

    case outcome do
      {:ok, x} -> put_in(taken.examples[id], x)
      :too_large -> taken |> drop(id) |> Map.update!(:too_large, &(&1 + 1))
      :mismatch -> taken |> drop(id) |> Map.update!(:mismatch, &[id | &1])
    end
  end

  # an example not held leaves the patterns that took it
  defp drop(acc, id) do
    patterns =
      Map.new(acc.patterns, fn {p, e} -> {p, %{e | examples: List.delete(e.examples, id)}} end)

    %{acc | patterns: patterns}
  end

  # the change's event, and its example's computation when classified
  defp event(law, doc, xml_ids, change, sets, i) do
    patterns = change |> MarkupPatterns.patterns(sets) |> Enum.map(&MarkupPatterns.key/1)
    id = example_id(law, change.key)
    {{:classified, i, id, patterns}, {i, fn -> example(law, doc, xml_ids, change, sets) end}}
  rescue
    error -> {{:error, Exception.message(error)}, nil}
  catch
    :exit, reason -> {{:error, inspect(reason)}, nil}
  end

  # the example's XML, checked to read as the whole law does
  defp example(law, doc, xml_ids, change, sets) do
    case MarkupPatterns.example(change, doc) do
      nil -> :too_large
      {xml, named} -> checked(law, xml, named, xml_ids, change, sets)
    end
  rescue
    error -> {:raise, Exception.message(error)}
  catch
    :exit, reason -> {:raise, inspect(reason)}
  end

  # an example reading differently alone isn't held (a pruned one can)
  defp checked(law, xml, named, xml_ids, change, sets) do
    expected = sets |> MarkupPatterns.outcome() |> MarkupPatterns.rekey(change.key, named)
    # the row names the example's ids need
    xml_ids = Map.filter(xml_ids, fn {x, _} -> String.contains?(xml, ~s(id="#{x}")) end)
    read = xml |> MarkupPatterns.read(named, law, xml_ids) |> MarkupPatterns.outcome()

    if read == expected,
      do:
        {:ok,
         %{
           json: %{"law" => law, "key" => named, "xml" => xml, "xml_ids" => xml_ids},
           outcome: expected
         }},
      else: :mismatch
  end

  # a short hash of the key: never an effect id itself (push protection)
  defp example_id(law, key),
    do:
      law <>
        "/" <> (:crypto.hash(:sha256, key) |> Base.encode16(case: :lower) |> binary_part(0, 10))

  defp law_of(id), do: id |> String.split("/") |> hd()
end
