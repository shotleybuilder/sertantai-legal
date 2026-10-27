alias SertantaiLegal.Scraper.AmendingLaw.Extent
alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache

for {law, refs} <- [
      {"UK_ukpga_2017_3", ["s.180", "s.182", "s.184"]},
      {"UK_ukpga_1977_45", ["s.65(1)", "s.65(4)", "s.65(7)", "s.38"]}
    ] do
  e = ReadCache.law(law).read
  for r <- refs, do: IO.puts("#{law} #{r} -> #{inspect(Extent.of(e, r))}")
end
