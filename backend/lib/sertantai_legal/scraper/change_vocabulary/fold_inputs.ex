defmodule SertantaiLegal.Scraper.ChangeVocabulary.FoldInputs do
  @moduledoc """
  A fingerprint of what a switched law's label fold reads besides its
  built changes (#194; the changes and the start come as the build's
  output digest, `ChangeDigest.build/2`): its provision rows as the fold
  reads them (section_id, extent, Part, Chapter, kind), its made date and
  title (`uk_lrt`), its CLML body and the known-limit rows named in it
  (`KnownLimits`). `LabelRefresh` records it on `labels_refreshed`, and
  `LabelStaleness` compares it with today's (`:fold_inputs`), so labels
  whose rows, register record, text or known limits moved show as stale.

  The known-limit rows' kept periods are the timeline's own, so not an
  input. Reads the database, the CLML store and the known-limit files.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.KnownLimits

  @doc "16 hex characters over `law`'s fold inputs now."
  @spec of(String.t()) :: String.t()
  def of(law) do
    {articles(law), register(law), body(law), known_limits(law)}
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp articles(law) do
    %{rows: [[md5]]} =
      Repo.query!(
        "SELECT md5(string_agg(concat_ws('~', section_id, extent_code, part, chapter, section_type), '|' " <>
          "ORDER BY section_id, extent_code, part, chapter, section_type)) " <>
          "FROM legal_articles WHERE law_name = $1",
        [law]
      )

    md5
  end

  defp register(law) do
    case Repo.query!(
           "SELECT coalesce(md_made_date, md_enactment_date), title_en FROM uk_lrt WHERE name = $1 LIMIT 1",
           [law]
         ) do
      %{rows: [[made, title]]} -> {made, title}
      _ -> nil
    end
  end

  # the body's text, not its gzip bytes: a re-store of the same text is no move
  defp body(law) do
    [_, type, year, num] = String.split(law, "_", parts: 4)

    case Path.wildcard("data/cache/clml/#{type}/#{year}/#{num}/body/data.xml.gz") do
      [path | _] -> :crypto.hash(:md5, path |> File.read!() |> :zlib.gunzip())
      [] -> nil
    end
  end

  defp known_limits(law) do
    KnownLimits.sids() |> Enum.filter(&String.starts_with?(&1, law <> ":")) |> Enum.sort()
  end
end
