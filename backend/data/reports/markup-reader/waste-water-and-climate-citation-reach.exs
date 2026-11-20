# Reach of Markup reader fix 12 (note-citation-not-amending): every claim
# set whose `cited`, `cited_text` or `affecting` differs between the stage
# reader (before) and the working one, with the feed's affecting law for
# that change (by effect id) where the feed holds it. Reads only.
# Args: STAGE_FILE STAGE_MODULE LAWS_FILE OUT
[stage_file, stage_mod, laws_file, out] = System.argv()
Code.compiler_options(ignore_module_conflict: true)
Code.require_file(stage_file)
before_mod = Module.concat([stage_mod])
alias SertantaiLegal.Scraper.ChangeVocabulary.{Build, Readers.Markup}
alias SertantaiLegal.Scraper.{EffectIndex, LatStagedParser}

val = fn cs, attr -> Enum.find_value(cs, fn c -> if c.attribute == attr, do: c.value end) end
sets = fn rows ->
  Map.new(rows, fn {k, t, cs} ->
    {{k, t}, {val.(cs, :cited), val.(cs, :cited_text), val.(cs, :affecting) || [], Enum.sort(for(c <- cs, c.attribute not in [:cited, :cited_text, :affecting], do: {c.attribute, c.value}))}}
  end)
end
short = fn k -> Regex.replace(~r/key-([0-9a-f]{8})[0-9a-f]{24}/, k, "key-\\1") end
laws = laws_file |> File.read!() |> String.split(~r/\s+/, trim: true) |> Enum.uniq()
{:ok, io} = File.open(out, [:write, :utf8])
IO.puts(io, "law\tkey\ttarget\tkind\tfeed\tcited_before\tcited_after\ttext_before\ttext_after\taffecting_before\taffecting_after")

tally =
  Enum.reduce(laws, %{}, fn law, acc ->
    [_, t, y, n] = String.split(law, "_", parts: 4)
    doc = "data/cache/clml/#{t}/#{y}/#{n}/body/data.xml.gz" |> File.read!() |> :zlib.gunzip() |> SweetXml.parse(quiet: true, namespace_conformant: false)
    ids = Build.xml_ids(law)
    a = sets.(before_mod.read(doc, law, ids))
    b = sets.(Markup.read(doc, law, ids))
    by_id = law |> LatStagedParser.law_effects(store: :only) |> Map.new(&{&1.effect_id, &1.affecting})
    bump = fn acc, k -> Map.update(acc, k, 1, &(&1 + 1)) end
    acc = acc |> Map.update(:sets, map_size(b), &(&1 + map_size(b)))
    gone = Map.keys(a) -- Map.keys(b)
    added = Map.keys(b) -- Map.keys(a)
    for {k, target} <- gone, do: IO.puts(io, Enum.join([law, short.(k), target, "TARGET GONE"], "\t"))
    for {k, target} <- added, do: IO.puts(io, Enum.join([law, short.(k), target, "TARGET ADDED"], "\t"))
    acc = Map.update(acc, :targets_moved, length(gone) + length(added), &(&1 + length(gone) + length(added)))

    Enum.reduce(b, acc, fn {{k, target}, {c2, t2, a2, o2}}, acc ->
      case a[{k, target}] do
        {c1, t1, a1, o1} when {c1, t1, a1, o1} != {c2, t2, a2, o2} ->
          feed = by_id[EffectIndex.effect_id(k)]
          kind =
            [c1 != c2 && "cited", t1 != t2 && "cited_text", a1 != a2 && "affecting", o1 != o2 && "OTHER"]
            |> Enum.filter(& &1) |> Enum.join("+")
          IO.puts(io, Enum.join([law, short.(k), target, kind, inspect(feed), inspect(c1), inspect(c2), inspect(t1), inspect(t2), inspect(a1), inspect(a2)], "\t"))
          acc = acc |> bump.(:moved) |> bump.({:kind, kind})
          acc = if c1 != c2, do: bump.(acc, {:cited, if(c2, do: :changed, else: :to_none)}), else: acc
          if feed do
            acc |> bump.(:with_feed) |> then(&if(c1 == feed, do: bump.(&1, :feed_agree_before), else: &1)) |> then(&if(c2 == feed, do: bump.(&1, :feed_agree_after), else: &1))
          else
            acc
          end
        _ -> acc
      end
    end)
  end)

IO.puts(io, "\nTALLY #{inspect(tally, limit: :infinity)}")
File.close(io)
IO.inspect(tally, label: "TALLY", limit: :infinity)
