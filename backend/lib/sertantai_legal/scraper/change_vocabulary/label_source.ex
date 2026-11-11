defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelSource do
  @moduledoc """
  A law's rows folded into label periods from its stored changes (change
  vocabulary CV-S09, the label check) — as `mix lat.vocabulary --golden
  --stored` folds the golden set, for every provision row of the law:

  - the rows: `legal_articles` provision rows (not signatures, headings
    or tables), each with its extent;
  - the start: the law's start as its latest build stored it
    (`Store.start/1`, resolved by `LawStart`; never the old register's,
    Maritime Safety: Switch-over); a start no source dates is a gap (C10),
    folded undated, and a law built before starts were stored can't be
    folded (`:start_not_built`: rebuild it);
  - the changes: `provision_changes` (`Store.for_law/1`);
  - today's label (`lat_label_timeline`), for stratum T.

  `timeline/1` gives the same periods in the timeline's shape
  (`LabelPeriods`, CV-05), beside the register's (`LabelTimeline.build/2`).

  Reads the database and the local CLML store; writes nothing.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Fold, Label, LabelPeriods, Ref, Store}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup

  @not_provisions ~w(signed heading table)

  @type row :: %{
          id: String.t(),
          sid: String.t(),
          made: Date.t() | nil,
          valid: Date.t() | nil | :unknown,
          changes: [Change.t()],
          extent: String.t() | nil,
          start: Date.t() | nil,
          periods: [Label.period()],
          reaching: [Change.t()],
          today: [map()]
        }

  @doc "Each provision row of `law` with its periods, the changes reaching it and today's label; `{:error, why}` when the law can't be folded."
  @spec rows(String.t()) :: [row()] | {:error, atom()}
  def rows(law) do
    with {:ok, xml} <- clml(law),
         {:ok, start} <- start(law) do
      made = made(law)
      valid = Markup.valid(xml)
      extents = extents(law)
      changes = Store.for_law(law) |> Enum.map(&%{&1 | target: Ref.canonical(&1.target)})
      made_of = made_of(changes)
      by_order = by_order(law, Map.keys(extents))

      provisions =
        Map.new(extents, fn {id, {_sid, extent, containers}} ->
          {id,
           %{
             extent: extent,
             containers: containers,
             start: start || LabelPeriods.undated_start(),
             start_dated: start != nil,
             # the law's making (LR-39): prospective from it until its start
             made: made,
             # each amending law's making: no undated change dates before it
             made_of: made_of,
             # left by its own law to an order we don't hold (Decision 8)
             by_order: MapSet.member?(by_order, String.replace(id, ~r/\[[^\]]+\]$/, "")),
             # the law's start, not the provision's own
             start_from_law: true
           }}
        end)

      labels =
        Fold.labels(law, xml, provisions, changes, title: title(law))

      today = today(law)

      for {id, p} <- Enum.sort(provisions) do
        base = String.replace(id, ~r/\[[^\]]+\]$/, "")

        %{
          id: id,
          sid: extents |> Map.fetch!(id) |> elem(0),
          extent: p.extent,
          start: start,
          periods: Map.get(labels, id, []),
          reaching: Enum.filter(changes, &Label.reaches?(&1, base)),
          # the law's making and the text's date, for the rules (CV-06)
          made: made,
          valid: valid,
          changes: changes,
          today: Map.get(today, id, [])
        }
      end
    end
  end

  @doc """
  The law's label timeline from its stored changes, in the timeline's shape
  (`LabelPeriods`): each provision row's periods under its stored
  section_id. `{:error, why}` when the law can't be folded.
  """
  @spec timeline(String.t()) :: {:ok, [map()]} | {:error, atom()}
  def timeline(law) do
    with [_ | _] = rows <- rows(law) do
      {:ok, Enum.flat_map(rows, &LabelPeriods.periods(law, &1.sid, &1.periods, &1.reaching))}
    else
      [] -> {:ok, []}
      {:error, _} = error -> error
    end
  end

  defp extents(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, extent_code, part, chapter FROM legal_articles WHERE law_name = $1 " <>
          "AND section_id IS NOT NULL AND NOT (section_type = ANY($2))",
        [law, @not_provisions]
      )

    Map.new(rows, fn [sid, extent, part, chapter] ->
      {sid |> unprefix(law) |> Ref.canonical(), {sid, extent, Label.containers(part, chapter)}}
    end)
  end

  @doc "Each row of `law` → its containers (`Label.containers/2`), as the parse named it."
  @spec containers(String.t()) :: %{String.t() => [String.t()]}
  def containers(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, part, chapter FROM legal_articles WHERE law_name = $1 " <>
          "AND section_id IS NOT NULL",
        [law]
      )

    Map.new(rows, fn [sid, part, chapter] ->
      {unprefix(sid, law), Label.containers(part, chapter)}
    end)
  end

  defp start(law) do
    case Store.start(law) do
      {:ok, d} -> {:ok, d}
      :none -> {:error, :start_not_built}
    end
  end

  # an SI's made date, else an Act's Royal Assent (as `LabelTimeline.made_date/1`)
  defp made(law) do
    case Repo.query!(
           "SELECT coalesce(md_made_date, md_enactment_date) FROM uk_lrt WHERE name = $1 LIMIT 1",
           [law]
         ) do
      %{rows: [[%Date{} = d]]} -> d
      _ -> nil
    end
  end

  # the rows its own law leaves to an order no rule held dates (J6:
  # `OwnCommencement.outcome/4` `:by_order`; Environmental Protection:
  # Label fold, Decision 8)
  defp by_order(law, ids) do
    case SertantaiLegal.Scraper.Commencement.Store.for_law(law) do
      [] ->
        MapSet.new()

      rules ->
        ctx = own_context(law)

        for id <- ids,
            base = String.replace(id, ~r/\[[^\]]+\]$/, ""),
            match?(
              {:by_order, _},
              SertantaiLegal.Scraper.ChangeVocabulary.Readers.OwnCommencement.outcome(
                rules,
                law,
                base,
                ctx
              )
            ),
            uniq: true,
            into: MapSet.new(),
            do: base
    end
  end

  defp own_context(law) do
    Repo.query!(
      "SELECT section_id, part, chapter FROM legal_articles WHERE law_name = $1 ORDER BY position",
      [law]
    ).rows
    |> Enum.map(fn [s, p, c] -> %{section_id: s, part: p, chapter: c} end)
    |> SertantaiLegal.Scraper.Commencement.OwnClause.context()
  end

  # the making of each law the changes name (Environmental Protection:
  # Label fold, Decision 1)
  defp made_of(changes) do
    case changes |> Enum.map(& &1.resolved.by) |> Enum.filter(&is_binary/1) |> Enum.uniq() do
      [] ->
        %{}

      laws ->
        Repo.query!(
          "SELECT name, coalesce(md_made_date, md_enactment_date) FROM uk_lrt WHERE name = ANY($1)",
          [laws]
        ).rows
        |> Enum.reject(fn [_, d] -> is_nil(d) end)
        |> Map.new(fn [n, d] -> {n, d} end)
    end
  end

  defp today(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, valid_from, valid_to, status, in_force_from, changed_by, territory " <>
          "FROM lat_label_timeline WHERE law_name = $1 ORDER BY section_id, valid_from",
        [law]
      )

    Enum.group_by(
      rows,
      fn [sid | _] -> sid |> unprefix(law) |> Ref.canonical() end,
      fn [_, f, t, s, i, c, ter] ->
        %{valid_from: f, valid_to: t, status: s, in_force_from: i, changed_by: c, territory: ter}
      end
    )
  end

  defp title(law) do
    case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law]) do
      %{rows: [[t]]} -> t
      _ -> nil
    end
  end

  defp unprefix(sid, law), do: String.replace_prefix(sid, law <> ":", "")

  defp clml(law) do
    [_, type, year, num] = String.split(law, "_", parts: 4)

    case Path.wildcard("data/cache/clml/#{type}/#{year}/#{num}/body/data.xml.gz") do
      [path | _] -> {:ok, path |> File.read!() |> :zlib.gunzip()}
      [] -> {:error, :no_clml}
    end
  end
end
