defmodule Mix.Tasks.Lat.LabelChecked do
  @moduledoc """
  The switch-over's checked rows against the current labels (CV-06,
  `ChangeVocabulary.Checked`): each accepted row matching or changed, and
  the rows left to fix, known, to decide or upstream. `--list` names each
  changed and to-fix row. Read-only.

      mix lat.label_checked [--list]
      mix lat.label_checked --accept "LAW|SID,LAW|SID" --why "…"   # the current label becomes the expected one

  `--accept` writes the current periods of the rows named into the fixture
  as accepted, with `--why` on each (the evidence; reviewed in the diff).
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Checked, LabelPeriods, LabelSource}

  @shortdoc "The switch-over's checked rows against the current labels (read-only)"
  @fixture "test/fixtures/change_vocabulary/switch_checked.json"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [list: :boolean, accept: :string, why: :string])

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    rows = @fixture |> File.read!() |> Jason.decode!() |> Map.fetch!("rows")

    current =
      for law <- rows |> Enum.map(& &1["law"]) |> Enum.uniq(),
          rs = LabelSource.rows(law),
          is_list(rs),
          r <- rs,
          into: %{},
          do: {"#{law}|#{r.sid}", LabelPeriods.periods(law, r.sid, r.periods, r.reaching)}

    results = Checked.compare(rows, current)
    counts = Enum.frequencies_by(results, &elem(&1, 0))
    Mix.shell().info("#{length(rows)} checked rows: #{inspect(counts)}")

    pass? = Map.keys(counts) -- [:match, :known, :upstream] == []
    Mix.shell().info(if pass?, do: "PASSED", else: "NOT PASSED")

    if ids = opts[:accept], do: accept(String.split(ids, ",", trim: true), current, opts[:why])

    if opts[:list] do
      for {kind, r} <- results,
          kind in [:changed, :missing, :to_fix, :to_decide],
          do: Mix.shell().info("#{kind}\t#{r["law"]}\t#{r["section_id"]}\t#{r["note"]}")
    end
  end

  defp accept(ids, current, why) do
    why || Mix.raise("--accept needs --why (the evidence)")
    doc = @fixture |> File.read!() |> Jason.decode!()

    rows =
      for r <- doc["rows"] do
        id = "#{r["law"]}|#{r["section_id"]}"

        case {id in ids, Map.fetch(current, id)} do
          {true, {:ok, now}} ->
            # a row keeps what its checker found, beside the why
            note =
              case r["status"] do
                "to_fix" -> "#{why} (was to fix: #{r["note"]})"
                "accepted" -> "#{why} (was: #{r["note"]})"
                _ -> why
              end

            %{r | "status" => "accepted", "periods" => Checked.norm(now), "note" => note}

          {true, :error} ->
            Mix.raise("#{id}: no current label")

          _ ->
            r
        end
      end

    File.write!(@fixture, Jason.encode!(%{doc | "rows" => rows}, pretty: true) <> "\n")
    Mix.shell().info("accepted #{length(ids)} rows")
  end
end
