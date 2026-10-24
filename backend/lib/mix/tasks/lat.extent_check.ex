defmodule Mix.Tasks.Lat.ExtentCheck do
  @moduledoc """
  The extent and application reader's check (change vocabulary CV-S05), for
  a family:

  1. **Amending laws:** every law changing the family's laws (the stored
     changes' `by`) accounted for — its extent basis as the reader reads it
     now (`AmendingLaw.Extent.read/1` + enabling powers + competence, as
     `mix lat.amending --extents` writes it): `clause` (its own default),
     `lists` (named provisions only), `application`, `powers`, `competence`,
     or `none` with why (`not_held`, `type_not_read`, `no_powers`,
     `no_clause`). Our faults: the stored `extent_rules` differ from the
     reading now (`stale`), or none stored (`not_stored`). Beside it, the
     law's own extent sentences the reader leaves unread
     (`Extent.Patterns`, by class: the catalogue's counted classes).
  2. **Text changes:** every stored text change (inserted, substituted,
     repealed, renumbered) of the family's laws, by where its territory
     comes from: `territory:law` (the amending law's application),
     `bound:law` (its extent at the amending provisions), `territory:feed`
     / `territory:markup` (derived), or none — and why, from the amending
     law's basis (`same` where it follows the enactment it changes).
  3. With `--sample FILE`, a reproducible sample of each (`--n` each,
     stratified so every kind is seen), with the words behind each, for
     checking.

  Read-only, never a fetch (the enabling cache only): the stored text (CLML), `extent_rules`, stored changes (`mix
  lat.vocabulary --build`). One law at a time.

      mix lat.extent_check --family "OH&S: Occupational"
      mix lat.extent_check --family F --sample FILE --n 50 [--seed N]
  """
  use Mix.Task

  alias Mix.Tasks.Lat.Amending
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Patterns, Store}

  @shortdoc "Every amending law's extent and every text change's territory accounted for (read-only)"

  @text_ops ~w(inserted substituted repealed repealed_in_part renumbered)
  @law_unread ~w(unread:not_read unread:in_clause unread:another_default unread:application unread:list unread:other_provision)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [family: :string, sample: :string, n: :integer, seed: :integer]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    family =
      opts[:family] ||
        Mix.raise("usage: mix lat.extent_check --family F [--sample FILE --n N --seed S]")

    laws = family_laws(family)
    changes = text_changes(laws)

    amending =
      changes |> Enum.map(& &1.by) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.sort()

    Mix.shell().info(
      "#{length(laws)} family laws with LAT; #{length(changes)} text changes by #{length(amending)} amending laws"
    )

    stored = Store.rows_for(amending)

    rows =
      for {law, i} <- Enum.with_index(amending, 1) do
        if rem(i, 100) == 0, do: Mix.shell().info("  #{i}/#{length(amending)}")
        Task.async(fn -> law_row(law, Map.get(stored, law)) end) |> Task.await(:infinity)
      end

    by_law = Map.new(rows, &{&1.law, &1})
    change_rows = Enum.map(changes, &change_row(&1, by_law))

    report(rows, change_rows)
    if opts[:sample], do: sample(opts, rows, change_rows)
  end

  defp family_laws(family) do
    Repo.query!(
      """
      SELECT name FROM uk_lrt WHERE family LIKE '%' || $1 || '%'
        AND name IN (SELECT DISTINCT law_name FROM legal_articles) ORDER BY name
      """,
      [family]
    ).rows
    |> List.flatten()
  end

  # each text change with its territory claims, by source
  defp text_changes(laws) do
    Repo.query!(
      """
      SELECT c.law_name, c.key, c.target, c.operation, c.by, c.territory,
             coalesce(array_agg(cl.source || ':' || cl.attribute || '=' || (cl.value #>> '{}'))
               FILTER (WHERE cl.attribute IN ('territory', 'extent')), '{}')
      FROM provision_changes c
      LEFT JOIN provision_change_claims cl ON cl.change_id = c.id
      WHERE c.law_name = ANY($1) AND c.operation = ANY($2)
      GROUP BY c.id ORDER BY c.law_name, c.target, c.key
      """,
      [laws, @text_ops]
    ).rows
    |> Enum.map(fn [law, key, target, op, by, territory, claims] ->
      %{
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
    doc = if Store.reads?(law), do: doc(law)

    cond do
      not Store.reads?(law) ->
        %{law: law, basis: "none", why: "type_not_read", fault: nil, unread: %{}, words: nil}

      doc == nil ->
        %{law: law, basis: "none", why: "not_held", fault: nil, unread: %{}, words: nil}

      true ->
        e = doc |> Extent.read() |> Amending.with_powers(law, cached: true)
        {basis, why} = basis(e, law)

        unread =
          doc
          |> Patterns.classes()
          |> Enum.filter(fn {_, _, c} -> c in @law_unread end)
          |> Enum.frequencies_by(&elem(&1, 2))

        fault =
          cond do
            stored == nil -> "not_stored"
            MapSet.new(stored) != rows(e, law) -> "stale"
            true -> nil
          end

        %{
          law: law,
          basis: basis,
          why: why,
          fault: fault,
          unread: unread,
          extent: e,
          words: e.text || words(doc)
        }
    end
  end

  defp basis(%Extent{} = e, law) do
    cond do
      e.default -> {"clause", nil}
      e.lists != [] -> {"lists", nil}
      e.application -> {"application", nil}
      e.powers -> {"powers", nil}
      e.competence -> {"competence", nil}
      act?(law) -> {"none", "no_clause"}
      true -> {"none", "no_powers"}
    end
  end

  # the reading as the rows `mix lat.amending --extents` writes, as a set
  # (compared with the rows stored, never through `from_rows/1`: N9)
  defp rows(%Extent{} = e, law),
    do:
      e
      |> Extent.to_rows(law)
      |> Enum.map(&Map.take(&1, [:kind, :place, :items, :source_ref]))
      |> MapSet.new()

  # the law's first extent or application words, where it states none read
  defp words(doc) do
    Enum.find_value(Patterns.classes(doc), fn {ref, s, _} -> "#{ref}: #{s}" end)
  end

  defp act?(law), do: (String.split(law, "_") |> Enum.at(1)) in ~w(ukpga asp anaw asc nia apni)

  defp doc(law) do
    with [_, t, y, n] <- String.split(law, "_", parts: 4),
         [_ | _] = paths <- Path.wildcard("data/cache/clml/#{t}/#{y}/#{n}/**/data.xml.gz") do
      Doc.new(law, paths |> Enum.sort() |> Enum.map(&(&1 |> File.read!() |> :zlib.gunzip())))
    else
      _ -> nil
    end
  end

  # ── text changes ─────────────────────────────────────────────────────

  defp change_row(c, by_law) do
    has = fn prefix -> Enum.find(c.claims, &String.starts_with?(&1, prefix)) end

    outcome =
      cond do
        has.("law_text:territory=") -> "territory:law"
        has.("law_text:extent=") -> "bound:law"
        has.("feed:territory=") -> "territory:feed"
        has.("markup:territory=") -> "territory:markup"
        c.by == nil -> "none:no_amending_law"
        true -> "none:" <> none_why(Map.get(by_law, c.by))
      end

    Map.put(c, :outcome, outcome)
  end

  defp none_why(nil), do: "no_amending_law"
  defp none_why(%{basis: "none", why: why}), do: "law_" <> why
  defp none_why(%{basis: "competence"}), do: "competence_only"

  defp none_why(%{extent: %Extent{lists: lists, default: d}}) when d == nil and lists != [],
    do: "not_named"

  defp none_why(%{extent: %Extent{} = e}) do
    if Enum.any?(e.lists, &match?({:same, _, _}, &1)),
      do: "same_or_not_named",
      else: "provision_not_named"
  end

  defp none_why(_), do: "unknown"

  # ── report ───────────────────────────────────────────────────────────

  defp report(rows, change_rows) do
    shell = Mix.shell()

    shell.info("\n#{length(rows)} amending laws — extent basis:")

    for {k, n} <- rows |> Enum.frequencies_by(&key/1) |> Enum.sort_by(&(-elem(&1, 1))),
        do: shell.info("  #{pad(n)}  #{k}")

    faults = Enum.filter(rows, & &1.fault)
    shell.info("\nour faults (stored extent_rules against the reading now): #{length(faults)}")

    for {f, n} <- Enum.frequencies_by(faults, & &1.fault), do: shell.info("  #{pad(n)}  #{f}")
    for r <- Enum.take(faults, 15), do: shell.info("    #{r.law} #{r.fault}")

    unread =
      Enum.reduce(rows, %{}, fn r, acc -> Map.merge(acc, r.unread, fn _, a, b -> a + b end) end)

    with_unread = Enum.count(rows, &(&1.unread != %{}))

    shell.info(
      "\nthe laws' own extent sentences left unread (catalogue classes, counted): #{with_unread} laws"
    )

    for {c, n} <- Enum.sort_by(unread, &(-elem(&1, 1))), do: shell.info("  #{pad(n)}  #{c}")

    shell.info("\n#{length(change_rows)} text changes — territory from:")

    for {k, n} <-
          change_rows |> Enum.frequencies_by(& &1.outcome) |> Enum.sort_by(&(-elem(&1, 1))),
        do: shell.info("  #{pad(n)}  #{k}")

    shell.info(
      if faults == [],
        do: "\nPASS (amending laws: our faults 0)",
        else: "\nFAIL (our faults #{length(faults)})"
    )
  end

  defp key(%{basis: "none", why: why}), do: "none: #{why}"
  defp key(%{basis: b}), do: b

  defp pad(n), do: String.pad_leading(to_string(n), 5)

  # ── sample ───────────────────────────────────────────────────────────

  defp sample(opts, rows, change_rows) do
    n = opts[:n] || 50
    :rand.seed(:exsss, {opts[:seed] || 1, 2, 3})

    laws =
      rows
      |> stratified(&key/1, n)
      |> Enum.map(fn r ->
        %{
          "law" => r.law,
          "basis" => key(r),
          "default" => r[:extent] && r.extent.default,
          "application" => r[:extent] && r.extent.application,
          "powers" => r[:extent] && r.extent.powers,
          "competence" => r[:extent] && r.extent.competence,
          "lists" =>
            for(
              {k, p, items} <- (r[:extent] && r.extent.lists) || [],
              do: %{"kind" => to_string(k), "place" => p, "items" => Enum.take(items, 20)}
            ),
          "clause" => r.words,
          "unread" => r.unread
        }
      end)

    changes =
      change_rows
      |> stratified(& &1.outcome, n)
      |> Enum.map(fn c ->
        %{
          "law" => c.law,
          "target" => c.target,
          "operation" => c.operation,
          "by" => c.by,
          "territory" => c.territory,
          "outcome" => c.outcome,
          "claims" => c.claims,
          "key_tail" => String.slice(c.key || "", -6, 6)
        }
      end)

    File.write!(
      opts[:sample],
      Jason.encode!(%{"laws" => laws, "changes" => changes}, pretty: true)
    )

    Mix.shell().info(
      "\nsample: #{length(laws)} laws, #{length(changes)} changes → #{opts[:sample]}"
    )
  end

  # every kind seen: an equal share per kind, the rest at random
  defp stratified(items, kind, n) do
    groups = Enum.group_by(items, kind)
    share = max(div(n, max(map_size(groups), 1)), 1)

    first =
      groups
      |> Enum.sort()
      |> Enum.flat_map(fn {_, g} -> g |> Enum.shuffle() |> Enum.take(share) end)

    rest = (items -- first) |> Enum.shuffle() |> Enum.take(max(n - length(first), 0))
    Enum.take(first ++ rest, n)
  end
end
