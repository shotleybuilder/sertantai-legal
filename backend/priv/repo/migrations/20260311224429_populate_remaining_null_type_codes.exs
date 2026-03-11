defmodule SertantaiLegal.Repo.Migrations.PopulateRemainingNullTypeCodes do
  @moduledoc """
  Populate type_code for the remaining 59 records where name has the UK__YYYY_NNN
  format (no type_code embedded in the name). Each type_code was individually
  verified against legislation.gov.uk by following redirects to the canonical URL.
  """
  use Ecto.Migration

  def up do
    # ukpga (UK Public General Acts)
    for name <- ~w(UK__1924_5 UK__1936_27 UK__2004_21) do
      execute(
        "UPDATE uk_lrt SET type_code = 'ukpga' WHERE name = '#{name}' AND type_code IS NULL"
      )
    end

    # nisi (Northern Ireland Orders in Council)
    for name <- ~w(UK__1984_1821 UK__1992_1728 UK__2006_1254) do
      execute("UPDATE uk_lrt SET type_code = 'nisi' WHERE name = '#{name}' AND type_code IS NULL")
    end

    # nisr (Northern Ireland Statutory Rules)
    for name <- ~w(UK__2004_63 UK__2009_248) do
      execute("UPDATE uk_lrt SET type_code = 'nisr' WHERE name = '#{name}' AND type_code IS NULL")
    end

    # ssi (Scottish Statutory Instruments)
    for name <- ~w(UK__2005_207 UK__2005_344 UK__2006_456 UK__2006_457 UK__2006_458 UK__2013_51) do
      execute("UPDATE uk_lrt SET type_code = 'ssi' WHERE name = '#{name}' AND type_code IS NULL")
    end

    # wsi (Wales Statutory Instruments)
    for name <- ~w(UK__2004_2555 UK__2016_406) do
      execute("UPDATE uk_lrt SET type_code = 'wsi' WHERE name = '#{name}' AND type_code IS NULL")
    end

    # uksi (UK Statutory Instruments) — all remaining
    uksi_names = ~w(
      UK__1967_1485 UK__1974_1885 UK__1974_2166 UK__1976_51 UK__1981_687
      UK__1987_1331 UK__1987_52 UK__1989_1671 UK__1989_971 UK__1990_304
      UK__1991_446 UK__1992_2885 UK__1994_3260 UK__1996_247 UK__1996_890
      UK__1997_195 UK__1997_1993 UK__1997_2703 UK__1998_2885 UK__1999_1877
      UK__1999_2550 UK__2001_3766 UK__2003_106 UK__2004_3168 UK__2005_1541
      UK__2005_1732 UK__2005_2001 UK__2005_2669 UK__2006_3311 UK__2007_2598
      UK__2010_328 UK__2010_471 UK__2011_2228 UK__2012_123 UK__2012_332
      UK__2013_1666 UK__2013_1758 UK__2014_28 UK__2015_1406 UK__2015_236
      UK__2020_641 UK__2021_730 UK__2023_320
    )

    for name <- uksi_names do
      execute("UPDATE uk_lrt SET type_code = 'uksi' WHERE name = '#{name}' AND type_code IS NULL")
    end
  end

  def down do
    :ok
  end
end
