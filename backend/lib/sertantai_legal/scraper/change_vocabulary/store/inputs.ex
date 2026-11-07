defmodule SertantaiLegal.Scraper.ChangeVocabulary.Store.Inputs do
  @moduledoc """
  What a law's change build read, fingerprinted (CV-S11): recorded on each
  `changes_built` event by the build, and taken again by `mix lat.stale` so
  `ChangeStaleness` can say which input moved.

  - `:lat_rows` — the law's LAT rows the changes are placed on (section
    id, extent, XML id), digested
  - `:law_text` — the stored law text's content (`ClmlStore.digest/2`)
  - `:feed` — the stored changes-feed pages' content
  - `:amendment_rules`, `:commencement_rules`, `:extent_rules` — each
    store's latest `read_at` over the rows the build reads: the amendment
    rules on the law; the commencement rules commencing the law or a law
    whose commencement it read (`sources`: the amending laws, their rules'
    sources, the laws its notes cite); the extent rules of those laws and
    its affecting laws

  `:affecting` and `:commencement_sources` are recorded too, so the rules
  can be fingerprinted again without a build. `readers/3` says which of
  those readings were made by other reader code (#193): `read_at` moves
  only when a reading is written, so a reader fix that is never re-run
  leaves the build looking current. DB and file reads only.

  (#193: the commencement fingerprint read rules *from* `sources`, not
  rules commencing them, so a re-read order moved nothing; the extent
  fingerprint missed the rules' sources and cited laws the build reads.)
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion, as: ExtentReadVersion
  alias SertantaiLegal.Scraper.Commencement.ReadVersion, as: CommencementReadVersion
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @keys [:lat_rows, :law_text, :feed, :amendment_rules, :commencement_rules, :extent_rules]

  @doc "The fingerprints `of/3` takes (the lists it records beside them aside)."
  @spec keys() :: [atom()]
  def keys, do: @keys

  @doc "The fingerprint of `law`'s inputs, given the laws the build read beside it."
  @spec of(String.t(), [String.t()], [String.t()]) :: map()
  def of(law, affecting, sources) do
    %{
      lat_rows: lat_rows(law),
      law_text: law |> ClmlStore.law_files() |> digest(),
      feed: law |> feed_files() |> digest(),
      amendment_rules:
        latest("SELECT max(read_at) FROM amendment_rules WHERE amends = $1", [law]),
      commencement_rules:
        latest("SELECT max(read_at) FROM commencement_rules WHERE commences = ANY($1)", [
          commenced(law, sources)
        ]),
      extent_rules:
        latest("SELECT max(read_at) FROM extent_rules WHERE source_law = ANY($1)", [
          extended(affecting, sources)
        ]),
      affecting: Enum.sort(affecting),
      commencement_sources: Enum.sort(sources)
    }
  end

  @doc """
  The readers whose readings the build read are by other reader code, or
  were read before the code was recorded (`reader_version` nil):
  `:commencement_reader` (`Commencement.ReadVersion`), `:extent_reader`
  (`Extent.ReadVersion`). Taken now, never recorded. The amending laws' own
  rules need no reason: the build reads a stale one from its text
  (`Primary.primary/2`).
  """
  @spec readers(String.t(), [String.t()], [String.t()]) :: [
          :commencement_reader | :extent_reader
        ]
  def readers(law, affecting, sources) do
    [
      {:commencement_reader,
       other_code?("commencement_rules WHERE commences = ANY($1)", [
         commenced(law, sources),
         CommencementReadVersion.current()
       ])},
      {:extent_reader,
       other_code?("extent_rules WHERE source_law = ANY($1)", [
         extended(affecting, sources),
         ExtentReadVersion.current()
       ])}
    ]
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  defp commenced(law, sources), do: Enum.uniq([law | sources])
  defp extended(affecting, sources), do: Enum.uniq(affecting ++ sources)

  defp other_code?(from, params) do
    Repo.query!(
      "SELECT EXISTS (SELECT 1 FROM #{from} AND reader_version IS DISTINCT FROM $2)",
      params
    ).rows == [[true]]
  end

  defp lat_rows(law) do
    Repo.query!(
      """
      SELECT md5(string_agg(section_id || '|' || coalesce(extent_code, '') || '|' ||
                            coalesce(source_xml_id, ''), ',' ORDER BY section_id))
      FROM legal_articles WHERE law_name = $1 AND section_id IS NOT NULL
      """,
      [law]
    ).rows
    |> hd()
    |> hd()
  end

  defp feed_files(law) do
    case String.split(law, "_", parts: 4) do
      [_, type, year, number] -> ClmlStore.feed_files(type, year, number)
      _ -> []
    end
  end

  # nil when nothing is held, so "absent then and now" hasn't moved
  defp digest([]), do: nil

  defp digest(files) do
    files
    |> Enum.map(&:erlang.md5(File.read!(&1)))
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp latest(sql, params) do
    case Repo.query!(sql, params).rows do
      [[%DateTime{} = t]] -> DateTime.to_iso8601(t)
      [[%NaiveDateTime{} = t]] -> NaiveDateTime.to_iso8601(t)
      _ -> nil
    end
  end
end
