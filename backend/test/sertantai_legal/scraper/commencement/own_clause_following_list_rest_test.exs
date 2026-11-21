defmodule SertantaiLegal.Scraper.Commencement.OwnClauseFollowingListRestTest do
  @moduledoc """
  An Act whose commencement clause is a dated list of "the following
  provisions of this Act" says nothing of the rest: they are in force on
  Royal Assent (Interpretation Act 1978 s.4(b)). And a listed item excepted
  only so far as it relates to something is in partly on the list's day,
  the excepted extent being left out with the rest (LAT Change Pipeline,
  step Commencement reader; 1973 c.37 s.39(1)).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.OwnCommencement
  alias SertantaiLegal.Scraper.Commencement.OwnClause
  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.ListItems

  @list "The following provisions of this Act shall come into operation on 1st April 1974, that is to say— section 9, except so far as relating to sections 21 and 22 of the Land Drainage Act 1930, Part VI of the Local Government Act 1948, section 21 of the Land Drainage Act 1961 and section 82 of the Water Resources Act 1963; section 10; section 11, except subsection (6) so far as relating to section 12 of the Water Act 1945; section 12(1) and (6) to (11), except subsections (9) and (11) so far as relating to section 12 of the Water Act 1945; section 14."

  @ids ~w[pt.I s.1 s.9 s.10 s.11 s.11(1) s.11(6) s.12 s.12(1) s.12(2) s.12(6) s.12(9) s.14 s.39 s.39(2)]

  defp rows(clause) do
    for {sid, text} <- Enum.map(@ids, &{&1, ""}) ++ [{"s.39(1)", clause}],
        do: %{section_id: "UK_x:" <> sid, text: text, part: "I", chapter: nil, extent_code: nil}
  end

  defp input(type, clause),
    do: %{
      type_code: type,
      made: ~D[1973-07-18],
      clml_head: ~s(<ukm:EnactmentDate Date="1973-07-18"/>),
      rows: rows(clause)
    }

  defp outcome(id, type \\ "ukpga", clause \\ @list) do
    input = input(type, clause)
    rules = OwnClause.rules("UK_x", input)
    {outcome, r} = OwnCommencement.outcome(rules, "UK_x", id, OwnClause.context(input.rows))
    {outcome, r && r.partial_from, r && r.full_from}
  end

  test "the provisions the list leaves out are in force on Royal Assent" do
    assert outcome("s.1") == {:dated, nil, ~D[1973-07-18]}
    assert outcome("s.39(2)") == {:dated, nil, ~D[1973-07-18]}
    assert outcome("s.12(2)") == {:dated, nil, ~D[1973-07-18]}
    assert LawStart.resolve(input("ukpga", @list)).date == ~D[1973-07-18]
  end

  test "the listed provisions keep the list's day" do
    assert outcome("s.10") == {:dated, nil, ~D[1974-04-01]}
    assert outcome("s.14") == {:dated, nil, ~D[1974-04-01]}
    assert outcome("s.12(1)") == {:dated, nil, ~D[1974-04-01]}
    assert outcome("s.11(1)") == {:dated, nil, ~D[1974-04-01]}
  end

  test "\"section 9, except so far as relating to\" another Act's provisions: partly in" do
    # the excepted extent is left out of the list: in at Royal Assent, the
    # section whole on the list's day
    assert outcome("s.9") == {:staged, ~D[1973-07-18], ~D[1974-04-01]}
    assert outcome("s.9", "asp") == {:partial_only, ~D[1974-04-01], nil}
  end

  test "\"section 11, except subsection (6) so far as relating to …\": that subsection partly in" do
    assert outcome("s.11(6)") == {:staged, ~D[1973-07-18], ~D[1974-04-01]}
    assert outcome("s.12(9)") == {:staged, ~D[1973-07-18], ~D[1974-04-01]}
    assert outcome("s.11(6)", "asp") == {:partial_only, ~D[1974-04-01], nil}
    assert outcome("s.12(6)") == {:dated, nil, ~D[1974-04-01]}

    assert ListItems.read(
             "section 11, except subsection (6) so far as relating to section 12 of the Water Act 1945"
           ) == %{plain: "section 11", excepted: "section 11(6)", qualified: "section 11(6)"}
  end

  test "a list with a statement for the rest leaves nothing to Royal Assent" do
    clause =
      "The following provisions of this Act shall come into operation on 1st April 1974, that is to say— section 10; section 14."

    rest = "The remaining provisions of this Act shall come into operation on 1st July 1974."
    input = input("ukpga", clause)

    rows =
      input.rows ++
        [%{section_id: "UK_x:s.39(3)", text: rest, part: "I", chapter: nil, extent_code: nil}]

    rules = OwnClause.rules("UK_x", %{input | rows: rows})
    {_, r} = OwnCommencement.outcome(rules, "UK_x", "s.1", OwnClause.context(rows))
    assert r.full_from == ~D[1974-07-01]
  end

  test "an instrument's or a devolved Act's list leaves its rest alone" do
    refute match?({:dated, _, ~D[1973-07-18]}, outcome("s.1", "asp"))

    regs = String.replace(@list, "of this Act", "of these Regulations")
    refute match?({:dated, _, ~D[1973-07-18]}, outcome("s.1", "uksi", regs))
  end
end
