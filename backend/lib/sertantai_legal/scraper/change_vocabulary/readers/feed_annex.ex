defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAnnex do
  @moduledoc """
  An Annex or Appendix the changes feed names, as a whole: back matter no
  row holds (annexes, like schedules, are not parsed into LAT). An
  unnumbered Annex's piece (`annex-section-2.2.1`, `annex-part-5`,
  `annex-SECTION`: Decision 2003/33, Regulation 1191/2014) is `annex`, as
  an unnumbered Schedule is `sch`; a numbered one keeps its number, a
  small letter too (`annex-IVa` → `annex.IVa`: Directive 2008/98); an
  Appendix its own (`appendix-A` → `appendix.A`). Pure.
  """

  # the kinds of piece an Annex holds: after "annex-", the Annex has no number
  @pieces ~w(section part paragraph chapter point table)

  @number ~r/^(?:[IVXLC]+|\d+)[A-Za-z]*$/

  @doc "The ref for Annex or Appendix id `id`; nil for any other id, or one that names neither a number nor a piece."
  @spec ref(String.t()) :: String.t() | nil
  def ref("annex-" <> rest), do: rest |> first() |> annex()
  def ref("appendix-" <> rest), do: rest |> first() |> appendix()
  def ref(_id), do: nil

  defp first(rest), do: rest |> String.split("-") |> hd()

  defp annex(first) do
    cond do
      String.downcase(first) in @pieces -> "annex"
      String.match?(first, @number) -> "annex." <> first
      true -> nil
    end
  end

  defp appendix(""), do: nil
  defp appendix(first), do: "appendix." <> first
end
