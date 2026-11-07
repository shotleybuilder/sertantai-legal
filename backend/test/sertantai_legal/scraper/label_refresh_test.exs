defmodule SertantaiLegal.Scraper.LabelRefreshTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LabelRefresh

  defp register(name) do
    [_, type, year, number] = String.split(name, "_")

    LegalRegister
    |> Ash.Changeset.for_create(:create, %{
      country: "uk",
      name: name,
      title_en: "Test",
      type_code: type,
      year: String.to_integer(year),
      number: number
    })
    |> Ash.create!()
  end

  test "a refresh is recorded as a labels_refreshed lat_event with the labels version" do
    register("UK_uksi_2099_2")

    :ok = LabelRefresh.record_success("UK_uksi_2099_2", %{records: 7, periods: 12})

    assert %{rows: [["labels_refreshed", prov]]} =
             Repo.query!(
               "SELECT event, provenance FROM lat_events WHERE law_name = 'UK_uksi_2099_2'"
             )

    assert prov == %{
             "labels_version" => SertantaiLegal.Scraper.LabelVersion.current(),
             "records" => 7,
             "periods" => 12
           }
  end

  test "a failed refresh is recorded as a labels_failed lat_event with its reason" do
    register("UK_uksi_2099_1")

    :ok = LabelRefresh.record_failure("UK_uksi_2099_1", {:fidelity, 3})

    assert %{rows: [["labels_failed", reason, "label_refresh"]]} =
             Repo.query!(
               "SELECT event, reason, source FROM lat_events WHERE law_name = 'UK_uksi_2099_1'"
             )

    assert reason =~ "fidelity"
  end

  test "a switched law's timeline is stamped with the change vocabulary's version" do
    assert LabelRefresh.code_version(true) ==
             SertantaiLegal.Scraper.ChangeVocabulary.Version.current()

    assert LabelRefresh.code_version(false) ==
             SertantaiLegal.Scraper.LabelTimeline.code_version()
  end

  test "a switched law's refresh records the change vocabulary's version (#193)" do
    register("UK_uksi_2099_3")
    version = SertantaiLegal.Scraper.ChangeVocabulary.Version.current()

    :ok =
      LabelRefresh.record_success("UK_uksi_2099_3", %{
        records: 0,
        periods: 4,
        changes_version: version
      })

    assert %{rows: [[%{"changes_version" => ^version, "periods" => 4}]]} =
             Repo.query!("SELECT provenance FROM lat_events WHERE law_name = 'UK_uksi_2099_3'")
  end
end
