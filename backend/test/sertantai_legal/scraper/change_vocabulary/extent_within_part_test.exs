defmodule SertantaiLegal.Scraper.ChangeVocabulary.ExtentWithinPartTest do
  @moduledoc """
  A change's extent claim where the amending law excepts a Part of the
  amended law (Energy Act 2016 s.85(2): "An amendment (other than an
  amendment of Part 1A of the Petroleum Act 1998) … has the same extent as
  the provision to which it relates"): the readers give the Part holding
  the change's target (the amended law's LAT rows), so a change in Part 1A
  takes the Act's default and any other follows its enactment (Fire and
  OH&S: Extent reader, Jason 2026-11-15).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ChangeTarget
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Feed, NoteDate}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @law "UK_ukpga_1998_17"
  @by "UK_ukpga_2016_20"
  @title "Petroleum Act 1998"
  @parts %{"s.9A" => ["pt.1A"], "s.9A(2)" => ["pt.1A"], "s.15" => ["pt.III"]}

  # Energy Act 2016 s.85 as the extent reader reads it
  @energy %Extent{
    default: "E+W+S+NI",
    lists: [{:same, nil, ["*"]}],
    targets: [
      %{kind: :only, place: "E+W+S+NI", scope: "*", law: @title, refs: ["pt.1A"]}
    ]
  }

  defp extents(claims),
    do: for(%Claim{source: :law_text, attribute: :extent, value: v} <- claims, do: v)

  describe "ChangeTarget.change/4" do
    test "the target's own row, else the provision holding it; none known, no `within`" do
      assert ChangeTarget.change(@law, @title, "s.9A(2)", @parts).within == ["pt.1A"]
      assert ChangeTarget.change(@law, @title, "s.9A(1)(b)(v)", @parts).within == ["pt.1A"]
      refute Map.has_key?(ChangeTarget.change(@law, @title, "s.99", @parts), :within)
      # (a Schedule's provision is in no Part of the body)
      assert ChangeTarget.change(@law, @title, "sch.2.para.7", @parts).within == []
      refute Map.has_key?(ChangeTarget.change(@law, @title, "s.9A", nil), :within)
    end
  end

  describe "the feed reader's extent claim" do
    defp effect(provisions, ref),
      do: %Effect{
        effect_id: "key-" <> String.duplicate("d", 32),
        type: "words substituted",
        affected_provisions: provisions,
        affected_refs: [ref],
        affecting: @by,
        affecting_provisions: "s. 73(2)",
        in_force_date: ~D[2016-10-01],
        in_force: [%{date: ~D[2016-10-01], qualification: nil, prospective: false}]
      }

    defp feed(e, amended) do
      xml_ids = %{"section-9A" => "s.9A", "section-15" => "s.15"}

      for {_key, _target, claims} <-
            Feed.read([e], @law, [], %{}, %{@by => @energy}, xml_ids, nil, amended),
          v <- extents(claims),
          do: v
    end

    test "a change to s.9A (Part 1A) takes the default; one outside it none (the same)" do
      amended = %{title: @title, parts: @parts}
      assert feed(effect("s. 9A", "section-9A"), amended) == ["E+W+S+NI"]
      assert feed(effect("s. 15", "section-15"), amended) == []
    end

    test "with the title alone (no Parts known) the bound is unknown" do
      assert feed(effect("s. 9A", "section-9A"), @title) == []
    end
  end

  describe "the note reader's extent claim" do
    defp change(target),
      do: %Change{
        key: "c1",
        target: target,
        claims: [
          %Claim{source: :markup, attribute: :operation, value: :substituted, ref: "c1"},
          %Claim{source: :markup, attribute: :cited, value: @by, ref: "c1"},
          %Claim{source: :markup, attribute: :affecting, value: ["s.73(2)"], ref: "c1"}
        ]
      }

    test "a change to s.9A(2) takes the default; one to s.15 none" do
      amended = %{law: @law, title: @title, parts: @parts}
      ext = %{@by => @energy}

      assert extents(NoteDate.extent_claims(change("s.9A(2)"), ext, amended)) == ["E+W+S+NI"]
      assert NoteDate.extent_claims(change("s.15"), ext, amended) == []

      assert Extent.of_change(
               @energy,
               ["s.73(2)"],
               ChangeTarget.change(@law, @title, "s.15", @parts)
             ) == :same
    end
  end
end
