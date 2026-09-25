defmodule Mix.Tasks.Making.Resolve do
  @moduledoc """
  Re-resolve `is_making` corpus-wide through `Legal.Making` (QQ-01a).

  Dry run by default: reports what would change and writes a CSV of every
  `is_making` flip. Nothing is written to the database without `--apply`.

      mix making.resolve                          # dry run, all laws
      mix making.resolve --names UK_a,UK_b        # dry run, named laws
      mix making.resolve --country uk             # dry run, UK partition only
      mix making.resolve --exclude UK_a,UK_b      # skip laws held for review
      mix making.resolve --apply                  # snapshot, then write

  With `--apply`, the Making columns are first copied to
  `making_backfill_snapshot_<YYYYMMDD>` (created once per day), double-encoded
  `making_detection_signals` strings are decoded, then each
  changed law is written through `Making.record/3` with `changed_by: "backfill"`,
  so every change is in `record_change_log`.

  Report: `data/reports/making/resolve-<timestamp>.csv`.
  """

  use Mix.Task

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Legal.Making
  alias SertantaiLegal.Legal.Making.Backfill
  alias SertantaiLegal.Repo

  @shortdoc "Re-resolve is_making through the Making resolver (dry run by default)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [apply: :boolean, names: :string, exclude: :string, country: :string]
      )

    Mix.Task.run("app.start")

    names = opts[:names] && String.split(opts[:names], ",", trim: true)
    exclude = opts[:exclude] && String.split(opts[:exclude], ",", trim: true)
    now = DateTime.utc_now()
    rows = Backfill.load_rows(names: names, exclude: exclude, country: opts[:country])
    plans = Backfill.plan_rows(rows, now)
    flips = Enum.filter(plans, &flip?/1)

    report(rows, plans, flips)
    path = write_csv(flips, now)
    Mix.shell().info("\nFlip report: #{path}")

    if opts[:apply], do: apply!(plans, now), else: Mix.shell().info("\nDry run: nothing written.")
  end

  defp flip?(%{row: row, attrs: attrs}), do: (row.is_making || false) != attrs.is_making

  defp report(rows, plans, flips) do
    Mix.shell().info("Laws: #{length(rows)}; Making state changes: #{length(plans)}")
    Mix.shell().info("is_making flips: #{length(flips)}\n")

    flips
    |> Enum.frequencies_by(fn %{row: r, attrs: a} ->
      {inspect(r.is_making), a.is_making, a.is_making_source}
    end)
    |> Enum.sort_by(fn {_k, n} -> -n end)
    |> Enum.each(fn {{old, new, source}, n} ->
      Mix.shell().info("  #{old} → #{new}  by #{source}: #{n}")
    end)

    Mix.shell().info("\nDecisions by source (all changed laws):")

    plans
    |> Enum.frequencies_by(& &1.attrs.is_making_source)
    |> Enum.each(fn {source, n} -> Mix.shell().info("  #{source}: #{n}") end)
  end

  defp write_csv(flips, now) do
    dir = Path.join(["data", "reports", "making"])
    File.mkdir_p!(dir)
    stamp = Calendar.strftime(now, "%Y%m%dT%H%M")
    path = Path.join(dir, "resolve-#{stamp}.csv")

    header = "name,country,title,live,old_is_making,new_is_making,source,reason\n"

    lines =
      Enum.map(flips, fn %{row: r, attrs: a} ->
        [
          r.name,
          r.country,
          r.title_en,
          r.live,
          r.is_making,
          a.is_making,
          a.is_making_source,
          a.is_making_reason
        ]
        |> Enum.map_join(",", &csv_field/1)
      end)

    File.write!(path, [header, Enum.intersperse(lines, "\n"), "\n"])
    path
  end

  defp csv_field(nil), do: ""

  defp csv_field(value) do
    s = to_string(value)

    if String.contains?(s, [",", "\"", "\n"]),
      do: "\"#{String.replace(s, "\"", "\"\"")}\"",
      else: s
  end

  defp apply!(plans, now) do
    snapshot = "making_backfill_snapshot_" <> Calendar.strftime(now, "%Y%m%d")

    Repo.query!("""
    CREATE TABLE IF NOT EXISTS #{snapshot} AS
    SELECT id, name, country, is_making, is_making_source, is_making_reason,
           is_making_decided_at, making_review, making_enrichment_verdict,
           making_classification, making_classification_source,
           making_detection_signals, duty_type, record_change_log
    FROM legal_register
    """)

    repaired = Backfill.repair_signal_encoding!()
    Mix.shell().info("\nSnapshot: #{snapshot}. Decoded #{repaired} double-encoded signals.")
    Mix.shell().info("Applying #{length(plans)} changes…")

    {ok, errors} =
      plans
      |> Enum.map(fn %{row: row, evidence: evidence} ->
        with {:ok, law} <- Ash.get(LegalRegister, row.id),
             {:ok, _} <- Making.record(law, evidence, "backfill") do
          :ok
        else
          error -> {row.name, error}
        end
      end)
      |> Enum.split_with(&(&1 == :ok))

    Mix.shell().info("Applied: #{length(ok)}; errors: #{length(errors)}")

    Enum.each(Enum.take(errors, 20), fn {name, e} ->
      Mix.shell().error("  #{name}: #{inspect(e)}")
    end)
  end
end
