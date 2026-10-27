alias SertantaiLegal.Scraper.AmendingLaw.Extent
alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache

for {law, refs} <- [
      {"UK_ukpga_2007_28", ["s.1", "s.10", "s.60"]},
      {"UK_ukpga_1980_66", ["s.264(3)", "s.264(3)(b)", "s.264(a)"]},
      {"UK_ukpga_1990_8", ["s.70(2)", "s.70(2)(b)"]},
      {"UK_ukpga_2014_2", ["s.46"]},
      {"UK_ukpga_1999_9", ["s.15", "sch.3"]},
      {"UK_ukpga_1999_28", ["s.1"]},
      {"UK_ukpga_2010_29", ["s.1"]},
      {"UK_ukpga_1968_64", ["s.1"]}
    ] do
  e = ReadCache.law(law).read
  IO.puts("#{law} default=#{inspect(e.default)}")
  for r <- refs, do: IO.puts("#{law} #{r} -> #{inspect(Extent.of(e, r))}")
end
