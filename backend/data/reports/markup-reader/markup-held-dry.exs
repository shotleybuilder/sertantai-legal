# Dry run: each held markup example, its expected outcome against the reader's now. Writes nothing.
alias SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns
dir = "test/fixtures/markup_patterns"
load = fn f -> dir |> Path.join(f <> ".json") |> File.read!() |> Jason.decode!() end
ex = load.("examples"); exp = load.("expected")["examples"]
for {id, e} <- Enum.sort(ex), want = exp[id], want != nil do
  got = e["xml"] |> MarkupPatterns.read(e["key"], e["law"], e["xml_ids"] || %{}) |> MarkupPatterns.outcome()
  if got != want do
    w = Map.new(want, &{&1["target"], &1["claims"]}); g = Map.new(got, &{&1["target"], &1["claims"]})
    gone = Map.keys(w) -- Map.keys(g); new = Map.keys(g) -- Map.keys(w)
    moved = for t <- Map.keys(w), Map.has_key?(g, t), w[t] != g[t] do
      d = for k <- Enum.uniq(Map.keys(w[t]) ++ Map.keys(g[t])), w[t][k] != g[t][k], do: "#{k}: #{inspect(w[t][k])} → #{inspect(g[t][k])}"
      "#{t} {#{Enum.join(d, "; ")}}"
    end
    IO.puts("#{id}\n  targets gone #{inspect(gone)} new #{inspect(new)}\n  moved #{inspect(moved)}")
  end
end
