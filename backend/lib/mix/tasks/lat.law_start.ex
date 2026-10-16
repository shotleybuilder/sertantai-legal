defmodule Mix.Tasks.Lat.LawStart do
  @moduledoc """
  How each law's start is decided (lat-refactor LR-33, `LawStart`): the
  treatments in force, from the register's `commencement` records.

      mix lat.law_start                       # the catalogue, with laws per treatment
      mix lat.law_start --treatment by_order  # the laws under one treatment
      mix lat.law_start --law UK_uksi_2015_1947         # one law: treatment, date, evidence, clause
      mix lat.law_start --law UK_uksi_2015_1947 --fresh # what the current code decides (from the DB rows; writes nothing)

  The register is written by `LabelRefresh` (after each parse, or `mix
  lat.relabel`); `--fresh` differs from it only when the code changed since.
  Report only.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{ChangeCollector, LawStart}

  @shortdoc "Report how each law's start is decided (LawStart treatments)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [law: :string, treatment: :string, fresh: :boolean])

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    cond do
      opts[:law] && opts[:fresh] -> fresh(opts[:law])
      opts[:law] -> stored(opts[:law])
      opts[:treatment] -> laws(opts[:treatment])
      true -> catalogue()
    end
  end

  defp catalogue do
    %{rows: rows} =
      Repo.query!("""
      SELECT effect_type, count(*) FROM lat_change_log
      WHERE collector = 'commencement' GROUP BY 1
      """)

    counts = Map.new(rows, fn [t, n] -> {t, n} end)

    for {t, dates?, rule, decided} <- LawStart.catalogue() do
      kind = if dates?, do: "dates", else: "LIMIT"

      Mix.shell().info(
        "#{String.pad_leading(to_string(Map.get(counts, to_string(t), 0)), 5)}  #{String.pad_trailing(to_string(t), 24)} #{kind}  #{rule} [#{decided}]"
      )
    end

    %{rows: [[missing]]} =
      Repo.query!("""
      SELECT count(DISTINCT law_name) FROM legal_articles a
      WHERE NOT EXISTS (SELECT 1 FROM lat_change_log c
                        WHERE c.law_name = a.law_name AND c.collector = 'commencement')
      """)

    if missing > 0,
      do:
        Mix.shell().info("#{missing} LAT laws have no commencement record yet (mix lat.relabel)")
  end

  defp laws(treatment) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT law_name, effective_from, evidence FROM lat_change_log
        WHERE collector = 'commencement' AND effect_type = $1 ORDER BY law_name
        """,
        [treatment]
      )

    for [law, date, ev] <- rows, do: Mix.shell().info("#{law}\t#{date || "-"}\t#{ev}")
  end

  defp stored(law) do
    case Repo.query!(
           """
           SELECT effect_type, effective_from, evidence, affected_ref FROM lat_change_log
           WHERE collector = 'commencement' AND law_name = $1
           """,
           [law]
         ) do
      %{rows: [[t, date, ev, text]]} ->
        explain(law, String.to_existing_atom(t), date, ev, text)

      _ ->
        Mix.shell().info("#{law}: no commencement record (mix lat.relabel --laws #{law})")
    end
  end

  defp fresh(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, text FROM legal_articles WHERE law_name = $1 ORDER BY position",
        [law]
      )

    input =
      ChangeCollector.law_start_input(
        law,
        Enum.map(rows, fn [s, t] -> %{section_id: s, text: t} end)
      )

    s = LawStart.resolve(input)
    explain(law, s.treatment, s.date, s.evidence, s.text)
  end

  defp explain(law, treatment, date, evidence, text) do
    {_, _, rule, decided} = Enum.find(LawStart.catalogue(), &(elem(&1, 0) == treatment))

    Mix.shell().info("""
    #{law}
      treatment: #{treatment}#{if LawStart.dates?(treatment), do: "", else: " (known limit)"}
      start:     #{date || "unknown"}
      evidence:  #{evidence}
      clause:    #{text || "-"}
      rule:      #{rule}
      decided:   #{decided}
    """)
  end
end
