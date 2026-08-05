defmodule Mix.Tasks.Secondary.List do
  @shortdoc "List registered secondary sources and their law links"

  @moduledoc """
  Lists all secondary sources, optionally filtered by type or status.

  ## Usage

      mix secondary.list
      mix secondary.list --type acop
      mix secondary.list --type jsp --verbose
      mix secondary.list --tree

  ## Options

      --type      Filter by source type: acop | guidance | standard | jsp | industry_code
      --status    Filter by status: current | withdrawn | superseded (default: all)
      --verbose   Show law links for each source
      --tree      Group chapters under their parent JSP (compact view)
  """

  use Mix.Task

  require Ash.Query

  alias SertantaiLegal.Legal.SecondarySource
  alias SertantaiLegal.Legal.SourceLink

  @switches [
    type: :string,
    status: :string,
    verbose: :boolean,
    tree: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    verbose? = Keyword.get(opts, :verbose, false)
    tree? = Keyword.get(opts, :tree, false)

    sources = fetch_sources(opts)

    if sources == [] do
      IO.puts("No secondary sources found.")
    else
      if tree? do
        print_tree(sources, verbose?)
      else
        IO.puts("=== Secondary Sources (#{length(sources)}) ===\n")
        print_header()

        Enum.each(sources, fn source ->
          print_row(source)

          if verbose? do
            print_links(source)
          end
        end)
      end

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

  defp print_tree(sources, verbose?) do
    # Separate parents (no parent_source_id) from children
    {parents, children} = Enum.split_with(sources, &is_nil(&1.parent_source_id))

    # Group children by parent_source_id
    children_by_parent = Enum.group_by(children, & &1.parent_source_id)

    # Standalone sources (no parent, no children)
    parent_ids = MapSet.new(parents, & &1.id)
    standalone = Enum.filter(parents, fn p -> !Map.has_key?(children_by_parent, p.id) end)
    with_children = Enum.filter(parents, fn p -> Map.has_key?(children_by_parent, p.id) end)

    # Orphan children (parent not in current result set)
    orphans = Enum.filter(children, fn c -> !MapSet.member?(parent_ids, c.parent_source_id) end)

    total_provisions = count_provisions(sources)

    IO.puts(
      "=== Secondary Sources (#{length(sources)} records, #{total_provisions} provisions) ===\n"
    )

    # Print parents with their children
    Enum.each(with_children, fn parent ->
      kids = Map.get(children_by_parent, parent.id, [])
      prov_count = count_provisions_for(parent.id, kids)

      IO.puts("#{parent.source_id} — #{parent.title}")

      IO.puts(
        "  #{to_string(parent.source_type)} | #{to_string(parent.legal_weight)} | #{length(kids)} chapters | #{prov_count} provisions"
      )

      if verbose? do
        print_links(parent)
      end

      Enum.each(kids, fn child ->
        child_provs = count_provisions_for_source(child.source_id)
        IO.puts("  ├─ #{child.source_id} (#{child_provs} provs)")
      end)

      IO.puts("")
    end)

    # Print standalone sources
    if standalone != [] do
      Enum.each(standalone, fn source ->
        provs = count_provisions_for_source(source.source_id)
        IO.puts("#{source.source_id} — #{truncate(source.title, 50)}")

        IO.puts(
          "  #{to_string(source.source_type)} | #{to_string(source.legal_weight)} | #{provs} provisions"
        )

        if verbose? do
          print_links(source)
        end

        IO.puts("")
      end)
    end

    # Print orphans if any
    if orphans != [] do
      IO.puts("--- Orphan chapters (parent not in result set) ---")

      Enum.each(orphans, fn source ->
        IO.puts("  #{source.source_id} — #{truncate(source.title, 50)}")
      end)

      IO.puts("")
    end
  end

  defp count_provisions(sources) do
    source_ids = Enum.map(sources, & &1.source_id)

    SertantaiLegal.Legal.SecondarySourceProvision
    |> Ash.Query.filter(source_id in ^source_ids)
    |> Ash.read!()
    |> length()
  end

  defp count_provisions_for(_parent_id, kids) do
    kid_ids = Enum.map(kids, & &1.source_id)

    SertantaiLegal.Legal.SecondarySourceProvision
    |> Ash.Query.filter(source_id in ^kid_ids)
    |> Ash.read!()
    |> length()
  end

  defp count_provisions_for_source(source_id) do
    SertantaiLegal.Legal.SecondarySourceProvision
    |> Ash.Query.filter(source_id == ^source_id)
    |> Ash.read!()
    |> length()
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
