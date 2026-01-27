defmodule SertantaiLegal.Scraper.Amending do
  @moduledoc """
  Fetches and parses amendment relationships from legislation.gov.uk.

  This module handles two types of relationships:
  - **Amending**: Laws that THIS law amends (uses `/changes/affecting` endpoint)
  - **Amended by**: Laws that amend THIS law (uses `/changes/affected` endpoint)

  Ported from Legl.Countries.Uk.LeglRegister.Amend.Amending and AmendedBy

  ## Usage

      # Get laws amended by this law
      {:ok, result} = Amending.get_laws_amended_by_this_law(%{type_code: "uksi", Year: 2024, Number: "1001"})

      # Get laws that amend this law
      {:ok, result} = Amending.get_laws_amending_this_law(%{type_code: "uksi", Year: 2024, Number: "1001"})

  ## Notes

  - The legacy code used BFS traversal with configurable depth. We use depth=0 (direct relationships only)
  - Amendment data is parsed from HTML tables returned by legislation.gov.uk
  - Results are separated into amendments vs revocations/repeals
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.Client
  alias SertantaiLegal.Scraper.IdField

  @results_count 1000

  @type amendment :: %{
          name: String.t(),
          title_en: String.t(),
          type_code: String.t(),
          number: String.t(),
          year: integer(),
          path: String.t(),
          target: String.t(),
          affect: String.t(),
          applied?: String.t()
        }

  @type amending_result :: %{
          amending: list(String.t()),
          rescinding: list(String.t()),
          stats: map(),
          amendments: list(amendment()),
          revocations: list(amendment())
        }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Get laws amended BY this law (this law is the amending/affecting law).

  Fetches from `/changes/affecting/{type_code}/{year}/{number}` endpoint.

  Returns amendment relationships including:
  - amending: List of law names this law amends (excluding self)
  - rescinding: List of law names this law revokes/repeals (excluding self)
  - self_amendments: List of self-referencing amendment records
  - self_revocations: List of self-referencing revocation records
  - stats: Amendment statistics (with accurate self_amendments count)

  ## Parameters
  - record: Map with :type_code, :Year, :Number keys

  ## Returns
  - `{:ok, amending_result}` with parsed amendment data
  - `{:error, reason}` on failure
  """
  @spec get_laws_amended_by_this_law(map()) :: {:ok, amending_result()} | {:error, String.t()}
  def get_laws_amended_by_this_law(record) do
    {type_code, year, number} = extract_record_params(record)
    self_name = IdField.build_uk_id(type_code, year, number)
    path = affecting_path(record)
    fetch_and_parse_amendments_with_self_filter(path, self_name, :affecting)
  end

  @doc """
  Get laws that amend THIS law (this law is the amended/affected law).

  Fetches from `/changes/affected/{type_code}/{year}/{number}` endpoint.

  Returns amendment relationships including:
  - amended_by: List of law names that amend this law (excluding self)
  - rescinded_by: List of law names that revoke/repeal this law (excluding self)
  - self_amendments: List of self-referencing amendment records
  - self_revocations: List of self-referencing revocation records
  - stats: Amendment statistics (with accurate self_amendments count)
  - live: Computed live status based on revocations

  ## Parameters
  - record: Map with :type_code, :Year, :Number keys

  ## Returns
  - `{:ok, amended_by_result}` with parsed amendment data
  - `{:error, reason}` on failure
  """
  @spec get_laws_amending_this_law(map()) :: {:ok, map()} | {:error, String.t()}
  def get_laws_amending_this_law(record) do
    {type_code, year, number} = extract_record_params(record)
    self_name = IdField.build_uk_id(type_code, year, number)
    path = affected_path(record)

    case fetch_and_parse_amendments_with_self_filter(path, self_name, :affected) do
      {:ok, result} ->
        # Determine live status based on revocations (excluding self)
        live = determine_live_status(result.revocations)

        {:ok,
         Map.merge(result, %{
           amended_by: result.amending,
           rescinded_by: result.rescinding,
           live: live
         })}

      error ->
        error
    end
  end

  # ============================================================================
  # URL Builders
  # ============================================================================

  @doc """
  Build URL path for laws affected (amended) by this law.

  ## Examples

      iex> Amending.affecting_path(%{type_code: "uksi", Year: 2024, Number: "1001"})
      "/changes/affecting/uksi/2024/1001?results-count=1000&sort=affecting-year-number"
  """
  @spec affecting_path(map()) :: String.t()
  def affecting_path(record) do
    {type_code, year, number} = extract_record_params(record)

    "/changes/affecting/#{type_code}/#{year}/#{number}?results-count=#{@results_count}&sort=affecting-year-number"
  end

  @doc """
  Build URL path for laws affecting (amending) this law.

  ## Examples

      iex> Amending.affected_path(%{type_code: "uksi", Year: 2024, Number: "1001"})
      "/changes/affected/uksi/2024/1001?results-count=1000&sort=affected-year-number"
  """
  @spec affected_path(map()) :: String.t()
  def affected_path(record) do
    {type_code, year, number} = extract_record_params(record)

    "/changes/affected/#{type_code}/#{year}/#{number}?results-count=#{@results_count}&sort=affected-year-number"
  end

  defp extract_record_params(record) do
    type_code = record[:type_code] || record["type_code"]
    year = record[:Year] || record["Year"]
    number = to_string(record[:Number] || record["Number"])
    {type_code, year, number}
  end

  # ============================================================================
  # Fetch and Parse
  # ============================================================================

  defp fetch_and_parse_amendments_with_self_filter(path, self_name, endpoint) do
    case Client.fetch_html(path) do
      {:ok, html} ->
        all_amendments = parse_amendments_html(html, endpoint: endpoint)

        # Separate self-references from other amendments
        {self_all, other_all} = Enum.split_with(all_amendments, &(&1.name == self_name))

        # Separate revocations from amendments for non-self
        {other_revocations, other_affectations} = separate_revocations(other_all)

        # Separate revocations from amendments for self
        {self_revocations, self_affectations} = separate_revocations(self_all)

        {:ok,
         %{
           # Non-self amendments (for amending/amended_by arrays)
           amending: build_links(other_affectations),
           rescinding: build_links(other_revocations),
           amendments: other_affectations,
           revocations: other_revocations,

           # Self-referencing amendments (for stats and detailed field)
           self_amendments: self_affectations,
           self_revocations: self_revocations,

           # Stats with accurate self count
           stats:
             build_stats_with_self(
               all_amendments,
               other_affectations,
               other_revocations,
               self_all
             )
         }}

      {:error, 404, _msg} ->
        # No amendments data is valid - law may not have any amendments
        {:ok,
         %{
           amending: [],
           rescinding: [],
           amendments: [],
           revocations: [],
           self_amendments: [],
           self_revocations: [],
           stats: %{
             total_changes: 0,
             amendments_count: 0,
             revocations_count: 0,
             laws_count: 0,
             amended_laws_count: 0,
             revoked_laws_count: 0,
             self_amendments_count: 0
           }
         }}

      {:error, _code, msg} ->
        {:error, msg}
    end
  end

  # ============================================================================
  # HTML Parsing
  # ============================================================================

  @doc """
  Parse amendment HTML table into structured data.

  The HTML contains a table with 9 columns:
  - Column 0: Affected law title
  - Column 1: Affected law path/link (e.g., "/id/uksi/2020/1234")
  - Column 2: Target section (e.g., "s. 2(1)")
  - Column 3: Affect type (e.g., "inserted", "substituted", "repealed")
  - Column 4: Affecting law title
  - Column 5: Affecting law path
  - Column 6: Affecting section
  - Column 7: Applied status ("Yes", "Not yet", etc.)
  - Column 8: Notes

  ## Options
  - `:endpoint` - `:affecting` (default) or `:affected`
    - `:affecting` reads the OTHER law from columns 0-1 (affected law)
    - `:affected` reads the OTHER law from columns 4-5 (affecting law)
  """
  @spec parse_amendments_html(String.t(), keyword()) :: list(amendment())
  def parse_amendments_html(html, opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, :affecting)

    case Floki.parse_document(html) do
      {:ok, document} ->
        document
        |> Floki.find("tbody tr")
        |> Enum.map(&parse_amendment_row(&1, endpoint))
        |> Enum.reject(&is_nil/1)

      {:error, _} ->
        []
    end
  end

  defp parse_amendment_row({"tr", _attrs, cells}, endpoint) do
    try do
      cells_list = Enum.with_index(cells)

      # For /changes/affecting: the OTHER law is in columns 0-1 (affected law)
      # For /changes/affected: the OTHER law is in columns 4-5 (affecting law)
      {title_col, link_col} =
        case endpoint do
          :affected -> {4, 5}
          _ -> {0, 1}
        end

      # Extract data from the appropriate columns
      title_en = get_cell_text(cells_list, title_col) |> extract_title()
      {path, type_code, year, number} = get_cell_link(cells_list, link_col)
      target = get_cell_text(cells_list, 2)
      affect = get_cell_text(cells_list, 3)
      applied? = get_cell_text(cells_list, 7)

      if path && type_code do
        %{
          name: build_name(type_code, year, number),
          title_en: title_en,
          type_code: type_code,
          number: number,
          year: parse_year(year),
          path: path,
          target: target,
          affect: affect,
          applied?: applied?
        }
      else
        nil
      end
    rescue
      _ -> nil
    end
  end

  defp parse_amendment_row(_, _endpoint), do: nil

  defp get_cell_text(cells_list, index) do
    case Enum.find(cells_list, fn {_cell, i} -> i == index end) do
      {{"td", _, content}, _} ->
        content
        |> extract_text_content()
        |> String.trim()

      _ ->
        ""
    end
  end

  defp get_cell_link(cells_list, index) do
    case Enum.find(cells_list, fn {_cell, i} -> i == index end) do
      {{"td", _, content}, _} ->
        extract_link(content)

      _ ->
        {nil, nil, nil, nil}
    end
  end

  defp extract_text_content(content) when is_list(content) do
    Enum.map(content, fn
      text when is_binary(text) -> text
      {"strong", _, children} -> extract_text_content(children)
      {"a", _, children} -> extract_text_content(children)
      {"span", _, children} -> extract_text_content(children)
      _ -> ""
    end)
    |> Enum.join(" ")
  end

  defp extract_text_content(text) when is_binary(text), do: text
  defp extract_text_content(_), do: ""

  defp extract_title(text) do
    text
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp extract_link(content) when is_list(content) do
    Enum.find_value(content, {nil, nil, nil, nil}, fn
      {"a", attrs, _children} ->
        href =
          Enum.find_value(attrs, fn
            {"href", value} -> value
            _ -> nil
          end)

        parse_legislation_path(href)

      {"strong", _, children} ->
        extract_link(children)

      _ ->
        nil
    end)
  end

  defp extract_link(_), do: {nil, nil, nil, nil}

  defp parse_legislation_path(nil), do: {nil, nil, nil, nil}

  defp parse_legislation_path(path) do
    # Parse paths like "/id/uksi/2020/1234" or "/uksi/2020/1234"
    case Regex.run(~r/\/(?:id\/)?([a-z]+)\/(\d{4})\/(\d+)/, path) do
      [_full, type_code, year, number] ->
        {path, type_code, year, number}

      _ ->
        {path, nil, nil, nil}
    end
  end

  defp build_name(type_code, year, number), do: IdField.build_uk_id(type_code, year, number)

  defp parse_year(year) when is_binary(year), do: String.to_integer(year)
  defp parse_year(year) when is_integer(year), do: year
  defp parse_year(_), do: 0

  # ============================================================================
  # Processing
  # ============================================================================

  defp separate_revocations(amendments) do
    Enum.split_with(amendments, fn %{affect: affect} ->
      affect_lower = String.downcase(affect || "")
      String.contains?(affect_lower, "repeal") or String.contains?(affect_lower, "revoke")
    end)
  end

  defp build_links(amendments) do
    amendments
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(fn a -> {-a.year, -parse_number_for_sort(a.number)} end)
    |> Enum.map(& &1.name)
  end

  # Parse number string to integer for sorting, handling non-numeric suffixes
  defp parse_number_for_sort(number) when is_binary(number) do
    case Integer.parse(number) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_number_for_sort(_), do: 0

  defp build_stats_with_self(all, other_amendments, other_revocations, self_all) do
    # Stats for non-self amendments only (what we report in main arrays)
    unique_other_amendments = Enum.uniq_by(other_amendments, & &1.name)
    unique_other_revocations = Enum.uniq_by(other_revocations, & &1.name)

    # Combined unique laws (excluding self)
    all_other = other_amendments ++ other_revocations
    unique_other_all = Enum.uniq_by(all_other, & &1.name)

    %{
      # Total includes self for reference
      total_changes: length(all),
      # Counts exclude self
      amendments_count: length(other_amendments),
      revocations_count: length(other_revocations),
      laws_count: length(unique_other_all),
      amended_laws_count: length(unique_other_amendments),
      revoked_laws_count: length(unique_other_revocations),
      # Self-amendment count (the actual count of self-referencing entries)
      self_amendments_count: length(self_all)
    }
  end

  # ============================================================================
  # Live Status
  # ============================================================================

  @live_in_force "✔ In force"
  @live_part_revoked "⭕ Part Revocation / Repeal"
  @live_revoked "❌ Revoked / Repealed / Abolished"

  defp determine_live_status([]), do: @live_in_force

  defp determine_live_status(revocations) do
    # Check if there are any "in full" revocations
    has_full_revocation =
      Enum.any?(revocations, fn %{affect: affect} ->
        affect_lower = String.downcase(affect || "")

        String.contains?(affect_lower, "in full") or
          (String.contains?(affect_lower, "repeal") and
             not String.contains?(affect_lower, "in part"))
      end)

    if has_full_revocation do
      @live_revoked
    else
      @live_part_revoked
    end
  end
end
