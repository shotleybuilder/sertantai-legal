defmodule SertantaiLegal.Scraper.Amendment.DisagreementTest do
  @moduledoc """
  The amending-law reader's family gate (Maritime Safety: Amending-law
  reader, Decision 1): each change the law's text states that
  legislation.gov.uk contradicts or doesn't state, grouped by cause and
  amending law, with its reviewed status.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.{CheckStrata, Disagreement, Rule}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, Evidence, Merge}

  @by "UK_uksi_2019_696"
  @law "UK_uksi_1998_2241"

  defp set(key, target, claims),
    do:
      {key, target,
       for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})}

  defp text(key, target, op, level \\ :provision),
    do:
      set(key, target, [
        {:law_text, :operation, op},
        {:law_text, :level, level},
        {:law_text, :by, @by},
        {:commencement, :date, ~D[2020-12-31]}
      ])

  defp feed(key, target, op, affecting, level \\ :provision),
    do:
      set(key, target, [
        {:feed, :operation, op},
        {:feed, :level, level},
        {:feed, :by, @by},
        {:feed, :date, ~D[2020-12-31]},
        {:feed, :affecting, affecting}
      ])

  defp rows(sets) do
    for {c, s} <-
          sets |> Merge.merge() |> Enum.map(&Evidence.resolve(&1, nil)) |> CheckStrata.classify(),
        s in [:D, :L],
        do: {@law, c, s}
  end

  defp rule(ref, op, treatment, text),
    do:
      Rule.new(
        amends: @law,
        targets: ["reg.5A"],
        operation: op,
        level: :provision,
        treatment: treatment,
        source: %{law: @by, ref: ref, text: text}
      )

  defp causes(sets, rules \\ []),
    do:
      sets
      |> rows()
      |> Disagreement.items(%{@law => rules}, %{})
      |> Enum.map(&{&1.shape, &1.reach})

  test "a substitution's new number, inserted by the law's text, is the by-design quote-new-number" do
    rules = [rule("regulation-3", :inserted, :quoted, "For regulation 5 substitute— 5. … 5A. …")]

    assert [{"quote-new-number", 1}] =
             causes(
               [
                 text("#{@by}:regulation-3", "reg.5A", :inserted),
                 feed("key-a", "reg.5A", :substituted, ["reg.3"])
               ],
               rules
             )
  end

  test "a substitution's new child legislation.gov.uk records only on the parent is quote-new-number too" do
    rules = [
      rule(
        "regulation-3",
        :inserted,
        :quoted,
        "for sub-paragraph (a) there shall be substituted—"
      )
    ]

    assert [{"quote-new-number", 1}] =
             causes([text("#{@by}:regulation-3", "reg.5A", :inserted)], rules)
  end

  test "inserted against substituted with no substituting quote is named by operation" do
    rules = [rule("regulation-3", :inserted, :quoted, "After regulation 5 insert— 5A. …")]

    assert [{"operation inserted/substituted", 1}] =
             causes(
               [
                 text("#{@by}:regulation-3", "reg.5A", :inserted),
                 feed("key-a", "reg.5A", :substituted, ["reg.3"])
               ],
               rules
             )
  end

  test "a level conflict is named by level" do
    assert [{"level words/provision", 1}] =
             causes([
               text("#{@by}:regulation-3", "reg.5", :substituted, :words),
               feed("key-a", "reg.5", :substituted, ["reg.3"], :provision)
             ])
  end

  test "a number a whole substitution's quote no longer makes is the by-design quote-dropped-number" do
    assert [{"quote-dropped-number", 1}] =
             causes([
               set("#{@by}:regulation-3#dropped", "reg.5B", [
                 {:law_text, :operation, :repealed},
                 {:law_text, :level, :provision},
                 {:law_text, :by, @by}
               ])
             ])
  end

  test "the law's text alone is named by operation and level, grouped by amending law" do
    assert [{"law text only: repealed provision", 2}] =
             causes([
               text("#{@by}:regulation-3", "reg.5", :repealed),
               text("#{@by}:regulation-4", "reg.6", :repealed)
             ])
  end

  test "joined to legislation.gov.uk's record naming no operation is apart from law text only" do
    assert [{"no operation from legislation.gov.uk: substituted words", 1}] =
             causes([
               text("#{@by}:regulation-3", "reg.5", :substituted, :words),
               set("key-a", "reg.5", [
                 {:feed, :by, @by},
                 {:feed, :date, ~D[2020-12-31]},
                 {:feed, :affecting, ["reg.3"]}
               ])
             ])
  end

  test "an item's words never carry an effect id the merge joined" do
    [item] =
      [
        text("#{@by}:regulation-3", "reg.5", :substituted, :words),
        set("key-a", "reg.5", [{:feed, :by, @by}, {:feed, :affecting, ["reg.3"]}])
      ]
      |> rows()
      |> Disagreement.items(%{}, %{})

    assert item.words == ["#{@law} reg.5 (regulation-3)"]
  end

  test "an item's status is its reviewed one, by law first, then by cause" do
    reviewed = %{
      "law text only: repealed provision @ #{@by}" => "known: legislation.gov.uk unrecorded",
      "quote-dropped-number" => "known: by design"
    }

    [item] =
      [text("#{@by}:regulation-3", "reg.5", :repealed)]
      |> rows()
      |> Disagreement.items(%{}, reviewed)

    assert item.law == @by
    assert item.status == "known: legislation.gov.uk unrecorded"
    assert item.words == ["#{@law} reg.5 (regulation-3)"]
    assert Disagreement.gate([item]).pass?
  end
end
