# Feed agreement of the moved note pointers: for each claim set whose
# `affecting` differs between the stage reader (before) and the working
# one, whether it equals the feed's AffectingProvisions for that change
# (by effect id; a legacy key: any effect of the cited law on the law).
# Reads only. Args: STAGE_FILE STAGE_MODULE LAWS_FILE OUT
[stage_file, stage_mod, laws_file, out] = System.argv()
Code.compiler_options(ignore_module_conflict: true)
Code.require_file(stage_file)
before_mod = Module.concat([stage_mod])
alias SertantaiLegal.Scraper.AmendingLaw.Pointer
alias SertantaiLegal.Scraper.ChangeVocabulary.{Build, Readers.Markup}
alias SertantaiLegal.Scraper.{EffectIndex, LatStagedParser}

val = fn cs, attr -> Enum.find_value(cs, fn c -> if c.attribute == attr, do: c.value end) end
sets = fn rows -> Map.new(rows, fn {k, t, cs} -> {{k, t}, {val.(cs, :affecting) || [], val.(cs, :cited)}} end) end
feed_refs = fn e ->
  e.affecting_provisions |> Pointer.refs_in() |> Enum.flat_map(&Pointer.to_refs/1)
  |> Enum.map(&String.replace_prefix(&1, "art.", "reg.")) |> MapSet.new()
end
laws = laws_file |> File.read!() |> String.split(~r/\s+/, trim: true) |> Enum.uniq()
{:ok, io} = File.open(out, [:write, :utf8])

tally =
  Enum.reduce(laws, %{}, fn law, acc ->
    [_, t, y, n] = String.split(law, "_", parts: 4)
    doc = "data/cache/clml/#{t}/#{y}/#{n}/body/data.xml.gz" |> File.read!() |> :zlib.gunzip() |> SweetXml.parse(quiet: true, namespace_conformant: false)
    ids = Build.xml_ids(law)
    a = sets.(before_mod.read(doc, law, ids))
    b = sets.(Markup.read(doc, law, ids))
    effects = LatStagedParser.law_effects(law, store: :only)
    by_id = Map.new(effects, &{&1.effect_id, &1})

    Enum.reduce(b, acc, fn {{k, target}, {new, cited}}, acc ->
      case a[{k, target}] do
        {old, _} when old != new ->
          {kind, wanted} =
            case by_id[EffectIndex.effect_id(k)] do
              nil -> {:legacy, for(e <- effects, e.affecting == cited, do: feed_refs.(e))}
              e -> {:keyed, [feed_refs.(e)]}
            end
          wanted = Enum.reject(wanted, &(MapSet.size(&1) == 0))
          all = Enum.reduce(wanted, MapSet.new(), &MapSet.union/2)
          covers = fn set -> Enum.any?(wanted, &MapSet.subset?(&1, MapSet.new(set))) end
          dropped = old -- new
          added = new -- old
          stats =
            if wanted == [] do
              %{no_feed: 1}
            else
              %{
                sets: 1,
                covers_before: if(covers.(old), do: 1, else: 0),
                covers_after: if(covers.(new), do: 1, else: 0),
                equal_before: if(MapSet.new(old) in wanted, do: 1, else: 0),
                equal_after: if(MapSet.new(new) in wanted, do: 1, else: 0),
                dropped_in_feed: Enum.count(dropped, &(&1 in all)),
                dropped_not_in_feed: Enum.count(dropped, &(&1 not in all)),
                added_in_feed: Enum.count(added, &(&1 in all)),
                added_not_in_feed: Enum.count(added, &(&1 not in all))
              }
            end
          IO.puts(io, Enum.join([law, String.slice(k, -8, 8), target, kind, inspect(stats), inspect(old), inspect(new), inspect(Enum.map(wanted, &MapSet.to_list/1) |> Enum.take(3))], "\t"))
          Map.update(acc, kind, stats, &Map.merge(&1, stats, fn _, x, y -> x + y end))
        _ -> acc
      end
    end)
  end)

File.close(io)
IO.inspect(tally, label: "TALLY", limit: :infinity)
