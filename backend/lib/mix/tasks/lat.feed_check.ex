defmodule Mix.Tasks.Lat.FeedCheck do
  @moduledoc """
  The feed reader's check (change vocabulary CV-S02): for a scope, every
  changes-feed effect accounted for — placed on provisions we hold, or
  unplaced with a reason (`ChangeVocabulary.Placement`) — and, with
  `--sample FILE`, a reproducible random sample of effects written beside
  what the reader made of them (provisions and facts), for checking.
  Read-only: the stored feeds, CLML and LAT rows.

      mix lat.feed_check --family "OH&S: Occupational"
      mix lat.feed_check --family "OH&S: Occupational" --all              # every fault listed
      mix lat.feed_check --family "OH&S: Occupational" --sample FILE --n 50 [--seed N]
  """
  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatRef
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Placement, Ref}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Feed, Markup}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed

  @shortdoc "Every feed effect accounted for; a sample for checking (read-only)"

  # what a finer form the feed names but we don't hold tells of our parse
  @tell_tales %{
    naming: "a row we hold under a faulty name, #185",
    no_ids: "the text numbers items with no id; the parse made no row, #184",
    not_found: "gone from the text, or not there: a candidate only"
  }

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          family: :string,
          laws: :string,
          all: :boolean,
          sample: :string,
          n: :integer,
          seed: :integer
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws = scope(opts)
    {held, missing} = laws |> Enum.map(&law_results/1) |> Enum.split_with(&match?({:ok, _}, &1))
    results = Enum.flat_map(held, &elem(&1, 1))

    # the check stands on stored sources (CV-S01): a law whose feed or text
    # isn't held is reported and fails the check, never read as "not in text"
    if missing != [] do
      Mix.shell().error(
        "#{length(missing)} laws lack stored sources (run mix lat.sources --family F --fetch):"
      )

      for {:missing, law, what} <- missing, do: Mix.shell().error("  #{law}: no #{what}")
    end

    if opts[:family], do: report_unparsed(opts[:family], length(laws))

    counts =
      Enum.frequencies_by(results, fn r ->
        case r.outcome do
          {:unplaced, reason} -> reason
          o -> o
        end
      end)

    faults =
      Enum.filter(results, fn r ->
        case r.outcome do
          {:unplaced, why} -> Placement.fault?(why)
          _ -> false
        end
      end)

    Mix.shell().info("#{length(results)} effects in #{length(laws)} laws:")

    for {k, n} <- Enum.sort_by(counts, &(-elem(&1, 1))),
        do:
          Mix.shell().info("  #{n}  #{k}#{if Placement.fault?(k), do: "  (our fault)", else: ""}")

    Mix.shell().info("\nour faults: #{length(faults)}")

    for r <- if(opts[:all], do: faults, else: Enum.take(faults, 20)),
        do:
          Mix.shell().info(
            "  #{elem(r.outcome, 1)}  #{r.law} #{inspect(r.effect.affected_provisions)} refs #{inspect(r.effect.affected_refs)} → #{inspect(r.targets)}"
          )

    # the feed's words name a finer provision than we hold (EU "Art. 56
    # para. 6 Point (b)"): placed on what we hold; maybe our parse missed it
    unheld =
      for r <- results,
          c <- r.claims,
          c.source == :feed and c.attribute == :finer_unheld and c.value != nil,
          uniq: true,
          do: {r.law, c.value, r.effect.affected_provisions, r.tell_tales[c.value]}

    Mix.shell().info("\nfiner form not held (parse tell-tales): #{length(unheld)}")

    unheld
    |> Enum.group_by(fn {_, _, _, kind} -> kind end)
    |> Enum.each(fn {kind, items} ->
      Mix.shell().info("  #{kind}: #{length(items)}  (#{@tell_tales[kind]})")

      for {law, ref, text, _} <- if(opts[:all], do: items, else: Enum.take(items, 10)),
          do: Mix.shell().info("    #{law} #{ref}  (#{inspect(text)})")
    end)

    if opts[:sample], do: sample(results, opts[:sample], opts[:n] || 50, opts[:seed])

    pass? = faults == [] and missing == []
    Mix.shell().info("\n#{if pass?, do: "PASS (placement)", else: "FAIL (placement)"}")
  end

  # family laws whose LAT isn't held (not making, discarded): out of scope
  defp report_unparsed(family, in_scope) do
    [[all]] =
      Repo.query!("SELECT count(*) FROM uk_lrt WHERE family LIKE '%' || $1 || '%'", [family]).rows

    Mix.shell().info(
      "#{all} family laws; #{in_scope} hold LAT rows (in scope), #{all - in_scope} don't"
    )
  end

  defp scope(opts) do
    cond do
      opts[:family] ->
        Repo.query!(
          """
          SELECT name FROM uk_lrt WHERE family LIKE '%' || $1 || '%'
            AND name IN (SELECT DISTINCT law_name FROM legal_articles) ORDER BY name
          """,
          [opts[:family]]
        ).rows
        |> List.flatten()

      opts[:laws] ->
        String.split(opts[:laws], ",", trim: true)

      true ->
        Mix.raise(
          "usage: mix lat.feed_check --family F | --laws A,B [--all] [--sample FILE --n N]"
        )
    end
  end

  # each effect of one law: its targets and claims as the reader made them,
  # and where it lands
  defp law_results(law) do
    [_, type, year, number] = String.split(law, "_", parts: 4)

    with {:feed, {:ok, effects}} <- {:feed, ChangesFeed.fetch(type, year, number, store: :only)},
         {:text, [path | _]} <-
           {:text, Path.wildcard("data/cache/clml/#{type}/#{year}/#{number}/body/data.xml.gz")} do
      xml = path |> File.read!() |> :zlib.gunzip()
      order = Markup.order(xml)

      row_ids =
        Repo.query!("SELECT section_id, source_xml_id FROM legal_articles WHERE law_name = $1", [
          law
        ]).rows

      rows =
        Enum.map(row_ids, fn [sid, _] ->
          sid |> String.replace_prefix(law <> ":", "") |> Ref.canonical()
        end)

      # each row's XML id → its ref, as the parse named it
      xml_ids = Ref.xml_ids(law, row_ids)

      held = %{
        rows: MapSet.new(rows),
        clml:
          order |> Enum.map(&Ref.from_clml(&1, law)) |> Enum.reject(&is_nil/1) |> MapSet.new(),
        schedules?: Enum.any?(rows, &String.starts_with?(&1, "sch.")),
        xml_ids: xml_ids,
        # the effects the text marks as made (change markup only)
        marked: Placement.marked(xml)
      }

      sets =
        effects
        |> Feed.read(law, order, %{}, %{}, xml_ids, rows)
        |> Enum.group_by(fn {key, _, _} -> key |> String.split("@") |> hd() end)

      # what each finer form not held tells of our parse
      by_ref = Map.new(xml_ids, fn {x, r} -> {r, x} end)

      tell_tales =
        for {_, _, claims} <- List.flatten(Map.values(sets)),
            %{attribute: :finer_unheld, value: v} <- claims,
            v != nil,
            into: %{} do
          held_above = v |> LatRef.ancestors() |> Enum.find(&Map.has_key?(by_ref, &1))
          {v, Placement.tell_tale(v, held.rows, list_items?(xml, by_ref[held_above]))}
        end

      results =
        for e <- effects, e.effect_id != nil do
          mine = Map.get(sets, e.effect_id, [])
          targets = mine |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
          claims = mine |> Enum.flat_map(&elem(&1, 2)) |> Enum.uniq()

          %{
            law: law,
            effect: e,
            targets: targets,
            claims: claims,
            sets: mine,
            tell_tales: tell_tales,
            outcome: Placement.classify(e, targets, held)
          }
        end

      {:ok, results}
    else
      {:feed, _} -> {:missing, law, "changes feed"}
      {:text, _} -> {:missing, law, "law text (CLML body)"}
    end
  end

  # the element's own text, up to the next element with an id: does it
  # number items with no id of their own?
  defp list_items?(_xml, nil), do: false

  defp list_items?(xml, xml_id) do
    case :binary.match(xml, ~s(id="#{xml_id}")) do
      {at, len} ->
        rest = binary_part(xml, at + len, byte_size(xml) - at - len)

        own =
          case :binary.match(rest, ~s( id=")) do
            {next, _} -> binary_part(rest, 0, next)
            :nomatch -> rest
          end

        String.contains?(own, "<ListItem")

      :nomatch ->
        false
    end
  end

  # a reproducible random sample (fixed seed; `--seed N` draws another):
  # each effect as the feed states it, beside what the reader made of it
  defp sample(results, file, n, seed) do
    :rand.seed(:exsss, if(seed, do: {seed, seed, seed}, else: {2026, 10, 22}))
    picked = results |> Enum.sort_by(&{&1.law, &1.effect.effect_id}) |> Enum.take_random(n)

    rows =
      for r <- picked do
        e = r.effect

        claim = fn attr ->
          for c <- r.claims, c.source == :feed, c.attribute == attr, uniq: true, do: c.value
        end

        %{
          law: r.law,
          effect_id: e.effect_id,
          feed: %{
            type: e.type,
            affected_provisions: e.affected_provisions,
            affected_refs: e.affected_refs,
            affecting: e.affecting,
            affecting_provisions: e.affecting_provisions,
            in_force:
              Enum.map(
                e.in_force || [],
                &%{date: &1.date, prospective: &1.prospective, qualification: &1.qualification}
              ),
            in_force_date: e.in_force_date,
            effect_extent: e.effect_extent,
            territorial_application: e.territorial_application,
            savings: Map.get(e, :savings)
          },
          reader: %{
            targets: r.targets,
            outcome: inspect(r.outcome),
            operation: claim.(:operation),
            date: claim.(:date),
            by: claim.(:by),
            effect_extent: claim.(:effect_extent),
            territory: claim.(:territory),
            savings: claim.(:savings),
            partial: claim.(:partial),
            # each change the reader made of it (a stage of a staged change
            # is its own, keyed "id@date")
            changes:
              for {key, target, claims} <- r.sets do
                v = fn a -> Enum.find_value(claims, &(&1.attribute == a and {:ok, &1.value})) end

                %{
                  key: key,
                  target: target,
                  operation: elem(v.(:operation) || {:ok, nil}, 1),
                  level: elem(v.(:level) || {:ok, nil}, 1),
                  date_first: elem(v.(:date_first) || {:ok, nil}, 1),
                  date: elem(v.(:date) || {:ok, nil}, 1),
                  partial: elem(v.(:partial) || {:ok, nil}, 1),
                  effect_extent: elem(v.(:effect_extent) || {:ok, nil}, 1),
                  in_force_for: elem(v.(:in_force_for) || {:ok, nil}, 1),
                  savings: elem(v.(:savings) || {:ok, nil}, 1)
                }
              end
          }
        }
      end

    File.write!(file, Jason.encode!(rows, pretty: true))
    Mix.shell().info("\nsample of #{length(rows)} written to #{file}")
  end
end
