# In-memory diff of the markup reader: a stage module (before) against the
# working Readers.Markup (after), over the laws listed. Writes nothing but
# the report. Args: STAGE_FILE STAGE_MODULE LAWS_FILE OUT
[stage_file, stage_mod, laws_file, out] = System.argv()
Code.compiler_options(ignore_module_conflict: true)
Code.require_file(stage_file)
before_mod = Module.concat([stage_mod])
alias SertantaiLegal.Scraper.ChangeVocabulary.{Build, Readers.Markup}

norm = fn sets -> MapSet.new(sets, fn {k, t, cs} -> {k, t, cs |> Enum.map(&{&1.attribute, &1.value}) |> Enum.sort()} end) end

laws = laws_file |> File.read!() |> String.split(~r/\s+/, trim: true) |> Enum.uniq()
{:ok, io} = File.open(out, [:write, :utf8])

totals =
  Enum.reduce(laws, %{laws: 0, moved_laws: 0, gone: 0, added: 0, attrs: %{}}, fn law, acc ->
    [_, t, y, n] = String.split(law, "_", parts: 4)
    path = "data/cache/clml/#{t}/#{y}/#{n}/body/data.xml.gz"

    if File.exists?(path) do
      doc = path |> File.read!() |> :zlib.gunzip() |> SweetXml.parse(quiet: true, namespace_conformant: false)
      ids = Build.xml_ids(law)
      a = norm.(before_mod.read(doc, law, ids))
      b = norm.(Markup.read(doc, law, ids))
      gone = MapSet.difference(a, b) |> Enum.to_list()
      added = MapSet.difference(b, a) |> Enum.to_list()
      ka = Map.new(gone, fn {k, t, cs} -> {{k, t}, cs} end)
      kb = Map.new(added, fn {k, t, cs} -> {{k, t}, cs} end)
      attrs =
        for {kt, cs} <- kb, old = ka[kt], old != nil, {attr, v} <- cs, List.keyfind(old, attr, 0) != {attr, v}, reduce: %{} do
          m -> Map.update(m, attr, 1, &(&1 + 1))
        end
      only_gone = Enum.count(Map.keys(ka), &(not Map.has_key?(kb, &1)))
      only_added = Enum.count(Map.keys(kb), &(not Map.has_key?(ka, &1)))
      if gone != [] or added != [] do
        IO.puts(io, "#{law}: targets gone #{only_gone}, added #{only_added}, attrs #{inspect(attrs)}")
        for {k, t, _} <- Enum.take(gone, 3), not Map.has_key?(kb, {k, t}), do: IO.puts(io, "  - #{String.slice(k, -8, 8)} #{t}")
        for {k, t, _} <- Enum.take(added, 3), not Map.has_key?(ka, {k, t}), do: IO.puts(io, "  + #{String.slice(k, -8, 8)} #{t}")
        for {{k, t}, cs} <- Enum.take(kb, 2), old = ka[{k, t}], old != nil,
            do: IO.puts(io, "  ~ #{String.slice(k, -8, 8)} #{t} #{inspect(cs -- old)} was #{inspect(old -- cs)}" |> String.slice(0, 400))
      end
      %{acc | laws: acc.laws + 1, moved_laws: acc.moved_laws + if(gone != [] or added != [], do: 1, else: 0),
        gone: acc.gone + only_gone, added: acc.added + only_added,
        attrs: Map.merge(acc.attrs, attrs, fn _, x, y -> x + y end)}
    else
      acc
    end
  end)

IO.puts(io, "\nTOTAL #{inspect(totals)}")
File.close(io)
IO.puts("TOTAL #{inspect(totals)}")
