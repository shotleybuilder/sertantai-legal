defmodule Mix.Tasks.Legal.FixMisidentified do
  @shortdoc "Fix misidentified Scottish/Welsh laws from Enhesa import"

  @moduledoc """
  Analyses and fixes laws where the Enhesa CSV import inferred the wrong type_code
  (e.g. S.S.I. matched as uksi instead of ssi).

  ## Usage

      mix legal.fix_misidentified <session_id>                  # Analyse only
      mix legal.fix_misidentified <session_id> --law UK_uksi_1976_72  # Analyse one law
      mix legal.fix_misidentified <session_id> --apply UK_uksi_1976_72  # Fix one law
      mix legal.fix_misidentified <session_id> --apply-all       # Fix all (after review)

  ## What it does

  For each misidentified law:
  1. Reads the Enhesa title from import session records
  2. Infers the correct type_code (ssi, wsi, ukpga) from the title
  3. Checks if the correct record already exists in LRT
  4. Reports what would change

  With --apply:
  - Updates session records (law_name + parsed_data) to correct name
  - Updates applicability records if any
  - Deletes the wrongly-scraped LRT record (if created by the scrape session)
  """

  use Mix.Task

  alias SertantaiLegal.Repo

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional, _} =
      OptionParser.parse(args,
        strict: [law: :string, apply: :string, apply_all: :boolean]
      )

    session_id = List.first(positional) || "scrape-qq-missing-2026-06-04"

    cond do
      opts[:apply] ->
        apply_one(session_id, opts[:apply])

      opts[:apply_all] ->
        apply_all(session_id)

      opts[:law] ->
        analyse_one(session_id, opts[:law])

      true ->
        analyse_all(session_id)
    end
  end

  # ── Analysis ──────────────────────────────────────────────────────

  defp analyse_all(session_id) do
    cases = build_cases(session_id)
    IO.puts("=== Misidentified Laws in #{session_id} ===\n")

    by_action = Enum.group_by(cases, & &1.action)

    for {action, laws} <- Enum.sort_by(by_action, fn {k, _} -> k end) do
      IO.puts("--- #{action} (#{length(laws)}) ---")

      for c <- laws do
        IO.puts("  #{c.current_name}")
        IO.puts("    Enhesa:  #{truncate(c.enhesa_title, 70)}")
        IO.puts("    Scraped: #{truncate(c.scraped_title, 70)}")
        IO.puts("    Correct: #{c.correct_name} (#{c.correct_type}) → #{c.action}")
        IO.puts("")
      end
    end

    IO.puts("Summary:")

    for {action, laws} <- Enum.sort_by(by_action, fn {k, _} -> k end) do
      IO.puts("  #{action}: #{length(laws)}")
    end
  end

  defp analyse_one(session_id, law_name) do
    cases = build_cases(session_id)

    case Enum.find(cases, &(&1.current_name == law_name)) do
      nil ->
        IO.puts("Law #{law_name} not found in misidentified set")

      c ->
        IO.puts("=== #{c.current_name} ===")
        IO.puts("Enhesa title:  #{c.enhesa_title}")
        IO.puts("Scraped title: #{c.scraped_title}")
        IO.puts("Correct name:  #{c.correct_name}")
        IO.puts("Correct type:  #{c.correct_type}")
        IO.puts("In LRT:        #{c.correct_exists}")
        IO.puts("Action:        #{c.action}")

        if c.action == "redirect" do
          IO.puts("\nWill:")
          IO.puts("  1. Update session records: #{c.current_name} → #{c.correct_name}")
          IO.puts("  2. Update applicability records (if any)")
          IO.puts("  3. Delete #{c.current_name} from LRT (wrongly scraped)")
        end

        if c.action == "redirect+scrape" do
          IO.puts("\nWill:")
          IO.puts("  1. Update session records: #{c.current_name} → #{c.correct_name}")
          IO.puts("  2. Update applicability records (if any)")
          IO.puts("  3. Delete #{c.current_name} from LRT (wrongly scraped)")
          IO.puts("  4. #{c.correct_name} needs scraping (not yet in LRT)")
        end
    end
  end

  # ── Apply ─────────────────────────────────────────────────────────

  defp apply_one(session_id, law_name) do
    cases = build_cases(session_id)

    case Enum.find(cases, &(&1.current_name == law_name)) do
      nil ->
        IO.puts("Law #{law_name} not found in misidentified set")

      c ->
        IO.puts("=== Fixing #{c.current_name} → #{c.correct_name} ===")
        do_fix(session_id, c)
    end
  end

  defp apply_all(session_id) do
    cases = build_cases(session_id)
    fixable = Enum.filter(cases, &(&1.action in ["redirect", "redirect+scrape"]))

    IO.puts("=== Applying #{length(fixable)} fixes ===\n")

    for c <- fixable do
      IO.puts("#{c.current_name} → #{c.correct_name}")
      do_fix(session_id, c)
    end
  end

  defp do_fix(session_id, c) do
    # 1. Update scrape session records
    {:ok, %{num_rows: n1}} =
      Repo.query(
        "UPDATE scrape_session_records SET law_name = $1, parsed_data = jsonb_set(jsonb_set(parsed_data::jsonb, '{name}', to_jsonb($1::text)), '{type_code}', to_jsonb($2::text)) WHERE session_id = $3 AND law_name = $4",
        [c.correct_name, c.correct_type, session_id, c.current_name]
      )

    IO.puts("  Scrape session records: #{n1}")

    # 2. Update import session records
    {:ok, %{num_rows: n2}} =
      Repo.query(
        "UPDATE scrape_session_records SET law_name = $1 WHERE session_id LIKE 'import-qq-%' AND law_name = $2",
        [c.correct_name, c.current_name]
      )

    IO.puts("  Import session records: #{n2}")

    # 3. Update applicability
    {:ok, %{num_rows: n3}} =
      Repo.query(
        "UPDATE org_applicabilities SET law_name = $1 WHERE law_name = $2",
        [c.correct_name, c.current_name]
      )

    IO.puts("  Applicability records: #{n3}")

    # 4. Delete wrong LRT record (only if it was from this scrape session)
    {:ok, %{num_rows: n4}} =
      Repo.query("DELETE FROM uk_lrt WHERE name = $1", [c.current_name])

    IO.puts("  LRT deleted: #{n4}")
    IO.puts("  Status: #{c.action}")
  end

  # ── Case Builder ──────────────────────────────────────────────────

  defp build_cases(session_id) do
    # Get all non-ssi laws from the scrape session with their Enhesa and scraped titles
    sql = """
    WITH scrape_laws AS (
      SELECT ssr.law_name, u.title_en as scraped_title
      FROM scrape_session_records ssr
      JOIN uk_lrt u ON u.name = ssr.law_name
      WHERE ssr.session_id = $1
        AND ssr.law_name NOT LIKE 'UK_ssi_%'
    ),
    import_titles AS (
      SELECT DISTINCT ON (ssr.law_name) ssr.law_name, ssr.parsed_data->>'title' as enhesa_title
      FROM scrape_session_records ssr
      WHERE ssr.session_id LIKE 'import-qq-%'
        AND ssr.law_name IN (SELECT law_name FROM scrape_laws)
    )
    SELECT s.law_name, i.enhesa_title, s.scraped_title
    FROM scrape_laws s
    JOIN import_titles i ON i.law_name = s.law_name
    ORDER BY s.law_name
    """

    {:ok, %{rows: rows}} = Repo.query(sql, [session_id])

    Enum.map(rows, fn [law_name, enhesa_title, scraped_title] ->
      correct_type = infer_correct_type(enhesa_title)
      correct_name = build_correct_name(law_name, correct_type)
      correct_exists = law_exists?(correct_name)
      titles_match = titles_similar?(enhesa_title, scraped_title)

      action =
        cond do
          titles_match -> "ok"
          correct_exists -> "redirect"
          true -> "redirect+scrape"
        end

      %{
        current_name: law_name,
        enhesa_title: enhesa_title,
        scraped_title: scraped_title,
        correct_type: correct_type,
        correct_name: correct_name,
        correct_exists: correct_exists,
        action: action
      }
    end)
    |> Enum.reject(&(&1.action == "ok"))
  end

  defp infer_correct_type(title) do
    cond do
      title =~ ~r/S\.S\.I\./ -> "ssi"
      title =~ ~r/\(Scotland\)/ and title =~ ~r/S\.I\./ -> "ssi"
      title =~ ~r/\(Scotland\)/ -> "ssi"
      title =~ ~r/Act\s+\d{4}/ and not (title =~ ~r/Regulations|Order|Rules/) -> "ukpga"
      true -> "uksi"
    end
  end

  defp build_correct_name(current_name, correct_type) do
    case String.split(current_name, "_") do
      ["UK", _old_type, year, number] -> "UK_#{correct_type}_#{year}_#{number}"
      _ -> current_name
    end
  end

  defp law_exists?(name) do
    case Repo.query("SELECT 1 FROM uk_lrt WHERE name = $1 LIMIT 1", [name]) do
      {:ok, %{num_rows: 1}} -> true
      _ -> false
    end
  end

  defp titles_similar?(enhesa, scraped) do
    # Strip the SI reference and "The " prefix from Enhesa, compare core title
    clean_enhesa =
      enhesa
      |> String.replace(~r/\s*\(S\.S?\.?I\.?\s*\d+.*$/, "")
      |> String.replace(~r/^The\s+/, "")
      |> String.downcase()
      |> String.trim()

    clean_scraped =
      (scraped || "")
      |> String.replace(~r/^The\s+/, "")
      |> String.downcase()
      |> String.trim()

    clean_scraped != "" and String.contains?(clean_scraped, String.slice(clean_enhesa, 0, 30))
  end

  defp truncate(nil, _), do: "(nil)"
  defp truncate(s, max) when byte_size(s) <= max, do: s
  defp truncate(s, max), do: String.slice(s, 0, max) <> "..."
end
