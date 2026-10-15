defmodule SertantaiLegal.Scraper.CommentaryPersisterTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{CommentaryPersister, NotePointer}

  test "each note is stored with its pointer law and change id, and no fact read from its text (LR-25)" do
    law =
      LegalRegister
      |> Ash.Changeset.for_create(:create, %{
        country: "uk",
        name: "UK_uksi_2099_7",
        title_en: "Test",
        type_code: "uksi",
        year: 2099,
        number: "7"
      })
      |> Ash.create!()

    text = "Reg. 1 revoked (1.4.2021) by S.I. 2021/5 reg. 3"

    {:ok, %{inserted: 1}} =
      CommentaryPersister.persist(
        [
          %{
            id: "UK_uksi_2099_7_F1",
            law_name: "UK_uksi_2099_7",
            code: "F1",
            code_type: :amendment,
            source: "lat_parser",
            text: text,
            affected_sections: ["UK_uksi_2099_7:reg.1"]
          }
        ],
        "UK_uksi_2099_7",
        law.id
      )

    assert %{rows: [[by, cid]]} =
             Repo.query!(
               "SELECT changed_by, change_id FROM amendment_annotations WHERE law_name = 'UK_uksi_2099_7'"
             )

    assert by == "UK_uksi_2021_5"
    assert cid == NotePointer.change_id("UK_uksi_2099_7", text)
  end
end
