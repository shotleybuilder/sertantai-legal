# CV-S05d run-02: Extent.of on a sample of each candidate wording (read-only)
alias SertantaiLegal.Scraper.AmendingLaw.Extent
alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache

cases = [
  {"S1 exception list", "UK_ukpga_1971_11", ["s.1", "s.17"]},
  {"S1 exception list", "UK_ukpga_1972_62", ["s.9", "sch.4"]},
  {"S1 exception list", "UK_ukpga_1976_55", ["s.15", "s.26(1)"]},
  {"S1 exception list", "UK_ukpga_1996_25", ["s.37", "s.41"]},
  {"S1 exception list", "UK_ukpga_1990_16", ["sch.3.para.7"]},
  {"S1 exception list", "UK_ukpga_1995_45", ["sch.5.para.1"]},
  {"S1 exception list", "UK_ukpga_1993_11", ["s.30"]},
  {"S1 exception list", "UK_ukpga_1981_69", ["s.15(1)", "sch.10"]},
  {"S1 range end", "UK_ukpga_1989_29", ["s.32Z1", "s.32Z2"]},
  {"S2 sub-letters", "UK_uksi_2005_457", ["reg.2(1)(a)", "reg.2(1)(b)"]},
  {"S2 sub-letters", "UK_ukpga_1998_37", ["s.36(2)(b)", "s.36(2)(d)"]},
  {"S2 sub-letters", "UK_ukpga_1981_29", ["s.19(2)(b)"]},
  {"S2 sub-letters", "UK_uksi_2024_437", ["reg.2(w)(ii)", "reg.2(x)"]},
  {"S3 or-lists", "UK_uksi_2019_530", ["reg.100"]},
  {"S3 or-lists", "UK_ukpga_2022_6", ["sch.2.para.46"]},
  {"S3 or-lists", "UK_uksi_2020_1540", ["reg.16"]},
  {"S4 qualified companion", "UK_ukpga_2022_30", ["s.55"]},
  {"S4 qualified companion", "UK_ukpga_2023_55", ["sch.13"]},
  {"S5 own subsections", "UK_ukpga_1992_43", ["s.56(1)"]},
  {"S5 own subsections", "UK_ukpga_1973_32", ["s.58(1)"]},
  {"S5 own subsections", "UK_ukpga_1998_31", ["s.145"]},
  {"S6 two statements", "UK_ukpga_1969_10", ["s.34", "s.35"]},
  {"S9 qualified read whole", "UK_ukpga_2006_41", ["s.271", "s.260"]},
  {"S10 ellipsis", "UK_ukpga_1974_40", ["s.101"]},
  {"S11 Schedule locator", "UK_ukpga_1977_38", ["sch.2.para.1", "sch.2.para.11"]},
  {"check", "UK_ukpga_2021_30", ["s.100"]},
  {"check", "UK_ukpga_1985_71", ["sch.2.para.10"]},
  {"check", "UK_ukpga_1972_11", ["sch.7.para.1"]},
  {"check", "UK_ukpga_1990_43", ["s.153"]},
  {"check", "UK_ukpga_2013_24", ["s.83", "s.10"]},
  {"check", "UK_uksi_2009_462", ["sch.1.para.25", "sch.3.para.14"]}
]

for {shape, law, refs} <- cases do
  e = ReadCache.law(law).read
  got = Enum.map_join(refs, "  ", &"#{&1}=#{inspect(Extent.of(e, &1))}")
  IO.puts("#{shape} | #{law} default=#{inspect(e.default)} | #{got}")
end
