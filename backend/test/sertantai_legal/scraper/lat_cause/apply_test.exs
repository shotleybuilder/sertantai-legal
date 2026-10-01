defmodule SertantaiLegal.Scraper.LatCause.ApplyTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatPersister, LatStatus}
  alias SertantaiLegal.Scraper.LatCause.Apply

  @paths ["/uksi/2099/1/body/data.xml"]

  defp row(name, text) do
    %{
      section_id: "#{name}:reg.1",
      law_name: name,
      section_type: "article",
      part: nil,
      chapter: nil,
      heading_group: nil,
      schedule: nil,
      provision: "1",
      sub: nil,
      paragraph: nil,
      sub_paragraph: nil,
      extent_code: "S",
      sort_key: "00001~",
      position: 1,
      depth: 1,
      hierarchy_path: "reg.1",
      text: text,
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }
  end

  defp xml(valid), do: "<Legislation><dct:valid>#{valid}</dct:valid><Body/></Legislation>"

  # One parse operation: snapshot → persist → (notes) → record.
  defp parse!(name, law_id, text, xml, opts \\ []) do
    before = Apply.snapshot(name)
    {:ok, %{op_id: op_id}} = LatPersister.persist([row(name, text)], name, law_id)

    for note <- Keyword.get(opts, :notes, []) do
      Repo.query!(
        """
        INSERT INTO amendment_annotations (id, country, law_name, law_id, code, code_type, source, text, affected_sections, created_at, updated_at)
        VALUES ($1, 'uk', $2, $3, 'F1', 'amendment', 'lat_parser', $4, $5, now(), now())
        """,
        [
          "#{name}_#{System.unique_integer([:positive])}",
          name,
          Ecto.UUID.dump!(law_id),
          note,
          ["#{name}:reg.1"]
        ]
      )
    end

    LatStatus.Apply.refresh(name)
    cause = Apply.record(name, op_id, before, {[xml], @paths}, opts[:explicit])

    %{rows: [[stored, hash, valid, paths]]} =
      Repo.query!(
        "SELECT cause, source_hash, source_valid_date, source_paths FROM lat_events WHERE op_key = $1 AND event = 'parsed'",
        [op_id]
      )

    assert stored == cause
    assert is_binary(hash)
    assert paths == @paths
    {cause, valid}
  end

  test "a law's parse lifecycle: initial → parser → legislative → unattributed → correction" do
    name = "UK_uksi_2099_#{System.unique_integer([:positive])}"

    law =
      LegalRegister
      |> Ash.Changeset.for_create(:create, %{
        country: "uk",
        name: name,
        title_en: "Test Regulations",
        type_code: "uksi",
        year: 2099,
        number: "1"
      })
      |> Ash.create!()

    assert {"initial", ~D[2024-01-01]} =
             parse!(name, law.id, "The occupier must keep a record.", xml("2024-01-01"))

    # same source CLML (a parser-only re-run)
    assert {"parser", _} =
             parse!(name, law.id, "The occupier must keep a record.", xml("2024-01-01"))

    # the source changed, with a new amendment note
    assert {"legislative", ~D[2025-06-01]} =
             parse!(name, law.id, "The occupier must keep a written record.", xml("2025-06-01"),
               notes: ["Words in reg. 1 inserted (1.6.2025) by S.I. 2025/9 reg. 2"]
             )

    # the source and text changed, no new note or status change
    assert {"unattributed", _} =
             parse!(
               name,
               law.id,
               "The occupier must keep a full written record.",
               xml("2025-07-01")
             )

    # a caller-flagged correction
    assert {"correction", _} =
             parse!(
               name,
               law.id,
               "The occupier must keep a full written record.",
               xml("2025-08-01"),
               explicit: "correction"
             )
  end
end
