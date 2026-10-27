# CV-S05d run-03: Extent.of on the new wordings found (read-only)
alias SertantaiLegal.Scraper.AmendingLaw.Extent
alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Lookup, ReadCache}

cases = [
  {"S13 owner read whole", "UK_ukpga_1995_45", ["s.11(1)", "s.11(7)"]},
  {"S13 owner read whole", "UK_ukpga_2016_12", ["s.14(5)", "s.14(1)"]},
  {"S13 owner read whole", "UK_uksi_2007_1843", ["reg.5(28)", "reg.5(1)"]},
  {"S13 owner read whole", "UK_ukpga_1980_51", ["sch.25.para.11", "sch.25.para.1"]},
  {"S13 owner read whole", "UK_ukpga_1977_38", ["s.12"]},
  {"S1 except-for form", "UK_ukpga_1982_49", ["s.1"]},
  {"S1 except-for form", "UK_ukpga_1991_65", ["s.8"]},
  {"S1 except-for form", "UK_ukpga_1973_26", ["s.86", "sch.3", "s.88"]},
  {"S6 two statements", "UK_ukpga_1987_27", ["s.42", "s.44"]},
  {"S6 verb in last item", "UK_ukpga_1982_53", ["s.3", "s.17"]},
  {"S2 sub-letters", "UK_ukpga_1985_71", ["sch.2.para.7(3)", "sch.2.para.7(1)", "sch.2.para.10"]}
]

for {shape, law, refs} <- cases do
  e = ReadCache.law(law).read
  got = Enum.map_join(refs, "  ", &"#{&1}=#{inspect(Extent.of(e, &1))}")
  IO.puts("#{shape} | #{law} default=#{inspect(e.default)} | #{got}")
end

# "Section 61B(1) to (7) … cease to apply in relation to England" (ukpga 2013/27 s.5)
e = ReadCache.law("UK_ukpga_2013_27").read

IO.puts(
  "S14 cease to apply | UK_ukpga_2013_27 | applies rows #{inspect(Enum.filter(e.applies, fn {_, _, r} -> "s.61B(1)" in r end))}"
)

_ = Lookup
