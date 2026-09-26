defmodule Mix.Tasks.Lat.PdfBacklog do
  @moduledoc """
  Work the PDF backlog: laws legislation.gov.uk publishes only as scanned
  PDFs (issue #165). See `SertantaiLegal.Scraper.PdfBacklog.Batch`.

      mix lat.pdf_backlog                         # status of every backlog law
      mix lat.pdf_backlog --run --dry-run         # parse ready/stale transcripts, persist nothing
      mix lat.pdf_backlog --run                   # parse + persist LAT for ready/stale laws
      mix lat.pdf_backlog --run --law UK_uksi_1979_791

  The manual step is writing `<backlog>/<law>/transcript.md` from the PDF
  (markup: `SertantaiLegal.Scraper.PdfBacklog.Transcript`). After a run, hand
  the laws to fractalaw for enrichment as usual.
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.PdfBacklog.Batch

  @shortdoc "Status / LAT parse of the scanned-PDF backlog"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [run: :boolean, dry_run: :boolean, law: :string])

    Mix.Task.run("app.start")

    laws = Batch.status()

    Enum.each(
      laws,
      &Mix.shell().info("#{String.pad_trailing(to_string(&1.state), 17)} #{&1.law_name}")
    )

    if opts[:run] do
      laws
      |> Enum.filter(&(&1.state in [:ready, :stale] or &1.law_name == opts[:law]))
      |> Enum.filter(&(is_nil(opts[:law]) or &1.law_name == opts[:law]))
      |> Enum.each(&run_one(&1.law_name, opts[:dry_run] || false))
    end
  end

  defp run_one(law, dry_run) do
    Mix.shell().info("\n#{law}#{if dry_run, do: " (dry run)", else: ""}")

    case Batch.run(law, dry_run: dry_run) do
      {:ok, %{rows: rows, qa: qa, persisted: persisted}} ->
        Mix.shell().info("  #{rows} LAT rows#{if persisted, do: " persisted", else: ""}")
        Enum.each(qa, &Mix.shell().info("  QA: #{&1}"))

      {:error, reason} ->
        Mix.shell().error("  #{reason}")
    end
  end
end
