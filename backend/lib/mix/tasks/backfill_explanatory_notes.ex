defmodule Mix.Tasks.BackfillExplanatoryNotes do
  @moduledoc """
  Backfill Explanatory Notes for laws that don't have one yet.

  Fetches the Explanatory Note from legislation.gov.uk and writes it
  directly to the record — no full LRT reparse needed.

  ## Usage

      # Backfill all QQ applicable laws missing notes
      mix backfill_explanatory_notes --org-id c075d56b-8420-4408-b695-ccfbc1ba15ec

      # Backfill specific laws
      mix backfill_explanatory_notes UK_uksi_1992_2793 UK_ukpga_2010_15

      # Dry run (fetch but don't persist)
      mix backfill_explanatory_notes --dry-run --org-id c075d56b-...

      # Limit to N laws (useful for testing)
      mix backfill_explanatory_notes --org-id c075d56b-... --limit 10
  """

  use Mix.Task

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Scraper.ExplanatoryNote
  alias SertantaiLegal.Repo

  require Ash.Query
  require Logger

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, names, _} =
      OptionParser.parse(args,
        switches: [org_id: :string, dry_run: :boolean, limit: :integer],
        aliases: [n: :limit]
      )

    dry_run = Keyword.get(opts, :dry_run, false)
    limit = Keyword.get(opts, :limit)
    org_id = Keyword.get(opts, :org_id)

    laws =
      cond do
        names != [] ->
          # Specific law names provided
          {:ok, records} =
            LegalRegister
            |> Ash.Query.filter(name in ^names)
            |> Ash.read()

          records

        org_id ->
          # All applicable laws for an org missing explanatory_note
          fetch_org_laws_missing_notes(org_id, limit)

        true ->
          IO.puts("Usage: mix backfill_explanatory_notes --org-id <uuid> | <law_name> ...")
          []
      end

    if laws == [] do
      IO.puts("No laws to process.")
    else
      IO.puts("Processing #{length(laws)} laws#{if dry_run, do: " (DRY RUN)", else: ""}...\n")
      process_laws(laws, dry_run)
    end
  end

  defp fetch_org_laws_missing_notes(org_id, limit) do
    sql = """
    SELECT lr.id, lr.name, lr.type_code, lr.year, lr.number
    FROM org_applicabilities oa
    JOIN legal_register lr ON lr.name = oa.law_name
    WHERE oa.organization_id = $1
      AND oa.status = 'yes'
      AND (lr.explanatory_note IS NULL OR lr.explanatory_note = '')
      AND lr.type_code NOT IN ('eur', 'eudr', 'eudn')
    ORDER BY lr.type_code, lr.name
    #{if limit, do: "LIMIT #{limit}", else: ""}
    """

    {:ok, bin} = Ecto.UUID.dump(org_id)

    case Repo.query(sql, [bin]) do
      {:ok, %{rows: rows, columns: cols}} ->
        Enum.map(rows, fn row ->
          cols |> Enum.zip(row) |> Map.new(fn {c, v} -> {String.to_atom(c), v} end)
        end)

      {:error, reason} ->
        IO.puts("Query error: #{inspect(reason)}")
        []
    end
  end

  defp process_laws(laws, dry_run) do
    results =
      Enum.reduce(laws, %{fetched: 0, not_found: 0, errors: 0, skipped: 0}, fn law, acc ->
        name = Map.get(law, :name)
        type_code = Map.get(law, :type_code)
        year = Map.get(law, :year)
        number = Map.get(law, :number)

        case ExplanatoryNote.fetch(type_code, year, to_string(number)) do
          {:ok, text} ->
            chars = String.length(text)

            if dry_run do
              IO.puts("  ✓ #{name}: #{chars} chars (dry run)")
              %{acc | fetched: acc.fetched + 1}
            else
              case update_note(name, text) do
                :ok ->
                  IO.puts("  ✓ #{name}: #{chars} chars")
                  %{acc | fetched: acc.fetched + 1}

                {:error, reason} ->
                  IO.puts("  ✗ #{name}: persist failed — #{inspect(reason)}")
                  %{acc | errors: acc.errors + 1}
              end
            end

          {:error, :not_found} ->
            IO.puts("  ⊘ #{name}: no note available")
            %{acc | not_found: acc.not_found + 1}

          {:error, :empty} ->
            IO.puts("  ⊘ #{name}: empty note")
            %{acc | not_found: acc.not_found + 1}

          {:error, reason} ->
            IO.puts("  ✗ #{name}: #{inspect(reason)}")
            %{acc | errors: acc.errors + 1}
        end
      end)

    IO.puts(
      "\nDone: #{results.fetched} fetched, #{results.not_found} not found, #{results.errors} errors"
    )
  end

  defp update_note(name, text) do
    case LegalRegister |> Ash.Query.filter(name == ^name) |> Ash.read_one() do
      {:ok, record} when not is_nil(record) ->
        case record
             |> Ash.Changeset.for_update(:update, %{explanatory_note: text})
             |> Ash.update() do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, :not_found}
    end
  end
end
