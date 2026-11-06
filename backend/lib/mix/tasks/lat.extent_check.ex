defmodule Mix.Tasks.Lat.ExtentCheck do
  @moduledoc """
  The extent and application reader's check (LAT Change Pipeline, step:
  Extent reader), for a family. The check itself is `Extent.Check` (pure);
  this task reads the DB and the read cache, and prints.

  1. **Amending laws:** every law changing the family's laws (the stored
     changes' `by`) accounted for — its extent basis as the reader reads it
     now (`AmendingLaw.Extent.read/1` + enabling powers + competence, as
     `mix lat.amending --extents` writes it): `clause` (its own default),
     `lists` (named provisions only), `application`, `powers`, `competence`,
     or `none` with why (`not_held`, `type_not_read`, `no_powers`,
     `no_clause`). Our faults: the stored `extent_rules` differ from the
     reading now (`stale`), or none stored (`not_stored`). Beside it, the
     law's own extent sentences the reader leaves unread
     (`Extent.Patterns`, by class: the catalogue's counted classes), and
     the extent sentences the catalogue misses (`Extent.Sweep`, by form:
     `AmendingLaw.SweepForm`; one in a `read:` form is a miss).
  2. **Text changes:** every stored text change (inserted, substituted,
     repealed, renumbered) of the family's laws, by where its territory
     comes from: `territory:law` (the amending law's application),
     `bound:law` (its extent at the amending provisions), `territory:feed`
     / `territory:markup` (derived), or none — and why, from the amending
     law's basis (`same` where it follows the enactment it changes;
     `unread_statement` where the law has a statement left unread, which
     withholds its provisions' bound: `Extent.Unread`).
  3. **The family gate** (Decision 1, Jason 2026-11-05): every text change
     with no bound, by cause and amending law (`Extent.Withheld`), with
     its words (the law's unread statements, or why it has no powers) and
     its reviewed status (`test/fixtures/extent_patterns/withheld.json`).
     PASS only with our faults 0, no sweep miss in a `read:` form, and
     every cause named `known:`.
  4. With `--sample FILE`, a reproducible sample of each (`--n` each,
     stratified so every kind is seen), with the words behind each, for
     checking.

  Read-only, never a fetch (the enabling cache only): the stored text (CLML), `extent_rules`, stored changes (`mix
  lat.vocabulary --build`). One law at a time.

      mix lat.extent_check --family "OH&S: Occupational"
      mix lat.extent_check --family F --sample FILE --n 50 [--seed N]
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Step

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source, as: Scope
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Check, Powers, ReadCache, Store, Withheld}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Draw
  alias SertantaiLegal.Scraper.LawRunner
  alias SertantaiLegal.Scraper.LawRunner.Guard

  @shortdoc "Every amending law's extent and every text change's territory accounted for (read-only)"

  @withheld "test/fixtures/extent_patterns/withheld.json"

  @text_ops ~w(inserted substituted repealed repealed_in_part renumbered)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [family: :string, sample: :string, n: :integer, seed: :integer, workers: :integer]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    family =
      opts[:family] ||
        Mix.raise("usage: mix lat.extent_check --family F [--sample FILE --n N --seed S]")

    laws = Scope.family_laws(family)
    changes = text_changes(laws)

    amending =
      changes |> Enum.map(& &1.by) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.sort()

    Mix.shell().info(
      "#{length(laws)} family laws with LAT; #{length(changes)} text changes by #{length(amending)} amending laws"
    )

    stored = Store.rows_for(amending)

    # several at once where the machine allows (`LawRunner.Guard`), in
    # law order after
    workers = Guard.workers(workers: opts[:workers])

    by_law =
      LawRunner.run(amending, &law_row(&1, Map.get(stored, &1)), fn _, _ -> :ok end,
        workers: workers
      )

    rows =
      for law <- amending do
        case by_law[law] do
          {:error, why} -> raise "#{law}: #{inspect(why)}"
          row -> row
        end
      end

    by_law = Map.new(rows, &{&1.law, &1})
    change_rows = Enum.map(changes, &Check.change_row(&1, by_law))

    gate = change_rows |> Withheld.items(by_law, reviewed()) |> Withheld.gate()

    step = report(rows, change_rows, gate)
    if opts[:sample], do: sample(opts, rows, change_rows)
    step
  end

  # each text change with its territory claims, by source
  defp text_changes(laws) do
    Repo.query!(
      """
      SELECT c.law_name, c.key, c.target, c.operation, c.by, c.territory,
             coalesce(array_agg(cl.source || ':' || cl.attribute || '=' || (cl.value #>> '{}')
                 ORDER BY cl.source, cl.attribute, cl.value #>> '{}')
               FILTER (WHERE cl.attribute IN ('territory', 'extent')), '{}'),
             coalesce((SELECT array_agg(DISTINCT e ->> 'v')
                FROM provision_change_claims a, jsonb_array_elements(a.value -> 'v') e
                WHERE a.change_id = c.id AND a.attribute = 'affecting'), '{}')
      FROM provision_changes c
      LEFT JOIN provision_change_claims cl ON cl.change_id = c.id
      WHERE c.law_name = ANY($1) AND c.operation = ANY($2)
      GROUP BY c.id ORDER BY c.law_name, c.target, c.key
      """,
      [laws, @text_ops]
    ).rows
    |> Enum.map(fn [law, key, target, op, by, territory, claims, affecting] ->
      %{
        affecting: affecting,
        law: law,
        key: key,
        target: target,
        operation: op,
        by: by,
        territory: territory,
        claims: claims
      }
    end)
  end

  # ── amending laws ────────────────────────────────────────────────────

  defp law_row(law, stored) do
    # the reading kept between runs (`ReadCache`, shared with the
    # catalogue and the re-read)
    reading = if Store.reads?(law), do: ReadCache.law(law)

    cond do
      not Store.reads?(law) ->
        Check.unread_law(law, "type_not_read")

      reading == nil ->
        Check.unread_law(law, "not_held")

      true ->
        e = Powers.with_powers(reading.read, law, cached: true)
        law |> Check.law_row(reading, e, stored) |> with_powers_why()
    end
  end

  # why an SI stating no default has no extent from its powers, for the
  # gate (its lists, if any, naming other provisions)
  defp with_powers_why(
         %{extent: %{default: nil, powers: nil, stated: nil, competence: nil}, law: law} = row
       ) do
    if Powers.act?(law), do: row, else: Map.put(row, :powers_why, Powers.why_none(law))
  end

  defp with_powers_why(row), do: row

  # ── report ───────────────────────────────────────────────────────────

  defp reviewed do
    case File.read(@withheld) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end

  defp report(rows, change_rows, gate) do
    t = Check.tallies(rows, change_rows)

    report_laws(rows, t)
    report_sentences(t)
    report_changes(change_rows, t)
    report_gate(gate)

    pass? = t.faults == [] and t.misses == [] and gate.pass?

    Mix.shell().info(
      "\n#{if pass?, do: "PASS", else: "FAIL"} (amending laws: our faults #{length(t.faults)}; " <>
        "sweep misses #{length(t.misses)}; no-bound causes not named: #{length(gate.failing)})"
    )

    Step.new("Extent reader", pass?, length(t.faults) + length(t.misses) + length(gate.failing))
  end

  defp report_laws(rows, t) do
    shell = Mix.shell()
    shell.info("\n#{length(rows)} amending laws — extent basis:")
    for {k, n} <- t.bases, do: shell.info("  #{pad(n)}  #{k}")

    shell.info("\nour faults (stored extent_rules against the reading now): #{length(t.faults)}")
    for {f, n} <- t.fault_kinds, do: shell.info("  #{pad(n)}  #{f}")
    for r <- Enum.take(t.faults, 15), do: shell.info("    #{r.law} #{r.fault}")
  end

  defp report_sentences(t) do
    shell = Mix.shell()

    shell.info(
      "\nthe laws' own extent sentences left unread (catalogue classes, counted): #{t.with_unread} laws"
    )

    for {c, n} <- t.unread, do: shell.info("  #{pad(n)}  #{c}")

    shell.info(
      "\nextent sentences the catalogue misses (the sweep, CV-S05a): #{length(t.uncaught)} in " <>
        "#{t.uncaught_laws} laws; " <>
        "#{length(t.misses)} in a form the reader is to read"
    )

    for {f, n} <- t.uncaught_forms, do: shell.info("  #{pad(n)}  #{f}")

    for {law, ref, s, form} <- t.misses,
        do: shell.info("    #{law} #{ref} (#{form}): #{String.slice(s, 0, 140)}")
  end

  defp report_changes(change_rows, t) do
    shell = Mix.shell()
    shell.info("\n#{length(change_rows)} text changes — territory from:")
    for {k, n} <- t.outcomes, do: shell.info("  #{pad(n)}  #{k}")

    shell.info("\ngrouped (CV-S05's table):")

    for k <- Check.groups(),
        do: shell.info("  #{pad(t.groups[k])}  #{pct(t.groups[k], t.groups.total)}  #{k}")
  end

  # the family gate: each text change with no bound, by cause and amending
  # law, reviewed in withheld.json (Decision 1, 2026-11-05)
  defp report_gate(gate) do
    shell = Mix.shell()
    counts = Enum.map_join(gate.counts, ", ", fn {k, n} -> "#{k} #{n}" end)
    shell.info("\ntext changes with no bound, by cause (#{@withheld}): #{counts}")
    shell.info("not named (widest reach first): #{length(gate.failing)}")

    for i <- gate.failing do
      shell.info("  #{pad(i.reach)}  #{i.shape} @ #{i.law}  [#{i.status || "no status"}]")
      for w <- Enum.take(i.words, 4), do: shell.info("           #{String.slice(w, 0, 200)}")
    end
  end

  defp pad(n), do: String.pad_leading(to_string(n), 5)

  defp pct(_n, 0), do: "  n/a"

  defp pct(n, total),
    do: String.pad_leading(:erlang.float_to_binary(100 * n / total, decimals: 1) <> "%", 6)

  # ── sample ───────────────────────────────────────────────────────────

  defp sample(opts, rows, change_rows) do
    n = opts[:n] || 50
    Draw.seed({opts[:seed] || 1, 2, 3})

    laws = rows |> Draw.equal_share(&Check.key/1, n) |> Enum.map(&Check.law_item/1)
    changes = change_rows |> Draw.equal_share(& &1.outcome, n) |> Enum.map(&Check.change_item/1)

    File.write!(
      opts[:sample],
      Jason.encode!(%{"laws" => laws, "changes" => changes}, pretty: true)
    )

    Mix.shell().info(
      "\nsample: #{length(laws)} laws, #{length(changes)} changes → #{opts[:sample]}"
    )
  end
end
