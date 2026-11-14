defmodule SertantaiLegal.Scraper.LawStart.TerritorialTest do
  @moduledoc "The country a commencement statement is for (`LawStart.Territorial`)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Territorial

  test "a country alone qualifies the statement" do
    assert Territorial.only(
             "The provisions come into force in relation to England, in accordance with provision made by order by the Secretary of State"
           ) == "England"

    assert Territorial.only(
             "Section 1 come into force in relation to premises in Wales, on such day as the Welsh Ministers may appoint"
           ) == "Wales"
  end

  test "never with another qualifier, two countries, or none" do
    refute Territorial.only(
             "Section 2 comes into force in relation to Wales, for the purpose of making regulations, on such day as …"
           )

    refute Territorial.only(
             "… on such day as the Secretary of State (as respects England) or the Assembly (as respects Wales) may by order appoint"
           )

    refute Territorial.only("Section 2 comes into force on such day as the Minister may appoint")
  end

  test "a subject commenced in its application to each country (1969 c.10 s.38(3))" do
    assert {"Part II of this Act",
            [
              {"England and Wales", "on such day as the Ministers may by order jointly appoint"},
              {"Scotland",
               "on such day as the Secretary of State for Scotland may by order so made appoint"}
            ]} =
             Territorial.by_application(
               "Part II of this Act, in its application to England and Wales, shall come into operation on such day as the Ministers may by order jointly appoint, and in its application to Scotland on such day as the Secretary of State for Scotland may by order so made appoint."
             )

    refute Territorial.by_application(
             "Part II of this Act shall come into operation on 1st May 1970."
           )
  end
end
