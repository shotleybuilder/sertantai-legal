defmodule SertantaiLegal.Scraper.ChangeVocabulary.MergeTest do
  @moduledoc """
  The law's text joins legislation.gov.uk's record of the same event
  (CV-04, the unjoined worklist): one event placed at two levels is one
  candidate; same-day events by one law are told apart by the amending
  provision the feed names; a record placed below the law's text is found.
  Real cases, trimmed.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, Merge}

  defp set(key, target, claims),
    do:
      {key, target,
       for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})}

  defp text(key, target, op, law),
    do:
      set(key, target, [
        {:law_text, :operation, op},
        {:law_text, :level, :words},
        {:law_text, :by, law},
        {:commencement, :date, ~D[2020-12-31]}
      ])

  defp feed(key, target, op, law, affecting),
    do:
      set(key, target, [
        {:feed, :operation, op},
        {:feed, :by, law},
        {:feed, :date, ~D[2020-12-31]},
        {:feed, :affecting, affecting}
      ])

  defp alone(changes),
    do: Enum.filter(changes, &(&1.aliases == [&1.key] and String.contains?(&1.key, ":")))

  test "one event placed at two levels is one candidate (RTA 1988 s.48(4A), 2020/16 s.13(2))" do
    changes =
      Merge.merge([
        text("UK_ukpga_2020_16:section-13-2", "s.48(4A)", :substituted, "UK_ukpga_2020_16"),
        feed("key-a", "s.48(4A)", :substituted, "UK_ukpga_2020_16", ["s.13(2)"]),
        set("key-a", "s.48", [{:markup, :operation, :substituted}])
      ])

    assert alone(changes) == []

    assert %{target: "s.48(4A)"} =
             Enum.find(changes, &("UK_ukpga_2020_16:section-13-2" in &1.aliases))
  end

  test "same-day events by one law: the amending provision the feed names decides (SI 2008/1597 reg.21, 2019/696 Sch.12 para.21)" do
    changes =
      Merge.merge([
        text(
          "UK_uksi_2019_696:schedule-12-paragraph-21-a",
          "reg.21",
          :substituted,
          "UK_uksi_2019_696"
        ),
        feed("key-a", "reg.21", :substituted, "UK_uksi_2019_696", ["sch.12.para.21(a)"]),
        feed("key-b", "reg.21", :substituted, "UK_uksi_2019_696", ["sch.12.para.21(d)"])
      ])

    assert alone(changes) == []

    assert %{key: "key-a"} =
             Enum.find(changes, &("UK_uksi_2019_696:schedule-12-paragraph-21-a" in &1.aliases))
  end

  test "a record placed below the law's text is the same event, where it is placed" do
    changes =
      Merge.merge([
        text(
          "UK_uksi_2019_696:schedule-12-paragraph-21-b",
          "reg.21",
          :substituted,
          "UK_uksi_2019_696"
        ),
        feed("key-c", "reg.21(1)(a)", :substituted, "UK_uksi_2019_696", ["sch.12.para.21(b)"])
      ])

    assert alone(changes) == []
    assert [%{key: "key-c", target: "reg.21(1)(a)"}] = changes
  end

  test "with nothing to tell two events apart, the law's text stays its own change (a visible gap)" do
    changes =
      Merge.merge([
        text(
          "UK_uksi_2019_696:schedule-12-paragraph-21-a",
          "reg.21",
          :substituted,
          "UK_uksi_2019_696"
        ),
        feed("key-a", "reg.21", :substituted, "UK_uksi_2019_696", []),
        feed("key-b", "reg.21", :substituted, "UK_uksi_2019_696", [])
      ])

    assert length(alone(changes)) == 1
  end

  test "the law's text meets a legacy markup change (no effect id) by the law its note cites (HSWA 1974 s.53(1))" do
    changes =
      Merge.merge([
        text("UK_ukpga_1987_43:schedule-5", "s.53(1)", :substituted, "UK_ukpga_1987_43"),
        set("d29p5549", "s.53(1)", [
          {:markup, :operation, :inserted},
          {:markup, :cited, "UK_ukpga_1987_43"}
        ])
      ])

    assert [%{key: "d29p5549", aliases: aliases}] = changes
    assert "UK_ukpga_1987_43:schedule-5" in aliases
  end

  test "joined below the provision the law's text names, the law's own placement is kept as a claim" do
    [c] =
      Merge.merge([
        text(
          "UK_uksi_2019_696:schedule-12-paragraph-21-b",
          "reg.21",
          :substituted,
          "UK_uksi_2019_696"
        ),
        feed("key-c", "reg.21(1)(a)", :substituted, "UK_uksi_2019_696", ["sch.12.para.21(b)"])
      ])

    assert SertantaiLegal.Scraper.ChangeVocabulary.Change.value(c, :law_text, :placed) == "reg.21"
  end

  test "one record from each source per event: joined changes don't snowball (RTA 1988 s.89, CDPA 1989/22)" do
    changes =
      Merge.merge([
        set("d29p11050", "s.89", [
          {:markup, :operation, :inserted},
          {:markup, :cited, "UK_ukpga_1989_22"}
        ]),
        set("d29p11046", "s.89", [
          {:markup, :operation, :inserted},
          {:markup, :cited, "UK_ukpga_1989_22"}
        ]),
        text(
          "UK_ukpga_1989_22:schedule-3-paragraph-8-e",
          "s.89(11)",
          :substituted,
          "UK_ukpga_1989_22"
        ),
        text("UK_ukpga_1989_22:section-4-2", "s.89(10)", :substituted, "UK_ukpga_1989_22")
      ])

    # no change holds two markup records or two of the law's instructions
    for c <- changes do
      assert Enum.count(c.aliases, &String.starts_with?(&1, "d29p")) <= 1
      assert Enum.count(Enum.uniq(c.aliases), &String.contains?(&1, ":")) <= 1
    end
  end
end
