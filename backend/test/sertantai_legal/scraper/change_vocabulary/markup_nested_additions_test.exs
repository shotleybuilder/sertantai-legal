defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupNestedAdditionsTest do
  @moduledoc """
  Fire and OH&S: Markup reader. A later insertion nested inside the earlier
  changes round it (HSWA s.11(4AA): 2015 c.20 inside 2013 c.32's s.11(4A),
  inside SI 2008/960's ss.11-13) belongs to the innermost change only:
  where the outer one's note cites an earlier law and the outer has no
  words of its own in the row (Decision 2 a: a legacy inner counts).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.NestedAdditions

  defp effect_id(n), do: "key-" <> String.duplicate(Integer.to_string(n), 32)

  defp add(id, note, inner),
    do: ~s(<Addition ChangeId="#{id}" CommentaryRef="#{note}">#{inner}</Addition>)

  defp note(id, year),
    do:
      ~s(<Commentary id="#{id}" Type="F"><Para><Text>Inserted by <Citation id="x#{year}" URI="http://www.legislation.gov.uk/id/ukpga/#{year}/1">#{year} c. 1</Citation></Text></Para></Commentary>)

  defp doc(body, notes),
    do:
      SweetXml.parse(
        "<Legislation><Body>#{body}</Body><Commentaries>#{notes}</Commentaries></Legislation>",
        quiet: true
      )

  # the year of each note's cited law
  defp years(pairs), do: fn n -> Map.get(Map.new(pairs), n) end

  # s.11(4A) by change 1 (2013, wrapped by the legacy d29p775 of 2008);
  # s.11(4AA) by change 2 (2015) inside both
  defp hswa do
    k1 = effect_id(1) <> "-1"
    k2 = effect_id(2) <> "-2"
    wrap = fn inner -> add("d29p775", "c1", add(k1, effect_id(1), inner)) end

    """
    <P1 id="section-11"><Pnumber>11</Pnumber><P1para><Text>Text.</Text>
    <P2 id="section-11-4A"><Pnumber>#{wrap.("4A")}</Pnumber><P2para><Text>#{wrap.("In subsection (4).")}</Text></P2para></P2>
    <P2 id="section-11-4AA"><Pnumber>#{wrap.(add(k2, effect_id(2), "4AA"))}</Pnumber><P2para><Text>#{wrap.(add(k2, effect_id(2), "Later words."))}</Text></P2para></P2>
    </P1para></P1>
    """
  end

  @hswa_years [
    {"c1", 2008},
    {"key-" <> String.duplicate("1", 32), 2013},
    {"key-" <> String.duplicate("2", 32), 2015}
  ]

  # d29p775 wraps 2013 c.32's s.11(4A) too: SI 2008/960's ss.11-13 came first
  test "the changes wrapped round a later insertion in a number are its wrappers" do
    assert NestedAdditions.wrappers(doc(hswa(), ""), years(@hswa_years)) ==
             MapSet.new([
               {"d29p775", "section-11-4A"},
               {"d29p775", "section-11-4AA"},
               {effect_id(1) <> "-1", "section-11-4AA"}
             ])
  end

  test "the later row takes the innermost change only; the earlier one keeps its own row" do
    notes = note("c1", 2008) <> note(effect_id(1), 2013) <> note(effect_id(2), 2015)

    targets =
      "<Legislation><Body>#{hswa()}</Body><Commentaries>#{notes}</Commentaries></Legislation>"
      |> Markup.read("UK_ukpga_1974_37", %{})
      |> Enum.map(fn {key, target, _} -> {key, target} end)
      |> Enum.sort()

    assert {effect_id(2), "s.11(4AA)"} in targets
    assert {effect_id(1), "s.11(4A)"} in targets
    refute {effect_id(1), "s.11(4AA)"} in targets
    refute Enum.any?(targets, &match?({"d29p775", "s.11(4AA)"}, &1))
  end

  # the Marriage Act 1949 s.5(2): the 1986 Act added the subsection; the
  # 2015 words substitution is marked round the number "2" and its first
  # words only. The outer change has words of its own: it is no wrapper
  test "an outer change with words of its own in the row is not a wrapper" do
    k = effect_id(4)

    body =
      ~s(<P2 id="section-5-2"><Pnumber>#{add("c62-1", "c62", add(k <> "-1", k, "2"))}</Pnumber><P2para><Text>) <>
        ~s(#{add("c62-1", "c62", add(k <> "-1", k, "Subsection (1)(a)"))}#{add("c62-1", "c62", " of this section shall not apply.")}</Text></P2para></P2>)

    assert NestedAdditions.wrappers(doc(body, ""), years([{"c62", 1986}, {k, 2015}])) ==
             MapSet.new()
  end

  # TCPA 1990 s.78(4BA): the 2015 Welsh Act's legacy M_F_ insertion inside
  # 2008 c.29's d29p4121 (golden). The Countryside (Scotland) Act 1967 s.48A
  # reads the same way, though its inner legacy Addition (2000) was no
  # insertion: a known limit (Decision 2 a)
  test "a legacy inner change round the number is the later insertion" do
    body =
      ~s(<P2 id="section-78-4BA"><Pnumber>#{add("d29p4121", "c1", add("M_F_7-1", "M_F_7", "4BA"))}</Pnumber>) <>
        ~s(<P2para><Text>#{add("d29p4121", "c1", add("M_F_7-1", "M_F_7", "Once notice."))}</Text></P2para></P2>)

    assert NestedAdditions.wrappers(doc(body, ""), years([{"c1", 2008}, {"M_F_7", 2015}])) ==
             MapSet.new([{"d29p4121", "section-78-4BA"}])
  end

  # the Local Employment Act 1960 s.32(1)(h)(iii): a 1982 repeal (S.)
  # marked round a 1973 change; an outer change citing a later law, or an
  # undated one, is no wrapper
  test "an outer change citing a later or unknown law is not a wrapper" do
    k = effect_id(5)

    body =
      ~s(<P1 id="section-32"><Pnumber>#{add("d29p1342", "c1", add(k <> "-1", k, "32"))}</Pnumber>) <>
        ~s(<P1para><Text>#{add("d29p1342", "c1", add(k <> "-1", k, "Words."))}</Text></P1para></P1>)

    assert NestedAdditions.wrappers(doc(body, ""), years([{"c1", 1982}, {k, 1973}])) ==
             MapSet.new()

    assert NestedAdditions.wrappers(doc(body, ""), years([{k, 1973}])) == MapSet.new()

    assert NestedAdditions.wrappers(doc(body, ""), years([{"c1", 1973}, {k, 1973}])) ==
             MapSet.new()
  end

  test "one change's copies nested in each other (a key inside its own copy) wrap nothing" do
    k = effect_id(3)

    body =
      ~s(<P1 id="section-2"><Pnumber>#{add(k <> "-1", k, add(k <> "-2", k, "2"))}</Pnumber><P1para><Text>Words.</Text></P1para></P1>)

    assert NestedAdditions.wrappers(doc(body, ""), years([{k, 2000}])) == MapSet.new()
  end
end
