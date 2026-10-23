defmodule Mix.Tasks.Lat.MarkupCheck do
  @moduledoc """
  The markup reader's check (change vocabulary CV-S03): for a scope, every
  change in the revised text's markup accounted for — placed on rows we
  hold, or unplaced with a reason (`ChangeVocabulary.MarkupPlacement`);
  the markup's keys against the law's changes feed (a count for CV-S07);
  and, with `--sample FILE`, a reproducible random sample of changes beside
  what the reader made of them, for checking. Read-only: the stored law
  text and feeds, and LAT rows. One law at a time.

      mix lat.markup_check --family "OH&S: Occupational"
      mix lat.markup_check --family "OH&S: Occupational" --all     # every fault listed
      mix lat.markup_check --family "OH&S: Occupational" --sample FILE --n 50 [--seed N]
  """
  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.{MarkupPatterns, MarkupPlacement, Ref}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed

  @shortdoc "Every markup change accounted for; a sample for checking (read-only)"

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
    shell = Mix.shell()

    # the check stands on stored sources (CV-S01)
    if missing != [] do
      shell.error(
        "#{length(missing)} laws lack stored sources (mix lat.sources --family F --fetch):"
      )

      for {:missing, law, what} <- missing, do: shell.error("  #{law}: no #{what}")
    end

    {changes, notes} = Enum.split_with(results, &(&1.change.elements != []))

    report("changes (change elements)", changes, opts)
    report("note placements (an effect placed by its note ref only)", notes, opts)

    shell.info("\nmarkup keys against the feed (changes; a count for CV-S07):")

    for {k, n} <- changes |> Enum.frequencies_by(& &1.feed) |> Enum.sort(),
        do: shell.info("  #{n}  #{k}")

    if opts[:sample], do: sample(changes, opts[:sample], opts[:n] || 50, opts[:seed])

    faults = Enum.filter(changes, &fault?/1)
    pass? = faults == [] and missing == []
    shell.info("\n#{if pass?, do: "PASS (placement)", else: "FAIL (placement)"}")
  end

  defp fault?(%{outcome: {:unplaced, why}}), do: MarkupPlacement.fault?(why)
  defp fault?(_), do: false

  defp report(title, results, opts) do
    shell = Mix.shell()
    laws = results |> Enum.map(& &1.law) |> Enum.uniq() |> length()
    shell.info("\n#{length(results)} #{title} in #{laws} laws:")

    counts =
      Enum.frequencies_by(results, fn r ->
        case r.outcome do
          {:unplaced, reason} -> reason
          o -> o
        end
      end)

    for {k, n} <- Enum.sort_by(counts, &(-elem(&1, 1))),
        do:
          shell.info("  #{n}  #{k}#{if MarkupPlacement.fault?(k), do: "  (our fault)", else: ""}")

    faults = Enum.filter(results, &fault?/1)
    shell.info("our faults: #{length(faults)}")

    for r <- if(opts[:all], do: faults, else: Enum.take(faults, 20)),
        do:
          shell.info(
            "  #{elem(r.outcome, 1)}  #{r.law} #{short(r.change.key)} at #{inspect(Enum.uniq(Enum.map(r.ids, &List.last(&1, nil))))} → #{inspect(r.targets)}"
          )
  end

  # an effect id shortened for the screen
  defp short("key-" <> hex), do: "key-…" <> String.slice(hex, -6, 6)
  defp short(id), do: id

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
          "usage: mix lat.markup_check --family F | --laws A,B [--all] [--sample FILE --n N]"
        )
    end
  end

  # each change of one law: what the reader made of it and where it lands
  defp law_results(law) do
    [_, type, year, number] = String.split(law, "_", parts: 4)

    with {:text, [path | _]} <-
           {:text, Path.wildcard("data/cache/clml/#{type}/#{year}/#{number}/body/data.xml.gz")},
         {:feed, {:ok, effects}} <- {:feed, ChangesFeed.fetch(type, year, number, store: :only)} do
      doc =
        path
        |> File.read!()
        |> :zlib.gunzip()
        |> SweetXml.parse(quiet: true, namespace_conformant: false)

      row_ids =
        Repo.query!("SELECT section_id, source_xml_id FROM legal_articles WHERE law_name = $1", [
          law
        ]).rows

      rows =
        MapSet.new(row_ids, fn [sid, _] ->
          sid |> String.replace_prefix(law <> ":", "") |> Ref.canonical()
        end)

      xml_ids = Ref.xml_ids(law, row_ids)

      held = %{rows: rows, schedules?: Enum.any?(rows, &String.starts_with?(&1, "sch."))}
      feed_ids = for e <- effects, e.effect_id != nil, into: MapSet.new(), do: e.effect_id

      sets = doc |> Markup.read(law, xml_ids) |> Enum.group_by(&elem(&1, 0))

      results =
        for {key, change} <- doc |> MarkupPatterns.changes() |> Enum.sort_by(&elem(&1, 0)) do
          mine = Map.get(sets, key, []) |> Enum.sort_by(fn {k, t, _} -> {k, t} end)
          targets = mine |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
          ids = Enum.map(change.elements ++ change.refs, &ids/1)

          %{
            law: law,
            change: change,
            sets: mine,
            targets: targets,
            ids: ids,
            feed: MarkupPlacement.against_feed(key, feed_ids),
            outcome: MarkupPlacement.classify(targets, ids, held)
          }
        end

      {:ok, results}
    else
      {:text, _} -> {:missing, law, "law text (CLML body)"}
      {:feed, _} -> {:missing, law, "changes feed"}
    end
  end

  # the ids of the elements above an element, outermost first
  defp ids(%{stack: stack}) do
    for {:xmlElement, _, _, _, _, _, _, attrs, _, _, _, _} <- stack,
        id =
          Enum.find_value(attrs, fn
            {:xmlAttribute, :id, _, _, _, _, _, _, v, _} -> to_string(v)
            _ -> nil
          end),
        id != nil,
        do: id
  end

  # in a P1group's Title: the provision the group holds (its first child
  # with an id), which the reader places the change on
  defp heading_of(%{stack: stack}) do
    names = Enum.map(stack, &elem(&1, 1))

    with i when i != nil <-
           names
           |> Enum.with_index()
           |> Enum.filter(&(elem(&1, 0) == :P1group))
           |> List.last()
           |> then(&(&1 && elem(&1, 1))),
         :Title <- Enum.at(names, i + 1) do
      group = Enum.at(stack, i)

      Enum.find_value(elem(group, 8), fn
        {:xmlElement, _, _, _, _, _, _, attrs, _, _, _, _} ->
          Enum.find_value(attrs, fn
            {:xmlAttribute, :id, _, _, _, _, _, _, v, _} -> to_string(v)
            _ -> nil
          end)

        _ ->
          nil
      end)
    else
      _ -> nil
    end
  end

  # a reproducible random sample (fixed seed; `--seed N` draws another):
  # each change as the markup states it, beside what the reader made of it
  defp sample(results, file, n, seed) do
    :rand.seed(:exsss, if(seed, do: {seed, seed, seed}, else: {2026, 10, 23}))
    picked = results |> Enum.sort_by(&{&1.law, &1.change.key}) |> Enum.take_random(n)

    rows =
      for r <- picked do
        %{
          law: r.law,
          key: r.change.key,
          markup:
            for e <- r.change.elements do
              %{
                element: e.kind,
                change_id: e.change_id,
                provision_ids: ids(e),
                # a heading change belongs to the provision its group holds
                heading_of: heading_of(e),
                attributes:
                  Map.take(e.attrs, ~w(RetainText SubstitutionRef Extent CommentaryRef)),
                text:
                  e.stack
                  |> List.last()
                  |> SertantaiLegal.Scraper.AmendingLaw.Doc.text()
                  |> String.slice(0, 160)
              }
            end,
          note_refs: Enum.map(r.change.refs, &ids/1),
          reader: %{
            outcome: inspect(r.outcome),
            feed: r.feed,
            changes:
              for {key, target, claims} <- r.sets do
                %{key: key, target: target, claims: Map.new(claims, &{&1.attribute, &1.value})}
              end
          }
        }
      end

    File.write!(file, Jason.encode!(rows, pretty: true))
    Mix.shell().info("\nsample of #{length(rows)} written to #{file}")
  end
end
