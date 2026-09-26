defmodule SertantaiLegal.Scraper.LatPersister.Carry do
  @moduledoc """
  DB helpers for carrying provision enrichment across a LAT re-parse
  (Gemini review 2026-09-26). Called by `LatPersister` inside its transaction;
  the matching itself is the pure `LatMerge.plan/2`.

  - `carried_columns/1` — every `legal_articles` column the parser does not
    produce (fractalaw taxa, significance, embeddings, legacy_id…), read from
    the catalogue so new enrichment columns are preserved automatically
  - `load_existing/2` — the law's current rows with their carried values
  - `apply_renames/1` — move `control_mappings` and
    `amendment_annotations.affected_sections` to renamed section ids
  - `log_changes/3` — record renamed / ambiguous / dropped ids in
    `lat_section_id_renames` (served to fractalaw)
  - `orphaned_mappings/1` — control mappings left on ids with no counterpart
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatMerge

  # Row identity and bookkeeping: never carried.
  @identity ~w(section_id country law_name law_id created_at updated_at)

  @doc "Columns to carry: table columns minus parser output and row identity."
  @spec carried_columns([atom()]) :: [String.t()]
  def carried_columns(parser_keys) do
    parser = MapSet.new(parser_keys, &to_string/1)

    %{rows: rows} =
      Repo.query!(
        "SELECT column_name FROM information_schema.columns WHERE table_name = 'legal_articles' ORDER BY ordinal_position",
        []
      )

    for [col] <- rows, col not in @identity, not MapSet.member?(parser, col), do: col
  end

  @doc """
  Existing rows for the law: `%{section_id, text, position, enriched, values}`
  where `values` holds the carried columns (atom keys) and `enriched` is true
  when any of them is set.
  """
  @spec load_existing(String.t(), [String.t()]) :: [map()]
  def load_existing(law_name, columns) do
    select = Enum.map_join(columns, ", ", &~s("#{&1}"))
    keys = Enum.map(columns, &String.to_existing_atom/1)

    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, text, position, #{select} FROM legal_articles WHERE law_name = $1",
        [law_name]
      )

    for [id, text, pos | vals] <- rows do
      values = Enum.zip(keys, vals) |> Map.new()

      %{
        section_id: id,
        text: text,
        position: pos,
        enriched: Enum.any?(vals, &(not is_nil(&1))),
        values: values
      }
    end
  end

  @doc "Point control mappings and annotation section lists at renamed ids."
  @spec apply_renames([%{old: String.t(), new: String.t()}]) :: :ok
  def apply_renames([]), do: :ok

  def apply_renames(renames) do
    olds = Enum.map(renames, & &1.old)
    news = Enum.map(renames, & &1.new)

    Repo.query!(
      """
      UPDATE control_mappings m SET section_id = u.new, updated_at = now() AT TIME ZONE 'utc'
      FROM unnest($1::text[], $2::text[]) AS u(old, new)
      WHERE m.section_id = u.old
      """,
      [olds, news]
    )

    Enum.each(renames, fn r ->
      Repo.query!(
        "UPDATE amendment_annotations SET affected_sections = array_replace(affected_sections, $1, $2) WHERE $1 = ANY(affected_sections)",
        [r.old, r.new]
      )
    end)
  end

  @doc "Log this re-parse's renamed, ambiguous and dropped ids under one reparse_id."
  @spec log_changes(String.t(), LatMerge.t(), String.t()) :: non_neg_integer()
  def log_changes(law_name, %LatMerge{} = plan, reparse_id) do
    entries =
      Enum.map(plan.renames, &{&1.old, &1.new, "renamed", &1.match}) ++
        Enum.map(plan.ambiguous, &{&1, nil, "ambiguous", nil}) ++
        Enum.map(plan.removed, &{&1, nil, "dropped", nil})

    case entries do
      [] ->
        0

      _ ->
        {olds, news, statuses, matches} = unzip4(entries)

        %{num_rows: n} =
          Repo.query!(
            """
            INSERT INTO lat_section_id_renames (law_name, old_section_id, new_section_id, status, match, reparse_id)
            SELECT $1, u.old, u.new, u.status, u.match, $6
            FROM unnest($2::text[], $3::text[], $4::text[], $5::text[]) AS u(old, new, status, match)
            """,
            [law_name, olds, news, statuses, matches, Ecto.UUID.dump!(reparse_id)]
          )

        n
    end
  end

  @doc "Control mappings still pointing at the given (no longer existing) ids."
  @spec orphaned_mappings([String.t()]) :: non_neg_integer()
  def orphaned_mappings([]), do: 0

  def orphaned_mappings(ids) do
    %{rows: [[n]]} =
      Repo.query!("SELECT count(*) FROM control_mappings WHERE section_id = ANY($1)", [ids])

    n
  end

  defp unzip4(entries) do
    {Enum.map(entries, &elem(&1, 0)), Enum.map(entries, &elem(&1, 1)),
     Enum.map(entries, &elem(&1, 2)), Enum.map(entries, &elem(&1, 3))}
  end
end
