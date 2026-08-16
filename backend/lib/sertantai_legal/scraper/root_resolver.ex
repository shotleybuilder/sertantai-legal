defmodule SertantaiLegal.Scraper.RootResolver do
  @moduledoc """
  Links cross-reference definitions to their root (originating) definitions.

  A cross-ref definition like "has the meaning given in section 126(1) of the
  Scotland Act 1998" gets linked to the Scotland Act 1998's own definition of
  the same term via the `definition_links` junction table.

  Two-pass approach:
  1. Extract `referenced_law_citation` from definition text
  2. Resolve to root definition(s) by matching to legal_register + legislative_definitions

  Designed to be re-run as more parent laws get their definitions parsed.

  ## Usage

      # Resolve all unlinked cross-refs
      RootResolver.resolve_all()

      # Resolve for a single term (testing)
      RootResolver.resolve_all(term: "scotland")

      # Re-resolve everything (after parsing more parent laws)
      RootResolver.resolve_all(force: true)

      # Dry run — returns results without writing
      RootResolver.resolve_all(dry_run: true)
  """

  alias SertantaiLegal.Repo

  import Ecto.Query

  require Logger

  # Anchors on "Act|Regulations|Order YYYY" and captures up to 80 chars before it.
  # Uses a possessive-style approach: grab a bounded chunk before the law type keyword.
  @law_type_year_re ~r/([A-Z][^\n]{0,80}?(?:Act|Regulations?|Order|Rules?|Directive|Measure))\s+(\d{4})/u

  # Short name: "the 1991 Act", "the 2003 Regulations"
  @short_name_re ~r/(?:the\s+)?(\d{4})\s+(Act|Regulations?|Order|Rules?)/u

  # Pronoun reference: "of that Act", "of those Regulations", "of that Order"
  @pronoun_ref_re ~r/(?:of\s+)?(?:that|those)\s+(Act|Regulations?|Order|Rules?|Measure)/iu

  # Section reference: "section 126(1)", "regulation 3", "article 2(1)"
  @section_re ~r/(section|regulation|article|paragraph|rule|part)\s+([\d]+(?:\([\d]+\))?(?:\([a-z]\))?)/iu

  @type result :: %{
          resolved: non_neg_integer(),
          citation_only: non_neg_integer(),
          internal: non_neg_integer(),
          unresolved: non_neg_integer()
        }

  @doc """
  Resolve cross-reference definitions to their roots.

  ## Options

    * `:term` — resolve a single term (for testing)
    * `:limit` — process at most N definitions
    * `:force` — re-resolve even if already linked
    * `:dry_run` — return results without writing to DB
  """
  @spec resolve_all(keyword()) :: {:ok, result()}
  def resolve_all(opts \\ []) do
    title_index = build_title_index()
    citation_index = build_citation_index()
    def_index = build_definition_index()
    sibling_index = build_sibling_index()

    Logger.info(
      "[RootResolver] Title index: #{map_size(title_index)} laws, " <>
        "Citation index: #{map_size(citation_index)} laws, " <>
        "Definition index: #{map_size(def_index)} entries, " <>
        "Sibling index: #{map_size(sibling_index)} sections"
    )

    defs = fetch_cross_refs(opts)
    Logger.info("[RootResolver] Definitions to resolve: #{length(defs)}")

    grouped =
      defs
      |> Enum.map(&resolve_one(&1, title_index, citation_index, def_index, sibling_index))
      |> Enum.group_by(fn {status, _} -> status end)

    resolved = Map.get(grouped, :resolved, [])
    citation_only = Map.get(grouped, :citation_only, [])
    internal = Map.get(grouped, :internal, [])
    unresolved = Map.get(grouped, :unresolved, [])

    counts = %{
      resolved: length(resolved),
      citation_only: length(citation_only),
      internal: length(internal),
      unresolved: length(unresolved)
    }

    Logger.info(
      "[RootResolver] Results — resolved: #{counts.resolved}, " <>
        "citation_only: #{counts.citation_only}, " <>
        "internal: #{counts.internal}, " <>
        "unresolved: #{counts.unresolved}"
    )

    # Write missing parent laws to file for backfill
    missing_parents = write_missing_parents(citation_only)

    unless Keyword.get(opts, :dry_run, false) do
      apply_updates(resolved ++ citation_only)
      Logger.info("[RootResolver] Updates applied")
    end

    {:ok, Map.put(counts, :missing_parents, missing_parents)}
  end

  @doc """
  Resolve a pronoun reference ("that Act/Regulations/Order") using sibling
  definitions in the same section.

  Given a definition like "given by section 65 of that Act", finds the law name
  from a sibling's `referenced_law_citation` in the same `{law_name, section_id}`,
  strips the sibling's section reference, and appends the current definition's
  section reference.

  Returns a citation string like "Building Safety Act 2022 section 65", or nil.
  """
  @spec resolve_pronoun_ref(String.t(), String.t(), String.t() | nil, map()) :: String.t() | nil
  def resolve_pronoun_ref(_definition, _law_name, nil, _sibling_index), do: nil

  def resolve_pronoun_ref(definition, law_name, section_id, sibling_index) do
    with true <- Regex.match?(@pronoun_ref_re, definition),
         sibling_citation when is_binary(sibling_citation) <-
           Map.get(sibling_index, {law_name, section_id}) do
      # Extract the law title from the sibling citation (strip section ref)
      law_title =
        sibling_citation
        |> String.replace(
          ~r/\s+(section|regulation|article|paragraph|rule|part)\s+.+$/i,
          ""
        )

      # Extract section ref from our definition
      our_section = extract_section(definition)

      if our_section do
        "#{law_title} #{our_section}"
      else
        law_title
      end
    else
      _ -> nil
    end
  end

  # -- Query --

  defp fetch_cross_refs(opts) do
    q =
      from(d in "legislative_definitions",
        where: d.references_other_law == true and d.citation == false,
        select: %{
          id: d.id,
          law_name: d.law_name,
          term: d.term,
          definition: d.definition,
          referenced_law_citation: d.referenced_law_citation,
          section_id: d.section_id
        }
      )

    q = if term = opts[:term], do: where(q, [d], d.term == ^term), else: q

    # Skip definitions that already have links (unless --force)
    q =
      unless opts[:force] do
        from(d in q,
          left_join: dl in "definition_links",
          on: dl.child_definition_id == d.id,
          where: is_nil(dl.child_definition_id)
        )
      else
        q
      end

    q = if limit = opts[:limit], do: limit(q, ^limit), else: q

    Repo.all(q)
  end

  # -- Indexes --

  defp build_title_index do
    from(lr in "legal_register",
      where: not is_nil(lr.title_en) and lr.title_en != "",
      select: {lr.name, lr.title_en, lr.year}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {name, title, year}, acc ->
      key = normalise_title(title)

      acc
      # Year-specific key: "scotland act" + 1998 → UK_ukpga_1998_46
      |> (fn a ->
            if year do
              Map.put(a, {key, year}, name)
            else
              a
            end
          end).()
      # Fallback without year (first one wins, prefer shorter name)
      |> Map.update(key, name, fn existing ->
        if String.length(name) <= String.length(existing), do: name, else: existing
      end)
    end)
  end

  defp build_citation_index do
    from(d in "legislative_definitions",
      where: d.citation == true,
      select: {d.law_name, d.term, d.definition}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {law_name, term, definition}, acc ->
      Map.put(acc, {law_name, String.downcase(term)}, String.trim(definition))
    end)
  end

  # Index of {law_name, term} → [id, ...] for all definitions.
  # A term can have multiple definitions in different sections of the same law.
  defp build_definition_index do
    from(d in "legislative_definitions",
      select: {d.law_name, d.term, d.id}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {law_name, term, id}, acc ->
      Map.update(acc, {law_name, term}, [id], &[id | &1])
    end)
  end

  # Index of {law_name, section_id} → first referenced_law_citation found among siblings.
  # Used to resolve "that Act/Regulations/Order" pronoun references.
  defp build_sibling_index do
    from(d in "legislative_definitions",
      where:
        not is_nil(d.referenced_law_citation) and d.referenced_law_citation != "" and
          not is_nil(d.section_id),
      select: {d.law_name, d.section_id, d.referenced_law_citation}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {law_name, section_id, citation}, acc ->
      # First citation wins per section (they typically reference the same law)
      Map.put_new(acc, {law_name, section_id}, citation)
    end)
  end

  # -- Resolution --

  defp resolve_one(def_row, title_index, citation_index, def_index, sibling_index) do
    definition = def_row.definition || ""

    # Try pronoun resolution first ("that Act" → sibling's named law)
    pronoun_citation =
      resolve_pronoun_ref(definition, def_row.law_name, def_row.section_id, sibling_index)

    cond do
      pronoun_citation != nil ->
        resolve_with_citation(pronoun_citation, def_row, title_index, def_index)

      internal_ref?(definition) ->
        {:internal, %{id: def_row.id}}

      true ->
        case extract_citation(definition, def_row.law_name, citation_index) do
          nil ->
            {:unresolved, %{id: def_row.id, term: def_row.term, law_name: def_row.law_name}}

          citation ->
            resolve_with_citation(citation, def_row, title_index, def_index)
        end
    end
  end

  defp resolve_with_citation(citation, def_row, title_index, def_index) do
    case resolve_to_root(citation, def_row.term, title_index, def_index) do
      {:ok, root_ids, _root_law_name} ->
        {:resolved, %{id: def_row.id, citation: citation, root_ids: root_ids}}

      {:law_found, root_law_name} ->
        {:citation_only,
         %{
           id: def_row.id,
           citation: citation,
           root_ids: [],
           target_law: root_law_name
         }}

      :not_found ->
        {:citation_only, %{id: def_row.id, citation: citation, root_ids: [], target_law: nil}}
    end
  end

  defp internal_ref?(definition) do
    Regex.match?(
      ~r/(?:given|specified|set out|provided|defined|construed)\s+(?:by|in)\s+(?:accordance\s+with\s+)?(?:section|regulation|article|paragraph|rule|schedule|part|subsection)\s+\d/iu,
      definition
    ) and
      not Regex.match?(@law_type_year_re, definition) and
      not Regex.match?(@short_name_re, definition) and
      not Regex.match?(~r/\bDirective\b/, definition)
  end

  # -- Citation extraction --

  defp extract_citation(definition, law_name, citation_index) do
    case extract_named_law(definition) do
      {:ok, title, _year} ->
        section = extract_section(definition)
        if section, do: "#{title} #{section}", else: title

      :no_match ->
        case Regex.run(@short_name_re, definition) do
          [_full, year, type] ->
            short_key = {law_name, String.downcase("#{year} #{type}")}
            full_title = Map.get(citation_index, short_key)

            raw = full_title || "the #{year} #{type}"
            section = extract_section(definition)
            if section, do: "#{raw} #{section}", else: raw

          nil ->
            # Try abbreviation lookup: "the Waste Directive" → citation_index
            extract_abbreviation_citation(definition, law_name, citation_index)
        end
    end
  end

  # Match abbreviation-style references like "the Waste Directive", "the 2004 Act"
  # by looking up the abbreviation in the citation_index for this law.
  @abbreviation_re ~r/(?:the\s+)(\w[\w\s]*(?:Directive|Convention|Treaty|Code))\b/u
  defp extract_abbreviation_citation(definition, law_name, citation_index) do
    case Regex.run(@abbreviation_re, definition) do
      [_full, abbrev] ->
        key = {law_name, String.downcase(abbrev)}

        case Map.get(citation_index, key) do
          nil -> nil
          full_title -> full_title
        end

      nil ->
        nil
    end
  end

  defp extract_named_law(definition) do
    case Regex.run(@law_type_year_re, definition) do
      [_full, raw_title, year] ->
        # Strip everything before the law title proper.
        # "...as in section 7 of the Acquisition of Land Act" → "Acquisition of Land Act"
        # The title starts after the last "of the" / "in the" / "as the" / "under the"
        title =
          raw_title
          |> String.replace(~r/^.*\b(?:of|in|as|under|by|from)\s+the\s+/i, "")
          |> String.replace(~r/^.*\bthe\s+/i, "")
          |> String.trim()
          |> String.trim_trailing(",")
          |> String.trim_trailing(";")

        {:ok, "#{title} #{year}", year}

      nil ->
        :no_match
    end
  end

  defp extract_section(definition) do
    case Regex.run(@section_re, definition) do
      [_full, type, num] -> "#{String.downcase(type)} #{num}"
      nil -> nil
    end
  end

  # -- Root resolution --

  defp resolve_to_root(citation, term, title_index, def_index) do
    # Strip section ref to get just the law title + year
    title_with_year =
      citation
      |> String.replace(~r/\s+(section|regulation|article|paragraph|rule|part)\s+.+$/i, "")
      |> normalise_title()

    title_without_year = String.replace(title_with_year, ~r/\s+\d{4}\s*$/, "")

    # Extract the year for year-specific lookup
    year =
      case Regex.run(~r/(\d{4})\s*$/, title_with_year) do
        [_, y] -> String.to_integer(y)
        nil -> nil
      end

    # Lookup priority: {title, year} → title_with_year → title_without_year
    root_law_name =
      (year && Map.get(title_index, {title_without_year, year})) ||
        Map.get(title_index, title_with_year) ||
        Map.get(title_index, title_without_year)

    case root_law_name do
      nil ->
        :not_found

      root_law_name ->
        case Map.get(def_index, {root_law_name, term}) do
          nil -> {:law_found, root_law_name}
          root_ids -> {:ok, root_ids, root_law_name}
        end
    end
  end

  defp normalise_title(title) do
    title
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/[^\w\s]/, "")
    |> String.trim()
  end

  # -- Persistence --

  defp apply_updates(results) do
    now = NaiveDateTime.utc_now()

    results
    |> Enum.chunk_every(500)
    |> Enum.each(fn batch ->
      Repo.transaction(fn ->
        Enum.each(batch, fn {_status, row} ->
          # Update referenced_law_citation on the definition row
          if row[:citation] do
            from(d in "legislative_definitions", where: d.id == ^row.id)
            |> Repo.update_all(set: [referenced_law_citation: row.citation, updated_at: now])
          end

          # Insert links into junction table
          Enum.each(row[:root_ids] || [], fn root_id ->
            Repo.insert_all(
              "definition_links",
              [%{child_definition_id: row.id, root_definition_id: root_id, inserted_at: now}],
              on_conflict: :nothing,
              conflict_target: [:child_definition_id, :root_definition_id]
            )
          end)
        end)
      end)
    end)
  end

  # -- Missing parents file --

  @missing_parents_path "data/root_resolver_missing_parents.txt"

  defp write_missing_parents(citation_only_results) do
    # Collect unique target law_names that need definition parsing
    missing =
      citation_only_results
      |> Enum.map(fn {_status, row} -> row[:target_law] end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    if length(missing) > 0 do
      path = Path.join(File.cwd!(), @missing_parents_path)
      File.write!(path, Enum.join(missing, "\n") <> "\n")

      Logger.info(
        "[RootResolver] Wrote #{length(missing)} missing parent laws to #{@missing_parents_path}" <>
          " — run: mix definitions.backfill --file #{@missing_parents_path} --force"
      )
    end

    length(missing)
  end
end
