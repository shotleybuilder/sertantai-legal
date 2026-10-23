defmodule SertantaiLegal.Scraper.ChangeVocabulary.Ref do
  @moduledoc """
  A CLML element id as a LAT provision ref, by the law's type — the one
  place kind words are decided for the change vocabulary (CV-03; CV-01:
  "one canonical kind word per law type"). `article-28-3` is
  "art.Article 28(3)" in EU retained law and "reg.28(3)" in an NI Order;
  `rule-2-da` "reg.2(da)";
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

  # a rule is named as a regulation ("rule-2-da" → "reg.2(da)"), as the
  # parse names Rules' rows (catalogue review H)
  def from_clml("rule-" <> rest, law_name), do: from_clml("regulation-" <> rest, law_name)

  def from_clml(id, law_name) do
    case {Order.ref(id), eu?(law_name)} do
      {nil, _} -> nil
      {"reg." <> rest, true} -> "art.Article " <> rest
      {ref, _} -> ref
    end
  end

  @doc """
  A ref in one spelling: any Unicode space (U+00A0 between "Article" and
  its number, as the parse names some EU articles: #182) is an ordinary
  space. Every name the vocabulary reads from LAT goes through it, so the
  readers agree today and nothing moves when the parse is fixed.
  """
  @spec canonical(String.t()) :: String.t()
  def canonical(ref), do: String.replace(ref, ~r/\p{Zs}/u, " ")

  @doc """
  Each LAT row's XML id → its ref (canonical, versions share their base:
  "section-23" → "s.23"), from `[section_id, source_xml_id]` rows — the
  parse's own naming, for the feed reader. One id can name several rows,
  where legislation.gov.uk repeats it (SI 1272/2008 gives `article-38-1`
  to Art. 38(A1), (1) and (3)): the row the id names by itself
  (`from_clml/2`) wins, else one without a `#n` repeat mark.
  """
  @spec xml_ids(String.t(), [[String.t() | nil]]) :: %{String.t() => String.t()}
  def xml_ids(law_name, rows) do
    rows
    |> Enum.reject(fn [_, x] -> is_nil(x) end)
    |> Enum.group_by(&List.last/1, fn [sid, _] ->
      sid
      |> String.replace_prefix(law_name <> ":", "")
      |> String.replace(~r/\[[^\]]+\]$/, "")
      |> canonical()
    end)
    |> Map.new(fn {x, refs} -> {x, pick(Enum.uniq(refs), x, law_name)} end)
  end

  defp pick([ref], _x, _law_name), do: ref

  defp pick(refs, x, law_name) do
    own = from_clml(x, law_name)

    if own in refs,
      do: own,
      else: Enum.find(refs, hd(refs), &(not String.contains?(&1, "#")))
  end

  defp eu?(nil), do: false
  defp eu?(law_name), do: Enum.at(String.split(law_name, "_"), 1) in @eu
end
