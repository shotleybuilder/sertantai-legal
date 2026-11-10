defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Powers do
  @moduledoc """
  Where a law stating no extent of its own extends (CV-07, CV-S05): an SI
  as far as its enabling powers (each enabling provision placed by its
  parent Act's own extent clause, or, where the parent states none, by the
  extent legislation.gov.uk states on the provision: Decision 2,
  2026-11-05), else — like a devolved legislature's
  Act — as far as its legislature's competence. Moved out of `mix
  lat.amending` (run time, 2026-10-25), where `mix lat.extent_check` also
  called it.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Lookup, StatedExtent}
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

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
      parents = Extent.Store.for_laws(parents)
      e = %{e | powers: Extent.from_powers(provisions, parents, stated(provisions, parents))}

      # with neither, a devolved instrument extends as far as its
      # legislature's competence
      if e.powers, do: e, else: %{e | competence: Extent.competence(law)}
    else
      # an Act stating no clause and no lists: the extent stated on the
      # whole Act (Decision 3, 2026-11-05); a devolved legislature's Act
      # stating none extends as far as its competence too (asp, nia, anaw,
      # asc; CV-S05: agent round 1)
      if act?(law),
        do: %{e | stated: whole_act(e, law), competence: Extent.competence(law)},
        else: e
    end
  end

  def with_powers(e, _law, _opts), do: e

  defp whole_act(%Extent{lists: []}, law),
    do: law |> ClmlStore.law_docs() |> StatedExtent.uniform()

  defp whole_act(_e, _law), do: nil

  # the extent legislation.gov.uk states on each enabling provision of a
  # parent stating no default (Decision 2, 2026-11-05: `Extent.StatedExtent`;
  # used only where the parent names the provision nowhere, Decision 2,
  # 2026-11-09: `Lookup.from_powers/3`)
  defp stated(provisions, parents) do
    unstated =
      for {law, %Extent{default: nil}} <- parents, into: MapSet.new(), do: law

    docs = Map.new(unstated, &{&1, ClmlStore.law_docs(&1)})

    for {law, ref} <- Lookup.powers_refs(provisions),
        MapSet.member?(unstated, law),
        code = StatedExtent.of(docs[law], ref),
        code != nil,
        into: %{},
        do: {{law, ref}, code}
  end

  @doc """
  Why an SI stating no extent gets none from its powers, for the family
  gate (the enabling cache and the stores only, never a fetch): its
  introduction not held, no powers clause read in it, a parent Act not
  read, or a parent placing an enabling provision nowhere.
  """
  @spec why_none(String.t()) :: String.t()
  def why_none(law) do
    case enabling(law, true) do
      [] -> no_provisions(law)
      provisions -> unplaced(provisions)
    end
  end

  defp no_provisions(law) do
    case SertantaiLegal.Scraper.EnactedBy.EnablingCache.from_store(law) do
      :not_held -> "introduction not held"
      {:ok, _} -> "no powers clause read in its introduction"
    end
  end

  defp unplaced(provisions) do
    parents = provisions |> Enum.map(& &1["law"]) |> Enum.uniq() |> Extent.Store.for_laws()
    stated = stated(provisions, parents)

    provisions
    |> Lookup.powers_refs()
    |> Enum.flat_map(fn {law, ref} ->
      cond do
        not Map.has_key?(parents, law) ->
          ["parent not read: #{law}"]

        Extent.from_powers(
          [%{"law" => law, "sections" => [], "schedules" => []} |> put_ref(ref)],
          parents,
          stated
        ) ->
          []

        true ->
          ["#{law} #{ref}: placed nowhere"]
      end
    end)
    |> Enum.uniq()
    |> Enum.join("; ")
  end

  defp put_ref(p, "s." <> n), do: %{p | "sections" => [n]}
  defp put_ref(p, "sch." <> n), do: %{p | "schedules" => [n]}

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
