defmodule SertantaiLegal.Scraper.Amendment.Reader.NewNumbers do
  @moduledoc """
  A substitution's quote that numbers more than it replaces: only what the
  instruction names is substituted; every other number the quote makes is
  inserted — the target never held it as it now reads, so its law's
  commencement never reached it.

  - New siblings (CV-S09 round 5: ERRA 2013 s.69(3), "For subsection (2)
    substitute— (2) … (2A) … (2B) …" on HSWA s.47).
  - None of the quote's numbers the one named (round 6: SI 2014/469, "For
    paragraph (1) substitute— (1A) … (1D)" on SI 1998/494 reg.6).
  - The children under the number named: the quote alone is evidence they
    are new (Jason 2026-10-30: SI 2014/469 substituting SI 1977/500
    reg.4(1)(g) with a (g)(i), (ii); SI 2026/484 CLP Art 37(6)(b), (9)(d)).

  Pure.
  """

  alias SertantaiLegal.Scraper.Amendment.Rule
  alias SertantaiLegal.Scraper.LatRef

  @doc """
  The quoted rule split by what the instruction's own rules (`named`) name
  as substituted: those targets stay substituted, every other number the
  quote makes is inserted. Unchanged when it isn't a substitution or
  nothing is named.
  """
  @spec split(Rule.t() | nil, [Rule.t() | nil]) :: [Rule.t()]
  def split(nil, _named), do: []

  def split(%Rule{operation: :substituted} = quoted, named) do
    replaced =
      for %Rule{operation: :substituted, targets: ts} <- named, t <- ts, uniq: true, do: t

    {kept, added} = Enum.split_with(quoted.targets, &named?(&1, replaced))

    cond do
      replaced == [] or added == [] -> [quoted]
      kept == [] -> [%{quoted | operation: :inserted}]
      true -> [%{quoted | targets: added, operation: :inserted}, %{quoted | targets: kept}]
    end
  end

  def split(quoted, _named), do: [quoted]

  # the target is one the instruction names (a range named covers it)
  defp named?(target, replaced), do: Enum.any?(replaced, &LatRef.covers?(&1, target))
end
