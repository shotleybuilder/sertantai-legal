defmodule SertantaiLegal.Scraper.Amendment.Reader.EuSpelling do
  @moduledoc """
  An EU law's rule targets spelt as its rows are: the reader keys an
  Article `art.10(3)` within, the rows (and `ChangeVocabulary.Ref`) name
  it `art.Article 10(3)`, so every EU rule had dropped as held by no row
  (4,454 rules on 54 EU laws: Amending-law reader: EU article naming,
  2026-11-27). A range's ends are spelt each (`art.Article 22..art.Article
  25`, as `LatRef` reads them). Kind `:article` is EU law only. Pure.
  """

  alias SertantaiLegal.Scraper.Amendment.Rule

  @doc "The rules with each EU law's (`kind: :article`) targets spelt `art.Article N…`."
  @spec rows_spelling([Rule.t()], [map()]) :: [Rule.t()]
  def rows_spelling(rules, laws) do
    eu = for %{kind: :article, law_name: l} <- laws, into: MapSet.new(), do: l
    Enum.map(rules, &spelt(&1, eu))
  end

  @doc "One target spelt as an EU row: `art.10(3)` → `art.Article 10(3)`; any other as it is."
  @spec target(String.t()) :: String.t()
  def target(t), do: Regex.replace(~r/(?<![\w.])art\.(?=\d)/u, t, "art.Article ")

  defp spelt(%Rule{amends: amends, targets: targets} = rule, eu) do
    if MapSet.member?(eu, amends),
      do: %{rule | targets: Enum.map(targets, &target/1)},
      else: rule
  end
end
