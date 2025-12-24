defmodule SertantaiLegal.Scraper.StagedParser do
  @moduledoc """
  Staged parser for UK legislation metadata.

  Parses legislation in four defined stages:
  1. **Extent** - Geographic extent from contents XML (E+W+S+NI)
  2. **Enacted_by** - Enacting parent laws from introduction/made XML
  3. **Amendments** - Laws amended by and amending this law
  4. **Repeal/Revoke** - Repeal/revocation status and relationships

  Note: Basic metadata (title, dates, SI codes) is already captured during
  the initial scrape by NewLaws.enrich_with_metadata() and is passed in
  via the record parameter.

  Each stage is independent and reports its own success/error status,
  allowing partial results when some stages fail.

  ## Usage

      # Parse a single record with all stages
      {:ok, result} = StagedParser.parse(%{type_code: "uksi", Year: 2024, Number: "1001"})

      # Result structure:
      %{
        record: %{...merged data...},
        stages: %{
          extent: %{status: :ok, data: %{...}},
          enacted_by: %{status: :ok, data: %{...}},
          amendments: %{status: :error, error: "...", data: nil},
          repeal_revoke: %{status: :ok, data: %{...}}
        },
        errors: ["amendments: HTTP 404..."],
        has_errors: true
      }
  """

  import SweetXml

  alias SertantaiLegal.Scraper.LegislationGovUk.Client
  alias SertantaiLegal.Scraper.Amending
  alias SertantaiLegal.Scraper.EnactedBy

  @stages [:extent, :enacted_by, :amendments, :repeal_revoke]

  # Live status codes (matching legl conventions)
  @live_in_force "✔ In force"
  @live_part_revoked "⭕ Part Revocation / Repeal"
  @live_revoked "❌ Revoked / Repealed / Abolished"

  @type stage :: :extent | :enacted_by | :amendments | :repeal_revoke
  @type stage_result :: %{status: :ok | :error | :skipped, data: map() | nil, error: String.t() | nil}
  @type parse_result :: %{
          record: map(),
          stages: %{stage() => stage_result()},
          errors: list(String.t()),
          has_errors: boolean()
        }

  @doc """
  Parse a law record through all stages.

  ## Parameters
  - record: Map with :type_code, :Year, :Number keys
  - opts: Options
    - :stages - List of stages to run (default: all)
    - :skip_on_error - Skip remaining stages if one fails (default: false)

  ## Returns
  `{:ok, parse_result}` with merged data and per-stage status
  """
  @spec parse(map(), keyword()) :: {:ok, parse_result()}
  def parse(record, opts \\ []) do
    stages_to_run = Keyword.get(opts, :stages, @stages)
    skip_on_error = Keyword.get(opts, :skip_on_error, false)

    # Build law identifiers
    type_code = record[:type_code] || record["type_code"]
    year = record[:Year] || record["Year"]
    number = record[:Number] || record["Number"]
    name = "#{type_code}/#{year}/#{number}"

    IO.puts("\n=== STAGED PARSE: #{name} ===")

    # Initialize result
    initial_result = %{
      record: Map.merge(record, %{name: name}),
      stages: %{},
      errors: [],
      has_errors: false
    }

    # Run each stage
    result =
      Enum.reduce_while(stages_to_run, initial_result, fn stage, acc ->
        if skip_on_error and acc.has_errors do
          # Mark remaining stages as skipped
          stage_result = %{status: :skipped, data: nil, error: "Skipped due to previous error"}
          {:cont, update_result(acc, stage, stage_result)}
        else
          stage_result = run_stage(stage, type_code, year, number, acc.record)
          updated = update_result(acc, stage, stage_result)

          if skip_on_error and stage_result.status == :error do
            {:halt, updated}
          else
            {:cont, updated}
          end
        end
      end)

    # Mark remaining stages as skipped if we halted early
    result =
      Enum.reduce(@stages, result, fn stage, acc ->
        if Map.has_key?(acc.stages, stage) do
          acc
        else
          stage_result = %{status: :skipped, data: nil, error: "Skipped"}
          update_result(acc, stage, stage_result)
        end
      end)

    IO.puts("\n=== PARSE COMPLETE: #{if result.has_errors, do: "WITH ERRORS", else: "SUCCESS"} ===\n")

    {:ok, result}
  end

  @doc """
  Get the list of all parsing stages.
  """
  @spec stages() :: list(stage())
  def stages, do: @stages

  # Update result with stage outcome
  defp update_result(result, stage, stage_result) do
    new_stages = Map.put(result.stages, stage, stage_result)

    new_errors =
      case stage_result.status do
        :error -> result.errors ++ ["#{stage}: #{stage_result.error}"]
        _ -> result.errors
      end

    new_record =
      case stage_result.status do
        :ok -> Map.merge(result.record, stage_result.data || %{})
        _ -> result.record
      end

    %{
      result
      | stages: new_stages,
        errors: new_errors,
        has_errors: length(new_errors) > 0,
        record: new_record
    }
  end

  # Run a specific stage
  defp run_stage(:extent, type_code, year, number, _record) do
    IO.puts("  [1/4] Extent...")
    run_extent_stage(type_code, year, number)
  end

  defp run_stage(:enacted_by, type_code, year, number, _record) do
    IO.puts("  [2/4] Enacted By...")
    run_enacted_by_stage(type_code, year, number)
  end

  defp run_stage(:amendments, type_code, year, number, record) do
    IO.puts("  [3/4] Amendments...")
    run_amendments_stage(type_code, year, number, record)
  end

  defp run_stage(:repeal_revoke, type_code, year, number, _record) do
    IO.puts("  [4/4] Repeal/Revoke...")
    run_repeal_revoke_stage(type_code, year, number)
  end

  # ============================================================================
  # Stage 1: Extent
  # ============================================================================

  defp run_extent_stage(type_code, year, number) do
    path = "/#{type_code}/#{year}/#{number}/contents/data.xml"

    case Client.fetch_xml(path) do
      {:ok, xml} ->
        data = parse_extent_xml(xml)
        IO.puts("    ✓ Extent: #{data[:extent] || "unknown"}")
        %{status: :ok, data: data, error: nil}

      {:error, 404, _} ->
        # Try without /contents/
        alt_path = "/#{type_code}/#{year}/#{number}/data.xml"

        case Client.fetch_xml(alt_path) do
          {:ok, xml} ->
            data = parse_extent_xml(xml)
            IO.puts("    ✓ Extent (alt path): #{data[:extent] || "unknown"}")
            %{status: :ok, data: data, error: nil}

          {:error, code, msg} ->
            IO.puts("    ✗ Extent failed: #{msg}")
            %{status: :error, data: nil, error: "HTTP #{code}: #{msg}"}
        end

      {:error, code, msg} ->
        IO.puts("    ✗ Extent failed: #{msg}")
        %{status: :error, data: nil, error: "HTTP #{code}: #{msg}"}
    end
  end

  defp parse_extent_xml(xml) do
    try do
      # Try multiple locations for extent:
      # 1. Legislation element's RestrictExtent attribute
      # 2. First ContentsItem's RestrictExtent attribute (most common for new legislation)
      # 3. Contents element's RestrictExtent attribute (fallback)

      extent = xpath_text(xml, ~x"//Legislation/@RestrictExtent"s)

      # Get extent from first ContentsItem if Legislation doesn't have it
      first_item_extent =
        case SweetXml.xpath(xml, ~x"//ContentsItem[1]/@RestrictExtent"s) do
          nil -> nil
          "" -> nil
          val -> to_string(val)
        end

      # Get extent from Contents element as fallback
      contents_extent =
        case SweetXml.xpath(xml, ~x"//Contents/@RestrictExtent"s) do
          nil -> nil
          "" -> nil
          val -> to_string(val)
        end

      # Parse section-level extents
      section_extents = parse_section_extents(xml)

      # Use first available extent: Legislation > first ContentsItem > Contents
      raw_extent =
        cond do
          extent != "" and extent != nil -> extent
          first_item_extent != "" and first_item_extent != nil -> first_item_extent
          contents_extent != "" and contents_extent != nil -> contents_extent
          true -> nil
        end

      normalized_extent = normalize_extent(raw_extent)
      regions = extent_to_regions(raw_extent)

      # Build base result with section-level data (always useful)
      base = %{
        section_extents: section_extents
      }

      # Only include top-level extent fields if we found data
      # This prevents overwriting values from metadata.ex (initial scrape)
      if normalized_extent do
        # Use Extent module to generate geo_detail with emoji flags and section breakdown
        {_region, _pan_region, geo_detail} = SertantaiLegal.Scraper.Extent.transform_extent(section_extents)

        Map.merge(base, %{
          geo_extent: regions_to_pan_region(regions),
          geo_region: regions,
          geo_detail: geo_detail,
          extent: regions_to_pan_region(regions),
          extent_regions: regions
        })
      else
        # No extent found in contents XML - preserve whatever came from metadata
        base
      end
    rescue
      e ->
        # Don't overwrite extent fields on error - just log it
        %{extent_error: "Parse error: #{inspect(e)}"}
    end
  end

  # Convert regions list to pan-region code (UK, GB, E+W, etc.)
  defp regions_to_pan_region([]), do: nil

  defp regions_to_pan_region(regions) do
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
      true -> regions |> Enum.map(&region_to_code/1) |> Enum.join("+")
    end
  end

  defp region_to_code("England"), do: "E"
  defp region_to_code("Wales"), do: "W"
  defp region_to_code("Scotland"), do: "S"
  defp region_to_code("Northern Ireland"), do: "NI"
  defp region_to_code(_), do: ""

  defp parse_section_extents(xml) do
    # Try to get section-level extent data
    try do
      SweetXml.xpath(xml, ~x"//ContentsItem"l)
      |> Enum.map(fn item ->
        ref = SweetXml.xpath(item, ~x"./@ContentRef"s) |> to_string()
        ext = SweetXml.xpath(item, ~x"./@RestrictExtent"s) |> to_string()
        {ref, normalize_extent(ext)}
      end)
      |> Enum.reject(fn {ref, ext} -> ref == "" or ext == "" end)
      |> Enum.into(%{})
    rescue
      _ -> %{}
    end
  end

  defp normalize_extent(nil), do: nil
  defp normalize_extent(""), do: nil

  defp normalize_extent(extent) do
    # Raw extent from legislation.gov.uk is like "E+W+S+N.I."
    # Normalize to "E+W+S+NI" format
    extent
    |> String.upcase()
    |> String.replace("N.I.", "NI")  # Handle "N.I." → "NI"
    |> String.replace("N.I", "NI")   # Handle "N.I" without trailing dot
    |> String.replace(".", "")       # Remove any remaining dots
    |> String.replace(" ", "")       # Remove spaces
  end

  defp extent_to_regions(nil), do: []
  defp extent_to_regions(""), do: []

  defp extent_to_regions(extent) do
    extent = normalize_extent(extent)

    regions =
      []
      |> maybe_add_region(extent, "E", "England")
      |> maybe_add_region(extent, "W", "Wales")
      |> maybe_add_region(extent, "S", "Scotland")
      |> maybe_add_region(extent, "NI", "Northern Ireland")

    regions
  end

  defp maybe_add_region(acc, extent, code, name) do
    if String.contains?(extent, code) do
      acc ++ [name]
    else
      acc
    end
  end

  # ============================================================================
  # Stage 2: Enacted By
  # ============================================================================
  #
  # Fetches the "made" version of the introduction XML to find enacting parent laws.
  #
  # Secondary legislation (SIs) are "made" under powers conferred by primary legislation
  # (Acts). This stage parses the enacting text to find which Acts enabled this SI.
  #
  # Acts (ukpga, anaw, asp, nia, apni) are not enacted by other laws, so this stage
  # returns empty for those type codes.

  defp run_enacted_by_stage(type_code, _year, _number)
       when type_code in ["ukpga", "anaw", "asp", "nia", "apni"] do
    # Acts are not enacted by other laws
    IO.puts("    ⚠ Skipped (Acts are not enacted by other laws)")
    %{status: :ok, data: %{enacted_by: [], is_act: true}, error: nil}
  end

  defp run_enacted_by_stage(type_code, year, number) do
    # Use the EnactedBy module for parsing - single source of truth
    path = EnactedBy.introduction_path(type_code, to_string(year), to_string(number))

    case EnactedBy.fetch_enacting_data(path) do
      {:ok, %{text: text, urls: urls} = data} ->
        # Use EnactedBy's pattern matching to find enacted_by laws
        enacted_by_ids = EnactedBy.find_enacting_laws(text, urls)

        # Convert law IDs to richer format for downstream compatibility
        enacted_by = Enum.map(enacted_by_ids, &parse_law_id_to_map/1)

        count = length(enacted_by)
        IO.puts("    ✓ Enacted by: #{count} parent law(s)")

        %{
          status: :ok,
          data: %{
            enacted_by: enacted_by,
            enacting_text: String.slice(data.enacting_text, 0, 500),
            introductory_text: String.slice(data.introductory_text, 0, 500)
          },
          error: nil
        }

      {:error, reason} ->
        IO.puts("    ✗ Enacted by failed: #{reason}")
        %{status: :error, data: nil, error: reason}
    end
  end

  # Convert law ID like "ukpga/1974/37" to map format
  defp parse_law_id_to_map(law_id) do
    case String.split(law_id, "/") do
      [type_code, year, number] ->
        %{
          name: law_id,
          type_code: type_code,
          year: year,
          number: number,
          uri: "http://www.legislation.gov.uk/id/#{law_id}"
        }

      _ ->
        %{name: law_id, type_code: nil, year: nil, number: nil, uri: nil}
    end
  end

  # ============================================================================
  # Stage 3: Amendments
  # ============================================================================
  #
  # Uses the Amending module to fetch amendment data from /changes/affecting
  # and /changes/affected endpoints. These provide detailed amendment info
  # including target sections, affect types, and application status.

  defp run_amendments_stage(type_code, year, number, _record) do
    record = %{type_code: type_code, Year: year, Number: number}

    # Fetch laws this law amends (affecting)
    affecting_result = Amending.get_laws_amended_by_this_law(record)

    # Fetch laws that amend this law (affected)
    affected_result = Amending.get_laws_amending_this_law(record)

    case {affecting_result, affected_result} do
      {{:ok, affecting}, {:ok, affected}} ->
        data = %{
          # Laws this law amends
          amending: affecting.amending,
          rescinding: affecting.rescinding,
          amending_count: length(affecting.amending),
          rescinding_count: length(affecting.rescinding),
          is_amending: length(affecting.amending) > 0,
          is_rescinding: length(affecting.rescinding) > 0,

          # Laws that amend this law
          amended_by: affected.amended_by,
          rescinded_by: affected.rescinded_by,
          amended_by_count: length(affected.amended_by),
          rescinded_by_count: length(affected.rescinded_by),

          # Flattened stats - Self-affects (shared)
          stats_self_affects_count: affecting.stats.self_amendments,

          # Flattened stats - Amending (🔺 this law affects others)
          amending_stats_affects_count: affecting.stats.amendments_count,
          amending_stats_affected_laws_count: affecting.stats.amended_laws_count,
          amending_stats_affects_count_per_law: build_count_per_law_summary(affecting.amendments),
          amending_stats_affects_count_per_law_detailed: build_count_per_law_detailed(affecting.amendments),

          # Flattened stats - Amended_by (🔻 this law is affected by others)
          amended_by_stats_affected_by_count: affected.stats.amendments_count,
          amended_by_stats_affected_by_laws_count: affected.stats.amended_laws_count,
          amended_by_stats_affected_by_count_per_law: build_count_per_law_summary(affected.amendments),
          amended_by_stats_affected_by_count_per_law_detailed: build_count_per_law_detailed(affected.amendments),

          # Flattened stats - Rescinding (🔺 this law rescinds others)
          rescinding_stats_rescinding_laws_count: affecting.stats.revoked_laws_count,
          rescinding_stats_rescinding_count_per_law: build_count_per_law_summary(affecting.revocations),
          rescinding_stats_rescinding_count_per_law_detailed: build_count_per_law_detailed(affecting.revocations),

          # Flattened stats - Rescinded_by (🔻 this law is rescinded by others)
          rescinded_by_stats_rescinded_by_laws_count: affected.stats.revoked_laws_count,
          rescinded_by_stats_rescinded_by_count_per_law: build_count_per_law_summary(affected.revocations),
          rescinded_by_stats_rescinded_by_count_per_law_detailed: build_count_per_law_detailed(affected.revocations),

          # Detailed amendment data (for future use)
          amending_details: affecting.amendments,
          rescinding_details: affecting.revocations,
          amended_by_details: affected.amendments,
          rescinded_by_details: affected.revocations
        }

        IO.puts("    ✓ Amends: #{data.amending_count} laws, Rescinds: #{data.rescinding_count} laws")
        IO.puts("    ✓ Amended by: #{data.amended_by_count} laws, Rescinded by: #{data.rescinded_by_count} laws")

        %{status: :ok, data: data, error: nil}

      {{:error, msg}, _} ->
        IO.puts("    ✗ Amendments (affecting) failed: #{msg}")
        %{status: :error, data: nil, error: "Affecting: #{msg}"}

      {_, {:error, msg}} ->
        IO.puts("    ✗ Amendments (affected) failed: #{msg}")
        %{status: :error, data: nil, error: "Affected: #{msg}"}
    end
  end

  # ============================================================================
  # Stage 4: Repeal/Revoke
  # ============================================================================

  defp run_repeal_revoke_stage(type_code, year, number) do
    path = "/#{type_code}/#{year}/#{number}/resources/data.xml"

    case Client.fetch_xml(path) do
      {:ok, xml} ->
        data = parse_repeal_revoke_xml(xml)
        status_str = if data[:revoked], do: "REVOKED", else: "Active"
        IO.puts("    ✓ Status: #{status_str}")
        %{status: :ok, data: data, error: nil}

      {:error, 404, _} ->
        # No resources file - assume not revoked (in force)
        IO.puts("    ⚠ No revocation data (404) - assuming active")
        %{status: :ok, data: %{live: @live_in_force, live_description: "", revoked: false, revoked_by: []}, error: nil}

      {:error, code, msg} ->
        IO.puts("    ✗ Repeal/Revoke failed: #{msg}")
        %{status: :error, data: nil, error: "HTTP #{code}: #{msg}"}
    end
  end

  defp parse_repeal_revoke_xml(xml) do
    try do
      # Check title for REVOKED/REPEALED
      title = xpath_text(xml, ~x"//dc:title/text()"s)
      title_revoked = String.contains?(String.upcase(title), "REVOKED") or
                      String.contains?(String.upcase(title), "REPEALED")

      # Check for ukm:RepealedLaw element
      repealed_law = SweetXml.xpath(xml, ~x"//ukm:RepealedLaw"o)
      has_repealed_element = repealed_law != nil

      # Get revocation dates
      dct_valid = xpath_text(xml, ~x"//dct:valid/text()"s)
      restrict_start_date = xpath_text(xml, ~x"//Legislation/@RestrictStartDate"s)

      # Get laws that revoke/repeal this one
      revoked_by =
        SweetXml.xpath(xml, ~x"//ukm:SupersededBy/ukm:Citation"l)
        |> Enum.map(fn citation ->
          uri = SweetXml.xpath(citation, ~x"./@URI"s) |> to_string()
          cit_title = SweetXml.xpath(citation, ~x"./@Title"s) |> to_string()
          %{uri: uri, title: cit_title, name: uri_to_name(uri)}
        end)
        |> Enum.reject(fn %{uri: uri} -> uri == "" end)

      # Determine revocation status
      # Full revocation: title explicitly says REVOKED/REPEALED or RepealedLaw element exists
      is_fully_revoked = title_revoked or has_repealed_element

      # Partial revocation: has revoking laws but not fully revoked
      # This means some provisions are revoked but the law is still partially in force
      is_partially_revoked = not is_fully_revoked and length(revoked_by) > 0

      # Build live status and description
      {live, live_description} = build_live_status(is_fully_revoked, is_partially_revoked, revoked_by)

      %{
        # Fields for modal display
        live: live,
        live_description: live_description,
        # Raw revocation data
        revoked: is_fully_revoked,
        partially_revoked: is_partially_revoked,
        revoked_title_marker: title_revoked,
        revoked_element: has_repealed_element,
        revoked_by: revoked_by,
        rescinded_by: format_revoked_by(revoked_by),
        dct_valid: parse_date(dct_valid),
        restrict_start_date: parse_date(restrict_start_date)
      }
    rescue
      e ->
        %{live: @live_in_force, live_description: "", revoked: false, repeal_revoke_error: "Parse error: #{inspect(e)}"}
    end
  end

  # In force - no revocations
  defp build_live_status(false, false, _revoked_by), do: {@live_in_force, ""}

  # Partial revocation - some provisions revoked but law still in force
  defp build_live_status(false, true, revoked_by) do
    names = Enum.map(revoked_by, fn %{name: name, title: title} ->
      if title != "", do: "#{name} (#{title})", else: name
    end)
    description = "Partially revoked by: " <> Enum.join(names, ", ")
    {@live_part_revoked, description}
  end

  # Full revocation - no details
  defp build_live_status(true, _partial, []) do
    {@live_revoked, "Revoked/Repealed"}
  end

  # Full revocation - with revoking law details
  defp build_live_status(true, _partial, revoked_by) do
    names = Enum.map(revoked_by, fn %{name: name, title: title} ->
      if title != "", do: "#{name} (#{title})", else: name
    end)
    description = "Revoked by: " <> Enum.join(names, ", ")
    {@live_revoked, description}
  end

  defp format_revoked_by([]), do: nil
  defp format_revoked_by(revoked_by) do
    Enum.map(revoked_by, fn %{name: name} -> name end)
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(date), do: date

  # ============================================================================
  # Helpers
  # ============================================================================

  defp uri_to_name(nil), do: nil
  defp uri_to_name(""), do: nil

  defp uri_to_name(uri) do
    # Convert URI like "http://www.legislation.gov.uk/id/uksi/2020/1234"
    # to name like "uksi/2020/1234"
    uri
    |> String.replace(~r"^https?://www\.legislation\.gov\.uk/id/", "")
    |> String.replace(~r"^https?://www\.legislation\.gov\.uk/", "")
  end

  defp xpath_text(xml, path) do
    case SweetXml.xpath(xml, path) do
      nil -> ""
      "" -> ""
      value when is_binary(value) -> String.trim(value)
      value -> to_string(value) |> String.trim()
    end
  end

  # ============================================================================
  # Amendment Per-Law String Builders
  # ============================================================================
  #
  # Builds the *_count_per_law summary and detailed strings from amendment lists.
  # These match the format imported from Airtable CSV exports.
  #
  # Summary format:   "UK_uksi_2020_100 - 3\nUK_uksi_2019_50 - 2"
  # Detailed format:  "UK_uksi_2020_100 - 3\n  reg. 1, reg. 2, reg. 3\nUK_uksi_2019_50 - 2\n  reg. 4"

  defp build_count_per_law_summary([]), do: nil
  defp build_count_per_law_summary(amendments) do
    amendments
    |> group_amendments_by_law()
    |> Enum.map(fn {law_name, items} ->
      "#{law_name} - #{length(items)}"
    end)
    |> Enum.join("\n")
  end

  defp build_count_per_law_detailed([]), do: nil
  defp build_count_per_law_detailed(amendments) do
    amendments
    |> group_amendments_by_law()
    |> Enum.map(fn {law_name, items} ->
      sections = items
                 |> Enum.map(& &1.target)
                 |> Enum.reject(&is_nil/1)
                 |> Enum.reject(&(&1 == ""))
                 |> Enum.uniq()
                 |> Enum.sort()

      count_line = "#{law_name} - #{length(items)}"
      if sections == [] do
        count_line
      else
        section_line = "  " <> Enum.join(sections, ", ")
        "#{count_line}\n#{section_line}"
      end
    end)
    |> Enum.join("\n")
  end

  defp group_amendments_by_law(amendments) do
    amendments
    |> Enum.group_by(& &1.name)
    |> Enum.sort_by(fn {_name, items} -> -length(items) end)
  end
end
