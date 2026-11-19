# Jason, Decision 3 (a), Waste, Water and Climate: Feed reader (2026-11-19): the
# 154 explained moved examples written as read now; the 2 pending misnested
# refs keep their held (correct) outcome; examples with no expectation and new
# patterns accepted as read; patterns no longer seen dropped.
dir = "test/fixtures/feed_patterns"
dry = Jason.decode!(File.read!(System.fetch_env!("DRY")))
ex = Jason.decode!(File.read!("#{dir}/examples.json"))
pats = Jason.decode!(File.read!("#{dir}/patterns.json"))["patterns"]
held = Jason.decode!(File.read!("#{dir}/expected.json"))
keep = MapSet.new(~w(UK_ukpga_1984_60/c666d7ee09 UK_ukpga_2023_30/6c1b7cb488))

examples =
  Map.new(ex, fn {id, _} ->
    now = dry["now"][id]
    out =
      cond do
        id in keep -> Map.fetch!(held["examples"], id)
        now != nil -> now
        true -> Map.fetch!(held["examples"], id)
      end
    {id, out}
  end)

statuses = Map.new(pats, fn {p, _} -> {p, Map.get(held["patterns"], p, "accepted")} end)
File.write!("#{dir}/expected.json", Mix.Tasks.Lat.FeedPatterns.encode(%{"patterns" => statuses, "examples" => examples}))
moved = Enum.count(dry["moved"], fn {id, _} -> not MapSet.member?(keep, id) end)
IO.puts("examples #{map_size(examples)} (moved written #{moved}, kept #{MapSet.size(keep)}, new #{length(dry["new"])}); patterns #{map_size(statuses)}, pending #{Enum.count(statuses, fn {_, s} -> String.starts_with?(s, "pending") end)}")
