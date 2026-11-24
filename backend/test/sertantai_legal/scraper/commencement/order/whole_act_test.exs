defmodule SertantaiLegal.Scraper.Commencement.Order.WholeActTest do
  @moduledoc "An order's statement of the whole Act, or all of it but some (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.WholeAct

  test "rest_of/1: the rest of the Act, less what is excepted" do
    assert {"the Act", refs} = WholeAct.rest_of("The rest of the Act, except sections 85 to 87,")
    assert refs != []
    assert WholeAct.rest_of("The Act") == {"The Act", []}
  end

  test "apart/1: all but a paragraph's provisions" do
    assert {{"paragraph", "2"}, "the Act"} =
             WholeAct.apart("Apart from the provisions mentioned in paragraph (2), the Act")
  end
end
