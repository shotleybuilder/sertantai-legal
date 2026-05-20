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

  alias SertantaiLegal.Scraper.Au.NswFeedClient
  alias SertantaiLegal.Scraper.Au.ActClient

  # Slug-based portals: construct URL from title, verify with HEAD request.
  @slug_portals %{
    "vic" => {"https://www.legislation.vic.gov.au/in-force", &__MODULE__.vic_slug/1},
    "nt" => {"https://legislation.nt.gov.au/Legislation", &__MODULE__.nt_slug/1}
  }

  # Feed-based portals: search by title via Atom feed.
  @feed_portals ~w(nsw)

  # Metadata-scraping portals: fetch page and parse HTML for status/dates.
  @metadata_portals ~w(act)

  @supported_jurisdictions Map.keys(@slug_portals) ++ @feed_portals ++ @metadata_portals

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

    {found, not_found, errors} =
      cond do
        jurisdiction in @metadata_portals ->
          process_metadata(records, jurisdiction, dry_run?, total)

        jurisdiction in @feed_portals ->
          process_feed(records, jurisdiction, dry_run?, total)

        true ->
          {base_url, slug_fn} = Map.fetch!(@slug_portals, jurisdiction)
          process_slugs(records, base_url, slug_fn, dry_run?, total)
      end

    prefix = if dry_run?, do: "[DRY RUN] ", else: ""

    Mix.shell().info("""
    #{prefix}#{String.upcase(jurisdiction)} complete:
      Found: #{found}/#{total}
      Not found: #{not_found}
      Errors: #{errors}
    """)
  end

  defp process_slugs(records, base_url, slug_fn, dry_run?, total) do
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
  end

  defp process_metadata(records, jurisdiction, dry_run?, total) do
    # Include records WITH source_url that need status verification,
    # plus unenriched records without source_url
    all_records =
      case LegalRegister
           |> Ash.Query.filter(
             country == "au" and jurisdiction == ^jurisdiction and
               not is_nil(source_url) and
               type_code not in ["standard", "model_cop", "cop", "nepm"]
           )
           |> Ash.read() do
        {:ok, with_urls} when is_list(with_urls) -> with_urls
        _ -> []
      end

    total = length(all_records)
    Mix.shell().info("  (#{total} records with URLs to verify)")

    all_records
    |> Enum.with_index(1)
    |> Enum.reduce({0, 0, 0}, fn {record, idx}, {f, nf, e} ->
      if rem(idx, 10) == 0, do: Mix.shell().info("  Processing #{idx}/#{total}...")
      Process.sleep(1000)

      url = record.source_url

      if is_nil(url) do
        {f, nf + 1, e}
      else
        case ActClient.fetch_url(url) do
          {:ok, %{status: status} = meta} when not is_nil(status) ->
            # Compare fetched status with what we have
            status_match = is_nil(record.live) or record.live == status
            flag = if status_match, do: "✓", else: "⚠"

            if dry_run? do
              msg = "  #{flag} #{record.title_en} → #{status}"
              msg = if not status_match, do: msg <> " (DB has: #{record.live})", else: msg
              Mix.shell().info(msg)
            else
              attrs = %{live: status}

              attrs =
                if meta.commenced_date,
                  do: Map.put(attrs, :md_coming_into_force_date, meta.commenced_date),
                  else: attrs

              attrs =
                if meta.repeal_date,
                  do: Map.put(attrs, :latest_rescind_date, meta.repeal_date),
                  else: attrs

              record |> Ash.Changeset.for_update(:update, attrs) |> Ash.update()
            end

            {f + 1, nf, e}

          {:ok, nil} ->
            if dry_run?, do: Mix.shell().info("  ✗ #{record.title_en} → 404 (bad URL?)")
            {f, nf + 1, e}

          {:ok, %{status: nil}} ->
            if dry_run?, do: Mix.shell().info("  ? #{record.title_en} → no status found")
            {f, nf + 1, e}

          {:error, reason} ->
            if dry_run?, do: Mix.shell().info("  ! #{record.title_en} → #{inspect(reason)}")
            {f, nf, e + 1}
        end
      end
    end)
  end

  defp process_feed(records, _jurisdiction, dry_run?, total) do
    records
    |> Enum.with_index(1)
    |> Enum.reduce({0, 0, 0}, fn {record, idx}, {f, nf, e} ->
      if rem(idx, 10) == 0, do: Mix.shell().info("  Processing #{idx}/#{total}...")
      # NSW feed rate limits aggressively — 10s between requests
      Process.sleep(10_000)

      case NswFeedClient.search_by_title(record.title_en) do
        {:ok, [best | _]} ->
          if dry_run? do
            Mix.shell().info("  ✓ #{record.title_en} → #{best.source_url}")
          else
            attrs = %{source_url: best.source_url}
            attrs = if best.number, do: Map.put(attrs, :number, best.number), else: attrs
            attrs = if best.status, do: Map.put(attrs, :live, best.status), else: attrs

            record |> Ash.Changeset.for_update(:update, attrs) |> Ash.update()
          end

          {f + 1, nf, e}

        {:ok, []} ->
          {f, nf + 1, e}

        {:error, _} ->
          {f, nf, e + 1}
      end
    end)
  end

  defp return_ok, do: :ok

  defp fetch_unenriched(jurisdiction, limit) do
    # Exclude non-legislation (standards, model CoPs) — they won't be on any legal register
    query =
      LegalRegister
      |> Ash.Query.filter(
        country == "au" and jurisdiction == ^jurisdiction and is_nil(source_url) and
          type_code not in ["standard", "model_cop", "cop"]
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
