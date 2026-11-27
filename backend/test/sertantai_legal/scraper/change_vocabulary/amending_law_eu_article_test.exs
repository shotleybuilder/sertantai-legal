defmodule SertantaiLegal.Scraper.ChangeVocabulary.AmendingLawEuArticleTest do
  @moduledoc """
  A words change in an EU Article's paragraph the law's rows don't hold
  sits in the Article's text (Amending-law reader: EU article naming,
  2026-11-27): Regulation (EU) 2019/631's rows hold its Articles without
  their paragraphs, so "in paragraph 1—, for “each Member State”
  substitute …" (SI 2020/1418 reg.3(8)(a)(i)) is words in Article 7.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.Rule
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw

  defp rule(amends, targets, level, op \\ :substituted),
    do:
      Rule.new(
        amends: amends,
        targets: targets,
        operation: op,
        level: level,
        source: %{
          law: "UK_uksi_2020_1418",
          ref: "regulation-3-8-a-i-aa",
          text: "for “each Member State” substitute"
        },
        treatment: :instruction
      )

  defp targets(rules, known),
    do:
      for({_key, target, _claims} <- AmendingLaw.read(rules, %{}, known), uniq: true, do: target)

  test "words in a paragraph not held go to the Article holding them" do
    known = ["art.Article 6", "art.Article 7", "art.Article 8"]

    assert targets([rule("UK_eur_2019_631", ["art.Article 7(1)"], :words)], known) == [
             "art.Article 7"
           ]
  end

  test "words in a paragraph held stay in it" do
    known = ["art.Article 7", "art.Article 7(1)"]

    assert targets([rule("UK_eur_2019_631", ["art.Article 7(1)"], :words)], known) == [
             "art.Article 7(1)"
           ]
  end

  test "a paragraph not held omitted whole is no change to its Article" do
    known = ["art.Article 7"]

    assert targets([rule("UK_eur_2019_631", ["art.Article 7(2)"], :provision, :repealed)], known) ==
             []
  end

  test "a UK law's words in a place not held are not moved" do
    known = ["reg.7"]
    assert targets([rule("UK_uksi_2010_1", ["reg.7(1)"], :words)], known) == []
  end
end
