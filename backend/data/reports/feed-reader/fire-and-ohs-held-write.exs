# Jason, Decision 4 (a): the moved held examples written as read now, the
# unheld accepted as read, new patterns accepted, the 2 misnested refs
# pending with their examples holding the correct outcome.
dir = "test/fixtures/feed_patterns"
dry = Jason.decode!(File.read!(System.fetch_env!("DRY")))
ex = Jason.decode!(File.read!("#{dir}/examples.json"))
pats = Jason.decode!(File.read!("#{dir}/patterns.json"))["patterns"]
held = Jason.decode!(File.read!("#{dir}/expected.json"))
why = "pending: misnested ref, a known limit (feed links the provision as section-N-iiia; Fire and OH&S: Feed reader, Decision 1)"
pending = %{"ref: section-N-iiia → s.N(+1)" => why, "ref: section-N(+1)-iiib → s.N(+2)" => why}

one = fn [first | _], target, op ->
  %{first | "target" => target, "claims" => Map.put(first["claims"], "feed.operation", op)}
end
correct = %{
  "UK_ukpga_2023_30/6c1b7cb488" => fn now -> [one.(now, "s.276(c)(iiia)", "inserted")] end,
  "UK_ukpga_1984_60/c666d7ee09" => fn now -> [one.(now, "s.17(1)(c)(iiia)", "substituted"), one.(now, "s.17(1)(c)(iiib)", "inserted")] end
}

examples =
  Map.new(ex, fn {id, _} ->
    now = dry["now"][id]
    out = cond do
      Map.has_key?(correct, id) -> correct[id].(now || held["examples"][id])
      now != nil -> now
      true -> Map.fetch!(held["examples"], id)
    end
    {id, out}
  end)

statuses = Map.new(pats, fn {p, _} -> {p, pending[p] || Map.get(held["patterns"], p, "accepted")} end)
File.write!("#{dir}/expected.json", Mix.Tasks.Lat.FeedPatterns.encode(%{"patterns" => statuses, "examples" => examples}))
IO.puts("examples #{map_size(examples)} (moved #{map_size(dry["moved"])}, new #{length(dry["new"])}); patterns #{map_size(statuses)}, pending #{Enum.count(statuses, fn {_, s} -> String.starts_with?(s, "pending") end)}")
