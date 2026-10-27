# round 13: each fix-list law read fresh from its stored text (no cache write), against the text's bound
alias SertantaiLegal.Scraper.AmendingLaw.Extent
alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache
alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

cases = [
  {"S1", "UK_ukpga_1971_11", "s.1", "E+W+S+NI"},
  {"S1", "UK_ukpga_1972_62", "s.9", "E+W+S+NI"},
  {"S1", "UK_ukpga_1976_55", "s.15", "E+W+S+NI"},
  {"S1", "UK_ukpga_1996_25", "s.41", "E+W+S+NI"},
  {"S1", "UK_ukpga_1990_16", "sch.3.para.7", "E+W+S+NI"},
  {"S1", "UK_ukpga_1995_45", "sch.5.para.1", "E+W+S+NI"},
  {"S1", "UK_ukpga_1993_11", "s.30", "E+W+S+NI"},
  {"S1", "UK_ukpga_1981_69", "s.15(1)", "E+W+S+NI"},
  {"S1", "UK_ukpga_1991_65", "s.8", "E+W+S+NI"},
  {"S1", "UK_ukpga_1982_49", "s.1", "E+W+S+NI"},
  {"S2", "UK_uksi_2005_457", "reg.2(1)(b)", "E+W"},
  {"S2", "UK_ukpga_1998_37", "s.36(2)(b)", "NI"},
  {"S2", "UK_ukpga_1981_29", "s.19(2)(b)", :not_ni},
  {"S2", "UK_uksi_2024_437", "reg.2(w)(ii)", "E+W+S+NI"},
  {"S2", "UK_uksi_2013_1506", "reg.34(a)", "E+W+S"},
  {"S13", "UK_ukpga_1995_45", "s.11(7)", "E+W+S"},
  {"S13", "UK_ukpga_2016_12", "s.14(1)", :not_uk},
  {"S13", "UK_uksi_2007_1843", "reg.5(1)", :not_s},
  {"S13", "UK_ukpga_1977_38", "sch.2.para.1", :not_s},
  {"S3", "UK_ukpga_2007_28", "s.1", "E+W"},
  {"S3", "UK_uksi_2019_530", "reg.100", :same},
  {"S3", "UK_ukpga_2022_6", "sch.2.para.46", :same},
  {"S3", "UK_uksi_2020_1540", "reg.16", :same},
  {"S4", "UK_ukpga_2022_30", "s.55", nil},
  {"S4", "UK_ukpga_2023_55", "sch.13", nil},
  {"S5", "UK_ukpga_1992_43", "s.56(1)", "E+W+S+NI"},
  {"S5", "UK_ukpga_1973_32", "s.58(1)", "S"},
  {"S5", "UK_ukpga_1998_31", "s.145", "E+W+S"},
  {"S5", "UK_ukpga_2017_3", "s.180", "E+W+S+NI"},
  {"S5", "UK_ukpga_1977_45", "s.65(1)", "E+W+NI"},
  {"S6", "UK_ukpga_1969_10", "s.34", "S"},
  {"S6", "UK_ukpga_1987_27", "s.42", "E+W"},
  {"S6", "UK_ukpga_1982_53", "s.3", "E+W"},
  {"S6", "UK_ukpga_1968_64", "s.1", "E+W"},
  {"S6", "UK_ukpga_1973_26", "s.1", "E+W"},
  {"S7", "UK_ukpga_1999_28", "s.1", "S+NI"},
  {"S7", "UK_ukpga_2010_29", "s.1", "E+W"},
  {"S9", "UK_ukpga_2006_41", "s.271", :not_uk},
  {"S9", "UK_ukpga_2014_2", "s.46", :not_uk},
  {"S10", "UK_ukpga_1974_40", "s.101", "E+W+S+NI"},
  {"S11", "UK_uksi_2020_818", "reg.16(1)", nil},
  {"S12", "UK_ukpga_1999_9", "s.15", :same},
  {"S15", "UK_ukpga_2023_55", "s.230", "E+W"},
  {"S16", "UK_ukpga_1972_20", "s.189", "E+W+S"}
]

for {shape, law, ref, want} <- cases do
  e = ReadCache.compute(law, ClmlStore.law_files(law)).read
  got = Extent.of(e, ref)

  ok =
    case want do
      :not_ni -> got != nil and not String.contains?(got, "NI")
      :not_uk -> got != "E+W+S+NI"
      :not_s -> got != "S"
      w -> got == w
    end

  IO.puts(
    "#{if ok, do: "OK  ", else: "MISS"} #{shape} #{law} #{ref} got=#{inspect(got)} want=#{inspect(want)} default=#{inspect(e.default)}"
  )
end
