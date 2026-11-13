# Dry run (read-only): every catalogue example whose reading now differs
# from its held expectation, with the change as claim-level differences,
# grouped by the kind of change. WRITE=1 writes the explained ones.
alias SertantaiLegal.Scraper.ChangeVocabulary.FeedPatterns
dir = "test/fixtures/feed_patterns"
ex = Jason.decode!(File.read!("#{dir}/examples.json"))
held = Jason.decode!(File.read!("#{dir}/expected.json"))
out = System.get_env("OUT")

flat = fn outcome ->
  for c <- outcome, {a, v} <- c["claims"] || %{}, into: MapSet.new(),
    do: {c["key"], c["target"], a, Jason.encode!(v)}
end

rows =
  for {id, item} <- Enum.sort(ex) do
    {effect, ctx} = FeedPatterns.decode(item)
    got = FeedPatterns.outcome(FeedPatterns.read(effect, ctx)) |> Jason.encode!() |> Jason.decode!()
    want = held["examples"][id]
    cond do
      want == nil -> {id, :new, got, nil}
      want == got -> nil
      true ->
        {g, w} = {flat.(got), flat.(want)}
        gone = MapSet.difference(w, g) |> Enum.sort()
        added = MapSet.difference(g, w) |> Enum.sort()
        keys = fn s -> s |> Enum.map(&elem(&1, 0)) |> MapSet.new() end
        attrs = (gone ++ added) |> Enum.map(&elem(&1, 2)) |> Enum.uniq() |> Enum.sort()
        newkeys = MapSet.difference(keys.(g), keys.(w)) |> MapSet.size()
        lostkeys = MapSet.difference(keys.(w), keys.(g)) |> MapSet.size()
        sig = Enum.join(attrs, "+") <> if(newkeys + lostkeys > 0, do: " | keys +#{newkeys} -#{lostkeys}", else: "")
        {id, {:moved, sig, gone, added, effect.type}, got, want}
    end
  end
  |> Enum.reject(&is_nil/1)

new = for {id, :new, _, _} <- rows, do: id
moved = for {id, {:moved, sig, g, a, t}, _, _} <- rows, do: {id, sig, g, a, t}

IO.puts("examples #{map_size(ex)}; held #{map_size(held["examples"])}; no held expectation #{length(new)}; moved #{length(moved)}\n")
IO.puts("== moved, by what changed")
for {sig, items} <- Enum.group_by(moved, &elem(&1, 1)) |> Enum.sort_by(fn {_, l} -> -length(l) end) do
  IO.puts("#{length(items)}  #{sig}")
  for {id, _, g, a, t} <- Enum.take(items, 2) do
    short = fn l -> l |> Enum.take(4) |> Enum.map(fn {k, tg, at, v} -> "#{k}/#{tg} #{at}=#{v}" end) |> Enum.join("; ") end
    IO.puts("    e.g. #{id} [#{t}]\n      was: #{short.(g)}\n      now: #{short.(a)}")
  end
end
IO.puts("\n== no held expectation (examples of new patterns)")
for id <- new, do: IO.puts("  #{id} [#{ex[id]["effect"]["type"]}]")

if out do
  File.write!(out, Jason.encode!(%{
    "moved" => Map.new(moved, fn {id, sig, _, _, _} -> {id, sig} end),
    "new" => new,
    "now" => Map.new(rows, fn {id, _, got, _} -> {id, got} end)
  }))
end
