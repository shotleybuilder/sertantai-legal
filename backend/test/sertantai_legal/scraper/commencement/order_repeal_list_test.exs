defmodule SertantaiLegal.Scraper.Commencement.OrderRepealListTest do
  @moduledoc """
  An item "section 101(2) in so far as it relates to the following repeals
  specified in Schedule 9—" lists the repeals it relates to below it: other
  laws' provisions, never ones the order brings in; and "the WIA", an
  abbreviation the order never defines as the Act, is another law (LAT
  Change Pipeline, step Commencement reader). The Water Act 2003
  (Commencement No. 5, Transitional Provisions and Savings) Order 2005 (SI
  2005/2714) art.4.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order

  @act %{law: "UK_ukpga_2003_37", title: "Water Act", year: "2003"}

  defp item(id, n, text, sub \\ ""),
    do: ~s(<P3 id="#{id}"><Pnumber>#{n}</Pnumber><P3para><Text>#{text}</Text>#{sub}</P3para></P3>)

  defp sub(id, n, text),
    do: ~s(<P4 id="#{id}"><Pnumber>#{n}</Pnumber><P4para><Text>#{text}</Text></P4para></P4>)

  defp rules do
    Doc.new("UK_uksi_2005_2714", [
      ~s"""
      <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Water Act 2003 (Commencement No. 5, Transitional Provisions and Savings) Order 2005</dc:title><Secondary><Body>
      <P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the Act” means the Water Act 2003.</Text></P1para></P1>
      <P1 id="article-4"><Pnumber>4</Pnumber><P1para><Text>The following provisions shall come into force on 1st April 2006—</Text>
      #{item("article-4-a", "a", "section 34 (the Authority) except in so far as subsection (2) gives effect to Schedule 1 for the purposes of inserting into the WIA paragraph 11 of Schedule 1A;")}
      #{item("article-4-d", "d", "section 52 (co-operation between water regulators);")}
      #{item("article-4-g", "g", "section 101(2) in so far as it relates to the following repeals specified in Schedule 9—", sub("article-4-g-i", "i", "the repeals of section 1 of, and Schedule 1 to, the WIA and the repeal in relation to section 219(1) of that Act;") <> sub("article-4-g-iv", "iv", "the repeals of section 185(2)(a) of, and Schedule 3, paragraphs 6 and 7, and Schedule 25, paragraphs 68(2)(a) and 76(a) to, the Water Act 1989."))}
      </P1para></P1>
      </Body></Secondary></Legislation>
      """
    ])
    |> Order.rules(@act)
  end

  test "the repeals listed under an item are never items; the WIA's provisions are never the Act's" do
    rules = rules()
    scopes = Enum.flat_map(rules, & &1.scope)

    assert "s.52" in scopes
    assert Enum.find(rules, &(&1.scope == ["s.101(2)"])).purposes != nil

    for ref <- ["s.1", "s.219(1)", "sch.1A.para.11", "s.185(2)(a)", "sch.3", "sch.25"],
        do: refute(ref in scopes, "#{ref} is another law's")
  end

  test "a 'following repeals' sub-list ends with its item: the next item is read" do
    rules =
      Doc.new("UK_uksi_2005_2714", [
        ~s"""
        <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Water Act 2003 (Commencement No. 5) Order 2005</dc:title><Secondary><Body>
        <P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the Act” means the Water Act 2003.</Text></P1para></P1>
        <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>The following provisions shall come into force on 1st October 2005—</Text>
        #{item("article-2-m", "m", "section 101(2) in so far as it relates to the following repeals specified in Schedule 9—", sub("article-2-m-i", "i", "the repeals of sections 28, 30 and 194 of, and Schedule 4 to, the WIA;") <> sub("article-2-m-iii", "iii", "the repeal of Schedule 4, paragraph 6 to the Water Act 1989;"))}
        #{item("article-2-n", "n", "section 63 (drought plans).")}
        </P1para></P1>
        </Body></Secondary></Legislation>
        """
      ])
      |> Order.rules(@act)

    scopes = Enum.flat_map(rules, & &1.scope)

    assert "s.63" in scopes

    for ref <- ["s.28", "s.30", "s.194", "sch.4"],
        do: refute(ref in scopes, "#{ref} is the WIA's")
  end
end
