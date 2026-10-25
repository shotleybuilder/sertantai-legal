defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Powers do
  @moduledoc """
  Where a law stating no extent of its own extends (CV-07, CV-S05): an SI
  as far as its enabling powers (each enabling provision placed by its
  parent Act's own extent clause), else — like a devolved legislature's
  Act — as far as its legislature's competence. Moved out of `mix
  lat.amending` (run time, 2026-10-25), where `mix lat.extent_check` also
  called it.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  @doc """
  An SI stating no extent extends as far as its enabling powers: its
  enabling provisions (its introduction: `EnablingCache`, fetched once
  on a miss), each placed by its parent Act's own extent clause (read
  first in this run, `extents/1`). CV-07.
  `cached: true` (the check, `mix lat.extent_check`; `--extents
  --cached`): the enabling cache only, never a fetch (CV-S05).
  """
  @spec with_powers(Extent.t(), String.t(), keyword()) :: Extent.t()
  def with_powers(e, law, opts \\ [])

  # (with lists too: "Regulation 12 and Schedule 10 extend to England and
  # Wales and Scotland" names those only; the rest extend as far as the
  # powers — SI 2019/758, CV-S05)
  def with_powers(%Extent{default: nil} = e, law, opts) do
    if Extent.Store.reads?(law) and not act?(law) do
      provisions = enabling(law, opts[:cached])
      parents = provisions |> Enum.map(& &1["law"]) |> Enum.uniq()
      e = %{e | powers: Extent.from_powers(provisions, Extent.Store.for_laws(parents))}

      # with neither, a devolved instrument extends as far as its
      # legislature's competence
      if e.powers, do: e, else: %{e | competence: Extent.competence(law)}
    else
      # a devolved legislature's Act stating none extends as far as its
      # competence too (asp, nia, anaw, asc; CV-S05: agent round 1)
      if act?(law), do: %{e | competence: Extent.competence(law)}, else: e
    end
  end

  def with_powers(e, _law, _opts), do: e

  @doc "An SI's enabling provisions: the enabling cache only (`cached`), else fetched once on a miss."
  @spec enabling(String.t(), boolean() | nil) :: [map()]
  def enabling(law, true) do
    case SertantaiLegal.Scraper.EnactedBy.EnablingCache.cached(law) do
      {:ok, ps} -> ps
      :none -> []
    end
  end

  def enabling(law, _),
    do: SertantaiLegal.Scraper.EnactedBy.EnablingCache.get(law, retry_empty: true)

  @doc "Whether the law is an Act (UK or devolved)."
  @spec act?(String.t()) :: boolean()
  def act?(law),
    do: (String.split(law, "_") |> Enum.at(1)) in ~w(ukpga asp anaw asc nia apni)
end
