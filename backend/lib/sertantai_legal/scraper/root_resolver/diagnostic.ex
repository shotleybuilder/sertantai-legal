defmodule SertantaiLegal.Scraper.RootResolver.Diagnostic do
  @moduledoc """
  Classifies all unlinked cross-reference definitions into failure categories.

  Builds on the same indexes as the resolver but instead of trying to link,
  diagnoses *why* each definition can't be linked. Produces a list of
  `%Finding{}` structs that can be aggregated into metrics or rendered in a
  dashboard.

  ## Categories

  - `:no_citation` — citation extractor returned nil
  - `:parent_not_in_lrt` — citation extracted but law not in legal_register
  - `:parent_unparsed` — law in LRT but definitions not yet parsed
  - `:term_not_found` — parent parsed, term absent from parent's definitions
  - `:term_normalisation` — parent parsed, term exists with different normalisation
  - `:citation_ambiguous` — citation matches multiple laws

  ## Usage

      {:ok, findings} = Diagnostic.run()
      summary = Diagnostic.summarise(findings)
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.RootResolver.{CitationExtractor, Indexes, Matcher}

  import Ecto.Query

  defmodule Finding do
    @moduledoc "A single diagnostic finding for an unlinked cross-reference definition."

    @type category ::
            :no_citation
            | :internal_ref
            | :parent_not_in_lrt
            | :parent_revoked
            | :parent_unparsed
            | :term_not_found
            | :term_normalisation
            | :citation_ambiguous

    @type t :: %__MODULE__{
            definition_id: binary(),
            law_name: String.t(),
            term: String.t(),
            category: category(),
            citation: String.t() | nil,
            target_law: String.t() | nil,
            nearest_term: String.t() | nil,
            detail: String.t() | nil
          }

    @enforce_keys [:definition_id, :law_name, :term, :category]
    defstruct [
      :definition_id,
      :law_name,
      :term,
      :category,
      :citation,
      :target_law,
      :nearest_term,
      :detail
    ]
  end

  @type summary :: %{
          total: non_neg_integer(),
          citation_resolved: non_neg_integer(),
          genuinely_unresolved: non_neg_integer(),
          by_category: %{Finding.category() => non_neg_integer()},
          by_family: %{String.t() => %{Finding.category() => non_neg_integer()}},
          top_parents: [{String.t(), non_neg_integer()}]
        }

  @doc """
  Run the diagnostic on all unlinked cross-reference definitions.

  ## Options

    * `:family` — restrict to definitions from laws in this family
    * `:limit` — process at most N definitions
  """
  @spec run(keyword()) :: {:ok, [Finding.t()]}
  def run(opts \\ []) do
    title_index = Indexes.build_title_index()
    citation_index = Indexes.build_citation_index()
    enacted_by_index = Indexes.build_enacted_by_index()
    parse_status = build_parse_status_index()
    live_status = build_live_status_index()
    parent_terms = build_parent_terms_index()

    defs = fetch_unlinked(opts)

    findings =
      Enum.map(defs, fn d ->
        classify(
          d,
          title_index,
          citation_index,
          enacted_by_index,
          parse_status,
          live_status,
          parent_terms
        )
      end)

    {:ok, findings}
  end

  # Categories that represent structural ceiling, not actionable bugs
  @ceiling_categories [:parent_revoked, :parent_not_in_lrt, :internal_ref]

  @doc "Aggregate findings into a summary map."
  @spec summarise([Finding.t()]) :: summary()
  def summarise(findings) do
    by_category =
      findings
      |> Enum.frequencies_by(& &1.category)

    by_family =
      findings
      |> Enum.group_by(& &1.law_name)
      |> Enum.flat_map(fn {law_name, fs} ->
        family = lookup_family(law_name)
        Enum.map(fs, &{family, &1.category})
      end)
      |> Enum.group_by(&elem(&1, 0))
      |> Enum.map(fn {family, pairs} ->
        {family, Enum.frequencies_by(pairs, &elem(&1, 1))}
      end)
      |> Map.new()

    top_parents =
      findings
      |> Enum.filter(&(&1.target_law != nil and &1.category not in @ceiling_categories))
      |> Enum.frequencies_by(& &1.target_law)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(30)

    # Split: findings with a citation (pointer-resolved) vs without (genuinely unresolved)
    citation_resolved = Enum.count(findings, &(&1.citation != nil))
    genuinely_unresolved = Enum.count(findings, &(&1.citation == nil))

    %{
      total: length(findings),
      citation_resolved: citation_resolved,
      genuinely_unresolved: genuinely_unresolved,
      by_category: by_category,
      by_family: by_family,
      top_parents: top_parents
    }
  end

  @doc "Print a human-readable summary to stdout."
  @spec print_summary(summary()) :: :ok
  def print_summary(summary) do
    {actionable, ceiling} =
      summary.by_category
      |> Enum.split_with(fn {cat, _} -> cat not in @ceiling_categories end)

    actionable_total = actionable |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    ceiling_total = ceiling |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    IO.puts("\n══ Resolution Diagnostic ══")

    IO.puts(
      "Total unlinked: #{summary.total} (#{actionable_total} actionable, #{ceiling_total} ceiling)"
    )

    IO.puts(
      "Citation-resolved: #{summary.citation_resolved}  |  Genuinely unresolved: #{summary.genuinely_unresolved}\n"
    )

    IO.puts("Actionable:")

    actionable
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.each(fn {cat, count} ->
      pct = Float.round(100.0 * count / max(summary.total, 1), 1)
      IO.puts("  #{pad(cat, 25)} #{pad_num(count, 6)}  (#{pct}%)")
    end)

    if ceiling != [] do
      IO.puts("\nCeiling (not actionable):")

      ceiling
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.each(fn {cat, count} ->
        pct = Float.round(100.0 * count / max(summary.total, 1), 1)
        IO.puts("  #{pad(cat, 25)} #{pad_num(count, 6)}  (#{pct}%)")
      end)
    end

    IO.puts("\nTop 20 unresolved parent laws:")

    summary.top_parents
    |> Enum.take(20)
    |> Enum.each(fn {law, count} ->
      IO.puts("  #{pad(law, 50)} #{count}")
    end)

    :ok
  end

  # -- Classification --

  @spec classify(map(), map(), map(), map(), map(), map(), map()) :: Finding.t()
  defp classify(
         d,
         title_index,
         citation_index,
         enacted_by_index,
         parse_status,
         live_status,
         parent_terms
       ) do
    definition = d.definition || ""

    citation =
      if d.referenced_law_citation && d.referenced_law_citation != "" do
        d.referenced_law_citation
        |> String.replace(~r/\Ameans\s+/i, "")
      else
        CitationExtractor.extract_citation(definition, d.law_name, citation_index) ||
          Matcher.resolve_bare_act_ref(definition, d.law_name, enacted_by_index)
      end

    base = %{definition_id: d.id, law_name: d.law_name, term: d.term}

    cond do
      citation == nil and CitationExtractor.internal_ref?(definition) ->
        struct!(
          Finding,
          Map.merge(base, %{category: :internal_ref, detail: "internal reference within same law"})
        )

      citation == nil ->
        struct!(Finding, Map.merge(base, %{category: :no_citation}))

      true ->
        target_law = resolve_law_name(citation, title_index)

        classify_with_target(
          base,
          citation,
          target_law,
          d.term,
          parse_status,
          live_status,
          parent_terms
        )
    end
  end

  @revoked_status "❌ Revoked / Repealed / Abolished"

  @spec classify_with_target(
          map(),
          String.t(),
          String.t() | nil,
          String.t(),
          map(),
          map(),
          map()
        ) :: Finding.t()
  defp classify_with_target(
         base,
         citation,
         nil,
         _term,
         _parse_status,
         _live_status,
         _parent_terms
       ) do
    struct!(Finding, Map.merge(base, %{category: :parent_not_in_lrt, citation: citation}))
  end

  defp classify_with_target(
         base,
         citation,
         target_law,
         term,
         parse_status,
         live_status,
         parent_terms
       ) do
    parsed? = Map.get(parse_status, target_law, false)
    live = Map.get(live_status, target_law)
    revoked? = live == @revoked_status

    cond do
      # Parent is fully revoked — definitions are gone, not actionable
      revoked? ->
        struct!(
          Finding,
          Map.merge(base, %{
            category: :parent_revoked,
            citation: citation,
            target_law: target_law,
            detail: "parent law is revoked — definitions no longer available"
          })
        )

      # Parent exists but definitions not yet parsed
      not parsed? ->
        struct!(
          Finding,
          Map.merge(base, %{
            category: :parent_unparsed,
            citation: citation,
            target_law: target_law
          })
        )

      # Parent parsed — check for term match
      true ->
        terms_in_parent = Map.get(parent_terms, target_law, MapSet.new())

        cond do
          MapSet.member?(terms_in_parent, term) ->
            # Term exists — this shouldn't happen if resolver ran correctly.
            # Could be citation_ambiguous (resolved to wrong law) or
            # section-level mismatch.
            struct!(
              Finding,
              Map.merge(base, %{
                category: :citation_ambiguous,
                citation: citation,
                target_law: target_law,
                detail:
                  "term exists in parent but resolver didn't link — possible multi-law ambiguity"
              })
            )

          (nearest = find_nearest_term(term, terms_in_parent)) != nil ->
            struct!(
              Finding,
              Map.merge(base, %{
                category: :term_normalisation,
                citation: citation,
                target_law: target_law,
                nearest_term: nearest,
                detail: "child: \"#{term}\" → parent has: \"#{nearest}\""
              })
            )

          true ->
            struct!(
              Finding,
              Map.merge(base, %{
                category: :term_not_found,
                citation: citation,
                target_law: target_law,
                detail: "parent has #{MapSet.size(terms_in_parent)} definitions, none match"
              })
            )
        end
    end
  end

  # -- Fuzzy matching --

  @spec find_nearest_term(String.t(), MapSet.t()) :: String.t() | nil
  defp find_nearest_term(term, terms) do
    child_words = term_words(term)

    # Skip if child term has fewer than 2 significant words — too ambiguous
    if MapSet.size(child_words) < 2 do
      nil
    else
      terms
      |> Enum.filter(fn parent_term ->
        parent_words = term_words(parent_term)

        # Parent must have at least 2 significant words
        # Child words all appear in parent (parent is more specific version)
        # High overlap for similar-length terms
        MapSet.size(parent_words) >= 2 and
          (MapSet.subset?(child_words, parent_words) or
             jaccard(child_words, parent_words) > 0.7)
      end)
      |> Enum.max_by(
        fn parent_term ->
          jaccard(child_words, term_words(parent_term))
        end,
        fn -> nil end
      )
    end
  end

  defp term_words(term) do
    term
    |> String.downcase()
    |> String.split(~r/[\s\-]+/)
    |> Enum.reject(&(&1 in ~w(the a an of for and in to)))
    |> MapSet.new()
  end

  defp jaccard(a, b) do
    intersection = MapSet.intersection(a, b) |> MapSet.size()
    union = MapSet.union(a, b) |> MapSet.size()
    if union == 0, do: 0.0, else: intersection / union
  end

  # -- Law name resolution (same as Matcher but returns law_name only) --

  @spec resolve_law_name(String.t(), map()) :: String.t() | nil
  defp resolve_law_name(citation, title_index) do
    title_with_year =
      citation
      |> String.replace(~r/\s+(section|regulation|article|paragraph|rule|part)\s+\d.*$/i, "")
      |> CitationExtractor.normalise_title()

    title_without_year = String.replace(title_with_year, ~r/\s+\d{4}\s*$/, "")

    year =
      case Regex.run(~r/(\d{4})\s*$/, title_with_year) do
        [_, y] -> String.to_integer(y)
        nil -> nil
      end

    (year && Map.get(title_index, {title_without_year, year})) ||
      Map.get(title_index, title_with_year) ||
      Map.get(title_index, title_without_year) ||
      CitationExtractor.extract_eu_law_name(citation)
  end

  # -- Index builders --

  @spec build_parse_status_index() :: map()
  defp build_parse_status_index do
    from(lr in "legal_register",
      where: not is_nil(lr.definitions_parsed_at),
      select: lr.name
    )
    |> Repo.all()
    |> Map.new(&{&1, true})
  end

  @spec build_live_status_index() :: map()
  defp build_live_status_index do
    from(lr in "legal_register",
      where: not is_nil(lr.live),
      select: {lr.name, lr.live}
    )
    |> Repo.all()
    |> Map.new()
  end

  @spec build_parent_terms_index() :: map()
  defp build_parent_terms_index do
    from(d in "legislative_definitions",
      select: {d.law_name, d.term}
    )
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {law_name, terms} -> {law_name, MapSet.new(terms)} end)
  end

  @spec fetch_unlinked(keyword()) :: [map()]
  defp fetch_unlinked(opts) do
    q =
      from(d in "legislative_definitions",
        where: d.references_other_law == true and d.citation == false,
        where:
          fragment(
            "NOT EXISTS (SELECT 1 FROM definition_links dl WHERE dl.child_definition_id = ?)",
            d.id
          ),
        select: %{
          id: d.id,
          law_name: d.law_name,
          term: d.term,
          definition: d.definition,
          referenced_law_citation: d.referenced_law_citation
        }
      )

    q =
      if family = opts[:family] do
        from(d in q,
          join: lr in "legal_register",
          on: lr.name == d.law_name,
          where: lr.family == ^family
        )
      else
        q
      end

    q = if limit = opts[:limit], do: limit(q, ^limit), else: q

    Repo.all(q)
  end

  # -- Family lookup (cached) --

  @spec lookup_family(String.t()) :: String.t()
  defp lookup_family(law_name) do
    case Process.get({:family_cache, law_name}) do
      nil ->
        family =
          Repo.one(
            from(lr in "legal_register",
              where: lr.name == ^law_name,
              select: lr.family
            )
          ) || "(no family)"

        Process.put({:family_cache, law_name}, family)
        family

      family ->
        family
    end
  end

  # -- Formatting helpers --

  defp pad(val, width) do
    str = to_string(val)
    String.pad_trailing(str, width)
  end

  defp pad_num(val, width) do
    str = to_string(val)
    String.pad_leading(str, width)
  end

  # -- Test helpers --

  if Mix.env() == :test do
    @doc false
    def test_classify(
          d,
          title_index,
          citation_index,
          enacted_by_index,
          parse_status,
          live_status,
          parent_terms
        ) do
      classify(
        d,
        title_index,
        citation_index,
        enacted_by_index,
        parse_status,
        live_status,
        parent_terms
      )
    end

    @doc false
    def test_resolve_law_name(citation, title_index), do: resolve_law_name(citation, title_index)

    @doc false
    def test_find_nearest_term(term, terms), do: find_nearest_term(term, terms)

    @doc false
    def revoked_status, do: @revoked_status

    @doc false
    def ceiling_categories, do: @ceiling_categories
  end
end
