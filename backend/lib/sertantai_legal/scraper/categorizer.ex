defmodule SertantaiLegal.Scraper.Categorizer do
  @moduledoc """
  Categorizes scraped laws into groups based on filters.

  Groups:
  - Group 1 (inc_w_si): Laws with matching SI code - highest priority
  - Group 2 (inc_wo_si): Laws with term match but no SI code - medium priority
  - Group 3 (exc): Laws excluded by filters - review needed

  Ported from Legl.Countries.Uk.LeglRegister.New.New.categoriser
  """

  alias SertantaiLegal.Scraper.Filters
  alias SertantaiLegal.Scraper.Storage

  @doc """
  Categorize records from raw.json into three groups.

  Reads raw.json, applies filters, and saves to:
  - inc_w_si.json (Group 1)
  - inc_wo_si.json (Group 2)
  - exc.json (Group 3)

  Returns counts for each group.
  """
  @spec categorize(String.t()) :: {:ok, map()} | {:error, any()}
  def categorize(session_id) do
    IO.puts("\n=== CATEGORIZING SESSION: #{session_id} ===")

    with {:ok, records} <- Storage.read_json(session_id, :raw) do
      result = categorize_records(records)
      save_categorized(session_id, result)
    end
  end

  @doc """
  Categorize a list of records into groups.

  Returns a map with:
  - :group1 - SI code match (highest priority)
  - :group2 - Term match only (medium priority)
  - :group3 - Excluded (no match)
  - :title_excluded - Excluded by title filter
  """
  @spec categorize_records(list(map())) :: map()
  def categorize_records(records) do
    IO.puts("Total records to categorize: #{Enum.count(records)}")

    # Step 1: Apply title filter
    {title_included, title_excluded} = Filters.title_filter(records)

    # Step 2: Apply SI code filter to get w/si and wo/si groups
    {with_si, without_si} = split_by_si_code(title_included)

    # Step 3: Apply SI code membership filter to w/si group
    {:ok, {si_matched, si_unmatched}} = Filters.si_code_filter(with_si)

    # Step 4: Combine unmatched SI codes with without_si for terms filter
    combined_for_terms = si_unmatched ++ without_si

    # Step 5: Apply terms filter
    {:ok, {terms_matched, terms_excluded}} = Filters.terms_filter({combined_for_terms, []})

    result = %{
      group1: si_matched,
      group2: terms_matched,
      group3: terms_excluded,
      title_excluded: title_excluded
    }

    print_summary(result)
    result
  end

  @doc """
  Save categorized records to JSON files.
  """
  @spec save_categorized(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def save_categorized(session_id, %{group1: g1, group2: g2, group3: g3, title_excluded: te}) do
    # Index Group 3 with numeric keys for easy reference (matches legl pattern)
    indexed_group3 = Storage.index_records(g3 ++ te)

    with :ok <- Storage.save_json(session_id, :group1, g1),
         :ok <- Storage.save_json(session_id, :group2, g2),
         :ok <- Storage.save_json(session_id, :group3, indexed_group3) do
      counts = %{
        group1_count: Enum.count(g1),
        group2_count: Enum.count(g2),
        group3_count: Enum.count(g3) + Enum.count(te),
        title_excluded_count: Enum.count(te)
      }

      # Save metadata for quick reference
      metadata = %{
        session_id: session_id,
        categorized_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        counts: counts,
        group1_description: "SI code match - highest priority",
        group2_description: "Term match only - medium priority",
        group3_description: "Excluded - review needed"
      }

      Storage.save_metadata(session_id, metadata)

      {:ok, counts}
    end
  end

  # Split records by whether they have an SI code
  defp split_by_si_code(records) do
    Enum.reduce(records, {[], []}, fn record, {with_si, without_si} ->
      si_code = record[:si_code] || record["si_code"]

      case si_code do
        nil -> {with_si, [record | without_si]}
        "" -> {with_si, [record | without_si]}
        [] -> {with_si, [record | without_si]}
        _ -> {[record | with_si], without_si}
      end
    end)
    |> then(fn {with_si, without_si} ->
      {Enum.reverse(with_si), Enum.reverse(without_si)}
    end)
  end

  defp print_summary(%{group1: g1, group2: g2, group3: g3, title_excluded: te}) do
    IO.puts("\n=== CATEGORIZATION SUMMARY ===")
    IO.puts("Group 1 (SI code match):    #{Enum.count(g1)}")
    IO.puts("Group 2 (Term match only):  #{Enum.count(g2)}")
    IO.puts("Group 3 (Excluded):         #{Enum.count(g3)}")
    IO.puts("Title excluded:             #{Enum.count(te)}")
    IO.puts("================================")
  end
end
