defmodule SertantaiLegal.Scraper.Amendment.Reader.NewNumbers do
  @moduledoc """
  A substitution's quote that numbers more than it replaces (CV-S09 round
  5: ERRA 2013 s.69(3), "For subsection (2) substitute— (2) … (2A) … (2B)
  …" on HSWA s.47): only what the instruction names, and what lies under
  it, is substituted; a number the quote adds besides is inserted — the
  target never held it, so its law's commencement never reached it. Pure.
  """

  alias SertantaiLegal.Scraper.Amendment.Rule
  alias SertantaiLegal.Scraper.LatRef

  @doc """
  The quoted rule split by what the instruction's own rules (`named`) name
  as substituted: those targets (and those under them) stay substituted,
  the rest are a second, inserted rule. Unchanged when it isn't a
  substitution or nothing is named.
  """
  @spec split(Rule.t() | nil, [Rule.t() | nil]) :: [Rule.t()]
  def split(nil, _named), do: []

  def split(%Rule{operation: :substituted} = quoted, named) do
    replaced =
      for %Rule{operation: :substituted, targets: ts} <- named, t <- ts, uniq: true, do: t

    {kept, added} = Enum.split_with(quoted.targets, &under?(&1, replaced))

    cond do
      replaced == [] or added == [] or kept == [] -> [quoted]
      true -> [%{quoted | targets: kept}, %{quoted | targets: added, operation: :inserted}]
    end
  end

  def split(quoted, _named), do: [quoted]

  # the target, or a provision holding it, is one the instruction names
  defp under?(target, replaced) do
    target
    |> LatRef.ancestors()
    |> Enum.any?(fn a -> Enum.any?(replaced, &LatRef.covers?(&1, a)) end)
  end
end
