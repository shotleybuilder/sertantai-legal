defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelSwitchDbTest do
  @moduledoc """
  A switched law's stored timeline read back as the rows the switch keeps
  for its known limits (Maritime Safety: Switch-over, 2026-11-07: the
  refresh no longer rebuilds the old register to get them).
  """
  use SertantaiLegal.DataCase, async: true

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.LabelSwitch

  test "the stored periods, as timeline rows; empty lists where the table holds none" do
    Repo.insert_all("lat_label_timeline", [
      %{
        id: Ecto.UUID.bingenerate(),
        law_name: "UK_uksi_2099_4",
        section_id: "UK_uksi_2099_4:reg.1",
        valid_from: ~D[2099-01-01],
        status: "in_force",
        in_force_from: ~D[2099-01-01],
        changed_by: nil,
        territory: "E+W",
        change_ids: [],
        code_version: "x",
        built_at: ~N[2099-01-01 00:00:00]
      }
    ])

    assert [row] = LabelSwitch.stored("UK_uksi_2099_4")

    assert row == %{
             law_name: "UK_uksi_2099_4",
             section_id: "UK_uksi_2099_4:reg.1",
             valid_from: ~D[2099-01-01],
             valid_to: nil,
             status: "in_force",
             in_force_from: ~D[2099-01-01],
             changed_by: nil,
             territory: "E+W",
             change_ids: [],
             changed_by_all: [],
             commenced_by: []
           }
  end
end
