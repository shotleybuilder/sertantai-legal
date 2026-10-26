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

  test "an extent read the same as stored is not written again (run time 2026-10-26)" do
    law = "UK_uksi_2099_903"

    e = %Extent{
      default: "E+W",
      ref: "reg.1",
      text: "These Regulations extend to England and Wales."
    }

    {:ok, _, _} = Store.write_read(law, e, cached: true)

    ids = fn ->
      SertantaiLegal.Repo.query!("SELECT id FROM extent_rules WHERE source_law = $1", [law]).rows
    end

    before = ids.()
    {:ok, _, _} = Store.write_read(law, e, cached: true)
    assert ids.() == before
    {:ok, _, _} = Store.write_read(law, %{e | default: "E+W+S"}, cached: true)
    refute ids.() == before
  end
end
