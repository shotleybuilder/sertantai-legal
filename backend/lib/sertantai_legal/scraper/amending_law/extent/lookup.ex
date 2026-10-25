defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Lookup do
  @moduledoc """
  Where an amending provision extends, from the extent read (CV-03, CV-07;
  decomposed from `AmendingLaw.Extent`, run time 2026-10-25): every list
  naming it, applied in a fixed order (the same extent, then the lists that
  set it, widen it, narrow it); a Schedule not named as its introducing
  section; stating none, an SI's enabling powers, else its legislature's
  competence. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Extent, RefList}
  alias SertantaiLegal.Scraper.Territory

  # the order lists apply in (`of/2`)
  @apply_order %{same: 0, unread: 0, only: 1, named: 2, also: 3, not: 4}

  @doc """
  Where the amending provision `ref` ("s.111", "sch.7.para.27(2)",
  "sch.17.pt.2") extends: a territory code, `:same` (the enactment it
  changes), or nil (the clause wasn't read).
  """
  @spec of(Extent.t(), String.t()) :: String.t() | :same | nil
  # stating none, an SI extends as far as its enabling powers (`powers`),
  # else a devolved instrument as far as its legislature (`competence`)
  def of(%Extent{default: nil, lists: [], powers: powers, competence: c}, _ref),
    do: powers || c

  # with no default, only a list naming the provision decides ("The
  # following provisions of this Act extend to England and Wales only—")
  def of(%Extent{} = e, ref) do
    candidates = [ref | containers(ref)] ++ introducing(e, ref)

    # every list naming it, in order: "only" sets, "also" widens, "not"
    # narrows (HSWA s.77: also NI by s.84(1), not Scotland by s.84(2))
    naming =
      Enum.filter(e.lists, fn {_kind, _place, items} ->
        items != ["*"] and Enum.any?(candidates, &named?(&1, items))
      end)

    # "every amendment the law makes" only where no list names it
    naming = if naming == [], do: Enum.filter(e.lists, &match?({_, _, ["*"]}, &1)), else: naming

    # a list naming its own extent ("only", "named") is more specific than
    # one deferring to the enactment ("same", or unknown "unread"): "Subject
    # to paragraph (7), the modifications in Schedule 2 have the same extent
    # …"; "(7) … paragraphs 65 … and 76 of Schedule 2 … extend to Scotland
    # only" (SI 2013/602 art.1: CV-S05 round 3 C)
    naming =
      if Enum.any?(naming, &match?({k, _, _} when k in [:only, :named], &1)),
        do: Enum.reject(naming, &match?({k, _, _} when k in [:same, :unread], &1)),
        else: naming

    # in a fixed order, whatever order they were stated or stored in: the
    # same extent, then the lists that set it, then those that widen, then
    # those that narrow (Police and Justice Act 2006 s.54: CV-S05 C)
    naming
    |> Enum.sort_by(fn {kind, _, _} -> Map.fetch!(@apply_order, kind) end)
    |> Enum.reduce_while(e.default || e.powers || e.competence, fn
      {:same, _, _}, _acc ->
        {:halt, :same}

      # stated, but not plainly: unknown, never the default
      {:unread, _, _}, _acc ->
        {:halt, nil}

      {:named, place, _}, nil ->
        {:cont, place}

      # a stated default is widened; an extent implied (powers, competence) is not
      {:named, place, _}, acc ->
        {:cont, if(e.default, do: Territory.union([acc, place]), else: place)}

      {:only, place, _}, _acc ->
        {:cont, place}

      {:also, _place, _}, nil ->
        {:cont, nil}

      {:also, place, _}, acc ->
        {:cont, Territory.union([acc, place])}

      {:not, _place, _}, nil ->
        {:cont, nil}

      {:not, place, _}, acc ->
        {:cont, Territory.subtract(acc, place)}
    end)
  end

  # "sch.7.para.27(2)" → ["sch.7.para.27", "sch.7"]; "sch.17.pt.2" → ["sch.17"]
  defp containers(ref) do
    case Regex.run(~r/^(sch\.\d+[A-Z]*)/, ref) do
      [_, sch] -> Enum.reject([String.replace(ref, ~r/\(.*$/, ""), sch], &(&1 == ref))
      nil -> [String.replace(ref, ~r/\(.*$/, "")] |> Enum.reject(&(&1 == ref))
    end
  end

  # a Schedule not named in the clause extends as its introducing section
  defp introducing(e, ref) do
    case Regex.run(~r/^(sch\.\d+[A-Z]*)/, ref) do
      [_, sch] -> List.wrap(Map.get(e.introduced_by, sch))
      nil -> []
    end
  end

  defp named?(ref, items), do: Enum.any?(items, &RefList.covers?(&1, ref))

  # a devolved legislature's instruments extend no further than its
  # competence (a Welsh Minister's SI forms part of the law of England and
  # Wales)
  @competence %{
    "nisr" => "NI",
    "nisi" => "NI",
    "nia" => "NI",
    "apni" => "NI",
    "ssi" => "S",
    "asp" => "S",
    "wsi" => "E+W",
    "anaw" => "E+W",
    "asc" => "E+W"
  }

  @doc """
  A devolved instrument's extent by its legislature's competence (CV-07),
  used only where it states none and its enabling powers aren't read: an
  NI statutory rule extends to Northern Ireland. Nil for a UK instrument.
  """
  @spec competence(String.t()) :: String.t() | nil
  def competence(law) do
    case String.split(law || "", "_", parts: 4) do
      [_, type, _, _] -> Map.get(@competence, type)
      _ -> nil
    end
  end

  @doc """
  True when the extent rests on the legislature's competence alone (the
  instrument states none and its powers aren't read). Such an extent
  doesn't confine an insertion the instrument makes (V1-04, signed off: a
  Welsh SI's insertion into a GB Act's single text applies across it;
  Forestry Act 1967 s.1(1A)).
  """
  @spec competence_only?(Extent.t()) :: boolean()
  def competence_only?(%Extent{default: nil, lists: [], powers: nil, competence: c}),
    do: c != nil

  def competence_only?(%Extent{}), do: false

  @doc """
  An SI's extent from its enabling powers (CV-07), where it states none:
  it can reach only as far as the provisions that empower it. `provisions`
  are its enabling provisions (`EnactedBy.EnablingCache`: per parent law,
  its sections and schedules); each is placed by its parent Act's own
  extent clause (`parents`: law → `Extent.t()`). The union of them; nil when any
  parent is unread or places a provision nowhere known (all or nothing: a
  partial union would understate the SI's reach), or none is named.
  """
  @spec from_powers([map()], %{String.t() => Extent.t()}) :: String.t() | nil
  def from_powers([], _parents), do: nil

  def from_powers(provisions, parents) do
    extents =
      for %{"law" => law} = p <- provisions,
          ref <-
            Enum.map(p["sections"] || [], &"s.#{&1}") ++
              Enum.map(p["schedules"] || [], &"sch.#{&1}"),
          do: with(%Extent{} = e <- Map.get(parents, law), do: of(powers_extent(e), ref))

    if extents != [] and Enum.all?(extents, &is_binary/1),
      do: Territory.union(extents)
  end

  # a parent Act's extent at its enabling sections: what "every amendment
  # the law makes" follows (a `*` same or unread list) is no enabling
  # section's (REUL 2023 s.23(2): uksi 2025/82, CV-S05 round 5)
  defp powers_extent(%Extent{lists: lists} = e),
    do: %{e | lists: Enum.reject(lists, &match?({k, _, ["*"]} when k in [:same, :unread], &1))}

  @doc """
  The territory of a change made by the amending provisions `refs` (an
  effect may name several: "Sch. 7 para. 27(2) Sch. 17 Pt. 2"): a repeals
  schedule with the enactment's extent follows the provision it corresponds
  to (`corresponds`); the provisions that remain must agree. Nil when none
  is read, or they disagree.
  """
  @spec of_change(Extent.t(), [String.t()]) :: String.t() | :same | nil
  def of_change(%Extent{} = e, refs) do
    extents = Enum.map(refs, &of(e, &1))

    extents =
      if e.corresponds and Enum.any?(extents, &is_binary/1),
        do: Enum.reject(extents, &(&1 == :same)),
        else: extents

    case Enum.uniq(extents) do
      [one] -> one
      _ -> nil
    end
  end
end
