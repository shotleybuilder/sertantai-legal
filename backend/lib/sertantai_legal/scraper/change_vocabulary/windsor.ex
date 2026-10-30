defmodule SertantaiLegal.Scraper.ChangeVocabulary.Windsor do
  @moduledoc """
  EU law the Windsor Framework keeps applying in Northern Ireland (Art 5(4),
  Annex 2), for C8 (Jason 2026-10-30: "Hold a small Windsor list"): a change
  the UK makes to such an instrument from IP completion day (2020-12-31)
  reaches Great Britain only — NI keeps the EU text (REACH Art 140, omitted
  for GB, in force in NI; CLP Art 2(17), substituted for GB).

  The list holds the family's instruments with their Annex 2 citation, each
  checked by Jason before it is relied on (`checked: true`). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Facts

  @ip_completion ~D[2020-12-31]
  @gb "E+W+S"

  # law → Annex 2 citation (the source each entry rests on)
  @annex2 %{
    "UK_eur_2008_1272" => %{
      citation: "Windsor Framework Art 5(4), Annex 2, heading 23, indent 11",
      source:
        "https://assets.publishing.service.gov.uk/media/696e5c22719d837d69afc82e/EM_COM__2025__822_Final.pdf",
      checked: false
    },
    "UK_eur_2006_1907" => %{
      citation: "Windsor Framework Art 5(4), Annex 2, heading 23 (chemicals)",
      source:
        "https://www.niassembly.gov.uk/globalassets/committee-blocks/windsor-framework-democratic-scrutiny-committee/com2025822/annex-c-ukgem-822.pdf",
      checked: false
    }
  }

  @doc "The Annex 2 entries held."
  @spec annex2() :: %{String.t() => map()}
  def annex2, do: @annex2

  @doc "True for an instrument the Windsor Framework keeps in NI (Annex 2)."
  @spec listed?(String.t() | nil) :: boolean()
  def listed?(law), do: Map.has_key?(@annex2, law)

  @doc """
  The law's changes with C8 applied: for a listed instrument, a change made
  by a UK law on or after IP completion day reaches E+W+S only.
  """
  @spec confine([Change.t()], String.t()) :: [Change.t()]
  def confine(changes, law) do
    if listed?(law), do: Enum.map(changes, &confine_one/1), else: changes
  end

  defp confine_one(%Change{resolved: %{date: %Date{} = date, by: by} = r} = c)
       when is_binary(by) do
    if uk_made?(by) and Date.compare(date, @ip_completion) != :lt,
      do: %{c | resolved: %{r | territory: gb(r.territory)}},
      else: c
  end

  defp confine_one(c), do: c

  defp gb(nil), do: @gb
  defp gb(t), do: Facts.intersect(t, @gb)

  # made by a UK legislature, not by the EU
  defp uk_made?(by), do: not String.starts_with?(by, "UK_eu")
end
