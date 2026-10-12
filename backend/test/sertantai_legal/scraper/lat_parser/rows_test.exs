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

  test "mark_repealed/2: empty text with notes and no children → [Revoked]" do
    rows = [%{row(text: "", commentary_refs: ["F1"]) | element: "P1"} |> Map.put(:depth, 1)]
    assert [%{text: "[Revoked]"}] = Rows.mark_repealed(rows, :article)
    assert [%{text: "[Repealed]"}] = Rows.mark_repealed(rows, :section)
  end

  test "assign_status/1: prospective, repealed, retained everywhere, in force" do
    rows = [
      row(text: "x") |> Map.put(:prospective, true),
      row(text: "[Revoked]") |> Map.put(:prospective, false),
      row(text: "x", excluded_extent: "E+W", extent_code: "E+W") |> Map.put(:prospective, false),
      row(text: "x") |> Map.put(:prospective, false)
    ]

    assert Enum.map(Rows.assign_status(rows), & &1.status) ==
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
