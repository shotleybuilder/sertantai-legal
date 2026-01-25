defmodule SertantaiLegal.Repo.Migrations.MigrateStatsTextToJsonb do
  @moduledoc """
  Data migration to convert text-based stats fields to JSONB.

  Converts 4 pairs of text fields (summary + detailed) into 4 JSONB fields.

  This migration creates a temporary PL/pgSQL function to parse the text format
  and convert it to JSONB, then drops the function after use.
  """

  use Ecto.Migration

  def up do
    # Create helper function to parse text blocks into JSONB
    execute(create_parse_function())

    # Convert each field pair
    execute("""
    UPDATE uk_lrt
    SET "🔺_affects_stats_per_law" = parse_stats_text_to_jsonb(
      "🔺_stats_affects_count_per_law",
      "🔺_stats_affects_count_per_law_detailed"
    )
    WHERE "🔺_stats_affects_count_per_law_detailed" IS NOT NULL
    """)

    execute("""
    UPDATE uk_lrt
    SET "🔺_rescinding_stats_per_law" = parse_stats_text_to_jsonb(
      "🔺_stats_rescinding_count_per_law",
      "🔺_stats_rescinding_count_per_law_detailed"
    )
    WHERE "🔺_stats_rescinding_count_per_law_detailed" IS NOT NULL
    """)

    execute("""
    UPDATE uk_lrt
    SET "🔻_affected_by_stats_per_law" = parse_stats_text_to_jsonb(
      "🔻_stats_affected_by_count_per_law",
      "🔻_stats_affected_by_count_per_law_detailed"
    )
    WHERE "🔻_stats_affected_by_count_per_law_detailed" IS NOT NULL
    """)

    execute("""
    UPDATE uk_lrt
    SET "🔻_rescinded_by_stats_per_law" = parse_stats_text_to_jsonb(
      "🔻_stats_rescinded_by_count_per_law",
      "🔻_stats_rescinded_by_count_per_law_detailed"
    )
    WHERE "🔻_stats_rescinded_by_count_per_law_detailed" IS NOT NULL
    """)

    # Drop helper function
    execute("DROP FUNCTION IF EXISTS parse_stats_text_to_jsonb(text, text)")
  end

  def down do
    # Clear the JSONB fields (text fields still have original data)
    execute("UPDATE uk_lrt SET \"🔺_affects_stats_per_law\" = NULL")
    execute("UPDATE uk_lrt SET \"🔺_rescinding_stats_per_law\" = NULL")
    execute("UPDATE uk_lrt SET \"🔻_affected_by_stats_per_law\" = NULL")
    execute("UPDATE uk_lrt SET \"🔻_rescinded_by_stats_per_law\" = NULL")
  end

  # ============================================================================
  # PL/pgSQL function to parse the text format
  # ============================================================================
  #
  # Text format (detailed):
  # ```
  # 4 - The Health and Care Act 2022 Regulations 2023
  # https://legislation.gov.uk/id/uksi/2023/1071
  #  reg. 1(2)(d) words omitted [Not yet]
  #  reg. 1(2)(e) word omitted [Not yet]
  #
  # 1 - The Statutory Parental Bereavement Pay Regulations 2020
  # https://legislation.gov.uk/id/uksi/2020/240
  #  reg. 1(2) words substituted [Not yet]
  # ```
  #
  # Law blocks are separated by blank lines (\n\n).
  # First line: "count - title"
  # Second line: "url" (contains legislation.gov.uk)
  # Subsequent lines (starting with space): " target affect [applied]"

  defp create_parse_function do
    """
    CREATE OR REPLACE FUNCTION parse_stats_text_to_jsonb(
      summary_text text,
      detailed_text text
    ) RETURNS jsonb AS $$
    DECLARE
      result jsonb := '{}'::jsonb;
      blocks text[];
      block text;
      lines text[];
      line text;
      count_title text;
      url_line text;
      law_name text;
      title text;
      url text;
      count_val int;
      details jsonb;
      detail_parts text[];
      target_affect text;
      applied text;
      i int;
    BEGIN
      -- If no detailed text, return empty object
      IF detailed_text IS NULL OR detailed_text = '' THEN
        RETURN '{}'::jsonb;
      END IF;

      -- Split by double newline (blank line between law blocks)
      blocks := regexp_split_to_array(detailed_text, E'\\n\\n');

      FOREACH block IN ARRAY blocks LOOP
        IF block IS NULL OR trim(block) = '' THEN
          CONTINUE;
        END IF;

        -- Split block into lines
        lines := regexp_split_to_array(block, E'\\n');

        IF array_length(lines, 1) < 2 THEN
          CONTINUE;
        END IF;

        -- First line: "count - title"
        count_title := lines[1];

        -- Parse count and title: "4 - The Example Regulations 2023"
        IF count_title ~ '^[0-9]+ - ' THEN
          count_val := (regexp_match(count_title, '^([0-9]+)'))[1]::int;
          title := regexp_replace(count_title, '^[0-9]+ - ', '');
        ELSE
          count_val := 1;
          title := count_title;
        END IF;

        -- Second line: URL (or may be missing in some legacy data)
        url_line := lines[2];
        IF url_line LIKE '%legislation.gov.uk%' THEN
          url := trim(url_line);
          -- Extract law name from URL path
          -- URL format: https://legislation.gov.uk/id/uksi/2023/1071
          law_name := 'UK_' || replace(
            replace(
              regexp_replace(url, '^.*/id/', ''),
              '/', '_'
            ),
            '-', '_'
          );
        ELSE
          -- URL might be missing, use title as fallback
          url := NULL;
          law_name := 'UNKNOWN_' || md5(title);
        END IF;

        -- Parse detail lines (start with space)
        details := '[]'::jsonb;
        FOR i IN 3..coalesce(array_length(lines, 1), 2) LOOP
          line := lines[i];
          IF line IS NULL OR trim(line) = '' THEN
            CONTINUE;
          END IF;

          -- Detail line format: " target affect [applied]"
          line := trim(line);

          -- Extract applied status from [brackets]
          IF line ~ '\\[.*\\]$' THEN
            applied := (regexp_match(line, '\\[([^\\]]+)\\]$'))[1];
            target_affect := trim(regexp_replace(line, '\\[([^\\]]+)\\]$', ''));
          ELSE
            applied := NULL;
            target_affect := line;
          END IF;

          -- Try to split target and affect (e.g., "reg. 1(2) words substituted")
          -- This is fuzzy - affect is usually the last 1-3 words
          details := details || jsonb_build_object(
            'target', target_affect,
            'affect', NULL,
            'applied', applied
          );
        END LOOP;

        -- Add law entry to result
        result := result || jsonb_build_object(
          law_name,
          jsonb_build_object(
            'name', law_name,
            'title', title,
            'url', url,
            'count', count_val,
            'details', details
          )
        );
      END LOOP;

      RETURN result;
    END;
    $$ LANGUAGE plpgsql;
    """
  end
end
