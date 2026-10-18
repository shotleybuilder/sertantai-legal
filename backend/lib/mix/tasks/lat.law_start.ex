defmodule Mix.Tasks.Lat.LawStart do
  @moduledoc """
  How each law's start is decided (lat-refactor LR-33, `LawStart`): the
  treatments in force, from the register's `commencement` records.

      mix lat.law_start                       # the catalogue, with laws per treatment
      mix lat.law_start --treatment by_order  # the laws under one treatment
      mix lat.law_start --law UK_uksi_2015_1947         # one law: treatment, date, evidence, clause
      mix lat.law_start --law UK_uksi_2015_1947 --fresh # what the current code decides (from the DB rows; writes nothing)

  A law's explanation lists its provision-level commencements too (LR-34:
  `LawStart.provision_catalogue/0`).

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
      SELECT effect_type, count(DISTINCT law_name), count(section_id) FROM lat_change_log_rows
      WHERE collector = 'commencement' GROUP BY 1
      """)

    counts = Map.new(rows, fn [t, n, _] -> {t, n} end)
    row_counts = Map.new(rows, fn [t, _, r] -> {t, r} end)

    for {t, dates?, rule, decided} <- LawStart.catalogue() do
      kind = if dates?, do: "dates", else: "LIMIT"

      Mix.shell().info(
        "#{String.pad_leading(to_string(Map.get(counts, to_string(t), 0)), 5)}  #{String.pad_trailing(to_string(t), 24)} #{kind}  #{rule} [#{decided}]"
      )
    end

    Mix.shell().info("\nprovisions (LR-34): laws, rows")

    for {t, affects?, rule, decided} <- LawStart.provision_catalogue() do
      kind = if affects?, do: "starts", else: "LIST  "

      Mix.shell().info(
        "#{String.pad_leading(to_string(Map.get(counts, to_string(t), 0)), 5)} #{String.pad_leading(to_string(Map.get(row_counts, to_string(t), 0)), 7)}  #{String.pad_trailing(to_string(t), 22)} #{kind}  #{rule} [#{decided}]"
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
        SELECT law_name, min(effective_from), min(evidence), count(section_id)
        FROM lat_change_log_rows
        WHERE collector = 'commencement' AND effect_type = $1 GROUP BY 1 ORDER BY 1
        """,
        [treatment]
      )

    for [law, date, ev, n] <- rows,
        do: Mix.shell().info("#{law}\t#{date || "-"}\t#{ev}\t#{n} rows")
  end

  defp stored(law) do
    case Repo.query!(
           """
           SELECT effect_type, effective_from, evidence, affected_ref FROM lat_change_log
           WHERE collector = 'commencement' AND law_name = $1 AND section_id IS NULL
             AND effect_type NOT LIKE 'provision\\_%'
           """,
           [law]
         ) do
      %{rows: [[t, date, ev, text]]} ->
        explain(law, String.to_existing_atom(t), date, ev, text)
        provisions(law)

      _ ->
        Mix.shell().info("#{law}: no commencement record (mix lat.relabel --laws #{law})")
    end
  end

  # the law's provision-level commencements (LR-34): one line per sentence
  defp provisions(law) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT effect_type, effective_from, evidence, affected_ref, count(section_id)
        FROM lat_change_log_rows
        WHERE collector = 'commencement' AND law_name = $1 AND effect_type LIKE 'provision\\_%'
        GROUP BY 1, 2, 3, 4 ORDER BY 3
        """,
        [law]
      )

    for [t, date, ev, text, n] <- rows,
        do: Mix.shell().info("  #{t} #{date || "-"} (#{n} rows) #{ev}: #{text}")
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

    # the provision records the commencement collector would write (CR-06)
    for {{t, d, ev, text}, recs} <-
          law
          |> ChangeCollector.Commencement.records(input)
          |> Enum.filter(&String.starts_with?(&1.effect_type, "provision_"))
          |> Enum.group_by(&{&1.effect_type, &1.effective_from, &1.evidence, &1.affected_ref}),
        do:
          Mix.shell().info(
            "  #{t} #{d || "-"} (#{Enum.count(recs, & &1.section_id)} rows) #{ev}: #{text}"
          )
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
