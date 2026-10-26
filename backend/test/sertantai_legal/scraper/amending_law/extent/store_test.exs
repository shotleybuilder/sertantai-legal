defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.StoreTest do
  use SertantaiLegal.DataCase, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Store

  test "an SI stating no extent is stored with its legislature's competence, never bare" do
    law = "UK_nisr_2099_901"
    assert {:ok, _, %Extent{competence: "NI"}} = Store.write_read(law, %Extent{}, cached: true)
    assert Enum.any?(Store.rows_for([law])[law], &(&1.kind == "competence" and &1.place == "NI"))
  end

  test "a stated default is stored as read" do
    law = "UK_uksi_2099_902"

    e = %Extent{
      default: "E+W",
      ref: "reg.1",
      text: "These Regulations extend to England and Wales."
    }

    assert {:ok, _, ^e} = Store.write_read(law, e, cached: true)
    assert Enum.map(Store.rows_for([law])[law], & &1.kind) == ["default"]
  end
end
