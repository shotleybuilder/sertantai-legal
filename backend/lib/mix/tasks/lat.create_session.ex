defmodule Mix.Tasks.Lat.CreateSession do
  @shortdoc "Create a LAT parse session with built-in filtering"

  @moduledoc """
  Creates a LAT parse session from law names, applying filters to exclude
  laws that don't need parsing (already have LAT, revoked, non-making).

  ## Usage

      # From a comma-separated list
      mix lat.create_session --name lat-parse-qq-gaps-2026-07-23 \\
        --laws UK_uksi_2015_1393,UK_uksi_2019_156

      # From a SQL query
      mix lat.create_session --name lat-parse-qq-gaps-2026-07-23 \\
        --query "SELECT name FROM legal_register WHERE lat_count = 0 AND live LIKE '✔%'"

      # From a file (one law name per line)
      mix lat.create_session --name lat-parse-qq-gaps-2026-07-23 \\
        --file /tmp/laws.txt

      # Only include making laws (exclude non-making, keep unclassified)
      mix lat.create_session --name lat-parse-making-2026-07-23 \\
        --laws UK_uksi_2015_1393,UK_uksi_1999_2001 --making-only

      # Skip filters (force all laws into the session)
      mix lat.create_session --name lat-parse-force-2026-07-23 \\
        --laws UK_uksi_2015_1393 --no-filter

  ## Filters (applied by default)

  Each input law is checked against legal_register. Laws are excluded if:

      1. Already has LAT (lat_count > 0) — already parsed
      2. Fully revoked (live = '❌ Revoked / ...') — dead legislation
      3. Non-making (is_making = false) — no obligations to parse (optional, --making-only)

  Use --no-filter to bypass all filters (e.g. for reparsing).

  ## Options

      --name          Session identifier (required)
      --laws          Comma-separated law names
      --query         SQL query returning law names (single column)
      --file          File with one law name per line
      --making-only   Also exclude non-making laws (keeps unclassified/NULL)
      --no-filter     Skip all filters (for reparse sessions)
      --dry-run       Show summary without creating the session
  """

  use Mix.Task

  require Ash.Query

  alias SertantaiLegal.Scraper.{ScrapeSession, ScrapeSessionRecord}

  @switches [
    name: :string,
    laws: :string,
    query: :string,
    file: :string,
    making_only: :boolean,
    no_filter: :boolean,
    dry_run: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    name = opts[:name] || abort("--name is required")
    dry_run = opts[:dry_run] || false
    no_filter = opts[:no_filter] || false
    making_only = opts[:making_only] || false

    Mix.Task.run("app.start")

    law_names = resolve_laws(opts)

    if law_names == [] do
      abort("No laws provided. Use --laws, --query, or --file")
    end

    # Validate all laws exist in legal_register
    {found, missing} = lookup_laws(law_names)

    if missing != [] do
      Mix.shell().error("Laws not found in legal_register:")
      Enum.each(missing, fn n -> Mix.shell().error("  #{n}") end)
      abort("#{length(missing)} law(s) not found. Fix and retry.")
    end

    # Apply filters
    {included, excluded} = apply_filters(found, no_filter, making_only)

    # Show summary
    print_summary(name, included, excluded)

    if dry_run do
      Mix.shell().info("\n--dry-run: nothing created")
      :ok
    else
      if included == [] do
        abort("No laws passed filters. Nothing to create.")
      end

      create_session(name, included)
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
        result = Ecto.Adapters.SQL.query!(SertantaiLegal.Repo, opts[:query])
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

  defp lookup_laws(law_names) do
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
          live: r.live,
          lat_count: r.lat_count || 0,
          is_making: r.is_making,
          making_classification: r.making_classification
        }
      end)

    missing = Enum.reject(law_names, &MapSet.member?(found_names, &1))

    {found, missing}
  end

  defp apply_filters(laws, true = _no_filter, _making_only), do: {laws, []}

  defp apply_filters(laws, _no_filter, making_only) do
    Enum.reduce(laws, {[], []}, fn law, {inc, exc} ->
      cond do
        law.lat_count > 0 ->
          {inc, [{law, "already has LAT (#{law.lat_count} provisions)"} | exc]}

        is_binary(law.live) and String.starts_with?(law.live, "❌") ->
          {inc, [{law, "revoked"} | exc]}

        making_only and law.is_making == false ->
          {inc, [{law, "not making (#{law.making_classification})"} | exc]}

        true ->
          {[law | inc], exc}
      end
    end)
    |> then(fn {inc, exc} -> {Enum.reverse(inc), Enum.reverse(exc)} end)
  end

  defp print_summary(name, included, excluded) do
    Mix.shell().info("Session:  #{name}")
    Mix.shell().info("Type:     lat_parse")
    Mix.shell().info("Input:    #{length(included) + length(excluded)} laws")
    Mix.shell().info("Included: #{length(included)}")
    Mix.shell().info("Excluded: #{length(excluded)}")

    if excluded != [] do
      Mix.shell().info("\nExcluded:")

      Enum.each(excluded, fn {law, reason} ->
        Mix.shell().info("  ✗ #{law.name}  #{reason}")
      end)
    end

    if included != [] do
      Mix.shell().info("\nIncluded:")

      Enum.each(included, fn law ->
        making_tag =
          case law.making_classification do
            nil -> "unclassified"
            mc -> mc
          end

        Mix.shell().info(
          "  ✓ #{law.name}  #{law.title_en}  [#{law.live || "unknown"}, #{making_tag}]"
        )
      end)
    end
  end

  defp create_session(name, laws) do
    today = Date.utc_today()

    {:ok, _session} =
      ScrapeSession
      |> Ash.Changeset.for_create(:create, %{
        session_id: name,
        year: today.year,
        month: today.month,
        day_from: today.day,
        day_to: today.day,
        status: :pending,
        session_type: "lat_parse",
        group1_count: length(laws)
      })
      |> Ash.create()

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
