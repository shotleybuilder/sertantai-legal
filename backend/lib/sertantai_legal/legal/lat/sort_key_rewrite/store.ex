defmodule SertantaiLegal.Legal.Lat.SortKeyRewrite.Store do
  @moduledoc """
  DB side of `SortKeyRewrite`: find stored `legal_articles` rows whose
  `sort_key` the 2026-09-26/27 fixes change (segment rewrite, then the
  per-law document-order repair), snapshot them, and rewrite them in
  place (one UPDATE per law, so the LAT stats trigger refreshes each law's
  `lat_hash` once and fractalaw's manifest picks the change up).

  Section ids, text and fractalaw's provision enrichment are untouched.
  """

  alias SertantaiLegal.Legal.Lat.SortKeyRewrite
  alias SertantaiLegal.Repo

  @type change :: %{
          section_id: String.t(),
          law_name: String.t(),
          old: String.t(),
          new: String.t()
        }

  @doc "Rows whose sort_key changes, for the given laws or `:all`."
  @spec plan([String.t()] | :all) :: [change()]
  def plan(laws \\ :all) do
    {where, params} =
      case laws do
        :all -> {"", []}
        names -> {"WHERE law_name = ANY($1)", [names]}
      end

    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, law_name, section_type, part, chapter, provision, paragraph, schedule, sort_key, position FROM legal_articles #{where}",
        params,
        timeout: 300_000
      )

    rows
    |> Enum.map(fn [sid, law, type, part, ch, prov, para, sch, key, pos] ->
      row = %{
        section_type: type,
        part: part,
        chapter: ch,
        provision: prov,
        paragraph: para,
        schedule: sch,
        position: pos
      }

      new =
        case SortKeyRewrite.rewrite(key || "", row) do
          {:ok, new} -> new
          :skip -> key
        end

      %{section_id: sid, law_name: law, position: pos, old: key, sort_key: new}
    end)
    |> Enum.group_by(& &1.law_name)
    |> Enum.flat_map(fn {_law, law_rows} -> SortKeyRewrite.monotonic(law_rows) end)
    |> Enum.filter(&(&1.sort_key != &1.old))
    |> Enum.map(
      &%{section_id: &1.section_id, law_name: &1.law_name, old: &1.old, new: &1.sort_key}
    )
  end

  @doc """
  Snapshot the old keys into `snapshot_table` (created if absent), then apply
  the changes in one transaction, one UPDATE per law.
  """
  @spec apply!([change()], String.t()) :: %{rows: non_neg_integer(), laws: non_neg_integer()}
  def apply!(changes, snapshot_table) do
    unless Regex.match?(~r/^[a-z_][a-z0-9_]*$/, snapshot_table),
      do: raise(ArgumentError, "invalid snapshot table name: #{snapshot_table}")

    by_law = Enum.group_by(changes, & &1.law_name)

    {:ok, rows} =
      Repo.transaction(
        fn ->
          Repo.query!("""
          CREATE TABLE IF NOT EXISTS #{snapshot_table} (
            section_id text PRIMARY KEY, law_name text NOT NULL,
            old_sort_key text NOT NULL, new_sort_key text NOT NULL,
            snapshot_at timestamptz NOT NULL DEFAULT now())
          """)

          Enum.reduce(by_law, 0, fn {law, cs}, acc ->
            ids = Enum.map(cs, & &1.section_id)
            olds = Enum.map(cs, & &1.old)
            news = Enum.map(cs, & &1.new)

            Repo.query!(
              """
              INSERT INTO #{snapshot_table} (section_id, law_name, old_sort_key, new_sort_key)
              SELECT u.id, $4, u.old, u.new FROM unnest($1::text[], $2::text[], $3::text[]) AS u(id, old, new)
              ON CONFLICT (section_id) DO NOTHING
              """,
              [ids, olds, news, law]
            )

            %{num_rows: n} =
              Repo.query!(
                """
                UPDATE legal_articles a SET sort_key = u.new
                FROM unnest($1::text[], $2::text[], $3::text[]) AS u(id, old, new)
                WHERE a.section_id = u.id AND a.sort_key = u.old
                """,
                [ids, olds, news]
              )

            acc + n
          end)
        end,
        timeout: :infinity
      )

    %{rows: rows, laws: map_size(by_law)}
  end
end
