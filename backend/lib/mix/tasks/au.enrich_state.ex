defmodule Mix.Tasks.Au.EnrichState do
  @moduledoc """
  Enrich AU state records with source URLs by constructing portal URLs from titles.

  Each state portal has a different URL pattern. For slug-based portals (VIC, NT),
  URLs are constructed from the title and verified with a HEAD request.

  ## Usage

      mix au.enrich_state vic                  # Enrich all VIC records
      mix au.enrich_state nt                   # Enrich all NT records
      mix au.enrich_state all                  # All supported states
      mix au.enrich_state vic --dry-run        # Report without updating
      mix au.enrich_state vic --limit 20       # First N records
  """

  use Mix.Task

  alias SertantaiLegal.Legal.LegalRegister

  require Ash.Query

  # Portal URL builders per jurisdiction.
  # Returns {base_url, slug_fn} or nil if not supported.
  @portals %{
    "vic" => {"https://www.legislation.vic.gov.au/in-force", &__MODULE__.vic_slug/1},
    "nt" => {"https://legislation.nt.gov.au/Legislation", &__MODULE__.nt_slug/1}
  }

  @supported_jurisdictions Map.keys(@portals)

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args, switches: [dry_run: :boolean, limit: :integer])

    dry_run? = Keyword.get(opts, :dry_run, false)
    limit = Keyword.get(opts, :limit, nil)

    jurisdictions =
      case List.first(positional) do
        "all" ->
          @supported_jurisdictions

        j when j in @supported_jurisdictions ->
          [j]

        other ->
          Mix.shell().error(
            "Unknown jurisdiction: #{other}. Supported: #{Enum.join(@supported_jurisdictions, ", ")}, all"
          )

          System.halt(1)
      end

    Mix.Task.run("app.start")

    for jurisdiction <- jurisdictions do
      process_jurisdiction(jurisdiction, dry_run?, limit)
    end
  end

  defp process_jurisdiction(jurisdiction, dry_run?, limit) do
    Mix.shell().info("\n=== #{String.upcase(jurisdiction)} ===")

    records = fetch_unenriched(jurisdiction, limit)
    total = length(records)
    Mix.shell().info("Found #{total} unenriched #{jurisdiction} records")

    if total == 0 do
      Mix.shell().info("Nothing to do.")
      return_ok()
    end

    {base_url, slug_fn} = Map.fetch!(@portals, jurisdiction)

    {found, not_found, errors} =
      records
      |> Enum.with_index(1)
      |> Enum.reduce({0, 0, 0}, fn {record, idx}, {f, nf, e} ->
        if rem(idx, 20) == 0, do: Mix.shell().info("  Processing #{idx}/#{total}...")

        slug = slug_fn.(record)
        url = "#{base_url}/#{slug}"

        case verify_url(url) do
          :ok ->
            unless dry_run?, do: update_source_url(record, url)
            {f + 1, nf, e}

          :not_found ->
            {f, nf + 1, e}

          :error ->
            {f, nf, e + 1}
        end
      end)

    prefix = if dry_run?, do: "[DRY RUN] ", else: ""

    Mix.shell().info("""
    #{prefix}#{String.upcase(jurisdiction)} complete:
      Found: #{found}/#{total}
      Not found: #{not_found}
      Errors: #{errors}
    """)
  end

  defp return_ok, do: :ok

  defp fetch_unenriched(jurisdiction, limit) do
    query =
      LegalRegister
      |> Ash.Query.filter(
        country == "au" and jurisdiction == ^jurisdiction and is_nil(source_url)
      )
      |> Ash.Query.sort(name: :asc)

    query = if limit, do: Ash.Query.limit(query, limit), else: query

    case Ash.read(query) do
      {:ok, records} when is_list(records) -> records
      _ -> []
    end
  end

  # ── Slug Builders ───────────────────────────────────────────────────

  @doc "Build VIC legislation URL slug: acts/title-slug or statutory-rules/title-slug"
  def vic_slug(record) do
    type_prefix =
      cond do
        String.contains?(record.type_code || "", "act") -> "acts"
        String.contains?(record.type_code || "", "reg") -> "statutory-rules"
        true -> "acts"
      end

    slug = title_to_slug(record.title_en)
    "#{type_prefix}/#{slug}"
  end

  @doc "Build NT legislation URL slug: UPPERCASE-TITLE-SLUG"
  def nt_slug(record) do
    record.title_en
    |> String.upcase()
    |> String.replace(~r/[^A-Z0-9]+/, "-")
    |> String.trim("-")
  end

  defp title_to_slug(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  # ── URL Verification ────────────────────────────────────────────────

  defp verify_url(url) do
    # Rate limit
    Process.sleep(50)

    case Req.head(url, receive_timeout: 10_000, redirect: true, retry: false) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status}} when status in [301, 302, 303, 307, 308] ->
        :ok

      {:ok, %Req.Response{status: 404}} ->
        :not_found

      {:ok, %Req.Response{status: _status}} ->
        :not_found

      {:error, _} ->
        :error
    end
  end

  defp update_source_url(record, url) do
    case record |> Ash.Changeset.for_update(:update, %{source_url: url}) |> Ash.update() do
      {:ok, _} -> :ok
      {:error, reason} -> Mix.shell().error("  Update failed: #{inspect(reason)}")
    end
  end
end
