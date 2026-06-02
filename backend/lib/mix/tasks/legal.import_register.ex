NimbleCSV.define(SertantaiLegal.ImportCSV, separator: ",", escape: "\"")

defmodule Mix.Tasks.Legal.ImportRegister do
  @shortdoc "Import a legacy legal register CSV, infer type codes, match against LRT"

  @moduledoc """
  Generic import tool for legacy legal register CSVs (Enhesa, Nimonik, etc.).

  Parses the CSV, infers UK law type codes from titles, matches against uk_lrt
  using the unique key (type_code + year + number), and groups results into
  matched / scrapeable / not_handled.

  ## Usage

      mix legal.import_register <csv_path> --customer <slug> --site <slug> [options]

  ## Options

    * `--customer SLUG` — Customer identifier (required)
    * `--site SLUG` — Site identifier (required)
    * `--vendor enhesa` — Vendor format hint (default: enhesa)
    * `--dry-run` — Parse and infer only, skip matching against DB
    * `--create-scrape-session` — Create a scrape session for scrapeable laws
    * `--qa` — Post-scrape QA: compare vendor titles against LRT titles for matched laws
    * `--qa-group 1|2` — QA only laws from a specific scrape session group (1=UK domestic, 2=EU retained)
    * `--status-report` — Generate status-report.json with live/revoked breakdown for customer
    * `--output-dir DIR` — Override output directory

  ## Examples

      mix legal.import_register backend/data/en_UKD_-_B_Regulation_Questions.csv --customer qq --site bsc
      mix legal.import_register backend/data/en_UKD_-_B_Regulation_Questions.csv --customer qq --site bsc --create-scrape-session
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, rest} =
      OptionParser.parse!(args,
        strict: [
          customer: :string,
          site: :string,
          vendor: :string,
          dry_run: :boolean,
          create_scrape_session: :boolean,
          qa: :boolean,
          qa_group: :string,
          status_report: :boolean,
          output_dir: :string
        ]
      )

    csv_path = List.first(rest) || Mix.raise("CSV file path required")
    customer = opts[:customer] || Mix.raise("--customer required")
    site = opts[:site] || Mix.raise("--site required")
    vendor = opts[:vendor] || "enhesa"

    unless File.exists?(csv_path) do
      Mix.raise("CSV file not found: #{csv_path}")
    end

    output_dir = opts[:output_dir] || Path.join(["data/imports", customer, site])
    File.mkdir_p!(output_dir)

    # Copy source CSV for audit trail
    File.cp!(csv_path, Path.join(output_dir, "source.csv"))

    Mix.shell().info("Importing #{vendor} register for #{customer}/#{site}")
    Mix.shell().info("Source: #{csv_path}")

    # Step 1: Extract + infer type codes
    rows = extract(csv_path, vendor)
    Mix.shell().info("Extracted #{length(rows)} rows")

    print_extraction_stats(rows)

    # Write extracted.json
    extracted_path = Path.join(output_dir, "extracted.json")
    File.write!(extracted_path, Jason.encode!(rows, pretty: true))
    Mix.shell().info("\nWrote #{extracted_path}")

    unless opts[:dry_run] do
      # Step 2+3: Match against LRT and group
      grouped = match_and_group(rows)

      print_match_stats(grouped)

      # Write matched.json
      matched_path = Path.join(output_dir, "matched.json")
      File.write!(matched_path, Jason.encode!(grouped, pretty: true))
      Mix.shell().info("\nWrote #{matched_path}")

      # Step 4: Post-scrape QA — compare titles
      if opts[:qa] || opts[:qa_group] do
        run_title_qa(grouped, rows, opts[:qa_group])
      end

      # Step 5: Status report — live/revoked breakdown for customer
      if opts[:status_report] do
        generate_status_report(grouped, customer, site, output_dir)
      end

      # Step 6: Create scrape session for scrapeable laws
      if opts[:create_scrape_session] do
        create_scrape_session(grouped, customer, site)
      end
    end
  end

  # --- Step 1: Extract + Infer Type Code ---

  defp extract(csv_path, "enhesa") do
    # Read file, strip BOM if present
    content =
      csv_path
      |> File.read!()
      |> String.replace_prefix("\uFEFF", "")

    [header_line | data_lines] = String.split(content, ~r/\r?\n/, trim: true)

    # Parse header to get column indices
    [headers] = SertantaiLegal.ImportCSV.parse_string(header_line <> "\n", skip_headers: false)
    headers = Enum.map(headers, &String.trim/1)

    col = fn name -> Enum.find_index(headers, &(&1 == name)) end
    id_idx = col.("Regulation Id")
    title_idx = col.("Regulation Title")
    jurisdiction_idx = col.("Jurisdiction")
    region_idx = col.("Region")
    answer_idx = col.("Answer")

    data_lines
    |> Enum.join("\n")
    |> Kernel.<>("\n")
    |> SertantaiLegal.ImportCSV.parse_string(skip_headers: false)
    |> Enum.map(fn fields ->
      extract_enhesa_row(fields, id_idx, title_idx, jurisdiction_idx, region_idx, answer_idx)
    end)
  end

  defp extract(_csv_path, vendor), do: Mix.raise("Unknown vendor: #{vendor}")

  defp extract_enhesa_row(fields, id_idx, title_idx, jurisdiction_idx, region_idx, answer_idx) do
    at = fn idx -> if idx, do: Enum.at(fields, idx, "") |> String.trim(), else: "" end

    vendor_id = at.(id_idx)
    title = at.(title_idx)
    answer = at.(answer_idx)

    {type_code, year, number} = infer_identity(title)

    %{
      vendor_id: vendor_id,
      title: title,
      type_code: type_code,
      year: year,
      number: number,
      lrt_name: build_lrt_name(type_code, year, number),
      answer: answer,
      jurisdiction: at.(jurisdiction_idx),
      region: at.(region_idx)
    }
  end

  defp build_lrt_name(type_code, year, number)
       when is_binary(type_code) and not is_nil(year) and not is_nil(number) do
    "UK_#{type_code}_#{year}_#{number}"
  end

  defp build_lrt_name(_, _, _), do: nil

  @doc """
  Infer type_code, year, and number from a law title.

  Returns `{type_code, year, number}` where any element may be nil.
  """
  def infer_identity(title) do
    cond do
      # ACOPs and guidance documents — not legislation
      acop?(title) ->
        {"acop", nil, nil}

      # International conventions — not scrapeable
      international?(title) ->
        {"intl", nil, nil}

      # --- EU Laws ---
      # CRITICAL: Determine type from the title PREFIX (what the law IS),
      # then extract its OWN reference — never a parent/amended law ref later in the title.
      # e.g. "Commission Regulation EC/748/2009 amending Directive 2003/87/EC"
      #       → eur/2009/748 (the Regulation), NOT eudr/2003/87 (the amended Directive)
      (result = infer_eu_identity(title)) != nil ->
        result

      # --- UK Public General Acts (must come before SI patterns) ---
      # Vendor-supplied chapter/SI numbers on Acts are UNRELIABLE across all formats:
      # (S.I.NN), (c.NN), (Ch.NN), (Chapter NN), "c.NN" inline — all can be wrong.
      # ALWAYS extract year only, match by title in the matching phase.
      # Covers: "Act YYYY (S.I.NN)", "Act YYYY (c.NN)", "Act YYYY (Ch.NN)",
      #         "Act YYYY, YYYY c.NN", "Act YYYY (c. N of YYYY)", plain "Act YYYY"
      match = Regex.run(~r/Act\s+(\d{4})\b/, title) ->
        [_, year] = match
        {"ukpga", parse_int(year), nil}

      # --- UK Statutory Instruments ---

      # "S.I.YYYY/NNN" format — most explicit, check first
      match = Regex.run(~r/S\.I\.?\s*(\d{4})\/(\d+)/, title) ->
        [_, year, number] = match
        {"uksi", parse_int(year), number}

      # "SI 2015/399" format
      match = Regex.run(~r/\bSI\s+(\d{4})\/(\d+)/, title) ->
        [_, year, number] = match
        {"uksi", parse_int(year), number}

      # "S.I. YYYY No. NNNN" — year then "No." then number inside the S.I. ref
      # e.g. "...Regulations 2010 (S.I. 2010 No. 1554)" → year=2010, number=1554
      match = Regex.run(~r/S\.I\.?\s*(\d{4})\s+No\.?\s*(\d+)/, title) ->
        [_, year, number] = match
        {"uksi", parse_int(year), number}

      # "... YYYY (S.I. NNN)" — year IMMEDIATELY before the S.I. ref
      # CRITICAL: Use the year closest to the SI ref, not the first year in the title.
      # e.g. "Health and Safety at Work etc. Act 1974... Regulations 2013 (S.I. 1667)"
      # must extract year=2013, number=1667 — NOT year=1974
      match = Regex.run(~r/(\d{4})\s*\(S\.I\.?\s*(?:No\.?\s*)?(\d+)\)/, title) ->
        [_, year, number] = match
        {"uksi", parse_int(year), number}

      # "S.I. No. NNN" (no year inside the ref) — take the LAST 4-digit year in the title
      match = Regex.run(~r/S\.I\.?\s*No\.?\s*(\d+)/, title) ->
        [_, number] = match
        year = extract_last_year(title)
        {"uksi", year, number}

      # Bare "S.I. NNN" — number only, no year or No. prefix
      match = Regex.run(~r/S\.I\.?\s*(\d+)/, title) ->
        [_, number] = match
        year = extract_last_year(title)
        {"uksi", year, number}

      # "(YYYY No. NNN)" format — common in Enhesa for SIs without "S.I." prefix
      match = Regex.run(~r/\((\d{4})\s+No\.\s*(\d+)\)/, title) ->
        [_, year, number] = match
        {"uksi", parse_int(year), number}

      # Regulations/Rules/Order without SI number — still uksi, just no number
      match = Regex.run(~r/Regulations?\s+(\d{4})\b/, title) ->
        [_, year] = match
        {"uksi", parse_int(year), nil}

      match = Regex.run(~r/Rules?\s+(\d{4})\b/, title) ->
        [_, year] = match
        {"uksi", parse_int(year), nil}

      match = Regex.run(~r/Order\s+(\d{4})\b/, title) ->
        [_, year] = match
        {"uksi", parse_int(year), nil}

      match = Regex.run(~r/Directions?\s+(\d{4})\b/, title) ->
        [_, year] = match
        {"uksi", parse_int(year), nil}

      # Catch remaining with a year
      match = Regex.run(~r/\b(1\d{3}|20\d{2})\b/, title) ->
        [_, year] = match
        {"unknown", parse_int(year), nil}

      # Nothing identifiable
      true ->
        {"unknown", nil, nil}
    end
  end

  # --- EU Identity Extraction ---
  # Determines EU law type from the title prefix, then extracts the FIRST
  # number/year reference. Returns {type_code, year, number} or nil.

  defp infer_eu_identity(title) do
    # Determine the EU law type from what the title STARTS with
    type_code =
      cond do
        Regex.match?(~r/^(?:Council\s+)?Directive\b/i, title) ->
          "eudr"

        Regex.match?(~r/^Commission\s+Directive\b/i, title) ->
          "eudr"

        Regex.match?(~r/^(?:European\s+Parliament\s+and\s+)?Council\s+Directive\b/i, title) ->
          "eudr"

        Regex.match?(~r/^(?:Commission\s+)?(?:Implementing\s+|Delegated\s+)?Regulation\b/i, title) ->
          "eur"

        Regex.match?(~r/^Council\s+Regulation\b/i, title) ->
          "eur"

        Regex.match?(~r/^Regulation\b/i, title) ->
          "eur"

        Regex.match?(~r/^(?:Commission\s+)?(?:Implementing\s+)?Decision\b/i, title) ->
          "eudn"

        Regex.match?(~r/^Decision\b/i, title) ->
          "eudn"

        true ->
          nil
      end

    if type_code do
      extract_first_eu_ref(title, type_code)
    else
      nil
    end
  end

  # Extract the EU law reference from the FIRST occurrence in the title.
  # Uses Regex.scan to find ALL EU-style A/B number pairs, takes the first,
  # then disambiguates which is year vs number.
  defp extract_first_eu_ref(title, type_code) do
    # Find all EU-style references: any pattern like "EC/A/B", "(EU) A/B", "A/B/EEC", "EU/A/B"
    # We extract raw pairs and disambiguate year vs number afterwards.
    patterns = [
      # "EU/A/B" — modern convention: year/number
      {~r/EU\/(\d+)\/(\d+)/i, :year_number},
      # "EC/A/B" — old convention: number/year
      {~r/EC\/(\d+)\/(\d+)/i, :number_year},
      # "(EU) A/B" or "(EC) A/B" — typically year/number
      {~r/\(E[CU]\)\s+(\d+)\/(\d+)/i, :year_number},
      # "(EU) No A/B" or "(EC) No A/B" — typically number/year
      {~r/\(E[CU]\)\s+No\.?\s+(\d+)\/(\d+)/i, :disambiguate},
      # "A/B/EEC" or "A/B/EC" or "A/B/EU" — typically year/number/suffix
      {~r/(\d{2,4})\/(\d+)\/(?:E[EU]?C|EU|EEC|Euratom)/i, :year_number},
      # "(EEC) A/B" or "(EEC) No A/B"
      {~r/\(EEC\)\s+(?:No\.?\s+)?(\d+)\/(\d+)/i, :disambiguate}
    ]

    # Try each pattern, take the first match
    Enum.find_value(patterns, fn {regex, mode} ->
      case Regex.run(regex, title) do
        [_, a, b] ->
          {year, number} = disambiguate_eu_ref(parse_int(a), b, mode)
          {type_code, year, number}

        _ ->
          nil
      end
    end)
  end

  # Given two parts of an EU reference (A/B), determine which is year and which is number.
  # EU refs come in two conventions:
  #   EC convention (pre-2015ish): number/year — e.g., EC/1907/2006
  #   EU modern convention: year/number — e.g., (EU) 2015/1011
  defp disambiguate_eu_ref(a, b_str, mode) do
    b = parse_int(b_str)

    case mode do
      :number_year ->
        {expand_year(parse_int(b_str)), to_string(a)}

      :year_number ->
        # Validate that a looks like a year; if not, swap
        if a >= 1900 and a <= Date.utc_today().year + 1 do
          {a, b_str}
        else
          {expand_year(parse_int(b_str)), to_string(a)}
        end

      :disambiguate ->
        # If one looks like a year (1900-2099) and the other doesn't, use that
        current_year = Date.utc_today().year
        a_is_year = a >= 1900 and a <= current_year + 1
        b_is_year = b != nil and b >= 1900 and b <= current_year + 1

        cond do
          a_is_year and not b_is_year -> {a, b_str}
          b_is_year and not a_is_year -> {b, to_string(a)}
          # Both are plausible years — take the first one (matches EU/YYYY/NNN convention)
          a_is_year and b_is_year -> {a, b_str}
          # Neither is a plausible 4-digit year — try 2-digit expansion
          a < 100 -> {expand_year(a), b_str}
          b != nil and b < 100 -> {expand_year(b), to_string(a)}
          true -> {expand_year(a), b_str}
        end
    end
  end

  defp acop?(title) do
    # L-series and EH-series HSE guidance: "(L143)", "(L101)", "EH40"
    # Approved Derogations / ISBN-based docs / Codes of Practice
    # Standalone "Code of Practice" without "Approved" prefix
    # Charging Schemes (not legislation)
    String.contains?(title, "Approved Code of Practice") or
      String.contains?(title, "Code of Practice and Guidance") or
      String.contains?(title, "Workplace Exposure Limits") or
      Regex.match?(~r/\(L\d+\)/, title) or
      Regex.match?(~r/\bEH\d+\b/, title) or
      Regex.match?(~r/\bISBN\b/, title) or
      String.contains?(title, "Approved Derogations") or
      (String.contains?(title, "Code of Practice") and not String.contains?(title, "Directive")) or
      String.contains?(title, "Charging Scheme")
  end

  defp international?(title) do
    String.starts_with?(title, "European Agreement") or
      String.starts_with?(title, "International Convention") or
      String.starts_with?(title, "International Civil Aviation") or
      String.starts_with?(title, "International Maritime") or
      String.starts_with?(title, "UN Recommendations on the Transport") or
      String.contains?(title, "ADR 20") or
      String.contains?(title, "RID 20") or
      String.contains?(title, "ICAO") or
      String.contains?(title, "IMDG Code")
  end

  defp clean_vendor_title(title) do
    title
    |> String.replace(~r/^The\s+/i, "")
    |> String.replace(~r/\s*\(S\.I\.?\s*(?:No\.?\s*)?\d+\)\s*/, "")
    |> String.replace(~r/\s*\(c\.\s*\d+\)\s*/, "")
    |> String.replace(~r/\s*\(Ch\.\s*\d+\)\s*/, "")
    |> String.replace(~r/,\s*S\.I\.\s*\d+\/\d+/, "")
    |> String.replace(~r/\s+\d{4}\s*$/, "")
    |> String.replace("'", "''")
    |> String.replace("´", "'")
    |> String.trim()
  end

  defp extract_last_year(title) do
    case Regex.scan(~r/\b(1\d{3}|20\d{2})\b/, title) do
      [] -> nil
      matches -> matches |> List.last() |> hd() |> parse_int()
    end
  end

  defp expand_year(year) when is_integer(year) and year < 100 do
    if year > 50, do: 1900 + year, else: 2000 + year
  end

  defp expand_year(year), do: year

  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(_), do: nil

  # --- Step 2+3: Match + Group ---

  defp match_and_group(rows) do
    repo = SertantaiLegal.Repo

    {matched, scrapeable, not_handled} =
      Enum.reduce(rows, {[], [], []}, fn row, {m, s, n} ->
        case row.type_code do
          "acop" ->
            {m, s, [Map.put(row, :match_status, :not_handled) | n]}

          "intl" ->
            {m, s, [Map.put(row, :match_status, :not_handled) | n]}

          "unknown" ->
            {m, s, [Map.put(row, :match_status, :unknown) | n]}

          type_code when is_binary(type_code) ->
            case find_in_lrt(repo, row) do
              {:ok, lrt} ->
                enriched =
                  row
                  |> Map.put(:match_status, :matched)
                  |> Map.put(:lrt_id, lrt.id)
                  |> Map.put(:lrt_name, lrt.name)
                  |> Map.put(:family, lrt.family)

                {[enriched | m], s, n}

              :not_found ->
                {m, [Map.put(row, :match_status, :scrapeable) | s], n}
            end
        end
      end)

    %{
      matched: Enum.reverse(matched),
      scrapeable: Enum.reverse(scrapeable),
      not_handled: Enum.reverse(not_handled),
      stats: %{
        total: length(rows),
        matched: length(matched),
        scrapeable: length(scrapeable),
        not_handled: length(not_handled)
      }
    }
  end

  defp find_in_lrt(repo, %{lrt_name: name}) when is_binary(name) do
    # Primary: exact match on name (type_code + year + number)
    case repo.query("SELECT id::text, name, family FROM uk_lrt WHERE name = $1 LIMIT 1", [name]) do
      {:ok, %{rows: [[id, name, family] | _]}} ->
        {:ok, %{id: id, name: name, family: family}}

      _ ->
        :not_found
    end
  end

  defp find_in_lrt(repo, %{type_code: type_code, year: year, title: title})
       when not is_nil(year) do
    # Fallback for laws without number (e.g. Acts without chapter number).
    # Use title matching — clean the vendor title and search by type_code + year + title_en.
    clean = clean_vendor_title(title)
    prefix = "UK_#{type_code}_#{year}_%"

    case repo.query(
           "SELECT id::text, name, family FROM uk_lrt WHERE name LIKE $1 AND title_en ILIKE $2 LIMIT 1",
           [prefix, "%#{clean}%"]
         ) do
      {:ok, %{rows: [[id, name, family] | _]}} ->
        {:ok, %{id: id, name: name, family: family}}

      _ ->
        # Last resort: type_code + year without title (may be ambiguous)
        case repo.query("SELECT id::text, name, family FROM uk_lrt WHERE name LIKE $1 LIMIT 1", [
               prefix
             ]) do
          {:ok, %{rows: [[id, name, family] | _]}} ->
            {:ok, %{id: id, name: name, family: family}}

          _ ->
            :not_found
        end
    end
  end

  defp find_in_lrt(_, _), do: :not_found

  # --- Step 4: Post-Scrape QA ---

  @uk_domestic_types ["uksi", "ukpga"]
  @eu_types ["eur", "eudr", "eudn"]

  defp run_title_qa(%{matched: matched}, rows, qa_group) do
    repo = SertantaiLegal.Repo

    # Filter by group if specified
    {filtered, group_label} =
      case qa_group do
        "1" ->
          laws = Enum.filter(matched, &(&1.type_code in @uk_domestic_types))
          {laws, "Group 1 (UK domestic)"}

        "2" ->
          laws = Enum.filter(matched, &(&1.type_code in @eu_types))
          {laws, "Group 2 (EU retained)"}

        _ ->
          {matched, "All matched"}
      end

    # Build lookup from extracted rows: lrt_name → vendor title
    vendor_titles =
      rows
      |> Enum.filter(& &1.lrt_name)
      |> Map.new(fn r -> {r.lrt_name, r.title} end)

    Mix.shell().info("\n=== POST-SCRAPE QA: Title Comparison [#{group_label}] ===")

    {good, mismatches} =
      Enum.reduce(filtered, {0, []}, fn row, {g, m} ->
        vendor_title = vendor_titles[row.lrt_name] || ""
        lrt_title = fetch_lrt_title(repo, row.lrt_name)

        cond do
          lrt_title == nil or lrt_title == "" ->
            {g, [{row.lrt_name, vendor_title, "(empty/missing)", :empty} | m]}

          titles_match?(vendor_title, lrt_title) ->
            {g + 1, m}

          true ->
            {g, [{row.lrt_name, vendor_title, lrt_title, :mismatch} | m]}
        end
      end)

    Mix.shell().info("Laws checked: #{length(filtered)}")
    Mix.shell().info("Titles agree: #{good}")
    Mix.shell().info("Mismatches: #{length(mismatches)}")

    if mismatches != [] do
      Mix.shell().info("")

      mismatches
      |> Enum.reverse()
      |> Enum.each(fn {name, vendor, lrt, reason} ->
        label = if reason == :empty, do: "EMPTY", else: "MISMATCH"
        Mix.shell().info("  #{label}: #{name}")
        Mix.shell().info("    Vendor:  #{String.slice(vendor, 0, 100)}")
        Mix.shell().info("    LRT:     #{String.slice(lrt, 0, 100)}")
        Mix.shell().info("")
      end)
    end
  end

  defp fetch_lrt_title(repo, name) do
    case repo.query("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [name]) do
      {:ok, %{rows: [[title] | _]}} -> title
      _ -> nil
    end
  end

  defp titles_match?(vendor, lrt) when is_binary(vendor) and is_binary(lrt) do
    v = clean_title(vendor)
    l = clean_title(lrt)
    v == l or String.contains?(v, l) or String.contains?(l, v)
  end

  defp titles_match?(_, _), do: false

  defp clean_title(title) do
    title
    |> String.replace(~r/^The\s+/i, "")
    |> String.replace(~r/\s*\(S\.I\.?\s*(?:No\.?\s*)?\d+\)\s*/, "")
    |> String.replace(~r/\s*\(c\.\s*\d+\)\s*/, "")
    |> String.replace(~r/\s*\(Ch\.\s*\d+\)\s*/, "")
    |> String.replace(~r/,\s*S\.I\.\s*\d+\/\d+/, "")
    |> String.replace(~r/\s+\d{4}\s*$/, "")
    # Normalize EU citation format: "EC/NNN/YYYY" → "(EC) No NNN/YYYY"
    |> String.replace(~r/\bEC\/(\d+)\/(\d{4})/, "(EC) No \\1/\\2")
    |> String.replace(~r/\bEU\/(\d+)\/(\d{4})/, "(EU) No \\1/\\2")
    |> String.replace(~r/\bEU\/(\d{4})\/(\d+)/, "(EU) \\1/\\2")
    |> String.replace(~r/\bEC\/(\d{4})\/(\d+)/, "(EC) \\1/\\2")
    # Normalize "(EC) No" vs "(EC) No." vs "(EC)"
    |> String.replace(~r/\(E[CU]\)\s+No\.?\s+/, "(EC) ")
    # Normalize "of the European Parliament and of the Council" vs "of the European Parliament and the Council"
    |> String.replace("and of the council", "and the council")
    # Normalize "Council Directive of DD Month YYYY" vs "Council Directive YYYY/NNN/EEC of"
    # Strip the directive reference number from the title for comparison
    |> String.replace(~r/\b\d{2,4}\/\d+\/(?:EEC|EC|EU|Euratom)\b/, "")
    |> String.replace(~r/\(\d{2,4}\/\d+\/(?:EEC|EC|EU)\)/, "")
    # Normalize unicode apostrophes and dashes
    |> String.replace("´", "'")
    |> String.replace("\u2011", "-")
    |> String.replace("\u2013", "-")
    |> String.replace("\u2014", "-")
    # Normalize whitespace
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.downcase()
  end

  # --- Step 5: Status Report ---

  defp generate_status_report(
         %{matched: matched, scrapeable: scrapeable, not_handled: not_handled},
         customer,
         site,
         output_dir
       ) do
    repo = SertantaiLegal.Repo

    # Fetch live status for all matched laws
    live_lookup =
      matched
      |> Enum.filter(& &1.lrt_name)
      |> Enum.map(& &1.lrt_name)
      |> Enum.uniq()
      |> Enum.chunk_every(500)
      |> Enum.flat_map(fn chunk ->
        placeholders =
          chunk |> Enum.with_index(1) |> Enum.map(fn {_, i} -> "$#{i}" end) |> Enum.join(",")

        sql = "SELECT name, live FROM uk_lrt WHERE name IN (#{placeholders})"

        case repo.query(sql, chunk) do
          {:ok, %{rows: rows}} -> rows
          _ -> []
        end
      end)
      |> Map.new(fn [name, live] -> {name, live} end)

    # Classify matched laws by status
    {in_force, part_revoked, revoked, unknown_status} =
      Enum.reduce(matched, {[], [], [], []}, fn r, {inf, pr, rev, unk} ->
        live = live_lookup[r.lrt_name]

        entry = %{
          lrt_name: r.lrt_name,
          title: r.title,
          family: r[:family],
          answer: r.answer,
          live_status: live
        }

        cond do
          is_binary(live) and String.contains?(live, "In force") ->
            {[entry | inf], pr, rev, unk}

          is_binary(live) and String.contains?(live, "Part") ->
            {inf, [entry | pr], rev, unk}

          is_binary(live) and
              (String.contains?(live, "Revoked") or String.contains?(live, "Repealed") or
                 String.contains?(live, "Abolished")) ->
            {inf, pr, [entry | rev], unk}

          true ->
            {inf, pr, rev, [entry | unk]}
        end
      end)

    revoked_but_yes = Enum.filter(revoked, &(&1.answer == "Yes"))

    report = %{
      customer: customer,
      site: site,
      generated: Date.utc_today() |> Date.to_iso8601(),
      summary: %{
        total_matched: length(matched),
        in_force: length(in_force),
        part_revoked: length(part_revoked),
        revoked: length(revoked),
        unknown_status: length(unknown_status),
        revoked_but_applicable: length(revoked_but_yes),
        scrapeable_not_yet_matched: length(scrapeable),
        not_handled: length(not_handled)
      },
      revoked_but_applicable: Enum.reverse(revoked_but_yes),
      revoked: Enum.reverse(revoked),
      part_revoked: Enum.reverse(part_revoked),
      in_force: Enum.reverse(in_force),
      unknown_status: Enum.reverse(unknown_status)
    }

    path = Path.join(output_dir, "status-report.json")
    File.write!(path, Jason.encode!(report, pretty: true))

    Mix.shell().info("\n=== STATUS REPORT ===")
    Mix.shell().info("In force:        #{length(in_force)}")
    Mix.shell().info("Part revoked:    #{length(part_revoked)}")
    Mix.shell().info("Revoked:         #{length(revoked)}")
    Mix.shell().info("Unknown status:  #{length(unknown_status)}")

    if revoked_but_yes != [] do
      Mix.shell().info("\n⚠  REVOKED BUT ANSWER=YES (customer tracking dead law):")

      Enum.each(revoked_but_yes, fn e ->
        Mix.shell().info("  #{e.lrt_name}")
        Mix.shell().info("    #{String.slice(e.title, 0, 100)}")
        Mix.shell().info("    Family: #{e.family || "(none)"}")
        Mix.shell().info("")
      end)
    end

    Mix.shell().info("Wrote #{path}")
  end

  # --- Step 6: Create Scrape Session ---

  alias SertantaiLegal.Scraper.{ScrapeSession, ScrapeSessionRecord}

  defp create_scrape_session(%{scrapeable: scrapeable}, customer, site) do
    # Only include laws with a full lrt_name (type_code + year + number)
    with_name = Enum.filter(scrapeable, & &1.lrt_name)
    skipped = length(scrapeable) - length(with_name)

    if with_name == [] do
      Mix.shell().info("\nNo scrapeable laws with full identifiers — skipping scrape session")
      return_val()
    end

    session_id = "import-#{customer}-#{site}"
    today = Date.utc_today()

    Mix.shell().info("\n=== CREATING SCRAPE SESSION ===")
    Mix.shell().info("Session ID: #{session_id}")
    Mix.shell().info("Laws to add: #{length(with_name)}")

    if skipped > 0 do
      Mix.shell().info("Skipped (no number): #{skipped}")
    end

    # Create or find existing session
    require Ash.Query

    session =
      case ScrapeSession
           |> Ash.Query.filter(session_id == ^session_id)
           |> Ash.read_one() do
        {:ok, nil} ->
          {:ok, session} =
            Ash.create(
              ScrapeSession,
              %{
                session_id: session_id,
                year: today.year,
                month: today.month,
                day_from: today.day,
                day_to: today.day,
                session_type: "import",
                status: :pending
              },
              action: :create
            )

          Mix.shell().info("Created new scrape session")
          session

        {:ok, existing} ->
          Mix.shell().info("Using existing scrape session (#{existing.status})")
          existing
      end

    # Group scrapeable laws by type_code for scrape session groups:
    # group1 = UK domestic (uksi, ukpga) — scrapeable from legislation.gov.uk
    # group2 = EU retained (eur, eudr, eudn) — scrapeable from legislation.gov.uk/eu
    {created, _errors} =
      with_name
      |> Enum.reduce({0, 0}, fn row, {ok, err} ->
        group = if row.type_code in ["uksi", "ukpga"], do: :group1, else: :group2

        case Ash.create(
               ScrapeSessionRecord,
               %{
                 session_id: session_id,
                 law_name: row.lrt_name,
                 group: group,
                 status: :pending,
                 parsed_data: %{
                   "vendor_id" => row.vendor_id,
                   "title" => row.title,
                   "type_code" => row.type_code,
                   "year" => row.year,
                   "number" => row.number,
                   "answer" => row.answer
                 }
               },
               action: :create
             ) do
          {:ok, _} -> {ok + 1, err}
          {:error, _} -> {ok, err + 1}
        end
      end)

    # Count actual records after dedup (upsert may collapse duplicates)
    {:ok, %{rows: [[g1_count]]}} =
      SertantaiLegal.Repo.query(
        "SELECT COUNT(*) FROM scrape_session_records WHERE session_id = $1 AND \"group\" = 'group1'",
        [session_id]
      )

    {:ok, %{rows: [[g2_count]]}} =
      SertantaiLegal.Repo.query(
        "SELECT COUNT(*) FROM scrape_session_records WHERE session_id = $1 AND \"group\" = 'group2'",
        [session_id]
      )

    # Update session with actual counts and mark as categorized
    {:ok, _} =
      Ash.update(
        session,
        %{
          group1_count: g1_count,
          group2_count: g2_count,
          group3_count: 0,
          title_excluded_count: skipped
        },
        action: :mark_categorized
      )

    Mix.shell().info(
      "Records created: #{g1_count + g2_count} (#{created - g1_count - g2_count} duplicates collapsed)"
    )

    Mix.shell().info("  Group 1 (UK domestic): #{g1_count}")
    Mix.shell().info("  Group 2 (EU retained): #{g2_count}")

    Mix.shell().info(
      "\nScrape session ready for review at: http://localhost:5175/admin/scrape/sessions"
    )
  end

  defp return_val, do: :ok

  # --- Reporting ---

  defp print_extraction_stats(rows) do
    by_type = Enum.frequencies_by(rows, & &1.type_code)
    with_name = Enum.count(rows, & &1.lrt_name)

    Mix.shell().info("\nType code inference:")

    by_type
    |> Enum.sort_by(fn {_, c} -> -c end)
    |> Enum.each(fn {type, count} ->
      Mix.shell().info("  #{String.pad_trailing(type || "nil", 10)} #{count}")
    end)

    Mix.shell().info("\nWith full LRT name (type+year+number): #{with_name}/#{length(rows)}")

    by_answer = Enum.frequencies_by(rows, & &1.answer)
    Mix.shell().info("\nAnswer distribution:")

    by_answer
    |> Enum.sort_by(fn {_, c} -> -c end)
    |> Enum.each(fn {answer, count} ->
      label = if answer == "", do: "(blank)", else: answer
      Mix.shell().info("  #{String.pad_trailing(label, 10)} #{count}")
    end)
  end

  defp print_match_stats(%{stats: stats} = grouped) do
    Mix.shell().info("\n=== MATCHING RESULTS ===")
    Mix.shell().info("Total:       #{stats.total}")
    Mix.shell().info("Matched:     #{stats.matched}")
    Mix.shell().info("Scrapeable:  #{stats.scrapeable}")
    Mix.shell().info("Not handled: #{stats.not_handled}")

    # Family summary of matched laws
    if stats.matched > 0 do
      families =
        grouped.matched
        |> Enum.frequencies_by(& &1.family)
        |> Enum.sort_by(fn {_, c} -> -c end)

      Mix.shell().info("\nMatched law families:")

      Enum.each(families, fn {family, count} ->
        label = family || "(no family)"
        Mix.shell().info("  #{String.pad_trailing(label, 50)} #{count}")
      end)
    end

    # Scrapeable type breakdown
    if stats.scrapeable > 0 do
      by_type = Enum.frequencies_by(grouped.scrapeable, & &1.type_code)
      Mix.shell().info("\nScrapeable by type:")

      Enum.each(by_type, fn {type, count} ->
        Mix.shell().info("  #{String.pad_trailing(type, 10)} #{count}")
      end)
    end

    # Not handled breakdown
    if stats.not_handled > 0 do
      by_type = Enum.frequencies_by(grouped.not_handled, & &1.type_code)
      Mix.shell().info("\nNot handled by type:")

      Enum.each(by_type, fn {type, count} ->
        Mix.shell().info("  #{String.pad_trailing(type, 10)} #{count}")
      end)
    end
  end
end
