defmodule SertantaiLegal.Scraper.Commencement.OrderRelatedListTest do
  @moduledoc """
  Waste, Water and Climate: Commencement reader — an open "so far as it
  relates to—" list: "in Schedule 7 (further amendments)— (i) paragraph
  3(8)(b) so far as it relates to— (aa) sections 39ZA, … of the 1991 Act;
  and (bb) sections 42 to 47, 49 and 51 to 53 of the 2014 Act" (SI
  2015/1469 art.2(f)). The sections listed are what the paragraph relates
  to, never brought in; a Schedule's paragraphs under a section's open list
  still are (SI 1975/1938: "Section 125(1), as far as it relates to:— (a) in
  Part III of Schedule 16, paragraphs 1, 2 …").
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order

  @act %{law: "UK_ukpga_2014_21", title: "Water Act", year: "2014"}

  defp p(id, label, text, inner \\ ""),
    do:
      ~s|<P4 id="#{id}"><Pnumber>#{label}</Pnumber><P4para><Text>#{text}</Text>#{inner}</P4para></P4>|

  test "the sections an open relating list names are never brought in" do
    body =
      ~s|<P1 id="article-1"><P1para><Text>In this Order “the 2014 Act” means the Water Act 2014; “the 1991 Act” means the Water Industry Act 1991.</Text></P1para></P1>| <>
        ~s|<P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>The following provisions of the 2014 Act come into force on 15th July 2015—</Text>| <>
        ~s|<P3 id="article-2-e"><Pnumber>e</Pnumber><P3para><Text>section 56 (further amendments) so far as it relates to the provisions set out in paragraph (f); and</Text></P3para></P3>| <>
        ~s|<P3 id="article-2-f"><Pnumber>f</Pnumber><P3para><Text>in Schedule 7 (further amendments)—</Text>| <>
        ~s|<P4 id="article-2-f-i"><Pnumber>i</Pnumber><P4para><Text>paragraph 3(8)(b) so far as it relates to—</Text>| <>
        p("article-2-f-i-aa", "aa", "sections 39ZA, 39D and 40J of the 1991 Act; and") <>
        p("article-2-f-i-bb", "bb", "sections 42 to 47, 49 and 51 to 53 of the 2014 Act; and") <>
        ~s|</P4para></P4>| <>
        p(
          "article-2-f-ii",
          "ii",
          "paragraphs 2 and 3(1) so far as they relate to those provisions."
        ) <>
        ~s|</P3para></P3></P1para></P1>|

    rules =
      Doc.new("UK_uksi_2015_1469", [
        ~s|<Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Water Act 2014 (Commencement No. 4 and Transitional Provisions) Order 2015</dc:title><Secondary><Body>#{body}</Body></Secondary></Legislation>|
      ])
      |> Order.rules(@act)

    scopes = Enum.map(rules, & &1.scope)
    assert ["s.56"] in scopes
    assert Enum.any?(scopes, &("sch.7.para.3(8)(b)" in &1))
    refute Enum.any?(scopes, &Enum.any?(&1, fn r -> r =~ ~r/^s\.(4[2-9]|5[0-3])/ end))
  end
end
