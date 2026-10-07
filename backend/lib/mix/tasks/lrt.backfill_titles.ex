defmodule Mix.Tasks.Lrt.BackfillTitles do
  @moduledoc """
  Backfill `title_en` for register laws that have none (2026-10-07: 1,453,
  nearly all legacy imports from 2024-04 and 2025-02 that never had their
  metadata fetched, e.g. UK_ukpga_2021_26, the Finance Act 2021).

      mix lrt.backfill_titles                 # dry run: fetch and list titles
      mix lrt.backfill_titles --apply         # write title_en (+ updated_at)
      mix lrt.backfill_titles --limit 20      # first N only

  The title comes from legislation.gov.uk metadata (`Metadata.fetch/1`, the
  same source as the LRT scrape). Only `title_en` is written, so nothing
  else on the record changes; `updated_at` is bumped for the delta sync.
  Laws whose name has no type code (`UK__1996_3016`) can't be fetched and
  are listed separately.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.Metadata

  @shortdoc "Fetch missing law titles from legislation.gov.uk"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [apply: :boolean, limit: :integer])
    Mix.Task.run("app.start")

    %{rows: rows} =
      Repo.query!("""
      SELECT name, coalesce(type_code, ''), year, number FROM legal_register
      WHERE country = 'uk' AND coalesce(title_en, '') = '' ORDER BY name
      """)

    {fetchable, malformed} =
      Enum.split_with(rows, fn [_, type, year, number] ->
        type != "" and year != nil and number != nil
      end)

    fetchable = if opts[:limit], do: Enum.take(fetchable, opts[:limit]), else: fetchable

    Mix.shell().info("#{length(fetchable)} laws to fetch; #{length(malformed)} with no type code")
    for [name | _] <- malformed, do: Mix.shell().info("  no type code: #{name}")

    results = Enum.map(fetchable, &fetch_title/1)
    found = for {name, {:ok, title}} <- results, do: {name, title}
    failed = for {name, {:error, reason}} <- results, do: {name, reason}

    for {name, title} <- found, do: Mix.shell().info("  #{name}: #{title}")
    for {name, reason} <- failed, do: Mix.shell().error("  #{name}: #{reason}")

    if opts[:apply] do
      for {name, title} <- found do
        Repo.query!(
          "UPDATE legal_register SET title_en = $2, updated_at = now() WHERE country = 'uk' AND name = $1",
          [name, title]
        )
      end

      Mix.shell().info("\nApplied: #{length(found)} titles written; #{length(failed)} failed")
    else
      Mix.shell().info(
        "\nDry run: #{length(found)} titles found, #{length(failed)} failed; nothing written"
      )
    end
  end

  defp fetch_title([name, type, year, number]) do
    case Metadata.fetch(%{type_code: type, Year: year, Number: to_string(number)}) do
      {:ok, %{Title_EN: title}} when is_binary(title) and title != "" -> {name, {:ok, title}}
      {:ok, _} -> {name, {:error, "no title in metadata"}}
      {:error, reason} -> {name, {:error, inspect(reason)}}
    end
  end
end
