defmodule Mix.Tasks.Lat.Qa do
  @moduledoc """
  Automated QA checks for parsed LAT data from a session.

  Runs 8 checks per law: row count, section type distribution, section_id
  uniqueness, doubled section_ids (Issue #120), prefix convention, hierarchy
  integrity, sort key ordering, and annotation sanity.

  ## Usage

      mix lat.qa SESSION_ID
      mix lat.qa --law UK_ssi_2009_140
      mix lat.qa SESSION_ID --verbose
  """

  use Mix.Task
  require Logger

  alias SertantaiLegal.Repo

  @shortdoc "Run automated QA on parsed LAT session"

  # EU type codes that legitimately use art. prefix
  @eu_type_codes ~w(eudr eur eudn)

  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional, _} =
      OptionParser.parse(args,
        switches: [verbose: :boolean, law: :string],
        aliases: [v: :verbose]
      )

    verbose? = Keyword.get(opts, :verbose, false)

    law_names =
      case Keyword.get(opts, :law) do
        nil ->
          case positional do
            [session_id] -> laws_from_session(session_id)
            _ -> Mix.raise("Usage: mix lat.qa SESSION_ID or --law LAW_NAME")
          end

        law_name ->
          [law_name]
      end

    session_label = List.first(positional) || "single law"
    IO.puts("── #{session_label} (#{length(law_names)} laws) ──\n")

    results = Enum.map(law_names, &run_checks(&1, verbose?))

    pass = Enum.count(results, &(&1.status == :pass))
    warn = Enum.count(results, &(&1.status == :warn))
    fail = Enum.count(results, &(&1.status == :fail))

    IO.puts("\n── Summary ──")
    IO.puts("  Pass: #{pass}  Warn: #{warn}  Fail: #{fail}")
  end

  defp laws_from_session(session_id) do
    case Repo.query(
           "SELECT law_name FROM scrape_session_records WHERE session_id = $1 ORDER BY law_name",
           [session_id]
         ) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [name] -> name end)
      _ -> Mix.raise("Session not found: #{session_id}")
    end
  end

  defp run_checks(law_name, verbose?) do
    checks = [
      check_row_count(law_name),
      check_section_types(law_name),
      check_uniqueness(law_name),
      check_doubled_ids(law_name),
      check_prefix(law_name),
      check_hierarchy(law_name),
      check_sort_order(law_name),
      check_annotations(law_name)
    ]

    failures = Enum.filter(checks, &(&1.level == :fail))
    warnings = Enum.filter(checks, &(&1.level == :warn))
    row_count = get_row_count(law_name)

    status =
      cond do
        failures != [] -> :fail
        warnings != [] -> :warn
        true -> :pass
      end

    icon =
      case status do
        :pass -> "✓"
        :warn -> "⚠"
        :fail -> "✗"
      end

    issues =
      (failures ++ warnings)
      |> Enum.map(& &1.message)
      |> Enum.join(", ")

    suffix = if issues == "", do: "all checks pass", else: issues

    IO.puts(
      "#{icon} #{String.pad_trailing(law_name, 25)} #{String.pad_leading(to_string(row_count), 5)} rows  [#{suffix}]"
    )

    if verbose? do
      Enum.each(checks, fn c ->
        icon =
          case c.level do
            :pass -> "  ✓"
            :warn -> "  ⚠"
            :fail -> "  ✗"
          end

        IO.puts("#{icon} #{c.name}: #{c.message}")
      end)
    end

    %{law_name: law_name, status: status, checks: checks}
  end

  # ── Check implementations ──────────────────────────────────────────

  defp check_row_count(law_name) do
    count = get_row_count(law_name)

    cond do
      count == 0 -> %{name: "row_count", level: :warn, message: "0 rows"}
      count <= 2 -> %{name: "row_count", level: :warn, message: "only #{count} rows"}
      true -> %{name: "row_count", level: :pass, message: "#{count} rows"}
    end
  end

  defp check_section_types(law_name) do
    query = """
    SELECT
      COUNT(*) FILTER (WHERE section_type = 'paragraph') AS paras,
      COUNT(*) FILTER (WHERE section_type IN ('article', 'section')) AS provisions
    FROM legal_articles WHERE law_name = $1
    """

    case Repo.query(query, [law_name]) do
      {:ok, %{rows: [[paras, provisions]]}} ->
        cond do
          provisions == 0 ->
            %{name: "section_types", level: :warn, message: "no provision rows"}

          paras == 0 ->
            %{name: "section_types", level: :warn, message: "no paragraph rows (shallow parse)"}

          true ->
            %{
              name: "section_types",
              level: :pass,
              message: "#{provisions} provisions, #{paras} paragraphs"
            }
        end

      _ ->
        %{name: "section_types", level: :warn, message: "query failed"}
    end
  end

  defp check_uniqueness(law_name) do
    query = """
    SELECT section_id, COUNT(*) FROM legal_articles
    WHERE law_name = $1 AND section_id NOT LIKE '%#%'
    GROUP BY section_id HAVING COUNT(*) > 1
    """

    case Repo.query(query, [law_name]) do
      {:ok, %{rows: []}} ->
        # Check disambiguated IDs
        disambig_query =
          "SELECT COUNT(*) FROM legal_articles WHERE law_name = $1 AND section_id LIKE '%#%'"

        case Repo.query(disambig_query, [law_name]) do
          {:ok, %{rows: [[0]]}} ->
            %{name: "uniqueness", level: :pass, message: "all unique"}

          {:ok, %{rows: [[n]]}} ->
            %{name: "uniqueness", level: :warn, message: "#{n} disambiguated (#position) IDs"}

          _ ->
            %{name: "uniqueness", level: :pass, message: "all unique"}
        end

      {:ok, %{rows: dupes}} ->
        %{name: "uniqueness", level: :fail, message: "#{length(dupes)} duplicate section_ids"}

      _ ->
        %{name: "uniqueness", level: :warn, message: "query failed"}
    end
  end

  defp check_doubled_ids(law_name) do
    query = """
    WITH doubled AS (
      SELECT section_id,
        regexp_replace(section_id, '\\.(\\d+[A-Za-z]*)\\(\\1\\).*$', '.\\1') AS base,
        (regexp_match(section_id, '\\.(\\d+[A-Za-z]*)\\(\\1\\)'))[1] AS num
      FROM legal_articles
      WHERE law_name = $1 AND section_id ~ '\\.(\\d+[A-Za-z]*)\\(\\1\\)'
    )
    SELECT COUNT(*) FROM doubled d
    WHERE NOT EXISTS (
      SELECT 1 FROM legal_articles la2
      WHERE la2.law_name = $1
        AND la2.section_id LIKE d.base || '(%'
        AND la2.section_id NOT LIKE d.base || '(' || d.num || ')%'
    )
    """

    case Repo.query(query, [law_name]) do
      {:ok, %{rows: [[0]]}} ->
        %{name: "doubled_ids", level: :pass, message: "none"}

      {:ok, %{rows: [[n]]}} ->
        %{name: "doubled_ids", level: :fail, message: "#{n} doubled section_ids"}

      _ ->
        %{name: "doubled_ids", level: :warn, message: "query failed"}
    end
  end

  defp check_prefix(law_name) do
    type_code = extract_type_code(law_name)
    is_eu = type_code in @eu_type_codes

    {bad_pattern, issue_label} =
      if is_eu do
        {":reg.", "reg. on EU law"}
      else
        {":art.", "art. on domestic"}
      end

    query = """
    SELECT COUNT(*) FROM legal_articles
    WHERE law_name = $1 AND section_id LIKE '%' || $2 || '%'
    """

    case Repo.query(query, [law_name, bad_pattern]) do
      {:ok, %{rows: [[0]]}} ->
        %{name: "prefix", level: :pass, message: "correct"}

      {:ok, %{rows: [[n]]}} ->
        %{name: "prefix", level: :fail, message: "#{n} rows with #{issue_label}"}

      _ ->
        %{name: "prefix", level: :warn, message: "query failed"}
    end
  end

  defp check_hierarchy(law_name) do
    query = """
    SELECT COUNT(*) FROM legal_articles
    WHERE law_name = $1
      AND section_type IN ('article', 'section', 'sub_article', 'sub_section')
      AND hierarchy_path IS NULL
    """

    case Repo.query(query, [law_name]) do
      {:ok, %{rows: [[0]]}} ->
        %{name: "hierarchy", level: :pass, message: "intact"}

      {:ok, %{rows: [[n]]}} ->
        %{name: "hierarchy", level: :warn, message: "#{n} orphan provisions"}

      _ ->
        %{name: "hierarchy", level: :warn, message: "query failed"}
    end
  end

  defp check_sort_order(law_name) do
    query = """
    WITH ordered AS (
      SELECT position, sort_key,
        LAG(sort_key) OVER (ORDER BY position) AS prev_sort_key
      FROM legal_articles WHERE law_name = $1
    )
    SELECT COUNT(*) FROM ordered
    WHERE prev_sort_key IS NOT NULL AND sort_key < prev_sort_key
    """

    case Repo.query(query, [law_name]) do
      {:ok, %{rows: [[0]]}} ->
        %{name: "sort_order", level: :pass, message: "monotonic"}

      {:ok, %{rows: [[n]]}} ->
        %{name: "sort_order", level: :warn, message: "#{n} sort breaks"}

      _ ->
        %{name: "sort_order", level: :warn, message: "query failed"}
    end
  end

  defp check_annotations(law_name) do
    query = """
    SELECT
      COALESCE(SUM(la.amendment_count), 0) AS lat_amendments,
      (SELECT COUNT(*) FROM amendment_annotations WHERE law_name = $1) AS annotation_records
    FROM legal_articles la WHERE la.law_name = $1
    """

    case Repo.query(query, [law_name]) do
      {:ok, %{rows: [[lat_amends, ann_records]]}} ->
        cond do
          lat_amends > 0 and ann_records == 0 ->
            %{
              name: "annotations",
              level: :warn,
              message: "#{lat_amends} amendments in LAT but 0 annotation records"
            }

          true ->
            %{name: "annotations", level: :pass, message: "#{ann_records} annotations"}
        end

      _ ->
        %{name: "annotations", level: :warn, message: "query failed"}
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────

  defp get_row_count(law_name) do
    case Repo.query("SELECT COUNT(*) FROM legal_articles WHERE law_name = $1", [law_name]) do
      {:ok, %{rows: [[n]]}} -> n
      _ -> 0
    end
  end

  defp extract_type_code(law_name) do
    case String.split(law_name, "_", parts: 4) do
      [_, type_code, _, _] -> type_code
      _ -> ""
    end
  end
end
