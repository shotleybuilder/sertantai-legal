defmodule SertantaiLegal.Scraper.Commencement.ClmlRefTest do
  @moduledoc """
  A CLML id as a LAT ref, in its own module (the Commencement reader's speed
  fixes: the CLML rows' cache reaches no order reading); `Order.ref/1`
  delegates here.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{ClmlRef, Order}

  test "provisions, Schedules and their Parts and paragraphs" do
    assert ClmlRef.ref("section-36-3") == "s.36(3)"
    assert ClmlRef.ref("regulation-4-2-a") == "reg.4(2)(a)"
    assert ClmlRef.ref("article-2") == "reg.2"
    assert ClmlRef.ref("schedule-11-paragraph-137-a") == "sch.11.para.137(a)"
    assert ClmlRef.ref("schedule-4-part-2-paragraph-3") == "sch.4.pt.2.para.3"
    assert ClmlRef.ref("schedule-paragraph-1") == "sch.para.1"
    assert ClmlRef.ref("crossheading-1") == nil
  end

  test "Order.ref/1 is the same reading" do
    for id <- ~w(section-36-3 schedule-4-part-2-paragraph-3 schedule-paragraph-1),
        do: assert(Order.ref(id) == ClmlRef.ref(id))
  end

  test "a provision kind's prefix: domestic articles are reg." do
    assert ClmlRef.prefix("section") == "s"
    assert ClmlRef.prefix("article") == "reg"
  end
end
