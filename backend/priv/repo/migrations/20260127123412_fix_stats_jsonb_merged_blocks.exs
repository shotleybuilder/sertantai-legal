defmodule SertantaiLegal.Repo.Migrations.FixStatsJsonbMergedBlocks do
  @moduledoc """
  Fix migration for records where the original text-to-JSONB migration merged
  multiple law blocks into a single key.

  Root cause: Some text fields use only \\n (no blank line) between law blocks,
  but the original parser split on \\n\\n. This caused subsequent law blocks to be
  absorbed as detail lines of the first law.

  Affected records (8 record/field pairs):
  - affects: UK_ssi_2025_165, UK_uksi_2025_581, UK_uksi_2023_1430,
             UK_uksi_2020_847, UK_uksi_2025_585, UK_ssi_2025_166
  - rescinding: UK_ssi_2025_165, UK_uksi_2023_1430

  Fix: Create a corrected parser that splits on the count-title pattern
  (line starting with a digit) rather than relying on \\n\\n.
  """

  use Ecto.Migration

  @affect_pattern ~S"((?:words?\s+)?(?:substituted|inserted|omitted|added|repealed|revoked|amended|modified|restricted|excluded|applied|extended|coming into force|power to modify conferred|saved|transitional provisions|transferred|expired|renumbered|deleted|disapplied|incorporated|prospectively repealed|superseded|continued)(?:\s+\(temp\.\))?)"

  def up do
    # Create corrected parser function
    execute(create_corrected_parse_function())

    # Re-parse only the affected records for affects field
    execute("""
    UPDATE uk_lrt
    SET "🔺_affects_stats_per_law" = parse_stats_text_to_jsonb_v2(
      "🔺_stats_affects_count_per_law",
      "🔺_stats_affects_count_per_law_detailed"
    )
    WHERE name IN (
      'UK_ssi_2025_165', 'UK_uksi_2025_581', 'UK_uksi_2023_1430',
      'UK_uksi_2020_847', 'UK_uksi_2025_585', 'UK_ssi_2025_166'
    )
    AND "🔺_stats_affects_count_per_law_detailed" IS NOT NULL
    """)

    # Re-parse only the affected records for rescinding field
    execute("""
    UPDATE uk_lrt
    SET "🔺_rescinding_stats_per_law" = parse_stats_text_to_jsonb_v2(
      "🔺_stats_rescinding_count_per_law",
      "🔺_stats_rescinding_count_per_law_detailed"
    )
    WHERE name IN ('UK_ssi_2025_165', 'UK_uksi_2023_1430')
    AND "🔺_stats_rescinding_count_per_law_detailed" IS NOT NULL
    """)

    # Drop helper function
    execute("DROP FUNCTION IF EXISTS parse_stats_text_to_jsonb_v2(text, text)")
  end

  def down do
    # No-op: reverting would restore the buggy data
    # The original text fields are still intact
  end

  defp create_corrected_parse_function do
    """
    CREATE OR REPLACE FUNCTION parse_stats_text_to_jsonb_v2(
      summary_text text,
      detailed_text text
    ) RETURNS jsonb AS $$
    DECLARE
      result jsonb := '{}'::jsonb;
      all_lines text[];
      line text;
      current_count int := 0;
      current_title text := '';
      current_url text := '';
      current_law_name text := '';
      current_details jsonb := '[]'::jsonb;
      has_current_block boolean := false;
      applied text;
      target_affect text;
      target_part text;
      affect_part text;
      affect_match text[];
      i int;
      line_count int;
    BEGIN
      IF detailed_text IS NULL OR detailed_text = '' THEN
        RETURN '{}'::jsonb;
      END IF;

      -- Split entire text into lines
      all_lines := regexp_split_to_array(detailed_text, E'\\n');
      line_count := array_length(all_lines, 1);

      FOR i IN 1..line_count LOOP
        line := all_lines[i];

        IF line IS NULL OR trim(line) = '' THEN
          CONTINUE;
        END IF;

        -- Check if this line starts a new law block: "count - title"
        IF line ~ '^[0-9]+ - ' THEN
          -- Save previous block if exists
          IF has_current_block AND current_law_name != '' THEN
            result := result || jsonb_build_object(
              current_law_name,
              jsonb_build_object(
                'name', current_law_name,
                'title', current_title,
                'url', current_url,
                'count', current_count,
                'details', current_details
              )
            );
          END IF;

          -- Start new block
          current_count := (regexp_match(line, '^([0-9]+)'))[1]::int;
          current_title := regexp_replace(line, '^[0-9]+ - ', '');
          current_url := '';
          current_law_name := '';
          current_details := '[]'::jsonb;
          has_current_block := true;

        -- URL line
        ELSIF line LIKE '%legislation.gov.uk%' AND current_url = '' THEN
          current_url := trim(line);
          -- Extract law name from URL path
          current_law_name := 'UK_' || replace(
            replace(
              regexp_replace(current_url, '^.*/id/', ''),
              '/', '_'
            ),
            '-', '_'
          );

        -- Detail line (starts with space or is a continuation)
        ELSIF has_current_block AND current_url != '' THEN
          line := trim(line);

          -- Extract applied status from [brackets]
          IF line ~ '\\[.*\\]$' THEN
            applied := (regexp_match(line, '\\[([^\\]]+)\\]$'))[1];
            target_affect := trim(regexp_replace(line, '\\s*\\[([^\\]]+)\\]$', ''));
          ELSE
            applied := NULL;
            target_affect := line;
          END IF;

          -- Try to extract affect keyword from target_affect
          affect_match := regexp_match(target_affect, '#{@affect_pattern}', 'i');
          IF affect_match IS NOT NULL THEN
            affect_part := affect_match[1];
            -- Target is everything before the affect
            target_part := trim(regexp_replace(target_affect, '\\s*' || regexp_replace(affect_part, '([().+*?\\[\\]])', '\\\\\\1', 'g') || '\\s*$', ''));
            IF target_part = '' THEN
              target_part := target_affect;
              affect_part := NULL;
            END IF;
          ELSE
            target_part := target_affect;
            affect_part := NULL;
          END IF;

          current_details := current_details || jsonb_build_object(
            'target', target_part,
            'affect', affect_part,
            'applied', applied
          );
        END IF;
      END LOOP;

      -- Save final block
      IF has_current_block AND current_law_name != '' THEN
        result := result || jsonb_build_object(
          current_law_name,
          jsonb_build_object(
            'name', current_law_name,
            'title', current_title,
            'url', current_url,
            'count', current_count,
            'details', current_details
          )
        );
      END IF;

      RETURN result;
    END;
    $$ LANGUAGE plpgsql;
    """
  end
end
