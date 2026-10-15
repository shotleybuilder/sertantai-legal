defmodule SertantaiLegal.Scraper.LabelRefreshTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LabelRefresh

  test "a failed refresh is recorded as a labels_failed lat_event with its reason" do
    LegalRegister
    |> Ash.Changeset.for_create(:create, %{
      country: "uk",
      name: "UK_uksi_2099_1",
      title_en: "Test",
      type_code: "uksi",
      year: 2099,
      number: "1"
    })
    |> Ash.create!()

    :ok = LabelRefresh.record_failure("UK_uksi_2099_1", {:fidelity, 3})

    assert %{rows: [["labels_failed", reason, "label_refresh"]]} =
             Repo.query!(
               "SELECT event, reason, source FROM lat_events WHERE law_name = 'UK_uksi_2099_1'"
             )

    assert reason =~ "fidelity"
  end
end
