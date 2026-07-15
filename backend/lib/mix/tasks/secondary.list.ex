defmodule Mix.Tasks.Secondary.List do
  @shortdoc "List registered secondary sources and their law links"

  @moduledoc """
  Lists all secondary sources, optionally filtered by type or status.

  ## Usage

      mix secondary.list
      mix secondary.list --type acop
      mix secondary.list --type jsp --verbose

  ## Options

      --type      Filter by source type: acop | guidance | standard | jsp | industry_code
      --status    Filter by status: current | withdrawn | superseded (default: all)
      --verbose   Show law links for each source
  """

  use Mix.Task

  require Ash.Query

  alias SertantaiLegal.Legal.SecondarySource
  alias SertantaiLegal.Legal.SourceLink

  @switches [
    type: :string,
    status: :string,
    verbose: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    verbose? = Keyword.get(opts, :verbose, false)

    sources = fetch_sources(opts)

    if sources == [] do
      IO.puts("No secondary sources found.")
    else
      IO.puts("=== Secondary Sources (#{length(sources)}) ===\n")
      print_header()

      Enum.each(sources, fn source ->
        print_row(source)

        if verbose? do
          print_links(source)
        end
      end)

      IO.puts("")
      print_summary(sources)
    end
  end

  defp fetch_sources(opts) do
    query =
      case Keyword.get(opts, :type) do
        nil ->
          SecondarySource

        type ->
          type_atom = String.to_atom(type)
          Ash.Query.filter(SecondarySource, source_type == ^type_atom)
      end

    query =
      case Keyword.get(opts, :status) do
        nil ->
          query

        status ->
          status_atom = String.to_atom(status)
          Ash.Query.filter(query, status == ^status_atom)
      end

    query
    |> Ash.Query.sort([:source_type, :source_id])
    |> Ash.read!()
  end

  defp print_header do
    IO.puts(
      String.pad_trailing("Source ID", 16) <>
        String.pad_trailing("Type", 16) <>
        String.pad_trailing("Weight", 16) <>
        String.pad_trailing("Status", 12) <>
        "Title"
    )

    IO.puts(String.duplicate("─", 100))
  end

  defp print_row(source) do
    IO.puts(
      String.pad_trailing(source.source_id, 16) <>
        String.pad_trailing(to_string(source.source_type), 16) <>
        String.pad_trailing(to_string(source.legal_weight), 16) <>
        String.pad_trailing(to_string(source.status), 12) <>
        truncate(source.title, 40)
    )
  end

  defp print_links(source) do
    source_uuid = source.id

    links =
      SourceLink
      |> Ash.Query.filter(secondary_source_id == ^source_uuid)
      |> Ash.read!()

    if links != [] do
      Enum.each(links, fn link ->
        section = if link.section_id, do: " (#{link.section_id})", else: ""
        IO.puts("    → #{link.law_name}#{section}  [#{link.link_type}]")
      end)
    end
  end

  defp print_summary(sources) do
    by_type = Enum.group_by(sources, & &1.source_type)

    summary =
      by_type
      |> Enum.sort_by(fn {type, _} -> to_string(type) end)
      |> Enum.map_join(", ", fn {type, items} -> "#{length(items)} #{type}" end)

    IO.puts("Total: #{length(sources)} (#{summary})")
  end

  defp truncate(str, max) when byte_size(str) <= max, do: str
  defp truncate(str, max), do: String.slice(str, 0, max - 1) <> "…"
end
