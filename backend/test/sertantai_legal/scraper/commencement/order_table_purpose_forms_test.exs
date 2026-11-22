defmodule SertantaiLegal.Scraper.Commencement.OrderTablePurposeFormsTest do
  @moduledoc """
  Waste, Water and Climate: Commencement reader, Decision 17. Four forms of
  the Schedule tables in the orders fetched for the never-searched laws:

  - a "Purpose" column under a "Column 1 | Column 2 | Column 3" header row
    (SSI 2005/351 Sch.1: ASP 2005/3 s.1(1) had been dated fully);
  - a completing purpose, "In so far as not already in force." (SSI 2016/42:
    ASP 2011/9 s.5(1) had never completed);
  - a repeals row's entries under another law's heading ("The following
    repeals in Schedule 6 … – | In the Pollution Control … Order 1978 – |
    Articles 3, 5 to 13, 16 and 18;": NISR 2003/489, whose entries had dated
    the 1997 Order's own Articles);
  - a completing qualifier in a list's middle ("Article 4(1)(a) and (b) and
    (5) and to the extent that they are not already in force (2) to (4) and
    (6) to (9)": NISR 2003/489, which had dropped the items after it).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order

  defp rules(law, title, act, body, table) do
    Doc.new(law, [
      ~s"""
      <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>#{title}</dc:title><Secondary><Body>#{body}</Body><Schedules><Schedule id="schedule-1"><Number>SCHEDULE 1</Number><TitleBlock><Title>Provisions coming into force on 20th June 2005</Title></TitleBlock><ScheduleBody><Tabular><table xmlns="http://www.w3.org/1999/xhtml">#{table}</table></Tabular></ScheduleBody></Schedule></Schedules></Secondary></Legislation>
      """
    ])
    |> Order.rules(act)
    |> Enum.filter(&(&1.treatment == :order_schedule))
  end

  @asp_2005_3 %{law: "UK_asp_2005_3", title: "Water Services etc. (Scotland) Act", year: "2005"}

  test "a Purpose column under a \"Column 1 | Column 2 | Column 3\" header row limits its row" do
    rules =
      rules(
        "UK_ssi_2005_351",
        "The Water Services etc. (Scotland) Act 2005 (Commencement No. 1 and Savings) Order 2005",
        @asp_2005_3,
        ~s|<P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the 2005 Act” means the Water Services etc. (Scotland) Act 2005.</Text></P1para></P1>|,
        ~s|<thead><tr><th>Column 1</th><th>Column 2</th><th>Column 3</th></tr><tr><th>Provisions of the 2005 Act</th><th>Subject matter</th><th>Purpose</th></tr></thead><tbody><tr><td>Section 1(1)</td><td>Water Industry Commission for Scotland</td><td>Only for the purpose of bringing into force the new section 1(1) of the 2002 Act</td></tr><tr><td>Section 31</td><td>Offences by bodies corporate and partnerships</td></tr></tbody>|
      )

    by_scope = Map.new(rules, &{&1.scope, &1})

    assert by_scope[["s.1(1)"]].purposes not in [nil, :fully]
    assert by_scope[["s.31"]].purposes in [nil, :fully]
  end

  test "a completing purpose, \"In so far as not already in force.\", brings its row in fully" do
    [rule] =
      rules(
        "UK_ssi_2016_42",
        "The Reservoirs (Scotland) Act 2011 (Commencement No. 4) Order 2016",
        %{law: "UK_asp_2011_9", title: "Reservoirs (Scotland) Act", year: "2011"},
        ~s|<P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the Act” means the Reservoirs (Scotland) Act 2011.</Text></P1para></P1>|,
        ~s|<thead><tr><th>Column (1) Provisions of the Act</th><th>Column (2) Subject matter</th><th>Column (3) Purpose</th></tr></thead><tbody><tr><td>Section 5(1)</td><td>Duty of multiple reservoir managers to co-operate</td><td>In so far as not already in force.</td></tr></tbody>|
      )

    assert rule.scope == ["s.5(1)"]
    assert rule.purposes in [nil, :fully]
  end

  @nisi_1997_2778 %{
    law: "UK_nisi_1997_2778",
    title: "Waste and Contaminated Land (Northern Ireland) Order",
    year: "1997"
  }

  @nisr_2003_489_body ~s|<P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the Order” means the Waste and Contaminated Land (Northern Ireland) Order 1997.</Text></P1para></P1>|

  test "a repeals row's entries under another law's heading are no provisions of the Order's" do
    rules =
      rules(
        "UK_nisr_2003_489",
        "The Waste and Contaminated Land (1997 Order) (Commencement No. 7) Order (Northern Ireland) 2003",
        @nisi_1997_2778,
        @nisr_2003_489_body,
        ~s|<thead><tr><th>Provisions of the Order</th><th>Subject matter</th></tr></thead><tbody><tr><td>Article 37</td><td>Annual reports</td></tr><tr><td>The following repeals in Schedule 6 and Article 83(2) in so far as it relates to those repeals –</td><td>Repeals</td></tr><tr><td>In the Pollution Control and Local Government (Northern Ireland) Order 1978 –</td><td/></tr><tr><td>Articles 3, 5 to 13, 16 and 18;</td><td/></tr><tr><td>Article 85;</td><td/></tr><tr><td>In Schedule 6 to the Gas (Northern Ireland) Order 1996, the entry relating to the Pollution Control and Local Government (Northern Ireland) Order 1978</td><td/></tr></tbody>|
      )

    scopes = rules |> Enum.flat_map(& &1.scope) |> MapSet.new()

    assert "reg.37" in scopes
    refute "reg.3" in scopes
    refute "reg.6" in scopes
    refute "reg.85" in scopes
    refute "sch" in scopes
  end

  test "a completing qualifier in a list's middle leaves the items after it the Article's" do
    rules =
      rules(
        "UK_nisr_2003_489",
        "The Waste and Contaminated Land (1997 Order) (Commencement No. 7) Order (Northern Ireland) 2003",
        @nisi_1997_2778,
        @nisr_2003_489_body,
        ~s|<thead><tr><th>Provisions of the Order</th><th>Subject matter</th></tr></thead><tbody><tr><td>Article 4(1)(a) and (b) and (5) and to the extent that they are not already in force (2) to (4) and (6) to (9)</td><td>Prohibition on unauthorised or harmful deposit</td></tr><tr><td>Article 3(1), (2), (3)(a) to the extent that it is not already in force, (3)(b) and (c), (4), (5) and (6) to the extent that it is not already in force</td><td>Meaning of “waste”</td></tr></tbody>|
      )

    scopes = rules |> Enum.flat_map(& &1.scope) |> MapSet.new()

    for ref <-
          ~w[reg.4(1)(a) reg.4(5) reg.4(2) reg.4(9) reg.3(1) reg.3(3)(a) reg.3(3)(b) reg.3(4) reg.3(6)],
        do:
          assert(
            Enum.any?(scopes, &covers?(&1, ref)),
            "#{ref} in #{inspect(MapSet.to_list(scopes))}"
          )

    assert Enum.all?(rules, &(&1.purposes in [nil, :fully]))
  end

  # a scope item names the ref, or a range of its siblings reaches it
  defp covers?(item, ref) do
    case String.split(item, "..") do
      [one] ->
        one == ref

      [from, to] ->
        [p, a] = Regex.run(~r/^(.*)\((\d+)\)$/, from, capture: :all_but_first)
        [^p, b] = Regex.run(~r/^(.*)\((\d+)\)$/, to, capture: :all_but_first)

        case Regex.run(~r/^#{Regex.escape(p)}\((\d+)\)$/, ref, capture: :all_but_first) do
          [n] -> String.to_integer(n) in String.to_integer(a)..String.to_integer(b)
          nil -> false
        end
    end
  end
end
