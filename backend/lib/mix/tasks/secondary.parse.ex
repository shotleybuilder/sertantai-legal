defmodule Mix.Tasks.Secondary.Parse do
  @shortdoc "Parse a PDF into secondary source provisions"

  @moduledoc """
  Parses a PDF document into structured provisions for a registered secondary source.

  ## Usage

      mix secondary.parse <source_id> <pdf_path>
      mix secondary.parse <source_id> <pdf_path> --dry-run
      mix secondary.parse <source_id> <pdf_path> --clear

  ## Options

      --dry-run   Show parsed provisions without writing to database
      --clear     Delete existing provisions for this source before inserting

  ## Example

      mix secondary.parse JSP-375 data/secondary-sources/jsp/jsp375/jsp375_ch08.pdf --dry-run
  """

  use Mix.Task

  require Ash.Query

  alias SertantaiLegal.Legal.SecondarySource
  alias SertantaiLegal.Legal.SecondarySourceProvision
  alias SertantaiLegal.Legal.SecondarySource.PdfParser

  @switches [dry_run: :boolean, clear: :boolean, profile: :string]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional, _} = OptionParser.parse(args, switches: @switches)
    dry_run? = Keyword.get(opts, :dry_run, false)
    clear? = Keyword.get(opts, :clear, false)

    parse_opts =
      case Keyword.get(opts, :profile) do
        nil -> []
        p -> [profile: String.to_atom(p)]
      end

    case positional do
      [source_id, pdf_path] ->
        parse(source_id, pdf_path, dry_run?, clear?, parse_opts)

      _ ->
        IO.puts("Usage: mix secondary.parse <source_id> <pdf_path> [--dry-run] [--clear]")
        System.halt(1)
    end
  end

  defp parse(source_id, pdf_path, dry_run?, clear?, parse_opts) do
    # Validate PDF exists
    unless File.exists?(pdf_path) do
      IO.puts("Error: PDF not found at #{pdf_path}")
      System.halt(1)
    end

    # Find the secondary source
    source =
      SecondarySource
      |> Ash.Query.filter(source_id == ^source_id)
      |> Ash.read!()
      |> case do
        [source] ->
          source

        [] ->
          IO.puts("Error: No secondary source registered with source_id '#{source_id}'")
          IO.puts("Register it first: mix secondary.register --source-id #{source_id} ...")
          System.halt(1)
      end

    IO.puts("=== Parse Secondary Source ===")
    IO.puts("Source:  #{source.source_id} — #{source.title}")
    IO.puts("PDF:     #{pdf_path}")
    IO.puts("Mode:    #{if dry_run?, do: "DRY RUN", else: "APPLY"}")
    IO.puts("")

    # Parse PDF
    case PdfParser.parse(pdf_path, source, parse_opts) do
      {:ok, provisions, profile} ->
        IO.puts("Profile: #{profile.name} (body=#{profile.fonts.body_size}pt)")
        IO.puts("Parsed #{length(provisions)} provisions\n")
        print_provisions(provisions)

        unless dry_run? do
          if clear?, do: clear_existing(source)
          upsert_provisions(provisions)
        end

      {:error, reason} ->
        IO.puts("Parse error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp print_provisions(provisions) do
    Enum.each(provisions, fn prov ->
      indent = String.duplicate("  ", prov.depth)
      label = String.upcase(to_string(prov.section_type))
      heading = prov.heading || String.slice(prov.text || "", 0, 70)
      IO.puts("#{indent}[#{label}] #{heading}")
      IO.puts("#{indent}  → #{prov.section_id}")
    end)

    IO.puts("")

    # Summary by type
    by_type = Enum.group_by(provisions, & &1.section_type)
    summary = Enum.map_join(by_type, ", ", fn {type, items} -> "#{length(items)} #{type}" end)
    IO.puts("Summary: #{summary}")
    IO.puts("")
  end

  defp clear_existing(source) do
    source_uuid = source.id

    existing =
      SecondarySourceProvision
      |> Ash.Query.filter(secondary_source_id == ^source_uuid)
      |> Ash.read!()

    if existing != [] do
      IO.puts("Clearing #{length(existing)} existing provisions...")
      Enum.each(existing, fn prov -> Ash.destroy!(prov) end)
    end
  end

  defp upsert_provisions(provisions) do
    IO.puts("Upserting #{length(provisions)} provisions...")

    {ok, errors} =
      Enum.reduce(provisions, {0, 0}, fn prov, {ok, err} ->
        case Ash.create(SecondarySourceProvision, prov, action: :upsert) do
          {:ok, _} ->
            {ok + 1, err}

          {:error, error} ->
            IO.puts("  ERROR: #{prov.section_id}: #{inspect(error)}")
            {ok, err + 1}
        end
      end)

    IO.puts("Done: #{ok} upserted, #{errors} errors")
  end
end
