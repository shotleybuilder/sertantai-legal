# The held catalogue readings that move (Fire and OH&S: Commencement reader,
# Decision 4 a): each non-pending example whose reading now differs from
# expected.json. A dry run prints them; `write` writes them (sorted keys).
alias SertantaiLegal.Scraper.Commencement.{OwnClause, SentencePatterns, OrderPatterns}
alias Mix.Tasks.Lat.FeedPatterns, as: Files
write? = System.argv() == ["write"]
load = fn dir, f -> dir |> Path.join(f <> ".json") |> File.read!() |> Jason.decode!() end

pending = fn dir ->
  st = load.(dir, "expected")["patterns"] || %{}
  for {p, %{"examples" => ids}} <- load.(dir, "patterns")["patterns"] || %{},
      String.starts_with?(Map.get(st, p, ""), "pending"), id <- ids, into: MapSet.new(), do: id
end

own = "test/fixtures/commencement_patterns"
reads =
  load.(own, "laws")
  |> Task.async_stream(fn {law, input} -> {law, OwnClause.read(law, SentencePatterns.input(law, input))} end,
    timeout: :infinity, ordered: false)
  |> Map.new(fn {:ok, r} -> r end)

own_got = fn %{"law" => law, "sentence" => s} ->
  g = SentencePatterns.outcome(s, reads[law]); %{"class" => g.class, "rules" => g.rules}
end

ord = "test/fixtures/order_patterns"
ord_got = fn %{"order" => o, "act" => a, "unit" => u, "xml" => xml} ->
  g = OrderPatterns.read(o, %{law: a["law"], title: a["title"], year: a["year"]}, xml,
        %{kind: u["kind"], id: u["id"], text: u["text"]})
  %{"class" => g.class, "rules" => g.rules}
end

for {dir, got} <- [{own, own_got}, {ord, ord_got}] do
  exp = load.(dir, "expected"); held = exp["examples"]; pend = pending.(dir)
  moved =
    for {id, e} <- load.(dir, "examples"), not MapSet.member?(pend, id),
        (g = got.(e)) != held[id], into: %{}, do: {id, g}
  IO.puts("#{dir}: #{map_size(moved)} moved")
  for id <- moved |> Map.keys() |> Enum.sort(), do: IO.puts("  #{id}")
  if write? do
    File.write!(Path.join(dir, "expected.json"),
      Files.encode(%{exp | "examples" => Map.merge(held, moved)}))
  end
end
