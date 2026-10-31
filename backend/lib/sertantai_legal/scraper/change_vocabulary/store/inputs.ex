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
    store's latest `read_at` over the rows the build reads: the law's own,
    its commencing laws' (`sources`), its amending laws' (`affecting`)

  `:affecting` and `:commencement_sources` are recorded too, so the rules
  can be fingerprinted again without a build. DB and file reads only.
  """

  alias SertantaiLegal.Repo
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
        latest(
          "SELECT max(read_at) FROM commencement_rules WHERE commences = $1 OR source_law = ANY($2)",
          [law, sources]
        ),
      extent_rules:
        latest("SELECT max(read_at) FROM extent_rules WHERE source_law = ANY($1)", [affecting]),
      affecting: Enum.sort(affecting),
      commencement_sources: Enum.sort(sources)
    }
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
