defmodule SertantaiLegal.Scraper.Commencement.RefContextTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Order, RefContext}

  test "a Schedule paragraph's ancestors are its Parts, then its Schedule" do
    a = RefContext.context().ancestors
    assert a.("sch.4.pt.2.para.3") == ["sch.4.pt.2", "sch.4"]
    assert a.("sch.para.3") == ["sch"]
    assert a.("s.3") == []
  end

  test "Order.context/0 is the same context" do
    assert Order.context().ancestors.("sch.4.pt.2.para.3") ==
             RefContext.context().ancestors.("sch.4.pt.2.para.3")
  end
end
