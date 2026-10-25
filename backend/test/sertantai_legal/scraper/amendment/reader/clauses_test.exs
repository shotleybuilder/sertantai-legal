defmodule SertantaiLegal.Scraper.Amendment.Reader.ClausesTest do
  @moduledoc "The reader's clause and operation helpers (decomposed from Amendment.Reader, run time 2026-10-25)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Text
  alias SertantaiLegal.Scraper.Amendment.Reader.Clauses

  defp text(i, opts \\ []), do: struct(Text, [id: "x", instruction: i] ++ opts)

  test "clauses/1: one per operation (AR-08: \"omit “either”; and at the end insert—\")" do
    assert [a, b] = Clauses.clauses(text("omit “either”; and at the end insert—"))
    assert a.instruction =~ "omit"
    assert b.instruction =~ "insert"
  end

  test "clauses/1: a piece with no verb joins the next (\"Sections 4 and 5 are repealed\")" do
    t = text("Sections 4 and 5 are repealed.")
    assert Clauses.clauses(t) == [t]
  end

  test "strip_captions/1, captionless/1: captions go, quoted words and titles' brackets stay (SI 1998/1420)" do
    s =
      "In section 118 (cancellation of revoked or suspended licences), after subsection (4) insert “(a) x”"

    refute Clauses.strip_captions(s) =~ "revoked"
    assert Clauses.strip_captions(s) =~ "(4)"
    assert Clauses.strip_captions(s) =~ "“(a) x”"
    assert Clauses.captionless(text(s)).instruction == Clauses.strip_captions(s)
  end

  test "operation/1: the verb, not the caption's" do
    s =
      "In section 118 (cancellation of revoked or suspended licences), after subsection (4) insert—"

    assert {"inserted", _} = Clauses.operation(text(s, inserted: [["4A"]]))
  end

  test "operation/1: words at the end are words inserted (2014 c.6 s.128(2)(e))" do
    assert Clauses.operation(text("In section 235(1), at the appropriate place insert—")) ==
             {"inserted", "words inserted"}
  end

  test "located_brackets/1: where the clause is" do
    assert Clauses.located_brackets("In section 7(1)(a), omit “x”") == ["1", "a"]
    assert Clauses.located_brackets("omit “in subsection (2)”") == []
  end

  test "words_unnamed?/1, unquote_words/1, asides/1" do
    assert Clauses.words_unnamed?("for “” substitute “y”")
    refute Clauses.words_unnamed?("omit subsection (2)")
    assert Clauses.unquote_words("omit “the 1984 Act” here") == "omit  here"

    assert Clauses.asides(
             "In section 9 (meaning of words) of the Planning (Listed Buildings and Conservation Areas) Act 1990"
           ) ==
             "In section 9  of the Planning (Listed Buildings and Conservation Areas) Act 1990"
  end

  test "uncaptioned/1: a provision's caption goes; a title keeps every bracket (Petroleum Act 1998 Sch. 4 para 33)" do
    assert Clauses.uncaptioned(
             "In section 1 (application of Part I of Health and Safety at Work etc. Act 1974 offshore), omit"
           ) == "In section 1, omit"

    title =
      "The Environmental Protection (Disposal of Polychlorinated Biphenyls and other Dangerous Substances) (England and Wales) Regulations 2000 are amended"

    assert Clauses.uncaptioned(title) == title

    assert Clauses.uncaptioned("In regulation 2(1) (interpretation), in paragraph (1)") ==
             "In regulation 2(1), in paragraph (1)"
  end

  test "unquote_words/1: nested quotes, innermost first (SI 2024/1268)" do
    assert Clauses.unquote_words(
             "omit ““x” means the Building (Approved Inspectors etc.) Regulations 2010”."
           ) ==
             "omit ."

    assert Clauses.unquote_words("for “a” substitute “b”") == "for  substitute "
  end
end
