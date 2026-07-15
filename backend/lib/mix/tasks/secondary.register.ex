defmodule Mix.Tasks.Secondary.Register do
  @shortdoc "Register a secondary source with optional law links"

  @moduledoc """
  Creates a SecondarySource record and optional SourceLink records.

  ## Usage

      mix secondary.register --source-id L8 --type acop --title "Legionella" \\
        --issuer HSE --weight reverse_burden --links UK_ukpga_1974_37:approved_under

      mix secondary.register --source-id JSP-375 --type jsp \\
        --title "Health and Safety Handbook" --issuer MoD --weight contractual \\
        --edition "Current (rolling updates)" --structure volumes \\
        --links UK_ukpga_1974_37:supplements,UK_uksi_1999_3242:supplements

  ## Options

      --source-id     Required. Stable identifier (e.g. L8, JSP-375, ISO-45001)
      --type          Required. acop | guidance | standard | jsp | industry_code
      --title         Required. Full document title
      --issuer        Required. Publishing body (HSE, MoD, BSI, ISO)
      --weight        Required. reverse_burden | regard_had_to | contractual | state_of_art | best_practice
      --edition       Optional. Edition label
      --effective     Optional. Effective date (YYYY-MM-DD)
      --url           Optional. Source URL
      --structure     Optional. volumes | parts | clauses | sections
      --links         Optional. Comma-separated law_name:link_type pairs
      --dry-run       Show what would be created without writing
  """

  use Mix.Task

  alias SertantaiLegal.Legal.SecondarySource
  alias SertantaiLegal.Legal.SourceLink

  @switches [
    source_id: :string,
    type: :string,
    title: :string,
    issuer: :string,
    weight: :string,
    edition: :string,
    effective: :string,
    url: :string,
    structure: :string,
    links: :string,
    dry_run: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    required = [:source_id, :type, :title, :issuer, :weight]
    missing = Enum.filter(required, &(!Keyword.has_key?(opts, &1)))

    if missing != [] do
      IO.puts("Missing required options: #{Enum.map_join(missing, ", ", &"--#{&1}")}")
      IO.puts("\nRun `mix help secondary.register` for usage.")
      System.halt(1)
    end

    dry_run? = Keyword.get(opts, :dry_run, false)
    register(opts, dry_run?)
  end

  defp register(opts, dry_run?) do
    source_id = Keyword.fetch!(opts, :source_id)
    source_type = String.to_atom(Keyword.fetch!(opts, :type))
    title = Keyword.fetch!(opts, :title)
    issuer = Keyword.fetch!(opts, :issuer)
    legal_weight = String.to_atom(Keyword.fetch!(opts, :weight))

    source_attrs = %{
      source_id: source_id,
      source_type: source_type,
      title: title,
      issuer: issuer,
      legal_weight: legal_weight,
      edition: Keyword.get(opts, :edition),
      effective_date: parse_date(Keyword.get(opts, :effective)),
      source_url: Keyword.get(opts, :url),
      structure_type: parse_atom(Keyword.get(opts, :structure))
    }

    links = parse_links(Keyword.get(opts, :links))

    IO.puts("=== Register Secondary Source ===")
    IO.puts("Source ID:    #{source_id}")
    IO.puts("Type:         #{source_type}")
    IO.puts("Title:        #{title}")
    IO.puts("Issuer:       #{issuer}")
    IO.puts("Legal weight: #{legal_weight}")

    if source_attrs.edition, do: IO.puts("Edition:      #{source_attrs.edition}")
    if source_attrs.effective_date, do: IO.puts("Effective:    #{source_attrs.effective_date}")
    if source_attrs.structure_type, do: IO.puts("Structure:    #{source_attrs.structure_type}")

    if links != [] do
      IO.puts("\nLaw links:")

      Enum.each(links, fn {law_name, link_type} ->
        IO.puts("  #{law_name} (#{link_type})")
      end)
    end

    if dry_run? do
      IO.puts("\n[DRY RUN] No changes made.")
    else
      case Ash.create(SecondarySource, source_attrs, action: :create) do
        {:ok, source} ->
          IO.puts("\nCreated secondary source: #{source.id}")
          create_links(source, links)

        {:error, error} ->
          IO.puts("\nError creating secondary source: #{inspect(error)}")
          System.halt(1)
      end
    end
  end

  defp create_links(_source, []), do: :ok

  defp create_links(source, links) do
    Enum.each(links, fn {law_name, link_type} ->
      attrs = %{
        secondary_source_id: source.id,
        law_name: law_name,
        link_type: link_type
      }

      case Ash.create(SourceLink, attrs, action: :create) do
        {:ok, _link} ->
          IO.puts("  Linked: #{law_name} (#{link_type})")

        {:error, error} ->
          IO.puts("  Error linking #{law_name}: #{inspect(error)}")
      end
    end)
  end

  defp parse_links(nil), do: []

  defp parse_links(links_str) do
    links_str
    |> String.split(",", trim: true)
    |> Enum.map(fn pair ->
      case String.split(String.trim(pair), ":", parts: 2) do
        [law_name, link_type] -> {law_name, String.to_atom(link_type)}
        [law_name] -> {law_name, :references}
      end
    end)
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp parse_atom(nil), do: nil
  defp parse_atom(str), do: String.to_atom(str)
end
