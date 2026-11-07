defmodule SertantaiLegal.Scraper.Checks.StoreScan do
  @moduledoc """
  A scan of every stored changes-feed effect for one form (#192), in place
  of the scans written fresh in each session: the pages under
  `data/cache/clml/changes/affected/` in path order, each effect counted
  once (an effect on two laws, at the first), each tested by the form
  (`StoreScan.Form`). Laws are read several at once (`LawRunner`'s
  guard), each reduced in its worker to its effects' ids and classes, so
  only those travel back. Reads the CLML store; writes nothing.
  """

  alias SertantaiLegal.Scraper.LawRunner
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed

  @root "data/cache/clml/changes/affected"

  @type found :: nil | {String.t(), String.t(), String.t()}
  @type result :: %{
          effects: non_neg_integer(),
          matches: [{String.t(), String.t(), String.t(), String.t(), String.t()}],
          classes: %{String.t() => {non_neg_integer(), non_neg_integer()}},
          failed: [{String.t(), term()}]
        }

  @doc """
  The scan of `form` over the store. `opts`: `:root`, `:laws` (names, a
  pre-flight), `:workers`.
  """
  @spec run(module(), keyword()) :: result()
  def run(form, opts \\ []) do
    by_law = pages(Keyword.get(opts, :root, @root), Keyword.get(opts, :laws))
    laws = Enum.map(by_law, &elem(&1, 0))
    pages = Map.new(by_law)

    results =
      LawRunner.run(
        laws,
        &law(pages[&1], form),
        fn _, _ -> :ok end,
        Keyword.take(opts, [:workers])
      )

    {ok, failed} = Enum.split_with(laws, &is_list(results[&1]))

    ok
    |> Enum.map(&{&1, results[&1]})
    |> reduce()
    |> Map.put(:failed, Enum.map(failed, &{&1, results[&1]}))
  end

  # each law's pages, laws and pages in path order (as a sorted glob gives them)
  defp pages(root, only) do
    root
    |> Path.join("*/*/*/data.feed.page-*.gz")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.chunk_by(&Path.dirname/1)
    |> Enum.map(fn [p | _] = ps -> {law_name(root, p), ps} end)
    |> Enum.filter(fn {law, _} -> only == nil or law in only end)
  end

  defp law_name(root, page) do
    [t, y, n | _] = page |> Path.relative_to(root) |> Path.split()
    Enum.join(["UK", t, y, n], "_")
  end

  # a law's effects in page order, each with what the form found
  defp law(pages, form) do
    for page <- pages,
        effect <- page |> File.read!() |> :zlib.gunzip() |> ChangesFeed.parse() |> elem(0) do
      {effect.effect_id, found(effect, form)}
    end
  end

  defp found(effect, form) do
    case form.match(effect) do
      nil -> nil
      class -> {effect.type || "", class, effect.affected_provisions || ""}
    end
  end

  @doc "Laws' effects (`{law, [{id, found}]}`, in path order) → the counts and matches, each effect once."
  @spec reduce([{String.t(), [{String.t() | nil, found()}]}]) :: map()
  def reduce(per_law) do
    {_seen, n, matches} =
      Enum.reduce(per_law, {MapSet.new(), 0, []}, fn {law, effects}, acc ->
        Enum.reduce(effects, acc, &first_seen(law, &1, &2))
      end)

    matches = Enum.reverse(matches)
    %{effects: n, matches: matches, classes: classes(matches)}
  end

  defp first_seen(law, {id, found}, {seen, n, matches} = acc) do
    cond do
      MapSet.member?(seen, id) ->
        acc

      found == nil ->
        {MapSet.put(seen, id), n + 1, matches}

      true ->
        {MapSet.put(seen, id), n + 1,
         [Tuple.insert_at(found, 0, id) |> Tuple.insert_at(0, law) | matches]}
    end
  end

  defp classes(matches) do
    matches
    |> Enum.group_by(&elem(&1, 3))
    |> Map.new(fn {class, ms} ->
      {class, {length(ms), ms |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length()}}
    end)
  end

  @doc "Every match as one tab-separated line (law, effect id, type, class, provisions text), sorted."
  @spec listing([tuple()]) :: String.t()
  def listing(matches) do
    matches
    |> Enum.sort()
    |> Enum.map_join(fn m -> (m |> Tuple.to_list() |> Enum.join("\t")) <> "\n" end)
  end
end
