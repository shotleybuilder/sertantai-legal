defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelSource do
  @moduledoc """
  A law's rows folded into label periods from its stored changes (change
  vocabulary CV-S09, the label check) — as `mix lat.vocabulary --golden
  --stored` folds the golden set, for every provision row of the law:

  - the rows: `legal_articles` provision rows (not signatures, headings
    or tables), each with its extent;
  - the start: the law's law-level commencement (`lat_change_log`); a law
    with none is a gap (C10), folded with its start undated;
  - the changes: `provision_changes` (`Store.for_law/1`);
  - today's label (`lat_label_timeline`), for stratum T.

  Reads the database and the local CLML store; writes nothing.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Label, Ref, Store}

  @not_provisions ~w(signed heading table)

  @type row :: %{
          id: String.t(),
          extent: String.t() | nil,
          start: Date.t() | nil,
          periods: [Label.period()],
          reaching: [Change.t()],
          today: [map()]
        }

  @doc "Each provision row of `law` with its periods, the changes reaching it and today's label; `{:error, why}` when the law can't be folded."
  @spec rows(String.t()) :: [row()] | {:error, atom()}
  def rows(law) do
    with {:ok, xml} <- clml(law) do
      start = start(law)
      extents = extents(law)
      changes = Store.for_law(law) |> Enum.map(&%{&1 | target: Ref.canonical(&1.target)})

      provisions =
        Map.new(extents, fn {id, {extent, containers}} ->
          {id,
           %{
             extent: extent,
             containers: containers,
             start: start || ~D[1900-01-01],
             start_dated: start != nil,
             # the law's start, not the provision's own
             start_from_law: true
           }}
        end)

      labels =
        ChangeVocabulary.labels(law, xml, [], provisions, changes: changes, title: title(law))

      today = today(law)

      for {id, p} <- Enum.sort(provisions) do
        base = String.replace(id, ~r/\[[^\]]+\]$/, "")

        %{
          id: id,
          extent: p.extent,
          start: start,
          periods: Map.get(labels, id, []),
          reaching: Enum.filter(changes, &Label.reaches?(&1, base)),
          today: Map.get(today, id, [])
        }
      end
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
      {sid |> unprefix(law) |> Ref.canonical(), {extent, Label.containers(part, chapter)}}
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
    case Repo.query!(
           "SELECT effective_from FROM lat_change_log WHERE law_name = $1 " <>
             "AND collector = 'commencement' AND section_id IS NULL LIMIT 1",
           [law]
         ) do
      %{rows: [[%Date{} = d]]} -> d
      _ -> nil
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
