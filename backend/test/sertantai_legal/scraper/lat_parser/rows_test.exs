defmodule SertantaiLegal.Scraper.LatParser.RowsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatParser.Rows

  defp row(fields) do
    Map.merge(
      %{
        element: "P1",
        schedule: nil,
        part: nil,
        chapter: nil,
        heading_group: nil,
        provision: nil,
        sub: nil,
        paragraph: nil,
        sub_paragraph: nil,
        extent_code: nil,
        text: "x",
        commentary_refs: [],
        excluded_extent: nil,
        from_version: false
      },
      Map.new(fields)
    )
  end

  test "mode/1: Acts number sections, everything else regulations/articles" do
    assert Rows.mode("ukpga") == :section
    assert Rows.mode("asc") == :section
    assert Rows.mode("uksi") == :article
  end

  test "drop_repeated_versions/1: a version row repeating the body adds nothing" do
    body = row(provision: "7", extent_code: "E")
    copy = row(provision: "7", extent_code: "E", from_version: true)
    other = row(provision: "7", extent_code: "W", from_version: true)

    assert Rows.drop_repeated_versions([body, copy, other]) ==
             Enum.map([body, other], &Map.delete(&1, :from_version))
  end

  test "assign_positions/1 numbers from 1" do
    assert [%{position: 1}, %{position: 2}] = Rows.assign_positions([row([]), row([])])
  end

  test "build_fields/4: section_id, citation, sort_key, depth" do
    [r] =
      [row(provision: "2", sub: "1", element: "P2")]
      |> Rows.assign_positions()
      |> Rows.build_fields("UK_uksi_2024_1", :article, "uksi")

    assert r.section_id == "UK_uksi_2024_1:reg.2(1)"
    assert r.section_type == "sub_article"
    assert is_binary(r.sort_key)
    assert is_integer(r.depth)
  end

  describe "build_fields/4: stable names for signatures, tables and figures (#186)" do
    defp ids(rows, law \\ "UK_uksi_2024_1", mode \\ :article, type \\ "uksi") do
      rows
      |> Rows.assign_positions()
      |> Rows.build_fields(law, mode, type)
      |> Rows.qualify_parallels()
      |> Enum.map(&String.replace(&1.section_id, ~r/^[^:]+:/, ""))
    end

    test "the signature is named by its kind alone" do
      assert ids([row(provision: "1"), row(element: "SignedSection")]) == ["reg.1", "signed"]
    end

    test "a table or figure is named by its provision and its count there" do
      rows = [
        row(provision: "7", sub: "1", element: "P2"),
        row(provision: "7", sub: "1", element: "Tabular"),
        row(provision: "7", sub: "1", element: "Tabular"),
        row(provision: "8", element: "P1"),
        row(provision: "8", element: "Figure"),
        row(provision: "8", element: "Tabular")
      ]

      assert ids(rows) ==
               [
                 "reg.7(1)",
                 "reg.7(1).table.1",
                 "reg.7(1).table.2",
                 "reg.8",
                 "reg.8.figure.1",
                 "reg.8.table.1"
               ]
    end

    test "Acts and schedules: s.N, sch.N.para.M; with no provision, the schedule or the law" do
      assert ids(
               [row(provision: "3", paragraph: "b", element: "Tabular")],
               "UK_ukpga_2024_1",
               :section,
               "ukpga"
             ) ==
               ["s.3(b).table.1"]

      assert ids([row(schedule: "2", paragraph: "4", element: "Tabular")]) == [
               "sch.2.para.4.table.1"
             ]

      assert ids([row(schedule: "2", element: "Tabular"), row(element: "Tabular")]) ==
               ["sch.2.table.1", "table.1"]
    end

    test "a figure keeps its section_type (note): compliance's enum has no figure yet" do
      [r] =
        [row(provision: "8", element: "Figure")]
        |> Rows.assign_positions()
        |> Rows.build_fields("UK_uksi_2024_1", :article, "uksi")

      assert r.section_type == "note"
    end

    test "stable: rows inserted before, or a table in another provision, rename nothing" do
      before = [row(provision: "9", element: "P1"), row(provision: "9", element: "Tabular")]

      inserted = [
        row(provision: "1", element: "P1"),
        row(provision: "2", element: "Tabular"),
        row(provision: "9", element: "P1"),
        row(provision: "9", element: "Tabular"),
        row(element: "SignedSection")
      ]

      assert ids(before) == ["reg.9", "reg.9.table.1"]
      assert ids(inserted) == ["reg.1", "reg.2.table.1", "reg.9", "reg.9.table.1", "signed"]
    end

    test "the provision's source suffix is kept (uksi 1986/1078 reg.16(5A)n1)" do
      rows = [
        row(provision: "16", sub: "5A", element: "P2") |> Map.put(:xml_id, "regulation-16-5An1"),
        row(provision: "16", sub: "5A", element: "Tabular")
      ]

      assert ids(rows) == ["reg.16(5A)n1", "reg.16(5A)n1.table.1"]
    end

    test "territorial versions count apart and keep the extent tag last" do
      rows = [
        row(provision: "10", extent_code: "E+W"),
        row(provision: "10", extent_code: "E+W", element: "Tabular"),
        row(provision: "10", extent_code: "S"),
        row(provision: "10", extent_code: "S", element: "Tabular")
      ]

      assert ids(rows, "UK_ukpga_2024_1", :section, "ukpga") ==
               ["s.10[E+W]", "s.10.table.1[E+W]", "s.10[S]", "s.10.table.1[S]"]
    end
  end

  test "mark_repealed/2: empty text with notes and no children → [Revoked]" do
    rows = [%{row(text: "", commentary_refs: ["F1"]) | element: "P1"} |> Map.put(:depth, 1)]
    assert [%{text: "[Revoked]"}] = Rows.mark_repealed(rows, :article)
    assert [%{text: "[Repealed]"}] = Rows.mark_repealed(rows, :section)
  end

  test "assign_status/1: what the revised text shows (markup_status, LR-25): prospective, repealed, retained everywhere, in force" do
    rows = [
      row(text: "x") |> Map.put(:prospective, true),
      row(text: "[Revoked]") |> Map.put(:prospective, false),
      row(text: "x", excluded_extent: "E+W", extent_code: "E+W") |> Map.put(:prospective, false),
      row(text: "x") |> Map.put(:prospective, false)
    ]

    assert Enum.map(Rows.assign_status(rows), & &1.markup_status) ==
             ~w(prospective repealed repealed_saved in_force)

    refute Map.has_key?(hd(Rows.assign_status(rows)), :prospective)
  end

  test "qualify_parallels/1: the same provision with different extents gets [extent]" do
    rows =
      [row(provision: "10", extent_code: "E+W"), row(provision: "10", extent_code: "S")]
      |> Rows.assign_positions()
      |> Rows.build_fields("UK_ukpga_2024_1", :section, "ukpga")
      |> Rows.qualify_parallels()

    assert Enum.map(rows, & &1.section_id) ==
             ["UK_ukpga_2024_1:s.10[E+W]", "UK_ukpga_2024_1:s.10[S]"]
  end

  test "disambiguate/1: a repeated id keeps its first occurrence plain; later ones count #2, #3 (LR-13)" do
    rows = [
      %{section_id: "a", position: 1},
      %{section_id: "b", position: 2},
      %{section_id: "a", position: 7},
      %{section_id: "a", position: 9}
    ]

    assert Enum.map(Rows.disambiguate(rows), & &1.section_id) == ["a", "b", "a#2", "a#3"]
  end
end
