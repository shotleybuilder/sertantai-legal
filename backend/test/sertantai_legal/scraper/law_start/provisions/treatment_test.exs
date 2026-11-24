defmodule SertantaiLegal.Scraper.LawStart.Provisions.TreatmentTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Provisions.Treatment

  test "a tail's treatment: dated, by order, unread" do
    assert Treatment.tail_treatment("on 31st May 2015", nil) == {:provision_dated, ~D[2015-05-31]}

    assert Treatment.tail_treatment("in relation to Wales on 1st October 2020", nil) ==
             {:provision_dated, ~D[2020-10-01]}

    assert Treatment.tail_treatment(
             "on such day as the Secretary of State may by order appoint",
             nil
           ) == {:provision_by_order, nil}

    assert Treatment.tail_treatment("when the moon is blue", nil) == {:provision_unread, nil}
  end

  test "an exception is relative to the first provision named, never a Part" do
    assert Treatment.relative_base([{"UK_x:reg.4", 1}], "UK_x:reg.1") == "UK_x:reg.4"
    assert Treatment.relative_base([{"UK_x:pt.7", 1}], "UK_x:reg.1") == "UK_x:reg.1"
  end
end
