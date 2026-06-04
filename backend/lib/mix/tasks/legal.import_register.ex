NimbleCSV.define(SertantaiLegal.ImportCSV, separator: ",", escape: "\"")

defmodule Mix.Tasks.Legal.ImportRegister do
  @shortdoc "Import a legacy legal register CSV — extract, transform, match, QA"

  @moduledoc """
  Iterative pipeline for importing customer legacy legal register CSVs.

  ## Pipeline

      source.csv → extracted.json → transformed.json → matched.json

  Each step is a separate flag. Run them in order, review between steps.

  ## Usage

      mix legal.import_register <csv_path> --customer <slug> --site <slug> <step_flags>

  ## Steps

    * `--extract` — Parse vendor CSV → extracted.json (raw rows, no inference)
    * `--transform` — Apply named patterns → transformed.json (iterative, reviewable)
    * `--match` — Look up in LRT → matched.json (matched/scrapeable/not_handled)
    * `--qa` — Post-scrape QA: compare vendor titles against LRT titles
    * `--qa-group 1|2` — QA only group 1 (UK domestic) or group 2 (EU retained)
    * `--status-report` — Generate status-report.json (live/revoked breakdown)
    * `--create-scrape-session` — Create scrape session for scrapeable laws

  ## Options

    * `--customer SLUG` — Customer identifier (required)
    * `--site SLUG` — Site identifier (required)
    * `--vendor enhesa` — Vendor format hint (default: enhesa)

  ## Examples

      # Full pipeline:
      mix legal.import_register data/file.csv --customer qq --site bsc --extract
      # Review extracted.json, then:
      mix legal.import_register data/file.csv --customer qq --site bsc --transform
      # Review transformed.json, then:
      mix legal.import_register data/file.csv --customer qq --site bsc --match
      # QA and status:
      mix legal.import_register data/file.csv --customer qq --site bsc --qa --status-report

      # Or run multiple steps at once:
      mix legal.import_register data/file.csv --customer qq --site bsc --extract --transform --match
  """

  use Mix.Task

  @requirements ["app.start"]

  # --- Transform Rules ---
  # Each rule: {name, description, test_fn, transform_fn}
  # Rules are applied IN ORDER to unresolved rows only.
  # A row is "resolved" when type_code is set to something other than nil.
  # Rules must be specific — better to leave unresolved than guess wrong.

  @transform_rules [
    # --- Not-legislation (mark and skip) ---
    {:acop, "Approved Codes of Practice / HSE guidance", &__MODULE__.match_acop?/1,
     &__MODULE__.mark_acop/1},
    {:intl, "International conventions (ADR, RID, ICAO, IMDG)", &__MODULE__.match_intl?/1,
     &__MODULE__.mark_intl/1},

    # --- Scottish Statutory Instruments (must match BEFORE generic S.I. rules) ---
    {:ssi_explicit, "S.S.I. NNN — Scottish Statutory Instrument", &__MODULE__.match_ssi?/1,
     &__MODULE__.transform_ssi/1},

    # --- UK Statutory Instruments (high confidence — explicit S.I. reference) ---
    {:uksi_si_yyyy_slash_nnn, "S.I. YYYY/NNN — explicit SI with slash",
     &__MODULE__.match_si_yyyy_slash_nnn?/1, &__MODULE__.transform_si_yyyy_slash_nnn/1},
    {:uksi_si_yyyy_no_nnn, "S.I. YYYY No. NNN — SI year then number",
     &__MODULE__.match_si_yyyy_no_nnn?/1, &__MODULE__.transform_si_yyyy_no_nnn/1},
    {:uksi_yyyy_paren_si_nnn, "YYYY (S.I. NNN) — year before parenthesised SI",
     &__MODULE__.match_yyyy_paren_si?/1, &__MODULE__.transform_yyyy_paren_si/1},
    {:uksi_si_nnn_only, "S.I. NNN — SI number with no year in ref, infer from title",
     &__MODULE__.match_si_nnn_only?/1, &__MODULE__.transform_si_nnn_only/1},
    {:uksi_yyyy_no_nnn, "(YYYY No. NNN) — year and number without S.I. prefix",
     &__MODULE__.match_yyyy_no_nnn?/1, &__MODULE__.transform_yyyy_no_nnn/1},
    {:uksi_si_prefix, "SI YYYY/NNN — SI prefix format", &__MODULE__.match_si_prefix?/1,
     &__MODULE__.transform_si_prefix/1},

    # --- UK Acts (year only — vendor numbers unreliable) ---
    {:ukpga, "UK Public General Act — year only, match by title", &__MODULE__.match_act?/1,
     &__MODULE__.transform_act/1},

    # --- UK SIs without S.I. reference (lower confidence) ---
    {:uksi_regs_year, "Regulations/Order/Rules/Directions YYYY — no SI number",
     &__MODULE__.match_regs_year?/1, &__MODULE__.transform_regs_year/1},

    # --- EU Directives (title starts with Directive/Council Directive) ---
    {:eudr_yyyy_nnn_suffix, "Directive YY/NNN/EC|EEC|EU|Euratom",
     &__MODULE__.match_directive_yy_nnn_suffix?/1,
     &__MODULE__.transform_directive_yy_nnn_suffix/1},
    {:eudr_paren_eu_yyyy_nnn, "Directive (EU) YYYY/NNN", &__MODULE__.match_directive_paren_eu?/1,
     &__MODULE__.transform_directive_paren_eu/1},
    {:eudr_eu_slash, "Directive EU/A/B", &__MODULE__.match_directive_eu_slash?/1,
     &__MODULE__.transform_directive_eu_slash/1},

    # --- EU Regulations (title starts with Regulation/Commission/Council Regulation) ---
    {:eur_ec_slash, "Regulation EC/NNN/YYYY — old EC convention (number/year)",
     &__MODULE__.match_regulation_ec_slash?/1, &__MODULE__.transform_regulation_ec_slash/1},
    {:eur_eu_slash, "Regulation EU/A/B — modern EU convention",
     &__MODULE__.match_regulation_eu_slash?/1, &__MODULE__.transform_regulation_eu_slash/1},
    {:eur_paren_eu, "Regulation (EU|EC) [No] A/B", &__MODULE__.match_regulation_paren?/1,
     &__MODULE__.transform_regulation_paren/1},
    {:eur_paren_eec, "Regulation (EEC) NNN/YY", &__MODULE__.match_regulation_eec?/1,
     &__MODULE__.transform_regulation_eec/1},

    # --- EU Decisions ---
    {:eudn_decision, "Decision YYYY/NNN or (EU) YYYY/NNN", &__MODULE__.match_decision?/1,
     &__MODULE__.transform_decision/1}
  ]

  @impl Mix.Task
  def run(args) do
    {opts, rest} =
      OptionParser.parse!(args,
        strict: [
          customer: :string,
          site: :string,
          vendor: :string,
          extract: :boolean,
          transform: :boolean,
          match: :boolean,
          qa: :boolean,
          qa_group: :string,
          status_report: :boolean,
          create_scrape_session: :boolean,
          output_dir: :string
        ]
      )

    csv_path = List.first(rest) || Mix.raise("CSV file path required")
    customer = opts[:customer] || Mix.raise("--customer required")
    site = opts[:site] || Mix.raise("--site required")
    vendor = opts[:vendor] || "enhesa"

    output_dir = opts[:output_dir] || Path.join(["data/imports", customer, site])
    File.mkdir_p!(output_dir)

    # Step 1: Extract
    if opts[:extract] do
      unless File.exists?(csv_path), do: Mix.raise("CSV file not found: #{csv_path}")
      File.cp!(csv_path, Path.join(output_dir, "source.csv"))
      run_extract(csv_path, vendor, output_dir)
    end

    # Step 2: Transform
    if opts[:transform] do
      run_transform(output_dir)
    end

    # Step 3: Match
    if opts[:match] do
      run_match(output_dir)
    end

    # Post-match steps (require matched.json)
    matched_path = Path.join(output_dir, "matched.json")

    if File.exists?(matched_path) do
      if opts[:qa] || opts[:qa_group] do
        transformed = read_json!(Path.join(output_dir, "transformed.json"))
        matched = read_json!(matched_path)
        run_title_qa(matched, transformed, opts[:qa_group])
      end

      if opts[:status_report] do
        matched = read_json!(matched_path)
        generate_status_report(matched, customer, site, output_dir)
      end

      if opts[:create_scrape_session] do
        matched = read_json!(matched_path)
        create_scrape_session(matched, customer, site)
      end
    end
  end

  # ============================================================================
  # Step 1: Extract (vendor-specific CSV parse — no inference)
  # ============================================================================

  defp run_extract(csv_path, vendor, output_dir) do
    Mix.shell().info("=== EXTRACT ===")
    rows = parse_csv(csv_path, vendor)
    Mix.shell().info("Parsed #{length(rows)} rows from #{vendor} CSV")

    path = Path.join(output_dir, "extracted.json")
    File.write!(path, Jason.encode!(rows, pretty: true))
    Mix.shell().info("Wrote #{path}")
  end

  defp parse_csv(csv_path, "enhesa") do
    content =
      csv_path
      |> File.read!()
      |> String.replace_prefix("\uFEFF", "")

    [header_line | data_lines] = String.split(content, ~r/\r?\n/, trim: true)
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
      at = fn idx -> if idx, do: Enum.at(fields, idx, "") |> String.trim(), else: "" end

      %{
        vendor_id: at.(id_idx),
        title: at.(title_idx),
        answer: at.(answer_idx),
        jurisdiction: at.(jurisdiction_idx),
        region: at.(region_idx),
        # Identity fields — populated by transform step
        type_code: nil,
        year: nil,
        number: nil,
        lrt_name: nil,
        confidence: nil,
        matched_by: nil
      }
    end)
  end

  defp parse_csv(_path, vendor), do: Mix.raise("Unknown vendor: #{vendor}")

  # ============================================================================
  # Step 2: Transform (iterative, pattern-by-pattern)
  # ============================================================================

  defp run_transform(output_dir) do
    Mix.shell().info("\n=== TRANSFORM ===")

    # Read transformed.json if it exists (re-run), otherwise start from extracted.json
    input_path =
      case File.exists?(Path.join(output_dir, "transformed.json")) do
        true -> Path.join(output_dir, "transformed.json")
        false -> Path.join(output_dir, "extracted.json")
      end

    unless File.exists?(input_path),
      do: Mix.raise("#{input_path} not found — run --extract first")

    rows = read_json!(input_path)
    Mix.shell().info("Loaded #{length(rows)} rows from #{Path.basename(input_path)}")

    # Atomize keys for pattern matching
    rows = Enum.map(rows, &atomize_row/1)

    # Count already resolved
    already_resolved = Enum.count(rows, & &1.type_code)

    if already_resolved > 0 do
      Mix.shell().info("Already resolved: #{already_resolved}")
    end

    # Apply rules to unresolved rows
    {transformed, rule_stats} = apply_transform_rules(rows)

    # Ensure rows are maps with atom keys for stats
    transformed = Enum.map(transformed, &atomize_row/1)

    # Print stats
    total = length(transformed)
    resolved = Enum.count(transformed, & &1.type_code)
    unresolved = total - resolved

    Mix.shell().info("\nRule results:")

    Enum.each(rule_stats, fn {name, count} ->
      if count > 0 do
        Mix.shell().info("  #{String.pad_trailing(to_string(name), 30)} #{count}")
      end
    end)

    Mix.shell().info("\nResolved: #{resolved}/#{total} (#{unresolved} unresolved)")

    # Show unresolved titles
    if unresolved > 0 do
      Mix.shell().info("\nUnresolved titles:")

      transformed
      |> Enum.filter(&is_nil(&1.type_code))
      |> Enum.each(fn row ->
        Mix.shell().info("  [#{row.vendor_id}] #{String.slice(row.title || "", 0, 90)}")
      end)
    end

    # Write transformed.json
    path = Path.join(output_dir, "transformed.json")
    File.write!(path, Jason.encode!(transformed, pretty: true))
    Mix.shell().info("\nWrote #{path}")
  end

  defp apply_transform_rules(rows) do
    {transformed, stats} =
      Enum.reduce(@transform_rules, {rows, []}, fn {name, _desc, test_fn, transform_fn},
                                                   {rows_acc, stats_acc} ->
        {new_rows, count} =
          Enum.map_reduce(rows_acc, 0, fn row, count ->
            if is_nil(row.type_code) and test_fn.(row) do
              result = transform_fn.(row)

              resolved =
                row
                |> Map.merge(result)
                |> Map.put(
                  :lrt_name,
                  build_lrt_name(result.type_code, result.year, result.number)
                )
                |> Map.put(:matched_by, to_string(name))
                |> Map.put(:confidence, result[:confidence] || "high")

              {resolved, count + 1}
            else
              {row, count}
            end
          end)

        {new_rows, [{name, count} | stats_acc]}
      end)

    {transformed, Enum.reverse(stats)}
  end

  defp atomize_row(row) when is_map(row) do
    Map.new(row, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    ArgumentError ->
      # Handle keys that don't exist as atoms yet
      Map.new(row, fn
        {k, v} when is_binary(k) -> {String.to_atom(k), v}
        {k, v} -> {k, v}
      end)
  end

  defp build_lrt_name(type_code, year, number)
       when is_binary(type_code) and not is_nil(year) and not is_nil(number) do
    "UK_#{type_code}_#{year}_#{number}"
  end

  defp build_lrt_name(_, _, _), do: nil

  # ============================================================================
  # Transform Rules — each is a test/transform pair
  # ============================================================================

  # --- ACOP ---
  def match_acop?(%{title: t}) do
    String.contains?(t, "Approved Code of Practice") or
      String.contains?(t, "Code of Practice and Guidance") or
      String.contains?(t, "Workplace Exposure Limits") or
      Regex.match?(~r/\(L\d+\)/, t) or
      Regex.match?(~r/\bEH\d+\b/, t) or
      Regex.match?(~r/\bISBN\b/, t) or
      String.contains?(t, "Approved Derogations") or
      (String.contains?(t, "Code of Practice") and not String.contains?(t, "Directive")) or
      String.contains?(t, "Charging Scheme")
  end

  def mark_acop(_row), do: %{type_code: "acop", year: nil, number: nil}

  # --- International ---
  def match_intl?(%{title: t}) do
    String.starts_with?(t, "European Agreement") or
      String.starts_with?(t, "International Convention") or
      String.starts_with?(t, "International Civil Aviation") or
      String.starts_with?(t, "International Maritime") or
      String.starts_with?(t, "UN Recommendations on the Transport") or
      String.contains?(t, "ADR 20") or
      String.contains?(t, "RID 20") or
      String.contains?(t, "ICAO") or
      String.contains?(t, "IMDG Code")
  end

  def mark_intl(_row), do: %{type_code: "intl", year: nil, number: nil}

  # --- Scottish SI: S.S.I. NNN ---
  # Matches (S.S.I. NNN), (S.S.I.NNN), S.S.I. NNN — must run before S.I. rules
  def match_ssi?(%{title: t}), do: Regex.match?(~r/S\.S\.I\.?\s*\d+/, t)

  def transform_ssi(%{title: t, year: csv_year}) do
    [_, number] = Regex.run(~r/S\.S\.I\.?\s*(\d+)/, t)
    # Year from title pattern "... YYYY (S.S.I. NNN)" or fall back to CSV year
    year =
      case Regex.run(~r/(\d{4})\s*\(S\.S\.I/, t) do
        [_, y] -> parse_int(y)
        _ -> csv_year
      end

    %{type_code: "ssi", year: year, number: number}
  end

  # --- UK SI: S.I. YYYY/NNN ---
  def match_si_yyyy_slash_nnn?(%{title: t}), do: Regex.match?(~r/S\.I\.?\s*\d{4}\/\d+/, t)

  def transform_si_yyyy_slash_nnn(%{title: t}) do
    [_, year, number] = Regex.run(~r/S\.I\.?\s*(\d{4})\/(\d+)/, t)
    %{type_code: "uksi", year: parse_int(year), number: number}
  end

  # --- UK SI: S.I. YYYY No. NNN ---
  def match_si_yyyy_no_nnn?(%{title: t}),
    do: Regex.match?(~r/S\.I\.?\s*\d{4}\s+No\.?\s*\d+/, t)

  def transform_si_yyyy_no_nnn(%{title: t}) do
    [_, year, number] = Regex.run(~r/S\.I\.?\s*(\d{4})\s+No\.?\s*(\d+)/, t)
    %{type_code: "uksi", year: parse_int(year), number: number}
  end

  # --- UK SI: YYYY (S.I. NNN) ---
  def match_yyyy_paren_si?(%{title: t}),
    do: Regex.match?(~r/\d{4}\s*\(S\.I\.?\s*(?:No\.?\s*)?\d+\)/, t)

  def transform_yyyy_paren_si(%{title: t}) do
    [_, year, number] = Regex.run(~r/(\d{4})\s*\(S\.I\.?\s*(?:No\.?\s*)?(\d+)\)/, t)
    %{type_code: "uksi", year: parse_int(year), number: number}
  end

  # --- UK SI: S.I. NNN (no year in ref) ---
  def match_si_nnn_only?(%{title: t}) do
    Regex.match?(~r/S\.I\.?\s*\d+/, t) and
      not Regex.match?(~r/S\.I\.?\s*\d{4}[\/\s]/, t)
  end

  def transform_si_nnn_only(%{title: t}) do
    [_, number] = Regex.run(~r/S\.I\.?\s*(\d+)/, t)
    year = extract_last_year(t)
    %{type_code: "uksi", year: year, number: number, confidence: "medium"}
  end

  # --- UK SI: (YYYY No. NNN) ---
  def match_yyyy_no_nnn?(%{title: t}),
    do: Regex.match?(~r/\(\d{4}\s+No\.\s*\d+\)/, t)

  def transform_yyyy_no_nnn(%{title: t}) do
    [_, year, number] = Regex.run(~r/\((\d{4})\s+No\.\s*(\d+)\)/, t)
    %{type_code: "uksi", year: parse_int(year), number: number}
  end

  # --- UK SI: SI YYYY/NNN ---
  def match_si_prefix?(%{title: t}), do: Regex.match?(~r/\bSI\s+\d{4}\/\d+/, t)

  def transform_si_prefix(%{title: t}) do
    [_, year, number] = Regex.run(~r/\bSI\s+(\d{4})\/(\d+)/, t)
    %{type_code: "uksi", year: parse_int(year), number: number}
  end

  # --- UK Public General Act ---
  def match_act?(%{title: t}), do: Regex.match?(~r/Act\s+\d{4}\b/, t)

  def transform_act(%{title: t}) do
    [_, year] = Regex.run(~r/Act\s+(\d{4})\b/, t)
    # NEVER trust vendor-supplied chapter numbers — match by title later
    %{type_code: "ukpga", year: parse_int(year), number: nil}
  end

  # --- UK SI without S.I. ref (Regulations/Order/Rules/Directions YYYY) ---
  def match_regs_year?(%{title: t}) do
    Regex.match?(~r/(?:Regulations?|Rules?|Order|Directions?)\s+\d{4}\b/, t) and
      not Regex.match?(~r/Act\s+\d{4}/, t)
  end

  def transform_regs_year(%{title: t}) do
    [_, year] = Regex.run(~r/(?:Regulations?|Rules?|Order|Directions?)\s+(\d{4})\b/, t)
    %{type_code: "uksi", year: parse_int(year), number: nil, confidence: "medium"}
  end

  # --- EU Directive: YY/NNN/EC or YY/NNN/EEC or YYYY/NNN/EU ---
  def match_directive_yy_nnn_suffix?(%{title: t}) do
    is_directive_title?(t) and
      Regex.match?(~r/\d{2,4}\/\d+\/(?:EC|EEC|EU|Euratom)/i, t)
  end

  def transform_directive_yy_nnn_suffix(%{title: t}) do
    [_, year, number] = Regex.run(~r/(\d{2,4})\/(\d+)\/(?:EC|EEC|EU|Euratom)/i, t)
    %{type_code: "eudr", year: expand_year(parse_int(year)), number: number}
  end

  # --- EU Directive: (EU) YYYY/NNN ---
  def match_directive_paren_eu?(%{title: t}) do
    is_directive_title?(t) and Regex.match?(~r/\(EU\)\s+\d{4}\/\d+/i, t)
  end

  def transform_directive_paren_eu(%{title: t}) do
    [_, year, number] = Regex.run(~r/\(EU\)\s+(\d{4})\/(\d+)/i, t)
    %{type_code: "eudr", year: parse_int(year), number: number}
  end

  # --- EU Directive: EU/A/B ---
  def match_directive_eu_slash?(%{title: t}) do
    is_directive_title?(t) and Regex.match?(~r/EU\/\d+\/\d+/i, t)
  end

  def transform_directive_eu_slash(%{title: t}) do
    [_, a, b] = Regex.run(~r/EU\/(\d+)\/(\d+)/i, t)
    {year, number} = disambiguate_pair(parse_int(a), b)
    %{type_code: "eudr", year: year, number: number}
  end

  # --- EU Regulation: EC/NNN/YYYY (old convention: number/year) ---
  def match_regulation_ec_slash?(%{title: t}) do
    is_regulation_title?(t) and Regex.match?(~r/EC\/\d+\/\d{4}/i, t)
  end

  def transform_regulation_ec_slash(%{title: t}) do
    [_, number, year] = Regex.run(~r/EC\/(\d+)\/(\d{4})/i, t)
    %{type_code: "eur", year: parse_int(year), number: number}
  end

  # --- EU Regulation: EU/A/B ---
  def match_regulation_eu_slash?(%{title: t}) do
    is_regulation_title?(t) and Regex.match?(~r/EU\/\d+\/\d+/i, t)
  end

  def transform_regulation_eu_slash(%{title: t}) do
    [_, a, b] = Regex.run(~r/EU\/(\d+)\/(\d+)/i, t)
    {year, number} = disambiguate_pair(parse_int(a), b)
    %{type_code: "eur", year: year, number: number}
  end

  # --- EU Regulation: (EU|EC) [No] A/B ---
  def match_regulation_paren?(%{title: t}) do
    is_regulation_title?(t) and
      Regex.match?(~r/\(E[CU]\)\s+(?:No\.?\s+)?\d+\/\d+/i, t)
  end

  def transform_regulation_paren(%{title: t}) do
    [_, a, b] = Regex.run(~r/\(E[CU]\)\s+(?:No\.?\s+)?(\d+)\/(\d+)/i, t)
    {year, number} = disambiguate_pair(parse_int(a), b)
    %{type_code: "eur", year: year, number: number}
  end

  # --- EU Regulation: (EEC) NNN/YY ---
  def match_regulation_eec?(%{title: t}) do
    is_regulation_title?(t) and Regex.match?(~r/\(EEC\)\s+(?:No\.?\s+)?\d+\/\d+/i, t)
  end

  def transform_regulation_eec(%{title: t}) do
    [_, a, b] = Regex.run(~r/\(EEC\)\s+(?:No\.?\s+)?(\d+)\/(\d+)/i, t)
    {year, number} = disambiguate_pair(parse_int(a), b)
    %{type_code: "eur", year: year, number: number}
  end

  # --- EU Decision ---
  def match_decision?(%{title: t}) do
    is_decision_title?(t) and Regex.match?(~r/\d+\/\d+/, t)
  end

  def transform_decision(%{title: t}) do
    # Try (EU) YYYY/NNN first, then bare YYYY/NNN/EC, then EU/A/B
    cond do
      match = Regex.run(~r/\(EU\)\s+(\d{4})\/(\d+)/i, t) ->
        [_, year, number] = match
        %{type_code: "eudn", year: parse_int(year), number: number}

      match = Regex.run(~r/(\d{4})\/(\d+)\/EC/i, t) ->
        [_, year, number] = match
        %{type_code: "eudn", year: parse_int(year), number: number}

      match = Regex.run(~r/EU\/(\d+)\/(\d+)/i, t) ->
        [_, a, b] = match
        {year, number} = disambiguate_pair(parse_int(a), b)
        %{type_code: "eudn", year: year, number: number}

      match = Regex.run(~r/(\d{4})\/(\d+)/i, t) ->
        [_, year, number] = match
        %{type_code: "eudn", year: parse_int(year), number: number}

      true ->
        %{type_code: "eudn", year: nil, number: nil, confidence: "low"}
    end
  end

  # --- Helpers ---

  # Title prefix checks — does the title describe this TYPE of EU law?
  # Covers all known vendor prefix variants (Council, Commission, European Parliament, Implementing, Delegated)
  defp is_directive_title?(title) do
    Regex.match?(
      ~r/^(?:(?:European\s+Parliament\s+and\s+)?Council\s+|Commission\s+(?:Implementing\s+|Delegated\s+)?)?Directive\b/i,
      title
    )
  end

  defp is_decision_title?(title) do
    Regex.match?(
      ~r/^(?:Council\s+|Commission\s+(?:Implementing\s+|Delegated\s+)?)?Decision\b/i,
      title
    )
  end

  defp is_regulation_title?(title) do
    Regex.match?(
      ~r/^(?:Commission\s+)?(?:Implementing\s+|Delegated\s+)?(?:Council\s+)?Regulation\b/i,
      title
    ) or Regex.match?(~r/^Regulation\b/i, title) or
      Regex.match?(~r/^Council\s+Regulation\b/i, title)
  end

  @doc "Disambiguate two numbers from an EU reference — determine which is year and which is number."
  def disambiguate_pair(a, b_str) when is_integer(a) do
    b = parse_int(b_str)
    current_year = Date.utc_today().year

    cond do
      # a is clearly a 4-digit year
      a >= 1900 and a <= current_year + 1 and (b == nil or b > current_year + 1 or b < 1900) ->
        {a, b_str}

      # b is clearly a 4-digit year
      b != nil and b >= 1900 and b <= current_year + 1 and (a > current_year + 1 or a < 1900) ->
        {b, to_string(a)}

      # Both are plausible 4-digit years — take the first (EU/YYYY/NNN convention)
      a >= 1900 and a <= current_year + 1 and b != nil and b >= 1900 and b <= current_year + 1 ->
        {a, b_str}

      # a is a 2-digit year
      a < 100 and (b == nil or b >= 100) ->
        {expand_year(a), b_str}

      # b is a 2-digit year
      b != nil and b < 100 and a >= 100 ->
        {expand_year(b), to_string(a)}

      # Default: treat a as year
      true ->
        {a, b_str}
    end
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

  # ============================================================================
  # Step 3: Match against LRT
  # ============================================================================

  defp run_match(output_dir) do
    Mix.shell().info("\n=== MATCH ===")

    transformed_path = Path.join(output_dir, "transformed.json")

    unless File.exists?(transformed_path),
      do: Mix.raise("#{transformed_path} not found — run --transform first")

    rows = read_json!(transformed_path) |> Enum.map(&atomize_row/1)
    repo = SertantaiLegal.Repo

    {matched, scrapeable, not_handled} =
      Enum.reduce(rows, {[], [], []}, fn row, {m, s, n} ->
        case row.type_code do
          nil ->
            {m, s, [Map.put(row, :match_status, :unresolved) | n]}

          tc when tc in ["acop", "intl"] ->
            {m, s, [Map.put(row, :match_status, :not_handled) | n]}

          _type_code ->
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

    grouped = %{
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

    print_match_stats(grouped)

    path = Path.join(output_dir, "matched.json")
    File.write!(path, Jason.encode!(grouped, pretty: true))
    Mix.shell().info("\nWrote #{path}")
  end

  defp find_in_lrt(repo, %{lrt_name: name}) when is_binary(name) do
    case repo.query("SELECT id::text, name, family FROM uk_lrt WHERE name = $1 LIMIT 1", [name]) do
      {:ok, %{rows: [[id, name, family] | _]}} ->
        {:ok, %{id: id, name: name, family: family}}

      _ ->
        :not_found
    end
  end

  defp find_in_lrt(repo, %{type_code: type_code, year: year, title: title})
       when not is_nil(year) do
    clean = clean_vendor_title(title)
    prefix = "UK_#{type_code}_#{year}_%"

    case repo.query(
           "SELECT id::text, name, family FROM uk_lrt WHERE name LIKE $1 AND title_en ILIKE $2 LIMIT 1",
           [prefix, "%#{clean}%"]
         ) do
      {:ok, %{rows: [[id, name, family] | _]}} ->
        {:ok, %{id: id, name: name, family: family}}

      _ ->
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

  # ============================================================================
  # Post-match: QA
  # ============================================================================

  @uk_domestic_types ["uksi", "ukpga"]
  @eu_types ["eur", "eudr", "eudn"]

  defp run_title_qa(matched_data, transformed_rows, qa_group) do
    repo = SertantaiLegal.Repo
    matched = matched_data["matched"] || matched_data[:matched] || []

    {filtered, group_label} =
      case qa_group do
        "1" ->
          laws =
            Enum.filter(matched, &((&1["type_code"] || &1[:type_code]) in @uk_domestic_types))

          {laws, "Group 1 (UK domestic)"}

        "2" ->
          laws = Enum.filter(matched, &((&1["type_code"] || &1[:type_code]) in @eu_types))
          {laws, "Group 2 (EU retained)"}

        _ ->
          {matched, "All matched"}
      end

    vendor_titles =
      transformed_rows
      |> Enum.filter(&((&1["lrt_name"] || &1[:lrt_name]) != nil))
      |> Map.new(fn r -> {r["lrt_name"] || r[:lrt_name], r["title"] || r[:title]} end)

    Mix.shell().info("\n=== POST-SCRAPE QA: Title Comparison [#{group_label}] ===")

    {good, mismatches} =
      Enum.reduce(filtered, {0, []}, fn row, {g, m} ->
        lrt_name = row["lrt_name"] || row[:lrt_name]
        vendor_title = vendor_titles[lrt_name] || ""
        lrt_title = fetch_lrt_title(repo, lrt_name)

        cond do
          lrt_title == nil or lrt_title == "" ->
            {g, [{lrt_name, vendor_title, "(empty/missing)", :empty} | m]}

          titles_match?(vendor_title, lrt_title) ->
            {g + 1, m}

          true ->
            {g, [{lrt_name, vendor_title, lrt_title, :mismatch} | m]}
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
    |> String.replace(~r/\bEC\/(\d+)\/(\d{4})/, "(EC) No \\1/\\2")
    |> String.replace(~r/\bEU\/(\d+)\/(\d{4})/, "(EU) No \\1/\\2")
    |> String.replace(~r/\bEU\/(\d{4})\/(\d+)/, "(EU) \\1/\\2")
    |> String.replace(~r/\bEC\/(\d{4})\/(\d+)/, "(EC) \\1/\\2")
    |> String.replace(~r/\(E[CU]\)\s+No\.?\s+/, "(EC) ")
    |> String.replace("and of the council", "and the council")
    |> String.replace(~r/\b\d{2,4}\/\d+\/(?:EEC|EC|EU|Euratom)\b/, "")
    |> String.replace(~r/\(\d{2,4}\/\d+\/(?:EEC|EC|EU)\)/, "")
    |> String.replace("´", "'")
    |> String.replace("\u2011", "-")
    |> String.replace("\u2013", "-")
    |> String.replace("\u2014", "-")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.downcase()
  end

  # ============================================================================
  # Post-match: Status Report
  # ============================================================================

  defp generate_status_report(matched_data, customer, site, output_dir) do
    repo = SertantaiLegal.Repo
    matched = matched_data["matched"] || matched_data[:matched] || []

    live_lookup =
      matched
      |> Enum.map(&(&1["lrt_name"] || &1[:lrt_name]))
      |> Enum.filter(& &1)
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

    {in_force, part_revoked, revoked, unknown_status} =
      Enum.reduce(matched, {[], [], [], []}, fn r, {inf, pr, rev, unk} ->
        lrt_name = r["lrt_name"] || r[:lrt_name]
        live = live_lookup[lrt_name]

        entry = %{
          lrt_name: lrt_name,
          title: r["title"] || r[:title],
          family: r["family"] || r[:family],
          answer: r["answer"] || r[:answer],
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
        scrapeable_not_yet_matched:
          length(matched_data["scrapeable"] || matched_data[:scrapeable] || []),
        not_handled: length(matched_data["not_handled"] || matched_data[:not_handled] || [])
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
      Mix.shell().info("\n!! REVOKED BUT ANSWER=YES (customer tracking dead law):")

      Enum.each(revoked_but_yes, fn e ->
        Mix.shell().info("  #{e.lrt_name}")
        Mix.shell().info("    #{String.slice(e.title, 0, 100)}")
        Mix.shell().info("    Family: #{e.family || "(none)"}")
        Mix.shell().info("")
      end)
    end

    Mix.shell().info("Wrote #{path}")
  end

  # ============================================================================
  # Post-match: Create Scrape Session
  # ============================================================================

  alias SertantaiLegal.Scraper.{ScrapeSession, ScrapeSessionRecord}

  defp create_scrape_session(matched_data, customer, site) do
    scrapeable = matched_data["scrapeable"] || matched_data[:scrapeable] || []

    with_name =
      Enum.filter(scrapeable, fn r ->
        name = r["lrt_name"] || r[:lrt_name]
        name != nil and name != ""
      end)

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

    {created, _errors} =
      with_name
      |> Enum.reduce({0, 0}, fn row, {ok, err} ->
        type_code = row["type_code"] || row[:type_code]
        group = if type_code in ["uksi", "ukpga"], do: :group1, else: :group2
        lrt_name = row["lrt_name"] || row[:lrt_name]

        case Ash.create(
               ScrapeSessionRecord,
               %{
                 session_id: session_id,
                 law_name: lrt_name,
                 group: group,
                 status: :pending,
                 parsed_data: %{
                   "vendor_id" => row["vendor_id"] || row[:vendor_id],
                   "title" => row["title"] || row[:title],
                   "type_code" => type_code,
                   "year" => row["year"] || row[:year],
                   "number" => row["number"] || row[:number],
                   "answer" => row["answer"] || row[:answer]
                 }
               },
               action: :create
             ) do
          {:ok, _} -> {ok + 1, err}
          {:error, _} -> {ok, err + 1}
        end
      end)

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

  # ============================================================================
  # Reporting
  # ============================================================================

  defp print_match_stats(%{stats: stats} = grouped) do
    Mix.shell().info("Total:       #{stats.total}")
    Mix.shell().info("Matched:     #{stats.matched}")
    Mix.shell().info("Scrapeable:  #{stats.scrapeable}")
    Mix.shell().info("Not handled: #{stats.not_handled}")

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

    if stats.scrapeable > 0 do
      by_type = Enum.frequencies_by(grouped.scrapeable, & &1.type_code)
      Mix.shell().info("\nScrapeable by type:")
      Enum.each(by_type, fn {type, count} -> Mix.shell().info("  #{type}: #{count}") end)
    end

    if stats.not_handled > 0 do
      by_type = Enum.frequencies_by(grouped.not_handled, &(&1.type_code || "unresolved"))
      Mix.shell().info("\nNot handled by type:")
      Enum.each(by_type, fn {type, count} -> Mix.shell().info("  #{type}: #{count}") end)
    end
  end

  defp read_json!(path) do
    path |> File.read!() |> Jason.decode!()
  end
end
