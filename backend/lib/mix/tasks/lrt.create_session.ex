defmodule Mix.Tasks.Lrt.CreateSession do
  @shortdoc "Create a scrape/import session from a list of law names"

  @moduledoc """
  Creates a scrape session and its records from law names provided via
  CLI arguments, a SQL query, or a file.

  All laws are validated against legal_register before insertion. Session
  metadata (year/month/day, counts, status) is set automatically.

  ## Usage

      # Comma-separated law names
      mix lrt.create_session --name qq-revoked-verify-2026-07-23 \\
        --laws UK_ssi_2006_133,UK_uksi_1999_2001,UK_uksi_2002_1144

      # From a SQL query
      mix lrt.create_session --name qq-revoked-verify-2026-07-23 \\
        --query "SELECT name FROM legal_register WHERE live LIKE '%Revoked%'"

      # From a file (one law name per line)
      mix lrt.create_session --name qq-revoked-verify-2026-07-23 \\
        --file /tmp/laws.txt

      # Dry run (validate only, don't create)
      mix lrt.create_session --name test --laws UK_uksi_2024_46 --dry-run

  ## Options

      --name     Session identifier (required)
      --laws     Comma-separated law names
      --query    SQL query returning law names (single column)
      --file     File with one law name per line
      --type     Session type: import (default), lat_parse, reparse
      --dry-run  Validate and show what would be created, but don't insert
  """

  use Mix.Task

  require Ash.Query

  alias SertantaiLegal.Scraper.{ScrapeSession, ScrapeSessionRecord}

  @switches [
    name: :string,
    laws: :string,
    query: :string,
    file: :string,
    type: :string,
    dry_run: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    name = opts[:name] || abort("--name is required")
    session_type = opts[:type] || "import"
    dry_run = opts[:dry_run] || false

    # Start app before resolve_laws — --query needs the Repo
    Mix.Task.run("app.start")

    law_names = resolve_laws(opts)

    if law_names == [] do
      abort("No laws provided. Use --laws, --query, or --file")
    end

    # Validate all laws exist in legal_register
    {found, missing} = validate_laws(law_names)

    if missing != [] do
      Mix.shell().error("Laws not found in legal_register:")

      Enum.each(missing, fn name ->
        Mix.shell().error("  #{name}")
      end)

      abort("#{length(missing)} law(s) not found. Fix and retry.")
    end

    # Show summary
    Mix.shell().info("Session: #{name}")
    Mix.shell().info("Type:    #{session_type}")
    Mix.shell().info("Laws:    #{length(found)}")
    Mix.shell().info("")

    Enum.each(found, fn entry ->
      Mix.shell().info("  #{entry.name}  #{entry.title_en}  [#{entry.live || "unknown"}]")
    end)

    if dry_run do
      Mix.shell().info("\n--dry-run: nothing created")
      :ok
    else
      create_session(name, session_type, found)
    end
  end

  defp resolve_laws(opts) do
    cond do
      opts[:laws] ->
        opts[:laws]
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      opts[:query] ->
        result =
          Ecto.Adapters.SQL.query!(SertantaiLegal.Repo, opts[:query])

        Enum.map(result.rows, fn [name | _] -> name end)

      opts[:file] ->
        opts[:file]
        |> File.read!()
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      true ->
        []
    end
    |> Enum.uniq()
  end

  defp validate_laws(law_names) do
    records =
      SertantaiLegal.Legal.LegalRegister
      |> Ash.Query.filter(name in ^law_names)
      |> Ash.read!()

    found_names = MapSet.new(records, & &1.name)

    found =
      Enum.map(records, fn r ->
        %{
          name: r.name,
          title_en: r.title_en,
          type_code: r.type_code,
          year: r.year,
          number: r.number,
          live: r.live
        }
      end)

    missing = Enum.reject(law_names, &MapSet.member?(found_names, &1))

    {found, missing}
  end

  defp create_session(name, session_type, laws) do
    today = Date.utc_today()

    # Create session
    {:ok, _session} =
      ScrapeSession
      |> Ash.Changeset.for_create(:create, %{
        session_id: name,
        year: today.year,
        month: today.month,
        day_from: today.day,
        day_to: today.day,
        status: :pending,
        session_type: session_type,
        group1_count: length(laws)
      })
      |> Ash.create()

    # Create records with enriched parsed_data
    Enum.each(laws, fn entry ->
      parsed_data = %{
        "name" => entry.name,
        "title_en" => entry.title_en,
        "type_code" => entry.type_code,
        "year" => to_string(entry.year),
        "number" => to_string(entry.number)
      }

      ScrapeSessionRecord
      |> Ash.Changeset.for_create(:create, %{
        session_id: name,
        law_name: entry.name,
        group: :group1,
        status: :pending,
        selected: false,
        parsed_data: parsed_data
      })
      |> Ash.create!()
    end)

    # Transition to categorized so records show in UI
    {:ok, session} =
      ScrapeSession
      |> Ash.Query.filter(session_id == ^name)
      |> Ash.read_one!()
      |> Ash.Changeset.for_update(:mark_categorized, %{})
      |> Ash.update()

    Mix.shell().info("\n✓ Session '#{name}' created")
    Mix.shell().info("  #{length(laws)} records in group1, status: #{session.status}")
  end

  defp abort(message) do
    Mix.shell().error(message)
    exit({:shutdown, 1})
  end
end
