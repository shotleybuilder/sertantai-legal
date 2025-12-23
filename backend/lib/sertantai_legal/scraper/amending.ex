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
  - amending: List of law names this law amends
  - rescinding: List of law names this law revokes/repeals
  - stats: Amendment statistics

  ## Parameters
  - record: Map with :type_code, :Year, :Number keys

  ## Returns
  - `{:ok, amending_result}` with parsed amendment data
  - `{:error, reason}` on failure
  """
  @spec get_laws_amended_by_this_law(map()) :: {:ok, amending_result()} | {:error, String.t()}
  def get_laws_amended_by_this_law(record) do
    path = affecting_path(record)
    fetch_and_parse_amendments(path)
  end

  @doc """
  Get laws that amend THIS law (this law is the amended/affected law).

  Fetches from `/changes/affected/{type_code}/{year}/{number}` endpoint.

  Returns amendment relationships including:
  - amended_by: List of law names that amend this law
  - rescinded_by: List of law names that revoke/repeal this law
  - stats: Amendment statistics
  - live: Computed live status based on revocations

  ## Parameters
  - record: Map with :type_code, :Year, :Number keys

  ## Returns
  - `{:ok, amended_by_result}` with parsed amendment data
  - `{:error, reason}` on failure
  """
  @spec get_laws_amending_this_law(map()) :: {:ok, map()} | {:error, String.t()}
  def get_laws_amending_this_law(record) do
    path = affected_path(record)

    case fetch_and_parse_amendments(path) do
      {:ok, result} ->
        # Determine live status based on revocations
        live = determine_live_status(result.revocations)
        {:ok, Map.merge(result, %{
          amended_by: result.amending,
          rescinded_by: result.rescinding,
          live: live
        })}

      error -> error
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

  defp fetch_and_parse_amendments(path) do
    case Client.fetch_html(path) do
      {:ok, html} ->
        amendments = parse_amendments_html(html)
        {revocations, affectations} = separate_revocations(amendments)

        {:ok, %{
          amending: build_links(affectations),
          rescinding: build_links(revocations),
          stats: build_stats(amendments, affectations, revocations),
          amendments: affectations,
          revocations: revocations
        }}

      {:error, 404, _msg} ->
        # No amendments data is valid - law may not have any amendments
        {:ok, %{
          amending: [],
          rescinding: [],
          stats: %{amendments_count: 0, revocations_count: 0, laws_count: 0},
          amendments: [],
          revocations: []
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

  The HTML contains a table with rows like:
  - Column 0: Affected law title
  - Column 1: Affected law path/link (e.g., "/id/uksi/2020/1234")
  - Column 2: Target section (e.g., "s. 2(1)")
  - Column 3: Affect type (e.g., "inserted", "substituted", "repealed")
  - Column 4: Affecting law title (this law)
  - Column 5: Affecting law path
  - Column 6: Affecting section
  - Column 7: Applied status ("Yes", "Not yet", etc.)
  - Column 8: Notes
  """
  @spec parse_amendments_html(String.t()) :: list(amendment())
  def parse_amendments_html(html) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        document
        |> Floki.find("tbody tr")
        |> Enum.map(&parse_amendment_row/1)
        |> Enum.reject(&is_nil/1)

      {:error, _} ->
        []
    end
  end

  defp parse_amendment_row({"tr", _attrs, cells}) do
    try do
      cells_list = Enum.with_index(cells)

      # Extract data from each cell
      title_en = get_cell_text(cells_list, 0) |> extract_title()
      {path, type_code, year, number} = get_cell_link(cells_list, 1)
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

  defp parse_amendment_row(_), do: nil

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
        href = Enum.find_value(attrs, fn
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
    |> Enum.map(& &1.name)
  end

  defp build_stats(all, amendments, revocations) do
    unique_all = Enum.uniq_by(all, & &1.name)
    unique_amendments = Enum.uniq_by(amendments, & &1.name)
    unique_revocations = Enum.uniq_by(revocations, & &1.name)

    %{
      total_changes: length(all),
      amendments_count: length(amendments),
      revocations_count: length(revocations),
      laws_count: length(unique_all),
      amended_laws_count: length(unique_amendments),
      revoked_laws_count: length(unique_revocations),
      self_amendments: count_self_amendments(all)
    }
  end

  defp count_self_amendments(_amendments) do
    # Count amendments where the target law is the same as the source law
    # This would require knowing the source law, which we'd get from the affecting_path columns
    # For now, return 0 - can be enhanced later
    0
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
    has_full_revocation = Enum.any?(revocations, fn %{affect: affect} ->
      affect_lower = String.downcase(affect || "")
      String.contains?(affect_lower, "in full") or
        (String.contains?(affect_lower, "repeal") and not String.contains?(affect_lower, "in part"))
    end)

    if has_full_revocation do
      @live_revoked
    else
      @live_part_revoked
    end
  end
end
