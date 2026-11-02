defmodule SertantaiLegal.Scraper.ChangeVocabulary.Primary do
  @moduledoc """
  The primary sources a law's build reads (CV-03, CV-07; moved out of `mix
  lat.vocabulary`, CV-06): the amending laws' rules (stored where fresh,
  else read now), their commencement rules, the affecting laws' extent
  clauses, the law's own commencement and row structure, its continuing
  orders and its feed pages' ids and savings.

  Reads the database and the local CLML store; writes nothing.
  """

  require Logger

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Store, as: ExtentStore

  # the amending laws' own text: their stored rules, and each one's
  # commencement rules
  @doc "The build's options from the primary sources for `law` and its feed `effects`."
  @spec primary(String.t(), [map()]) :: keyword()
  def primary(law, effects) do
    stored_rules = SertantaiLegal.Scraper.Amendment.Store.for_law(law)

    # the stored rules stand only where read by this reader from the text
    # held now; a stale amending law is read again here, for this law, at
    # the provisions this law's notes and feed point to (never stale rules:
    # run time, 2026-10-25)
    rules = fresh_rules(law, effects, stored_rules)

    # each amending law's commencement rules: the rules' sources and the
    # feed's affecting laws
    # … and the laws the notes cite: a change no source dates is dated from
    # its amending law at the provision its note names (CV-07)
    cited =
      Repo.query!(
        """
        SELECT DISTINCT coalesce(citation_law, changed_by) FROM amendment_annotations
        WHERE law_name = $1 AND code_type = 'amendment' AND coalesce(citation_law, changed_by) ~ '^UK_'
        """,
        [law]
      ).rows
      |> List.flatten()

    commencement =
      (Enum.map(rules, & &1.source.law) ++ Enum.map(effects, & &1.affecting) ++ cited)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Map.new(&{&1, SertantaiLegal.Scraper.Commencement.Store.for_law(&1)})

    title = title(law)

    # each affecting law's own extent clause (Act or SI): read into `extent_rules`,
    # else from its CLML held (named: `mix lat.amending --extents`)
    acts =
      effects
      |> Enum.map(& &1.affecting)
      |> Kernel.++(Enum.map(rules, & &1.source.law))
      |> Kernel.++(cited)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.filter(&ExtentStore.reads?/1)

    stored = ExtentStore.for_laws(acts)

    # (the reading kept between runs: `Extent.ReadCache`, run time 2026-10-25)
    unread =
      for law <- acts,
          not Map.has_key?(stored, law),
          reading = SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache.law(law),
          reading != nil,
          into: %{},
          do: {law, reading.read}

    if unread != %{},
      do:
        Logger.info(
          "  #{map_size(unread)} Acts' extent clauses not in extent_rules (read from CLML): mix lat.amending --extents --law #{law}"
        )

    extents = Map.merge(stored, unread)

    own = SertantaiLegal.Scraper.Commencement.Store.for_law(law)

    # the law's row structure, for its own commencement (Parts, Chapters,
    # document order: CV-S04)
    own_context =
      Repo.query!(
        "SELECT section_id, part, chapter FROM legal_articles WHERE law_name = $1 ORDER BY position",
        [law]
      ).rows
      |> Enum.map(fn [s, p, c] -> %{section_id: s, part: p, chapter: c} end)
      |> SertantaiLegal.Scraper.Commencement.OwnClause.context()

    # when it was passed (an Act's Royal Assent), for its own sunset
    passed =
      Enum.find_value(own, fn r ->
        with :act_enactment <- r.treatment, {:date, d} <- r.when, do: d, else: (_ -> nil)
      end)

    # the orders continuing it, from their CLML held (the feed names them:
    # "continued until …"), each with its territory
    continuations =
      for law_c <-
            effects
            |> Enum.filter(&(&1.type =~ ~r/\bcontinu/i))
            |> Enum.map(& &1.affecting)
            |> Enum.uniq(),
          [_, t, y, n] <- [String.split(law_c, "_", parts: 4)],
          [path | _] <- [Path.wildcard("data/cache/clml/#{t}/#{y}/#{n}/body/data.xml.gz")] do
        doc =
          SertantaiLegal.Scraper.AmendingLaw.Doc.new(law_c, [
            path |> File.read!() |> :zlib.gunzip()
          ])

        %{
          law: law_c,
          text:
            doc.roots
            |> Enum.map(&SertantaiLegal.Scraper.AmendingLaw.Doc.text/1)
            |> Enum.join(" "),
          territory: SertantaiLegal.Scraper.LawTerritory.territory(law_c, register_extent(law_c))
        }
      end

    pages = feed_pages(law)

    [
      rules: rules,
      commencement: commencement,
      extents: extents,
      extents_unread: unread |> Map.keys() |> Enum.sort(),
      passed: passed,
      act_title: title && String.replace(title, ~r/\s*\(repealed[^)]*\)\s*$/i, ""),
      effect_uris: SertantaiLegal.Scraper.ChangeVocabulary.FeedUris.from_pages(pages),
      effect_savings: SertantaiLegal.Scraper.ChangeVocabulary.FeedSavings.from_pages(pages),
      continuations: continuations,
      own_commencement: own,
      own_context: own_context,
      title: title
    ]
  end

  # the law's amendment rules: stored where the amending law's index is
  # fresh, else read now from the text held (`Amendment.ReadLaw`)
  defp fresh_rules(law, effects, stored) do
    alias SertantaiLegal.Scraper.Amendment.{Index, ReadLaw}
    alias SertantaiLegal.Scraper.AmendingLaw.Pointer

    by_feed = for e <- effects, ReadLaw.text_effect?(e), do: e

    amending =
      (Enum.map(stored, & &1.source.law) ++ Enum.map(by_feed, & &1.affecting))
      |> Enum.filter(&(is_binary(&1) and &1 =~ ~r/^UK_/))
      |> Enum.uniq()

    stale = Enum.reject(amending, &Index.fresh?(&1, Index.get(&1)))
    ref = if stale != [], do: ReadLaw.law_ref(law)

    read =
      for a <- stale, doc = ReadLaw.doc(a), doc != nil do
        refs =
          ReadLaw.note_refs(a, ReadLaw.notes(a, law)) ++
            for(
              e <- by_feed,
              e.affecting == a,
              r <- Pointer.refs_in(e.affecting_provisions),
              do: r
            )

        {rules, _ids} = ReadLaw.rules(doc, [ref], refs)
        rules
      end

    # never read by the read pass, or read by other code or from other text
    {unread, outdated} = Enum.split_with(stale, &(Index.get(&1) == nil))

    if stale != [],
      do:
        Logger.info(
          "  #{length(stale)} amending laws read from their text: #{length(unread)} not read by the read pass, " <>
            "#{length(outdated)} with stale stored rules (mix lat.amending --read)"
        )

    Enum.reject(stored, &(&1.source.law in stale)) ++ List.flatten(read)
  end

  # the law's stored feed pages, raw: the re-keyed effects (`FeedUris`,
  # CV-S07 round 2) and savings given as ranges (`FeedSavings`, CV-S08)
  defp feed_pages(law) do
    [_, type, year, number] = String.split(law, "_", parts: 4)

    type
    |> SertantaiLegal.Scraper.LegislationGovUk.ClmlStore.feed_files(year, number)
    |> Enum.map(&(&1 |> File.read!() |> :zlib.gunzip()))
  end

  # the law's title: its own place (a devolved law's territory)
  @doc "The law's title in the register."
  @spec title(String.t()) :: String.t() | nil
  def title(law) do
    case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law]) do
      %{rows: [[t]]} -> t
      _ -> nil
    end
  end

  defp register_extent(law) do
    case SertantaiLegal.Repo.query!(
           "SELECT title_en, geo_extent FROM uk_lrt WHERE name = $1 LIMIT 1",
           [law]
         ) do
      %{rows: [[t, g]]} -> SertantaiLegal.Scraper.LawTerritory.extent(t, g)
      _ -> nil
    end
  end
end
