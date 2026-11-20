# Every claim set the markup reader's joined-SectionRef fix moves, in full,
# with the law's family: a stage module (before) against the working
# Readers.Markup, over the laws listed. Reads the register for the family
# names; writes only the report. Args: STAGE_FILE STAGE_MODULE LAWS_FILE OUT
[stage_file, stage_mod, laws_file, out] = System.argv()
Code.compiler_options(ignore_module_conflict: true)
Code.require_file(stage_file)
before_mod = Module.concat([stage_mod])
alias SertantaiLegal.Scraper.Amendment.PatternSource
alias SertantaiLegal.Scraper.ChangeVocabulary.{Build, Readers.Markup}

families =
  for f <- ["Waste, Water and Climate", "Environmental Protection", "OH&S: Occupational",
            "OH&S: Mines & Quarries", "FIRE", "FIRE: Dangerous and Explosive Substances",
            "OH&S: Gas & Electrical Safety", "OH&S: Offshore Safety", "Maritime Safety"],
      law <- (try do PatternSource.family_laws(f) rescue e -> IO.puts("#{f}: #{Exception.message(e)}"); [] end),
      reduce: %{} do
    m -> Map.put_new(m, law, f)
  end

sets = fn rows ->
  Map.new(rows, fn {k, t, cs} -> {{k, t}, cs |> Enum.map(&{&1.attribute, &1.value}) |> Enum.sort()} end)
end

short = fn k -> String.slice(k, -8, 8) end
laws = laws_file |> File.read!() |> String.split(~r/\s+/, trim: true) |> Enum.uniq()
{:ok, io} = File.open(out, [:write, :utf8])

for law <- laws do
  [_, t, y, n] = String.split(law, "_", parts: 4)
  path = "data/cache/clml/#{t}/#{y}/#{n}/body/data.xml.gz"
  family = Map.get(families, law, "-")

  if File.exists?(path) do
    doc = path |> File.read!() |> :zlib.gunzip() |> SweetXml.parse(quiet: true, namespace_conformant: false)
    ids = Build.xml_ids(law)
    a = sets.(before_mod.read(doc, law, ids))
    b = sets.(Markup.read(doc, law, ids))

    for {{k, target}, old} <- a, not Map.has_key?(b, {k, target}),
        do: IO.puts(io, Enum.join([law, family, short.(k), target, "GONE", inspect(old)], "\t"))

    for {{k, target}, new} <- b do
      case a[{k, target}] do
        nil -> IO.puts(io, Enum.join([law, family, short.(k), target, "ADDED", inspect(new)], "\t"))
        ^new -> :same
        old -> IO.puts(io, Enum.join([law, family, short.(k), target, inspect(old -- new, limit: :infinity), inspect(new -- old, limit: :infinity)], "\t"))
      end
    end
  end
end

File.close(io)
