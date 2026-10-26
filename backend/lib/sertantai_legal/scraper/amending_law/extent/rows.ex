defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Rows do
  @moduledoc """
  An extent reading as `extent_rules` rows and back (CV-04; decomposed from
  `AmendingLaw.Extent`, run time 2026-10-25): one row per statement — the
  default, each list, the corresponding-repeal sentence, the application,
  powers, competence and each Schedule's introducing section. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  @doc """
  The extent read as `extent_rules` rows, one per statement (CV-04): the
  default (`"default"`, with the clause's ref and words), each list
  (`"also"`, `"only"`, `"same"`, in order), the corresponding-repeal
  sentence (`"corresponds"`) and each Schedule's introducing section
  (`"introduces"`: `items` the Schedule, `source_ref` the section). An Act
  read with no clause gives a `"none"` row, so read is told from unread.
  """
  @spec to_rows(Extent.t(), String.t()) :: [map()]
  def to_rows(%Extent{} = e, law) do
    row = fn kind, place, items, ref, text, position ->
      %{
        kind: kind,
        place: place,
        items: items,
        source_law: law,
        source_ref: ref,
        source_text: text,
        position: position
      }
    end

    # the lists are kept with no default too ("Sections 107 and 116A extend
    # to Scotland only" alone): before CV-S05 (N9) only a "none" row was
    # written then, and the lists were lost
    lists =
      e.lists
      |> Enum.with_index(1)
      |> Enum.map(fn {{kind, place, items}, i} ->
        row.(to_string(kind), place, items, e.ref, nil, i)
      end)

    corresponds = if e.corresponds, do: [row.("corresponds", nil, [], e.ref, nil, 0)], else: []

    clause =
      case {e.default, lists} do
        {nil, []} -> [row.("none", nil, [], nil, nil, 0)] ++ corresponds
        {nil, _} -> lists ++ corresponds
        {d, _} -> [row.("default", d, [], e.ref, e.text, 0)] ++ lists ++ corresponds
      end

    applies =
      if e.application, do: [row.("applies", e.application, [], e.ref, nil, 0)], else: []

    powers = if e.powers, do: [row.("powers", e.powers, [], nil, nil, 0)], else: []

    competence =
      if e.competence, do: [row.("competence", e.competence, [], nil, nil, 0)], else: []

    clause ++
      applies ++
      powers ++
      competence ++
      for {sch, sec} <- Enum.sort(e.introduced_by),
          do: row.("introduces", nil, [sch], sec, nil, 0)
  end

  @doc "The extent from its `extent_rules` rows; nil when there are none (not read)."
  @spec from_rows([map()]) :: Extent.t() | nil
  def from_rows([]), do: nil

  def from_rows(rows) do
    default = Enum.find(rows, &(&1.kind == "default"))

    %Extent{
      default: default && default.place,
      ref: default && default.source_ref,
      text: default && default.source_text,
      lists:
        for(
          r <- Enum.sort_by(rows, & &1.position),
          # ("not" was dropped here before CV-S05: a stored "Part III …
          # does not extend to Scotland" read back as nothing)
          r.kind in ~w(also only same not named unread),
          do: {String.to_existing_atom(r.kind), r.place, r.items}
        ),
      corresponds: Enum.any?(rows, &(&1.kind == "corresponds")),
      application: Enum.find_value(rows, &(&1.kind == "applies" && &1.place)),
      powers: Enum.find_value(rows, &(&1.kind == "powers" && &1.place)),
      competence: Enum.find_value(rows, &(&1.kind == "competence" && &1.place)),
      introduced_by:
        for(r <- rows, r.kind == "introduces", into: %{}, do: {hd(r.items), r.source_ref})
    }
  end
end
