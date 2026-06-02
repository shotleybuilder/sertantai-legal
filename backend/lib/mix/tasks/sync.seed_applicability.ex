defmodule Mix.Tasks.Sync.SeedApplicability do
  @shortdoc "Pre-populate org applicability from a customer import's matched.json"

  @moduledoc """
  Creates OrgApplicability records from the Enhesa Answer field in the
  matched.json file produced by `mix legal.import_register`.

  ## Usage

      mix sync.seed_applicability <matched_json_path> <organization_id>
      mix sync.seed_applicability <matched_json_path> <organization_id> --dry-run

  ## Example

      mix sync.seed_applicability backend/data/imports/qq/bsc/matched.json 550e8400-e29b-41d4-a716-446655440000

  ## How it works

  1. Reads matched.json (output of import pipeline)
  2. Extracts the "matched" array (laws found in LRT)
  3. Maps "Yes" → :yes, "No" → :no (skips empty answers)
  4. Upserts OrgApplicability with source = :enhesa_import
  """

  use Mix.Task

  alias SertantaiLegal.Sync.OrgApplicability

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional, _} = OptionParser.parse(args, switches: [dry_run: :boolean])
    dry_run? = Keyword.get(opts, :dry_run, false)

    case positional do
      [json_path, org_id] ->
        seed(json_path, org_id, dry_run?)

      _ ->
        IO.puts(
          "Usage: mix sync.seed_applicability <matched_json_path> <organization_id> [--dry-run]"
        )

        System.halt(1)
    end
  end

  defp seed(json_path, org_id, dry_run?) do
    IO.puts("=== Seed Applicability from Import ===")
    IO.puts("Source: #{json_path}")
    IO.puts("Org:    #{org_id}")
    IO.puts("Mode:   #{if dry_run?, do: "DRY RUN", else: "APPLY"}\n")

    # Read matched.json
    case File.read(json_path) do
      {:ok, contents} ->
        data = Jason.decode!(contents)
        matched = Map.get(data, "matched", [])

        IO.puts("Total matched laws: #{length(matched)}")

        # Filter to records with Yes/No answer and valid lrt_name
        with_answers =
          matched
          |> Enum.filter(fn r ->
            answer = r["answer"]
            lrt_name = r["lrt_name"]
            answer in ["Yes", "No"] and is_binary(lrt_name) and lrt_name != ""
          end)

        IO.puts("Records with Yes/No answer: #{length(with_answers)}\n")

        # Build applicability params
        rows =
          Enum.map(with_answers, fn r ->
            %{
              organization_id: org_id,
              law_name: r["lrt_name"],
              status: map_answer(r["answer"]),
              source: :enhesa_import
            }
          end)

        yes_count = Enum.count(rows, &(&1.status == :yes))
        no_count = Enum.count(rows, &(&1.status == :no))

        IO.puts("  Yes: #{yes_count}")
        IO.puts("  No:  #{no_count}")

        if dry_run? do
          IO.puts("\nDry run complete. Re-run without --dry-run to apply.")
        else
          apply_rows(rows)
        end

      {:error, reason} ->
        IO.puts("Error reading #{json_path}: #{reason}")
        System.halt(1)
    end
  end

  defp apply_rows(rows) do
    IO.puts("\n=== Applying #{length(rows)} applicability records ===")

    {ok, err} =
      Enum.reduce(rows, {0, 0}, fn params, {ok_count, err_count} ->
        case OrgApplicability.upsert(params) do
          {:ok, _} ->
            {ok_count + 1, err_count}

          {:error, e} ->
            IO.puts("  Error for #{params.law_name}: #{inspect(e)}")
            {ok_count, err_count + 1}
        end
      end)

    IO.puts("\n  Applied: #{ok}")
    IO.puts("  Errors:  #{err}")
  end

  defp map_answer("Yes"), do: :yes
  defp map_answer("No"), do: :no
end
