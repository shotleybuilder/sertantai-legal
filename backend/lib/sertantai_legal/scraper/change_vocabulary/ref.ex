defmodule SertantaiLegal.Scraper.ChangeVocabulary.Ref do
  @moduledoc """
  A CLML element id as a LAT provision ref, by the law's type — the one
  place kind words are decided for the change vocabulary (CV-03; CV-01:
  "one canonical kind word per law type"). `article-28-3` is
  "art.Article 28(3)" in EU retained law and "reg.28(3)" in an NI Order;
  `regulation-14-1` "reg.14(1)"; `section-78-4BA` "s.78(4BA)"; an EU annex
  as a whole, `annex-XVII` "annex.XVII". Pure.
  """

  alias SertantaiLegal.Scraper.Commencement.Order

  @eu ~w(eur eudr eudn)

  @doc "The LAT ref for CLML id `id` in law `law_name`; nil for none."
  @spec from_clml(String.t(), String.t() | nil) :: String.t() | nil
  # an EU annex, named as a whole ("annex-XVII-part-2" → "annex.XVII"):
  # annexes, like schedules, are not parsed into LAT (a known v0.1 limit)
  def from_clml("annex-" <> rest, _law_name) do
    case Regex.run(~r/^([IVXLC]+|\d+[A-Z]*)\b/, rest) do
      [_, n] -> "annex." <> n
      nil -> nil
    end
  end

  def from_clml(id, law_name) do
    case {Order.ref(id), eu?(law_name)} do
      {nil, _} -> nil
      {"reg." <> rest, true} -> "art.Article " <> rest
      {ref, _} -> ref
    end
  end

  defp eu?(nil), do: false
  defp eu?(law_name), do: Enum.at(String.split(law_name, "_"), 1) in @eu
end
