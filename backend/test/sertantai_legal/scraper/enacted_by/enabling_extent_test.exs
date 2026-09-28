defmodule SertantaiLegal.Scraper.EnactedBy.EnablingExtentTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.EnactedBy.EnablingExtent
  alias SertantaiLegal.Scraper.ExtentBackfill
  alias SertantaiLegal.Scraper.LatPersister

  defp law(type, attrs) do
    n = System.unique_integer([:positive])
    name = "UK_#{type}_2099_#{n}"

    LegalRegister
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{country: "uk", name: name, title_en: "T", type_code: type, year: 2099, number: "#{n}"},
        attrs
      )
    )
    |> Ash.create!()
  end

  defp section(name, n, extent) do
    %{
      section_id: "#{name}:s.#{n}",
      law_name: name,
      section_type: "section",
      part: "3",
      chapter: nil,
      heading_group: nil,
      schedule: nil,
      provision: "#{n}",
      sub: nil,
      paragraph: nil,
      sub_paragraph: nil,
      extent_code: extent,
      sort_key: "000." <> String.pad_leading("#{n}", 6, "0") <> "~",
      position: n,
      depth: 1,
      hierarchy_path: nil,
      text: "Section #{n}.",
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }
  end

  setup do
    act = law("ukpga", %{geo_extent: "GB", geo_extent_source: "law_level"})

    {:ok, _} =
      LatPersister.persist(
        [
          section(act.name, 82, "E+W"),
          section(act.name, 219, "E+W"),
          section(act.name, 221, "E+W+S")
        ],
        act.name,
        act.id
      )

    %{act: act}
  end

  test "the enabling sections' extents, all-or-nothing", %{act: act} do
    assert EnablingExtent.extents(%{
             "provisions" => [
               %{"law" => act.name, "sections" => ["82", "219"], "schedules" => []}
             ]
           }) ==
             ["E+W"]

    assert EnablingExtent.extents(%{
             "provisions" => [
               %{"law" => act.name, "sections" => ["82", "999"], "schedules" => []}
             ]
           }) ==
             nil

    assert EnablingExtent.extents(nil) == nil
  end

  test "an unrevised SI with a legacy UK extent is bounded by its enabling sections (Surface Waters Regs 1994)",
       %{act: act} do
    si =
      law("uksi", %{
        geo_extent: "UK",
        document_status: "final",
        enabling_provisions: %{
          "provisions" => [%{"law" => act.name, "sections" => ["82", "219"], "schedules" => []}]
        }
      })

    ExtentBackfill.refresh(si.name)

    %{rows: [[extent, source]]} =
      Repo.query!("SELECT geo_extent, geo_extent_source FROM legal_register WHERE name = $1", [
        si.name
      ])

    assert {extent, source} == {"E+W", "enabling_provisions"}
  end
end
