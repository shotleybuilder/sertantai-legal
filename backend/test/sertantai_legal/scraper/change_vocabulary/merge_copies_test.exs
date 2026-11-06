defmodule SertantaiLegal.Scraper.ChangeVocabulary.MergeCopiesTest do
  @moduledoc """
  Decision 2 (Maritime Safety: Merge, 2026-11-06): the new paragraphs a
  joined change makes below it (2009 c.25 Sch.21 para.34 on MSA 1995
  s.271(6) and its (a)-(c)) stay their own changes, with the event's key
  and its dates, the feed's claims marked placed on the parent.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Merge}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Merge.Copies

  @by "UK_ukpga_2009_25"
  @key "#{@by}:schedule-21-paragraph-34"
  @effect "key-" <> String.duplicate("b", 32)

  defp c(key, target, claims, aliases \\ []),
    do: %Change{
      key: key,
      target: target,
      aliases: Enum.uniq([key | aliases]),
      claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})
    }

  defp parent,
    do:
      c(
        @effect,
        "s.271(6)",
        [
          {:feed, :operation, :substituted},
          {:feed, :level, :words},
          {:feed, :by, @by},
          {:feed, :date, ~D[2013-07-25]},
          {:feed, :partial, false},
          {:feed, :effect_extent, "E+W+S+NI"},
          {:law_text, :operation, :substituted},
          {:law_text, :by, @by}
        ],
        [@key]
      )

  defp child(target, extra \\ []),
    do:
      c(
        @key,
        target,
        [
          {:law_text, :operation, :inserted},
          {:law_text, :level, :provision},
          {:law_text, :by, @by}
        ] ++
          extra
      )

  test "a new paragraph takes the event's key and its feed dates, placed on the parent" do
    [_, got] = Copies.carry([parent(), child("s.271(6)(a)")])

    assert got.key == @effect
    assert @key in got.aliases
    assert got.target == "s.271(6)(a)"
    assert Change.value(got, :feed, :date) == ~D[2013-07-25]
    assert Change.value(got, :feed, :partial) == false
    assert Change.value(got, :feed, :placed) == "s.271(6)"
    # no operation, level or territory carried: the law's text states them
    assert Change.values(got, :feed, :operation) == []
    assert Change.values(got, :feed, :level) == []
    assert Change.values(got, :feed, :effect_extent) == []
    assert Change.value(got, :law_text, :operation) == :inserted
  end

  test "the child's own commencement claims are kept beside the event's" do
    [_, got] =
      Copies.carry([parent(), child("s.271(6)(a)", [{:commencement, :date, ~D[2010-01-01]}])])

    assert Change.value(got, :commencement, :date) == ~D[2010-01-01]
    assert Change.value(got, :feed, :date) == ~D[2013-07-25]
  end

  test "untouched: a copy on no provision below, another key, an unfed parent" do
    sibling = child("s.272")
    other = c("#{@by}:schedule-21-paragraph-35", "s.271(6)(a)", [{:law_text, :by, @by}])

    unfed = %{
      parent()
      | key: @key,
        claims: Enum.reject(parent().claims, &(&1.source == :feed))
    }

    assert Copies.carry([parent(), sibling, other]) == [parent(), sibling, other]
    assert Copies.carry([unfed, child("s.271(6)(a)")]) == [unfed, child("s.271(6)(a)")]
  end

  test "through the merge: the parent joins the feed, the new paragraphs carry its key and date" do
    set = fn key, target, claims ->
      {key, target,
       for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})}
    end

    changes =
      Merge.merge([
        set.(@effect, "s.271(6)", [
          {:feed, :operation, :substituted},
          {:feed, :level, :words},
          {:feed, :by, @by},
          {:feed, :date, ~D[2013-07-25]},
          {:feed, :affecting, ["sch.21.para.34"]}
        ]),
        set.(@key, "s.271(6)", [
          {:law_text, :operation, :substituted},
          {:law_text, :level, :words},
          {:law_text, :by, @by}
        ]),
        set.(@key, "s.271(6)(a)", [
          {:law_text, :operation, :inserted},
          {:law_text, :level, :provision},
          {:law_text, :by, @by}
        ])
      ])

    assert changes |> Enum.map(&{&1.key, &1.target}) |> Enum.sort() ==
             [{@effect, "s.271(6)"}, {@effect, "s.271(6)(a)"}]

    child = Enum.find(changes, &(&1.target == "s.271(6)(a)"))
    assert Change.value(child, :feed, :date) == ~D[2013-07-25]
    assert Change.value(child, :law_text, :operation) == :inserted
  end
end
