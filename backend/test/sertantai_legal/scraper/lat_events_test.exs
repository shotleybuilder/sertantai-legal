defmodule SertantaiLegal.Scraper.LatEventsTest do
  # Registers the test process as the ChangeNotifier (not started in test) to
  # capture the casts — so not async.
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Scraper.{LatEvents, LatHash, LatPersister}
  alias SertantaiLegal.Scraper.LatHash.Query

  setup do
    Process.register(self(), SertantaiLegal.Zenoh.ChangeNotifier)

    name = "UK_ssi_2099_#{System.unique_integer([:positive])}"

    law =
      LegalRegister
      |> Ash.Changeset.for_create(:create, %{
        country: "uk",
        name: name,
        title_en: "Test Regulations",
        type_code: "ssi",
        year: 2099,
        number: "1"
      })
      |> Ash.create!()

    %{name: name, law: law}
  end

  defp row(name, n) do
    %{
      section_id: "#{name}:reg.#{n}",
      law_name: name,
      section_type: "article",
      part: nil,
      chapter: nil,
      heading_group: nil,
      schedule: nil,
      provision: "#{n}",
      sub: nil,
      paragraph: nil,
      sub_paragraph: nil,
      extent_code: "S",
      sort_key: "0000#{n}~",
      position: n,
      depth: 1,
      hierarchy_path: "reg.#{n}",
      text: "Text #{n}.",
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }
  end

  test "a persist event carries the committed row_count and lat_hash", %{name: name, law: law} do
    {:ok, _} = LatPersister.persist([row(name, 1), row(name, 2)], name, law.id)

    assert_receive {:"$gen_cast", {:notify, "lat", "persist", meta}}
    assert %{law_name: ^name, count: 2, row_count: 2, lat_hash: hash} = meta
    assert hash == Query.for_law(name).lat_hash
    refute hash == LatHash.empty_hash()
  end

  test "an event for a law with no LAT carries row_count 0 and the empty hash", %{name: name} do
    LatEvents.notify(name, "lat_deleted", %{lat_deleted: 3})

    assert_receive {:"$gen_cast", {:notify, "lat", "lat_deleted", meta}}
    assert meta == %{law_name: name, lat_deleted: 3, row_count: 0, lat_hash: LatHash.empty_hash()}
  end

  test "notify_laws/3 sends one event per law named in the section_ids", %{name: name} do
    other = name <> "0"

    LatEvents.notify_laws(
      ["#{name}:reg.1", "#{name}:reg.2", "#{other}:reg.4"],
      "persist",
      %{reason: "section_ids_fixed"}
    )

    assert_receive {:"$gen_cast",
                    {:notify, "lat", "persist", %{law_name: ^name, reason: "section_ids_fixed"}}}

    assert_receive {:"$gen_cast", {:notify, "lat", "persist", %{law_name: ^other}}}
    refute_receive {:"$gen_cast", _}
  end
end
