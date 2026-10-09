defmodule SertantaiLegal.Scraper.EffectIndex do
  @moduledoc """
  A law's effects (legislation.gov.uk changes feed, `ChangesFeed.Effect`)
  indexed for the LAT (lat-refactor LR-03; plan `docs/LAT-EFFECTS-LAYER-PLAN.md`).

  Handles:
  - `new/1` — by effect id and by structured affected ref (`section-101`)
  - `effect_id/1` — a markup `ChangeId` ("key-<hex>-<ts>") → its effect id
    ("key-<hex>"); legacy ids (`d29p…`) have none
  - `get/2`, `for_change/2`, `on/2` — lookups
  - `whole_provision/2` — applied effects that repeal or insert a whole
    provision (not words, not substitutions): rule 3

  Pure.
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @type t :: %{
          by_id: %{String.t() => Effect.t()},
          by_ref: %{String.t() => [Effect.t()]},
          law_extent: String.t() | nil
        }

  @whole ~w(repealed revoked omitted inserted added)

  @doc "An empty index (a law with no effects, or none loaded)."
  @spec empty() :: t()
  def empty, do: %{by_id: %{}, by_ref: %{}, law_extent: nil}

  @doc """
  Index effects by id and by affected ref. A range ("ss. 1-30") covers every
  id between its ends in `order` (the document's ids in document order;
  each id's first occurrence — versions repeat ids later). `law_extent` (the
  law's own extent) stands in for an effect's missing `AffectedExtent`, so a
  devolved instrument's amendment isn't read as narrower than the UK.
  """
  @spec new([Effect.t()], [String.t()], String.t() | nil) :: t()
  def new(effects, order \\ [], law_extent \\ nil) do
    position =
      order
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {id, i}, acc -> Map.put_new(acc, id, i) end)

    effects =
      Enum.map(effects, fn e -> %{e | affected_extent: e.affected_extent || law_extent} end)

    %{
      law_extent: law_extent,
      by_id: for(%Effect{effect_id: id} = e <- effects, id != nil, into: %{}, do: {id, e}),
      by_ref:
        effects
        |> Enum.flat_map(fn e ->
          refs = (e.affected_refs || []) ++ in_ranges(e.affected_ranges || [], order, position)
          refs |> Enum.uniq() |> Enum.map(&{&1, e})
        end)
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    }
  end

  defp in_ranges(ranges, order, position) do
    Enum.flat_map(ranges, fn {first, last} ->
      with from when from != nil <- position[first],
           to when to != nil <- position[last],
           true <- from <= to do
        Enum.slice(order, from..to)
      else
        _ -> []
      end
    end)
  end

  @doc "The effect id in a markup ChangeId; nil for a legacy id."
  @spec effect_id(String.t() | nil) :: String.t() | nil
  def effect_id("key-" <> _ = change_id), do: String.replace(change_id, ~r/-\d+$/, "")
  def effect_id(_change_id), do: nil

  @doc "The effect with this id."
  @spec get(t(), String.t() | nil) :: Effect.t() | nil
  def get(_index, nil), do: nil
  def get(index, id), do: Map.get(index.by_id, id)

  @doc "The effect behind a markup ChangeId."
  @spec for_change(t(), String.t() | nil) :: Effect.t() | nil
  def for_change(index, change_id), do: get(index, effect_id(change_id))

  @doc """
  The effect behind a change: by its `ChangeId`, else by a `key-` commentary
  ref — the effect id itself, a structured join (an `M_F_` ChangeId carries
  one: 1993/11 s.20); a note's text is never read.
  """
  @spec for(t(), String.t() | nil, String.t() | nil) :: Effect.t() | nil
  def for(index, change_id, ref) do
    for_change(index, change_id) ||
      if(is_binary(ref) and String.starts_with?(ref, "key-"), do: get(index, ref))
  end

  @doc "Effects naming this provision (by structured ref)."
  @spec on(t(), String.t() | nil) :: [Effect.t()]
  def on(_index, nil), do: []
  def on(index, ref), do: Map.get(index.by_ref, ref, [])

  @doc "Applied effects that repeal or insert this whole provision."
  @spec whole_provision(t(), String.t() | nil) :: [Effect.t()]
  def whole_provision(index, ref) do
    index
    |> on(ref)
    |> Enum.filter(&(&1.applied == true and String.trim(&1.type || "") in @whole))
  end
end
