defmodule Mix.Tasks.Legal.BackfillMakingProvenance do
  @moduledoc """
  Backfill making classifier provenance for laws missing it (#136).

  Runs MakingDetector.detect/1 on laws that have is_making set but no
  making_confidence/making_detection_tier/making_detection_signals. These
  are legacy import records that predated the classifier pipeline.

  MakingDetector uses metadata only (title, description, paragraph counts)
  — no provisions needed. The provenance is a lightweight pre-filter guess
  that gets overwritten after fractalaw enrichment.

  ## Usage

      mix legal.backfill_making_provenance           # backfill all
      mix legal.backfill_making_provenance --dry-run  # show counts only
  """

  use Mix.Task
  require Logger

  alias SertantaiLegal.Legal.Taxa.MakingDetector

  @shortdoc "Backfill making classifier provenance on legacy imports"

  @impl Mix.Task
  def run(args) do
    dry_run = "--dry-run" in args

    Mix.Task.run("app.start")

    # Find laws with is_making=true but no classifier provenance.
    # Also include laws with making_classification set but no confidence
    # (same gap — classification without provenance).
    query = """
    SELECT id::text, name, title_en, md_description,
           md_body_paras, md_schedule_paras, type_code,
           is_making, making_classification
    FROM legal_register
    WHERE making_confidence IS NULL
      AND making_detection_tier IS NULL
      AND (is_making = true OR making_classification IS NOT NULL)
    ORDER BY name
    """

    case SertantaiLegal.Repo.query(query) do
      {:ok, %{rows: rows, columns: columns}} ->
        laws = Enum.map(rows, fn row -> Enum.zip(columns, row) |> Map.new() end)
        IO.puts("Found #{length(laws)} laws missing classifier provenance.")

        if dry_run do
          show_preview(laws)
        else
          backfill(laws)
        end

      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  defp show_preview(laws) do
    # Show what MakingDetector would classify them as
    results =
      Enum.map(laws, fn law ->
        result = detect(law)
        {law["is_making"], result.classification}
      end)

    agrees =
      Enum.count(results, fn {existing, detected} ->
        (existing == true and detected == :making) or
          (existing != true and detected != :making)
      end)

    disagrees = length(results) - agrees

    by_classification =
      results
      |> Enum.map(fn {_, c} -> c end)
      |> Enum.frequencies()

    IO.puts("\nDry run — MakingDetector results:")
    IO.puts("  making:     #{Map.get(by_classification, :making, 0)}")
    IO.puts("  not_making: #{Map.get(by_classification, :not_making, 0)}")
    IO.puts("  uncertain:  #{Map.get(by_classification, :uncertain, 0)}")
    IO.puts("\n  Agrees with existing is_making: #{agrees}")
    IO.puts("  Disagrees:                      #{disagrees}")
  end

  defp backfill(laws) do
    IO.puts("Running MakingDetector on #{length(laws)} laws...")

    # Stamp provenance fields only. Do NOT change is_making — the existing
    # value came from import/enrichment and is more authoritative than the
    # metadata-only detector. The detector result is a pre-filter guess that
    # records *what the metadata says*, not the final classification.
    {ok, disagrees, errors} =
      Enum.reduce(laws, {0, 0, 0}, fn law, {ok, disagrees, errors} ->
        result = detect(law)
        fields = MakingDetector.to_parsed_law_fields(result)

        update_sql = """
        UPDATE legal_register
        SET making_confidence = $1,
            making_detection_tier = $2,
            making_detection_signals = $3,
            updated_at = now()
        WHERE name = $4
        """

        params = [
          fields.making_confidence,
          fields.making_detection_tier,
          Jason.encode!(fields.making_detection_signals),
          law["name"]
        ]

        case SertantaiLegal.Repo.query(update_sql, params) do
          {:ok, _} ->
            was_making = law["is_making"] == true

            detector_agrees =
              (was_making and result.classification == :making) or
                (not was_making and result.classification != :making)

            if not detector_agrees do
              IO.puts(
                "  ⚠ #{law["name"]}: is_making=#{was_making} but detector says #{fields.making_classification} (#{Float.round(fields.making_confidence, 2)})"
              )

              {ok + 1, disagrees + 1, errors}
            else
              {ok + 1, disagrees, errors}
            end

          {:error, reason} ->
            IO.puts("  ✗ #{law["name"]}: #{inspect(reason)}")
            {ok, disagrees, errors + 1}
        end
      end)

    IO.puts(
      "\nDone. #{ok} stamped with provenance, #{disagrees} disagree with existing is_making, #{errors} errors."
    )
  end

  defp detect(law) do
    metadata = %{
      title_en: law["title_en"],
      md_description: law["md_description"],
      md_body_paras: law["md_body_paras"],
      md_schedule_paras: law["md_schedule_paras"],
      type_code: law["type_code"]
    }

    MakingDetector.detect(metadata)
  end
end
