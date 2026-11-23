defmodule SertantaiLegal.Scraper.StepProcedures.HeldMoves do
  @moduledoc """
  The commencement catalogues' held answers a step moves: each held,
  non-pending example whose reading now differs from `expected.json`
  (`moves/2`, written by `write_moves/2`), and the dry run's new patterns
  brought into the fixtures with their examples, laws and readings
  (`add_new/4`). Pure: a catalogue's fixtures are a map of its files
  (`"patterns"`, `"examples"`, `"expected"`, and `"laws"` for the own
  clauses' catalogue), and the reading is passed in
  (`StepProcedures.CatalogueReadings`). `mix lat.held_moves` runs it.
  """

  @type files :: %{String.t() => map()}
  @type reading :: %{String.t() => term()}
  @type move :: %{held: reading() | nil, now: reading()}

  @doc "Each held, non-pending example whose reading by `read` differs from its held one."
  @spec moves(files(), (map() -> reading())) :: %{String.t() => move()}
  def moves(files, read) do
    held = files["expected"]["examples"]
    pending = pending(files)

    for {id, e} <- files["examples"],
        not MapSet.member?(pending, id),
        now = read.(e),
        now != held[id],
        into: %{},
        do: {id, %{held: held[id], now: now}}
  end

  @doc "The fixtures with `moves` written into `expected.json`."
  @spec write_moves(files(), %{String.t() => move()}) :: files()
  def write_moves(files, moves) do
    now = Map.new(moves, fn {id, m} -> {id, m.now} end)
    update_in(files, ["expected", "examples"], &Map.merge(&1, now))
  end

  @doc """
  The dry run's new patterns brought in: their examples (leaving any old
  pattern they move from, which is dropped when left empty), the laws they
  need, and fresh readings for them and for the examples of the laws that
  changed. `statuses`: pattern → `"pending: …"`; any other new pattern is
  `"accepted"`. `read` takes the laws and gives the reading function.
  """
  @spec add_new(files(), files(), %{String.t() => String.t()}, (map() | nil ->
                                                                  (map() -> reading()))) ::
          {files(), %{new: [String.t()], emptied: [String.t()]}}
  def add_new(files, dry, statuses, read) do
    pats = files["patterns"]["patterns"]
    new = Map.drop(dry["patterns"]["patterns"], Map.keys(pats))
    ids = new |> Enum.flat_map(fn {_, v} -> v["examples"] end) |> MapSet.new()

    {kept, emptied} = leave_old(pats, ids)
    examples = Map.merge(files["examples"], Map.take(dry["examples"], MapSet.to_list(ids)))
    {laws, touched} = laws(files, dry, ids)
    reread = Enum.uniq(MapSet.to_list(ids) ++ same_law(examples, touched))
    reader = read.(laws)
    readings = Map.new(reread, &{&1, reader.(examples[&1])})
    new_statuses = Map.new(new, fn {p, _} -> {p, Map.get(statuses, p, "accepted")} end)

    out =
      files
      |> put_in(["patterns", "patterns"], Map.merge(kept, new))
      |> Map.put("examples", examples)
      |> update_in(
        ["expected", "patterns"],
        &(&1 |> Map.drop(emptied) |> Map.merge(new_statuses))
      )
      |> update_in(["expected", "examples"], &Map.merge(&1, readings))
      |> put_laws(laws)

    {out, %{new: new |> Map.keys() |> Enum.sort(), emptied: Enum.sort(emptied)}}
  end

  defp pending(files) do
    status = files["expected"]["patterns"] || %{}

    for {p, %{"examples" => ids}} <- files["patterns"]["patterns"],
        String.starts_with?(Map.get(status, p, ""), "pending"),
        id <- ids,
        into: MapSet.new(),
        do: id
  end

  defp leave_old(pats, ids) do
    kept =
      Map.new(pats, fn {p, v} ->
        {p, %{v | "examples" => Enum.reject(v["examples"], &MapSet.member?(ids, &1))}}
      end)

    emptied = for {p, %{"examples" => []}} <- kept, pats[p]["examples"] != [], do: p
    {Map.drop(kept, emptied), emptied}
  end

  # the own clauses' catalogue: the laws a new example needs, where the dry
  # run's input differs from the held one
  defp laws(%{"laws" => held}, %{"laws" => dl} = dry, ids) do
    need =
      for id <- ids, l = dry["examples"][id]["law"], held[l] != dl[l], into: %{}, do: {l, dl[l]}

    {Map.merge(held, need), Map.keys(need)}
  end

  defp laws(_files, _dry, _ids), do: {nil, []}

  defp same_law(examples, touched),
    do: for({id, e} <- examples, e["law"] in touched, do: id)

  defp put_laws(files, nil), do: files
  defp put_laws(files, laws), do: Map.put(files, "laws", laws)
end
