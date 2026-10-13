defmodule SertantaiLegal.Scraper.LabelTimeline do
  @moduledoc """
  Builds a law's labels timeline (lat-refactor LR-24) into
  `lat_label_timeline`: reads its rows (`legal_articles`), its changes
  (`lat_change_log_rows`) and its coming into force (`uk_lrt`), runs
  `LabelProjection.timeline/4`, and replaces the law's periods in one
  transaction. Thin: the rules are `LabelProjection`'s.

  The CLML markup status (J2) is the row's `status` where its provenance is
  `markup` and it is repealed or prospective. The law's start: the
  register's `md_coming_into_force_date`, else its CLML metadata
  (`LabelProjection.clml_start/2`, J3).
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LabelProjection, LatStatus}

  @doc "A law's timeline from the DB: `%{periods, gaps, rows}` (`rows`: today's labels, for the diff)."
  @spec build(String.t(), Date.t()) :: map()
  def build(law_name, today) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT section_id, extent_code, status, change_provenance->>'status',
               effective_from, changed_by, change_provenance->>'change'
        FROM legal_articles WHERE law_name = $1 ORDER BY position
        """,
        [law_name]
      )

    # J5: rows a note points to as inserted / substituted whole — the row or
    # an ancestor (a pointer only: it withholds the law's start, it supplies
    # no fact; 1962/58 s.58B(2) under "S. 58B inserted")
    %{rows: pointed} =
      Repo.query!(
        """
        SELECT DISTINCT unnest(affected_sections) FROM amendment_annotations
        WHERE law_name = $1 AND code_type = 'amendment'
          AND text ~* '\\y(inserted|added|substituted)\\y'
          AND text !~* '\\ywords?\\y[^.;]{0,40}\\y(inserted|added|substituted)\\y'
        """,
        [law_name]
      )

    pointed = MapSet.new(List.flatten(pointed))

    # T1: the laws each row's amendment notes name (a pointer), to check the
    # register dates a change by each on the row
    %{rows: noted} =
      Repo.query!(
        """
        SELECT s, coalesce(citation_law, changed_by) FROM amendment_annotations,
               unnest(affected_sections) s
        WHERE law_name = $1 AND code_type = 'amendment'
        """,
        [law_name]
      )

    noted = Enum.group_by(noted, &hd/1, fn [_, l] -> l end)

    rows =
      for [sid, extent, status, prov, from, by, change_src] <- rows do
        %{
          section_id: sid,
          extent_code: extent,
          markup_status: if(prov == "markup" and status in ~w(repealed prospective), do: status),
          inserted_pointer:
            sid |> LatStatus.ancestors() |> Enum.any?(&MapSet.member?(pointed, &1)),
          today: %{status: status, effective_from: from, changed_by: by, source: change_src}
        }
      end

    %{rows: changes, columns: cols} =
      Repo.query!(
        """
        SELECT section_id, evidence, operation, effect_type, affecting_law, in_force,
               effective_from, savings, via, prospective, applied, effect_extent,
               territorial_application, source
        FROM lat_change_log_rows WHERE law_name = $1 AND section_id IS NOT NULL
        """,
        [law_name]
      )

    changes =
      Enum.map(changes, fn r ->
        cols |> Enum.map(&String.to_atom/1) |> Enum.zip(r) |> Map.new()
      end)

    # T1: a row has an undatable text change when change markup on it has no
    # date, or a note on it names a law with no dated text change on the row
    # (or names none)
    dated =
      for c <- changes,
          c.effective_from != nil,
          c.operation != "other",
          into: MapSet.new(),
          do: {c.section_id, c.affecting_law}

    undated_markup = for c <- changes, c.source == "markup", into: MapSet.new(), do: c.section_id

    undated? = fn sid ->
      MapSet.member?(undated_markup, sid) or
        Enum.any?(Map.get(noted, sid, []), fn law ->
          law == nil or
            not Enum.any?(LatStatus.ancestors(sid), &MapSet.member?(dated, {&1, law}))
        end)
    end

    rows = Enum.map(rows, &Map.put(&1, :undated_change, undated?.(&1.section_id)))

    law_start =
      case Repo.query!("SELECT md_coming_into_force_date FROM uk_lrt WHERE name = $1 LIMIT 1", [
             law_name
           ]) do
        %{rows: [[%Date{} = d]]} -> d
        _ -> clml_start(law_name)
      end

    law_name
    |> LabelProjection.timeline(rows, changes, today: today, law_start: law_start)
    |> Map.put(:rows, rows)
  end

  # J3: the law's coming into force from its stored CLML metadata
  defp clml_start(law_name) do
    with [_, type, year, number] <- String.split(law_name, "_", parts: 4),
         [path | _] <-
           Path.wildcard("data/cache/clml/#{type}/#{year}/#{number}/**/data.xml.gz")
           |> Enum.sort(),
         {:ok, gz} <- File.read(path) do
      gz |> head() |> LabelProjection.clml_start(type)
    else
      _ -> nil
    end
  end

  # the metadata sits at the top of the document
  defp head(gz) do
    xml = :zlib.gunzip(gz)
    binary_part(xml, 0, min(byte_size(xml), 80_000))
  end

  @doc "Replace the law's periods. Returns the number written."
  @spec write(String.t(), [LabelProjection.Period.t()], String.t()) :: {:ok, non_neg_integer()}
  def write(law_name, periods, code_version) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      Repo.query!("DELETE FROM lat_label_timeline WHERE law_name = $1", [law_name])

      periods
      |> Enum.map(fn p ->
        p
        |> Map.from_struct()
        |> Map.merge(%{id: Ecto.UUID.bingenerate(), code_version: code_version, built_at: now})
      end)
      |> Enum.chunk_every(2000)
      |> Enum.reduce(0, fn chunk, n ->
        {k, _} = Repo.insert_all("lat_label_timeline", chunk)
        n + k
      end)
    end)
  end
end
