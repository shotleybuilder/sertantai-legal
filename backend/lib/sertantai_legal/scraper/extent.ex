defmodule SertantaiLegal.Scraper.Extent do
  @moduledoc """
  Determines the geographic extent (England, Wales, Scotland, Northern Ireland)
  of UK legislation by fetching contents XML from legislation.gov.uk.

  Extracts `RestrictExtent` attributes from `ContentsItem` elements.

  Sets three fields:
  - `Geo_Region`: List of nations the law applies to
  - `Geo_Pan_Region`: High-level region code (UK, GB, E+W, E, W, S, NI)
  - `Geo_Extent`: Formatted string with provisions mapped to regions

  Ported from Legl.Countries.Uk.LeglRegister.Extent
  """

  import SweetXml

  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  @doc """
  Set the extent fields for a legal record.

  ## Parameters
  - record: Map with :type_code, :Year, :Number keys

  ## Returns
  Map with :Geo_Region, :Geo_Pan_Region, :Geo_Extent fields set

  ## Examples

      iex> Extent.set_extent(%{type_code: "uksi", Year: 2024, Number: "123"})
      %{..., Geo_Region: ["England", "Wales"], Geo_Pan_Region: "E+W", Geo_Extent: "..."}
  """
  @spec set_extent(map()) :: map()
  def set_extent(%{type_code: type_code, Year: year, Number: number} = record)
      when is_binary(type_code) and is_binary(number) do
    year_str = if is_integer(year), do: Integer.to_string(year), else: year
    path = contents_xml_path(type_code, year_str, number)

    case fetch_extent_data(path) do
      {:ok, extent_data} ->
        {geo_region, geo_pan_region, geo_extent} = transform_extent(extent_data)

        record
        |> Map.put(:Geo_Parent, "United Kingdom")
        |> Map.put(:Geo_Region, geo_region)
        |> Map.put(:Geo_Pan_Region, geo_pan_region)
        |> Map.put(:Geo_Extent, geo_extent)

      {:error, _reason} ->
        # Return record unchanged if extent data unavailable
        record
    end
  end

  def set_extent(record), do: record

  @doc """
  Build the contents XML path for a law.
  """
  @spec contents_xml_path(String.t(), String.t(), String.t()) :: String.t()
  def contents_xml_path(type_code, year, number) do
    # Handle numbers with slashes (e.g., "123/456")
    if String.contains?(number, "/") do
      "/#{type_code}/#{number}/contents/data.xml"
    else
      "/#{type_code}/#{year}/#{number}/contents/data.xml"
    end
  end

  @doc """
  Fetch extent data from legislation.gov.uk.

  Returns list of {provision, extent_code} tuples.
  """
  @spec fetch_extent_data(String.t()) :: {:ok, list()} | {:error, String.t()}
  def fetch_extent_data(path) do
    IO.puts("  Fetching extent: #{path}")

    case Client.fetch_xml(path) do
      {:ok, xml} ->
        extent_data = parse_contents_xml(xml)
        {:ok, extent_data}

      {:ok, :html, _body} ->
        # Try with /made/ path
        made_path = String.replace(path, "/contents/", "/contents/made/")

        if made_path != path do
          fetch_extent_data(made_path)
        else
          {:error, "Received HTML instead of XML"}
        end

      {:error, 307, _msg} ->
        # Try with /made/ path for redirects
        made_path = String.replace(path, "/contents/", "/contents/made/")

        if made_path != path do
          fetch_extent_data(made_path)
        else
          {:error, "Redirect without made path available"}
        end

      {:error, code, msg} ->
        {:error, "HTTP #{code}: #{msg}"}
    end
  end

  @doc """
  Parse contents XML to extract provision/extent tuples.
  """
  @spec parse_contents_xml(String.t()) :: list({String.t(), String.t()})
  def parse_contents_xml(xml) when is_binary(xml) do
    try do
      xml
      |> xpath(
        ~x"//ContentsItem"l,
        content_ref: ~x"./@ContentRef"s,
        restrict_extent: ~x"./@RestrictExtent"s
      )
      |> Enum.map(fn %{content_ref: ref, restrict_extent: extent} ->
        # Normalize extent code (remove dots from N.I.)
        extent = String.replace(extent, ".", "")
        {ref, extent}
      end)
      |> Enum.reject(fn {_ref, extent} -> extent == "" end)
    rescue
      _ -> []
    end
  end

  @doc """
  Transform raw extent data into geo fields.

  Returns {geo_region, geo_pan_region, geo_extent}.
  """
  @spec transform_extent(list()) :: {list(String.t()), String.t(), String.t()}
  def transform_extent([]), do: {[], "", ""}

  def transform_extent(data) do
    # Clean and normalize extent codes
    clean_data = clean_extent_data(data)

    # Get unique extent codes
    unique_extents = get_unique_extents(clean_data)

    # Build geo fields
    geo_region = build_geo_region(unique_extents)
    geo_pan_region = build_geo_pan_region(geo_region)
    geo_extent = build_geo_extent(clean_data, unique_extents)

    {geo_region, geo_pan_region, geo_extent}
  end

  # Clean and normalize extent codes
  defp clean_extent_data(data) do
    Enum.reduce(data, [], fn
      {provision, "(E+W)"}, acc -> [{provision, "E+W"} | acc]
      {provision, "EW"}, acc -> [{provision, "E+W"} | acc]
      {provision, "EWS"}, acc -> [{provision, "E+W+S"} | acc]
      {_provision, ""}, acc -> acc
      {provision, extent}, acc -> [{provision, extent} | acc]
    end)
    |> Enum.reverse()
  end

  # Get unique extent codes sorted by length (longest first)
  defp get_unique_extents(data) do
    data
    |> Enum.map(fn {_provision, extent} -> extent end)
    |> Enum.uniq()
    |> Enum.sort_by(&byte_size/1, :desc)
  end

  # Build list of nation names from extent codes
  defp build_geo_region(extents) do
    extents
    |> Enum.flat_map(&extent_to_nations/1)
    |> Enum.uniq()
    |> order_regions()
  end

  # Convert extent code to list of nations
  defp extent_to_nations(extent) do
    case extent do
      "E+W+S+NI" -> ["England", "Wales", "Scotland", "Northern Ireland"]
      "E+W+S" -> ["England", "Wales", "Scotland"]
      "E+W+NI" -> ["England", "Wales", "Northern Ireland"]
      "E+S+NI" -> ["England", "Scotland", "Northern Ireland"]
      "W+S+NI" -> ["Wales", "Scotland", "Northern Ireland"]
      "E+W" -> ["England", "Wales"]
      "E+S" -> ["England", "Scotland"]
      "E+NI" -> ["England", "Northern Ireland"]
      "W+S" -> ["Wales", "Scotland"]
      "W+NI" -> ["Wales", "Northern Ireland"]
      "S+NI" -> ["Scotland", "Northern Ireland"]
      "E" -> ["England"]
      "W" -> ["Wales"]
      "S" -> ["Scotland"]
      "NI" -> ["Northern Ireland"]
      _ -> []
    end
  end

  # Order regions in standard order
  defp order_regions(regions) do
    order = %{
      "England" => 1,
      "Wales" => 2,
      "Scotland" => 3,
      "Northern Ireland" => 4
    }

    Enum.sort_by(regions, fn r -> Map.get(order, r, 99) end)
  end

  # Build pan-region code from region list
  defp build_geo_pan_region([]), do: ""

  defp build_geo_pan_region(regions) do
    sorted = Enum.sort(regions)

    cond do
      sorted == ["England", "Northern Ireland", "Scotland", "Wales"] -> "UK"
      sorted == ["England", "Scotland", "Wales"] -> "GB"
      sorted == ["England", "Wales"] -> "E+W"
      sorted == ["England", "Scotland"] -> "E+S"
      sorted == ["England"] -> "E"
      sorted == ["Wales"] -> "W"
      sorted == ["Scotland"] -> "S"
      sorted == ["Northern Ireland"] -> "NI"
      true -> Enum.map(regions, &region_to_code/1) |> Enum.join("+")
    end
  end

  defp region_to_code("England"), do: "E"
  defp region_to_code("Wales"), do: "W"
  defp region_to_code("Scotland"), do: "S"
  defp region_to_code("Northern Ireland"), do: "NI"
  defp region_to_code(_), do: ""

  # Build formatted geo_extent string with provisions mapped to regions
  defp build_geo_extent(_data, [single_extent]) do
    # All provisions have the same extent
    "#{single_extent}: All provisions"
  end

  defp build_geo_extent(data, unique_extents) do
    # Group provisions by extent
    extent_map =
      Enum.reduce(unique_extents, %{}, fn extent, acc ->
        Map.put(acc, extent, [])
      end)

    extent_map =
      Enum.reduce(data, extent_map, fn {provision, extent}, acc ->
        provisions = Map.get(acc, extent, [])
        Map.put(acc, extent, [provision | provisions])
      end)

    # Format as string, sorted by extent length (broadest first)
    extent_map
    |> Enum.map(fn {extent, provisions} -> {extent, Enum.reverse(provisions)} end)
    |> Enum.sort_by(fn {extent, _} -> -byte_size(extent) end)
    |> Enum.map(fn {extent, provisions} ->
      provisions_str = Enum.join(provisions, ", ")
      "#{extent}: #{provisions_str}"
    end)
    |> Enum.join(" | ")
  end
end
