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
      mix lat.feed_check --family "OH&S: Occupational" --sample FILE --n 50
  """
  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Placement, Ref}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Feed, Markup}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed

  @shortdoc "Every feed effect accounted for; a sample for checking (read-only)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [family: :string, laws: :string, all: :boolean, sample: :string, n: :integer]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws = scope(opts)
    results = Enum.flat_map(laws, &law_results/1)

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

    if opts[:sample], do: sample(results, opts[:sample], opts[:n] || 50)

    Mix.shell().info("\n#{if faults == [], do: "PASS (placement)", else: "FAIL (placement)"}")
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

    with {:ok, effects} <- ChangesFeed.fetch(type, year, number, store: :only),
         [path | _] <- Path.wildcard("data/cache/clml/#{type}/#{year}/#{number}/body/data.xml.gz") do
      xml = path |> File.read!() |> :zlib.gunzip()
      order = Markup.order(xml)

      rows =
        Repo.query!("SELECT section_id FROM legal_articles WHERE law_name = $1", [law]).rows
        |> List.flatten()
        |> Enum.map(&String.replace_prefix(&1, law <> ":", ""))

      held = %{
        rows: MapSet.new(rows),
        clml:
          order |> Enum.map(&Ref.from_clml(&1, law)) |> Enum.reject(&is_nil/1) |> MapSet.new(),
        schedules?: Enum.any?(rows, &String.starts_with?(&1, "sch."))
      }

      sets =
        effects
        |> Feed.read(law, order)
        |> Enum.group_by(fn {key, _, _} -> key |> String.split("@") |> hd() end)

      for e <- effects, e.effect_id != nil do
        mine = Map.get(sets, e.effect_id, [])
        targets = mine |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
        claims = mine |> Enum.flat_map(&elem(&1, 2)) |> Enum.uniq()

        %{
          law: law,
          effect: e,
          targets: targets,
          claims: claims,
          outcome: Placement.classify(e, targets, held)
        }
      end
    else
      _ -> []
    end
  end

  # a reproducible random sample (fixed seed): each effect as the feed
  # states it, beside what the reader made of it
  defp sample(results, file, n) do
    :rand.seed(:exsss, {2026, 10, 22})
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
            partial: claim.(:partial)
          }
        }
      end

    File.write!(file, Jason.encode!(rows, pretty: true))
    Mix.shell().info("\nsample of #{length(rows)} written to #{file}")
  end
end
