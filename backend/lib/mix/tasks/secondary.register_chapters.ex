defmodule Mix.Tasks.Secondary.RegisterChapters do
  @shortdoc "Register a multi-chapter JSP as parent + chapter SecondarySource records"

  @moduledoc """
  Scans a directory of chapter PDFs and registers each as a child SecondarySource
  under a parent JSP record. Derives chapter identifiers from filenames.

  ## Usage

      mix secondary.register_chapters \\
        --source-id JSP-375 \\
        --type jsp \\
        --title "Health and Safety Handbook" \\
        --issuer MoD \\
        --weight contractual \\
        --dir data/secondary-sources/jsp/jsp375 \\
        --links UK_ukpga_1974_37:supplements

      mix secondary.register_chapters ... --dry-run

  ## Filename convention

  PDFs must follow `{prefix}_{chapter_id}.pdf`:
  - `jsp375_ch23.pdf` → chapter_id = `CH23`
  - `jsp815_element4.pdf` → chapter_id = `EL4`
  - `jsp418_leaflet6.pdf` → chapter_id = `LF6`
  - `jsp392_part1.pdf` → chapter_id = `PT1`
  - `jsp815_annexA.pdf` → chapter_id = `ANNEXA`

  ## What it creates

  1. Parent record: source_id = `JSP-375`, no provisions (grouping only)
  2. Chapter records: source_id = `JSP-375-CH23`, parent_source_id → parent
  3. Law links on the PARENT (chapters inherit via aggregation, or get their own later)
  """

  use Mix.Task

  require Ash.Query

  alias SertantaiLegal.Legal.SecondarySource
  alias SertantaiLegal.Legal.SourceLink

  @switches [
    source_id: :string,
    type: :string,
    title: :string,
    issuer: :string,
    weight: :string,
    edition: :string,
    dir: :string,
    links: :string,
    dry_run: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    required = [:source_id, :type, :title, :issuer, :weight, :dir]
    missing = Enum.filter(required, &(!Keyword.has_key?(opts, &1)))

    if missing != [] do
      IO.puts("Missing required options: #{Enum.map_join(missing, ", ", &"--#{&1}")}")
      IO.puts("\nRun `mix help secondary.register_chapters` for usage.")
      System.halt(1)
    end

    dry_run? = Keyword.get(opts, :dry_run, false)
    register(opts, dry_run?)
  end

  defp register(opts, dry_run?) do
    source_id = Keyword.fetch!(opts, :source_id)
    dir = Keyword.fetch!(opts, :dir)

    unless File.dir?(dir) do
      IO.puts("Error: Directory not found: #{dir}")
      System.halt(1)
    end

    # Discover chapter PDFs
    pdfs =
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".pdf"))
      |> Enum.sort()

    if pdfs == [] do
      IO.puts("Error: No PDF files found in #{dir}")
      System.halt(1)
    end

    chapter_ids = Enum.map(pdfs, &derive_chapter_id/1)

    IO.puts("=== Register Multi-Chapter Source ===")
    IO.puts("Parent:   #{source_id}")
    IO.puts("Dir:      #{dir}")
    IO.puts("Chapters: #{length(pdfs)}")
    IO.puts("Mode:     #{if dry_run?, do: "DRY RUN", else: "APPLY"}\n")

    Enum.zip(pdfs, chapter_ids)
    |> Enum.each(fn {pdf, ch_id} ->
      IO.puts("  #{pdf} → #{source_id}-#{ch_id}")
    end)

    IO.puts("")

    if dry_run? do
      IO.puts("[DRY RUN] No changes made.")
    else
      parent = find_or_create_parent(opts)
      IO.puts("Parent: #{parent.source_id} (#{parent.id})")

      # Step 2: Create law links on parent
      create_parent_links(parent, Keyword.get(opts, :links))

      # Step 3: Register each chapter
      IO.puts("\nRegistering chapters:")

      Enum.zip(pdfs, chapter_ids)
      |> Enum.each(fn {pdf, ch_id} ->
        child_source_id = "#{source_id}-#{ch_id}"
        title = derive_chapter_title(pdf, ch_id, parent.title)

        register_chapter(child_source_id, title, parent, opts)
      end)

      IO.puts("\nDone.")
    end
  end

  defp find_or_create_parent(opts) do
    source_id = Keyword.fetch!(opts, :source_id)

    existing =
      SecondarySource
      |> Ash.Query.filter(source_id == ^source_id)
      |> Ash.read!()

    case existing do
      [parent] ->
        IO.puts("Found existing parent: #{source_id}")
        parent

      [] ->
        attrs = %{
          source_id: source_id,
          source_type: String.to_atom(Keyword.fetch!(opts, :type)),
          title: Keyword.fetch!(opts, :title),
          issuer: Keyword.fetch!(opts, :issuer),
          legal_weight: String.to_atom(Keyword.fetch!(opts, :weight)),
          edition: Keyword.get(opts, :edition),
          structure_type: :sections
        }

        {:ok, parent} = Ash.create(SecondarySource, attrs, action: :create)
        IO.puts("Created parent: #{source_id}")
        parent
    end
  end

  defp create_parent_links(_parent, nil), do: :ok

  defp create_parent_links(parent, links_str) do
    links_str
    |> String.split(",", trim: true)
    |> Enum.each(fn pair ->
      case String.split(String.trim(pair), ":", parts: 2) do
        [law_name, link_type] ->
          attrs = %{
            secondary_source_id: parent.id,
            law_name: law_name,
            link_type: String.to_atom(link_type)
          }

          case Ash.create(SourceLink, attrs, action: :create) do
            {:ok, _} -> IO.puts("  Linked: #{law_name} (#{link_type})")
            {:error, _} -> IO.puts("  Link exists: #{law_name} (#{link_type})")
          end

        [law_name] ->
          attrs = %{
            secondary_source_id: parent.id,
            law_name: law_name,
            link_type: :references
          }

          Ash.create(SourceLink, attrs, action: :create)
      end
    end)
  end

  defp register_chapter(child_source_id, title, parent, opts) do
    existing =
      SecondarySource
      |> Ash.Query.filter(source_id == ^child_source_id)
      |> Ash.read!()

    case existing do
      [_] ->
        IO.puts("  SKIP #{child_source_id} (exists)")

      [] ->
        attrs = %{
          source_id: child_source_id,
          source_type: String.to_atom(Keyword.fetch!(opts, :type)),
          title: title,
          issuer: Keyword.fetch!(opts, :issuer),
          legal_weight: String.to_atom(Keyword.fetch!(opts, :weight)),
          edition: Keyword.get(opts, :edition),
          parent_source_id: parent.id,
          structure_type: :sections
        }

        case Ash.create(SecondarySource, attrs, action: :create) do
          {:ok, _} -> IO.puts("  OK    #{child_source_id} — #{title}")
          {:error, e} -> IO.puts("  ERROR #{child_source_id}: #{inspect(e)}")
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Chapter ID derivation from filename
  # ---------------------------------------------------------------------------

  @doc false
  def derive_chapter_id(filename) do
    basename = Path.rootname(filename)

    cond do
      # jsp375_ch23 → CH23
      match = Regex.run(~r/_ch(\d+)$/i, basename) ->
        "CH#{Enum.at(match, 1)}"

      # jsp815_element4 → EL4
      match = Regex.run(~r/_element(\d+)$/i, basename) ->
        "EL#{Enum.at(match, 1)}"

      # jsp418_leaflet6 → LF6
      match = Regex.run(~r/_leaflet(\d[\w-]*)$/i, basename) ->
        "LF#{Enum.at(match, 1)}"

      # jsp392_part1 → PT1
      match = Regex.run(~r/_part(\d+)$/i, basename) ->
        "PT#{Enum.at(match, 1)}"

      # jsp815_annexA → ANNEXA
      match = Regex.run(~r/_(annex\w+)$/i, basename) ->
        String.upcase(Enum.at(match, 1))

      # jsp816_framework → FRAMEWORK
      match = Regex.run(~r/_(\w+)$/, basename) ->
        String.upcase(Enum.at(match, 1))

      # Fallback
      true ->
        String.upcase(basename)
    end
  end

  defp derive_chapter_title(filename, chapter_id, parent_title) do
    "#{parent_title} — #{humanize_chapter_id(chapter_id)}"
  end

  defp humanize_chapter_id("CH" <> n), do: "Chapter #{n}"
  defp humanize_chapter_id("EL" <> n), do: "Element #{n}"
  defp humanize_chapter_id("LF" <> n), do: "Leaflet #{n}"
  defp humanize_chapter_id("PT" <> n), do: "Part #{n}"
  defp humanize_chapter_id("ANNEX" <> rest), do: "Annex #{rest}"
  defp humanize_chapter_id("FRAMEWORK"), do: "Framework"
  defp humanize_chapter_id(id), do: id
end
