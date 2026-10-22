defmodule Mix.Tasks.Lat.Sources do
  @moduledoc """
  Sources held (change vocabulary CV-S01): for a scope, the documents its
  labels need against what the local store holds — by category, every
  missing or stale document named with its status, and each law's feed
  against the register's change statistics. Read-only: it never fetches.

      mix lat.sources --family "OH&S: Occupational"
      mix lat.sources --laws UK_uksi_2010_404,UK_ukpga_1974_37
      mix lat.sources --family "OH&S: Occupational" --all   # every failure listed

  Statuses: `held` (fresh), `absent` (legislation.gov.uk has none: a stored
  404), `not_fetched`, `incomplete` (a feed missing pages), `stale` (older
  than legislation.gov.uk's latest, or with no date fetched over 30 days
  ago: `ClmlStore.fresh?`). The rules are `Sources`'; this task reads the
  facts.
  """
  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{EffectKind, LatScope, Sources}
  alias SertantaiLegal.Scraper.EnactedBy.EnablingCache
  alias SertantaiLegal.Scraper.LegislationGovUk.{ChangesFeed, ClmlStore}

  @shortdoc "Sources a scope's labels need, against what is held (read-only)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [family: :string, laws: :string, all: :boolean])

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws = scope(opts)
    Mix.shell().info("#{length(laws)} laws in scope")

    facts = Enum.map(laws, &law_facts/1)

    amenders =
      facts
      |> Enum.flat_map(&Sources.needs(&1, %{}))
      |> Enum.filter(&(&1.category == :amending))
      |> Enum.map(& &1.law)
      |> Enum.uniq()

    amending = Map.new(amenders, &{&1, amending_facts(&1)})

    needs =
      facts |> Enum.flat_map(&Sources.needs(&1, amending)) |> Enum.uniq_by(&{&1.law, &1.part})

    valid = valid_dates(Enum.map(needs, & &1.law))
    statuses = Enum.map(needs, &{&1, status(&1, valid)})

    # each feed counted as the register counts it
    comparisons =
      for f <- facts,
          do:
            f.law
            |> Sources.register_counts(f.effects)
            |> Map.merge(%{law: f.law, register: f.register})

    print(Sources.report(statuses, comparisons), opts)
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
        Mix.raise("usage: mix lat.sources --family F | --laws A,B [--all]")
    end
  end

  # one law in scope: its documents, its feed's effects (store only), the
  # laws its notes cite, the register's change statistics
  defp law_facts(law) do
    [_, type, year, number] = String.split(law, "_", parts: 4)
    slash = "#{type}/#{year}/#{number}"

    effects =
      case ChangesFeed.fetch(type, year, number, store: :only) do
        {:ok, es} ->
          Enum.map(
            es,
            &%{affecting: &1.affecting, kind: EffectKind.kind(&1.type, nil), type: &1.type}
          )

        _ ->
          []
      end
      |> Enum.reject(&is_nil(&1.affecting))

    cited =
      Repo.query!(
        """
        SELECT DISTINCT coalesce(citation_law, changed_by) FROM amendment_annotations
        WHERE law_name = $1 AND code_type = 'amendment' AND coalesce(citation_law, changed_by) ~ '^UK_'
        """,
        [law]
      ).rows
      |> List.flatten()

    register =
      case Repo.query!(
             ~s(SELECT "🔻_stats_affected_by_count", "🔻_stats_affected_by_laws_count" FROM uk_lrt WHERE name = $1),
             [law]
           ).rows do
        [[e, l]] when is_integer(e) -> %{effects: e, laws: l}
        _ -> nil
      end

    %{
      law: law,
      scope: LatScope.paths(slash, LatScope.get(law)),
      effects: effects,
      cited: cited,
      register: register
    }
  end

  # an amending SI's enabling powers (cached, never fetched); an amending
  # Act's commencing orders (its own feed, store only)
  defp amending_facts(law) do
    [_, type, year, number] = String.split(law, "_", parts: 4)

    enabling =
      case EnablingCache.cached(law) do
        {:ok, ps} -> ps |> Enum.map(& &1["law"]) |> Enum.uniq()
        :none -> []
      end

    commenced_by =
      case ChangesFeed.fetch(type, year, number, store: :only) do
        {:ok, es} ->
          for e <- es,
              EffectKind.kind(e.type, nil) == "commenced",
              is_binary(e.affecting),
              e.affecting != law,
              uniq: true,
              do: e.affecting

        _ ->
          []
      end

    %{enabling: enabling, commenced_by: commenced_by}
  end

  defp valid_dates(laws) do
    Repo.query!("SELECT name, md_dct_valid_date FROM uk_lrt WHERE name = ANY($1)", [
      Enum.uniq(laws)
    ]).rows
    |> Map.new(fn [n, d] -> {n, d} end)
  end

  defp status(%{part: :introduction, law: law}, _valid) do
    case EnablingCache.cached(law) do
      {:ok, _} -> :held
      :none -> :not_fetched
    end
  end

  defp status(%{part: :feed, law: law}, _valid) do
    [_, type, year, number] = String.split(law, "_", parts: 4)

    case ChangesFeed.fetch(type, year, number, store: :only) do
      {:ok, _} ->
        # a feed carries no valid date: fresh while recently fetched
        case ClmlStore.get(ChangesFeed.page_path(type, year, number, 1)) do
          {:ok, _, meta} -> if ClmlStore.fresh?(meta, nil), do: :held, else: :stale
          _ -> :held
        end

      _ ->
        case ClmlStore.get(ChangesFeed.page_path(type, year, number, 1)) do
          :none -> :not_fetched
          {:missing, _} -> :absent
          _ -> :incomplete
        end
    end
  end

  defp status(%{part: part, law: law}, valid) do
    [_, type, year, number] = String.split(law, "_", parts: 4)

    path =
      case part do
        :body -> "/#{type}/#{year}/#{number}/body/data.xml"
        :schedules -> "/#{type}/#{year}/#{number}/schedules/data.xml"
        path when is_binary(path) -> path
      end

    case ClmlStore.get(path) do
      {:ok, _, meta} -> if ClmlStore.fresh?(meta, Map.get(valid, law)), do: :held, else: :stale
      {:missing, _} -> :absent
      :none -> :not_fetched
    end
  end

  defp print(r, opts) do
    Mix.shell().info("\nneeded against held, by category:")

    for c <- r.order, counts = r.counts[c], counts != nil do
      total = counts |> Map.values() |> Enum.sum()

      Mix.shell().info(
        "  #{c}: #{total} — " <>
          Enum.map_join(Enum.sort(counts), ", ", fn {s, n} -> "#{s} #{n}" end)
      )
    end

    Mix.shell().info("\nfailures: #{length(r.failures)}")

    for f <- if(opts[:all], do: r.failures, else: Enum.take(r.failures, 20)),
        do:
          Mix.shell().info(
            "  #{f.status}  #{f.category}  #{f.law} #{inspect(f.part)}  (for #{f.for})"
          )

    Mix.shell().info(
      "\nfeeds differing from the register's change statistics: #{length(r.register_differences)}"
    )

    for d <-
          if(opts[:all], do: r.register_differences, else: Enum.take(r.register_differences, 20)),
        do:
          Mix.shell().info(
            "  #{d.law}: effects #{d.effects} vs register #{d.register.effects}; laws #{d.laws} vs #{d.register.laws}"
          )

    Mix.shell().info("\n#{if r.pass, do: "PASS", else: "FAIL"}")
  end
end
