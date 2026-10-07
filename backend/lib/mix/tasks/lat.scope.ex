defmodule Mix.Tasks.Lat.Scope do
  @moduledoc """
  Scoped LAT (#166, `Scraper.LatScope`).

      # A law's relevant part (never narrows; logged in the scope's history)
      mix lat.scope --law UK_ukpga_2006_46 --add part/15/chapter/5 --purpose relevance \\
        --reason "QQ: environmental reporting" [--create] [--parse]

      # Enabling-extent scopes for a fetch batch (after `mix live.enabling --batch N`):
      # non-Making parent Acts without LAT get LAT of just the cited sections
      mix lat.scope --enabling --batch 1a            # dry run
      mix lat.scope --enabling --batch 1a --apply    # set scopes and parse

      # Relevance scopes for large Acts with no family (Jason, 2026-10-07):
      # keep each Part an in-family SI is made under, plus named fragments
      mix lat.scope --relevance [--min-rows 3000] [--law UK_ukpga_2006_46]   # dry run
      mix lat.scope --relevance --law UK_ukpga_2016_25 --add part/1 --apply

      # Exclude a law with no EHS link from LAT (reviewed case by case):
      # archive + discard its LAT, mark the scope excluded so no parse brings it back
      mix lat.scope --exclude --law UK_ukpga_1989_40 --reason "no EHS/HR provisions"

  `--relevance --apply` works on one `--law` at a time (each Act's scope is
  approved before its rows go): the whole LAT is archived to the NAS, the
  scope narrowed (`LatScope.narrow!/3`), and the law re-parsed with cause
  `scope`, so fractalaw sees the removed rows in `lat-changes`. Dropping
  enriched rows outside the scope is the point of a narrow, so the re-parse
  is forced past `LatPersister`'s enrichment gate; the archive keeps them,
  enrichment included, and their count is reported. If the parse fails, the
  previous scope is restored.

  `--create` scopes a law that holds no LAT (an unscoped law with LAT is
  whole and is never narrowed here). Parsing goes through `LatStagedParser`,
  which fetches only the scoped fragments.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatArchive
  alias SertantaiLegal.Scraper.LatScope
  alias SertantaiLegal.Scraper.LatScope.Relevance
  alias SertantaiLegal.Scraper.LatScope.RelevanceData
  alias SertantaiLegal.Scraper.LatStagedParser
  alias SertantaiLegal.Scraper.LiveStatus.EffectsBackfill

  @shortdoc "Set a law's scoped LAT fragments (#166)"

  @enabling_cache Path.join(["data", "cache", "enabling"])

  # Fragments named per Act, on top of the Parts its in-family SIs cite.
  # Each is confirmed with Jason before it is applied (2026-10-07).
  @named %{
    # directors' report: SECR and non-financial reporting (QQ)
    "UK_ukpga_2006_46" => ["part/15/chapter/5"],
    # QQ register (LEGAL & GOVERNANCE): the interception offence and
    # interception for business purposes; the rest is state powers
    "UK_ukpga_2016_25" => ["part/1", "part/2/chapter/2"],
    # QQ register (13 sites): spectrum licensing, apparatus, approval
    "UK_ukpga_2006_36" => ["part/2", "part/3", "part/4"],
    # QQ register (1 site): communications, encryption-key notices
    "UK_ukpga_2000_23" => ["part/I", "part/III"],
    # QQ register (FIREARMS, 10 sites): corrosives, possession, firearms
    "UK_ukpga_2019_17" => ["part/1", "part/4", "part/6"]
  }

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          law: :string,
          add: :string,
          purpose: :string,
          reason: :string,
          create: :boolean,
          parse: :boolean,
          enabling: :boolean,
          batch: :string,
          apply: :boolean,
          relevance: :boolean,
          exclude: :boolean,
          min_rows: :integer
        ]
      )

    Mix.Task.run("app.start")

    cond do
      opts[:relevance] -> relevance(opts)
      opts[:exclude] -> exclude(opts)
      opts[:enabling] -> enabling(opts)
      true -> one(opts)
    end
  end

  defp one(opts) do
    law = opts[:law] || Mix.raise("Give --law")
    fragments = String.split(opts[:add] || Mix.raise("Give --add"), ",", trim: true)

    result =
      LatScope.set!(law,
        fragments: fragments,
        purpose: opts[:purpose] || "relevance",
        reason: opts[:reason],
        set_by: "mix lat.scope",
        create: opts[:create] || false
      )

    Mix.shell().info("#{law}: #{inspect(result)}")
    if opts[:parse] && is_map(result), do: parse(law)
  end

  defp enabling(opts) do
    label = opts[:batch] || Mix.raise("Give --batch N")

    names =
      EffectsBackfill.batch(EffectsBackfill.target_laws(), label) ||
        Mix.raise("No batch #{label}")

    wanted =
      for name <- names,
          {:ok, json} <- [File.read(Path.join(@enabling_cache, name <> ".json"))],
          p <- Jason.decode!(json),
          reduce: %{} do
        acc ->
          Map.update(
            acc,
            p["law"],
            LatScope.fragments_for(p),
            &Enum.uniq(&1 ++ LatScope.fragments_for(p))
          )
      end

    %{rows: rows} =
      Repo.query!(
        "SELECT name, coalesce(is_making, false), coalesce(lat_count, 0), lat_scope FROM legal_register WHERE country = 'uk' AND name = ANY($1)",
        [Map.keys(wanted)]
      )

    targets =
      for [name, making, lat, scope] <- rows,
          not making,
          lat == 0 or scope != nil,
          do: {name, Map.fetch!(wanted, name)}

    Mix.shell().info(
      "Batch #{label}: #{length(targets)} non-Making parents to scope (enabling extent)"
    )

    for {name, fragments} <- targets,
        do: Mix.shell().info("  #{name}: #{Enum.join(fragments, ", ")}")

    if opts[:apply] do
      for {name, fragments} <- targets do
        case LatScope.set!(name,
               fragments: fragments,
               purpose: "enabling_extent",
               reason: "enabling provisions of batch #{label} SIs",
               set_by: "mix lat.scope --enabling",
               create: true
             ) do
          %{} -> parse(name)
          {:unchanged, _} -> :ok
          other -> Mix.shell().info("  #{name}: #{inspect(other)}")
        end
      end
    else
      Mix.shell().info("\nDry run: nothing written.")
    end
  end

  defp relevance(opts) do
    laws =
      case opts[:law] do
        nil ->
          RelevanceData.candidates(opts[:min_rows] || 3000)

        law ->
          [%{name: law, title: "", rows: length(RelevanceData.rows(law))}]
      end

    if opts[:apply] && (opts[:law] == nil or length(laws) != 1),
      do: Mix.raise("--apply needs one --law (each Act's scope is approved first)")

    extra = String.split(opts[:add] || "", ",", trim: true)
    plans = Enum.map(laws, &relevance_plan(&1, extra))

    for plan <- plans, do: report_plan(plan)

    case {opts[:apply], plans} do
      {true, [%{fragments: [_ | _]} = plan]} -> apply_plan(plan)
      {true, [_]} -> Mix.shell().error("No fragments: nothing to apply")
      _ -> Mix.shell().info("\nDry run: nothing written.")
    end
  end

  defp relevance_plan(%{name: name} = law, extra) do
    citations = RelevanceData.citations(name)
    cited = citations |> Enum.flat_map(fn {_, _, sections} -> sections end) |> Enum.uniq()
    named = Map.get(@named, name, []) ++ extra
    fragments = Relevance.fragments(RelevanceData.section_parts(name), cited, named)

    {kept, dropped} =
      name |> RelevanceData.rows() |> Enum.split_with(&Relevance.kept?(&1, fragments))

    Map.merge(law, %{
      citations: citations,
      named: named,
      fragments: fragments,
      kept: length(kept),
      enriched_dropped: Enum.count(dropped, & &1.enriched)
    })
  end

  defp report_plan(plan) do
    Mix.shell().info("\n#{plan.name} #{plan.title} (#{plan.rows} rows)")

    for {si, family, sections} <- plan.citations do
      cited = if sections == [], do: "no sections found", else: Enum.join(sections, ", ")
      Mix.shell().info("  #{si} [#{family}]: #{cited}")
    end

    if plan.named != [], do: Mix.shell().info("  named: #{Enum.join(plan.named, ", ")}")

    case plan.fragments do
      [] ->
        Mix.shell().info("  → no EHS link found and nothing named: review this Act")

      fragments ->
        Mix.shell().info(
          "  → scope #{Enum.join(fragments, ", ")}: ~#{plan.kept} of #{plan.rows} rows kept; " <>
            "#{plan.enriched_dropped} enriched rows outside it (archived on --apply)"
        )
    end
  end

  defp apply_plan(%{name: name, fragments: fragments} = plan) do
    previous = LatScope.get(name)

    with {:ok, ref} <- LatArchive.archive(name) do
      Mix.shell().info("  archived #{name} → #{ref}")

      LatScope.narrow!(name, fragments,
        purpose: "relevance",
        reason:
          "#166 relevance: Parts cited by in-family SIs + named (#{Enum.join(plan.named, ", ")})",
        set_by: "mix lat.scope --relevance"
      )

      case LatStagedParser.parse(name, cause: "scope", force: true) do
        {:ok, %{has_errors: false, lat: lat}} ->
          Mix.shell().info("  parsed #{name}: #{lat.inserted} rows (was #{plan.rows})")

        other ->
          restore_scope(name, previous)
          Mix.shell().error("  #{name}: parse failed, scope restored: #{inspect(other)}")
      end
    else
      {:error, reason} ->
        Mix.shell().error("  #{name}: archive failed, nothing changed: #{reason}")
    end
  end

  defp exclude(opts) do
    law = opts[:law] || Mix.raise("Give --law")
    reason = opts[:reason] || Mix.raise("Give --reason")
    previous = LatScope.get(law)

    LatScope.exclude!(law, reason: reason, set_by: "mix lat.scope --exclude")

    case LatArchive.discard(law, "not_relevant") do
      {:ok, ref} ->
        Mix.shell().info("#{law}: excluded from LAT; archived → #{inspect(ref)}")

      {:error, e} ->
        restore_scope(law, previous)
        Mix.shell().error("#{law}: discard failed, scope restored: #{e}")
    end
  end

  defp restore_scope(name, previous) do
    Repo.query!(
      "UPDATE legal_register SET lat_scope = $2 WHERE country = 'uk' AND name = $1",
      [name, previous]
    )
  end

  defp parse(law) do
    case LatStagedParser.parse(law, cause: "scope") do
      {:ok, %{has_errors: false, lat: lat}} ->
        Mix.shell().info("  parsed #{law}: #{lat.inserted} rows")

      {:ok, r} ->
        Mix.shell().error("  #{law}: #{r[:error]}")

      {:error, e} ->
        Mix.shell().error("  #{law}: #{e}")
    end
  end
end
