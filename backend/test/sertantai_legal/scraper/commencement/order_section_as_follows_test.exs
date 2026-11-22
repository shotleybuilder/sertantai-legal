defmodule SertantaiLegal.Scraper.Commencement.OrderSectionAsFollowsTest do
  @moduledoc """
  "section 6 (…) as follows— (i) subsection (1) so far as …; (ii)
  subsection (2) …" and "subsection (1) of section 8 (…) as follows— (i) so
  far as it inserts section 40E into the 1991 Act …": the heading names the
  provision, each line below it is that provision's, partly; an open
  "subsection (1) so far as it— (aa) substitutes section 110A" names
  another law's section, never the Act's (LAT Change Pipeline, step
  Commencement reader). The Water Act 2014 (Commencement No. 6 …) Order
  2016 (SI 2016/1007) art.2 and (Commencement No. 4 …) Order 2015 (SI
  2015/1938) art.2.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order

  @act %{law: "UK_ukpga_2014_21", title: "Water Act", year: "2014"}

  defp p(tag, id, n, text, sub \\ ""),
    do:
      ~s(<#{tag} id="#{id}"><Pnumber>#{n}</Pnumber><#{tag}para><Text>#{text}</Text>#{sub}</#{tag}para></#{tag}>)

  defp rules(law, date, items) do
    Doc.new(law, [
      ~s"""
      <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Water Act 2014 (Commencement) Order</dc:title><Secondary><Body>
      <P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the 2014 Act” means the Water Act 2014; “the 1991 Act” means the Water Industry Act 1991.</Text></P1para></P1>
      <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>The following provisions of the 2014 Act come into force on #{date}—</Text>
      #{items}
      </P1para></P1>
      </Body></Secondary></Legislation>
      """
    ])
    |> Order.rules(@act)
  end

  defp read(rules), do: Map.new(rules, &{&1.scope, &1.purposes != nil})

  test "a section's lines under its 'as follows' heading are its subsections, partly (SI 2015/1938)" do
    read =
      rules(
        "UK_uksi_2015_1938",
        "18th December 2015",
        p(
          "P3",
          "article-2-a",
          "a",
          "section 6 (arrangements with the Water Industry Commission for Scotland) as follows—",
          p(
            "P4",
            "article-2-a-i",
            "i",
            "subsection (1) so far as it relates to sub-paragraph (ii); and"
          ) <>
            p(
              "P4",
              "article-2-a-ii",
              "ii",
              "subsection (2) so far as it inserts section 17FA into the 1991 Act;"
            )
        ) <>
          p(
            "P3",
            "article-2-d",
            "d",
            "section 14 (exceptions to duty and undertakings in lieu of merger references), so far as not already in force;"
          )
      )
      |> read()

    assert read[["s.6(1)"]] == true
    assert read[["s.6(2)"]] == true
    assert read[["s.14"]] == false
    refute Map.has_key?(read, ["s.17FA"])
  end

  test "a subsection's heading, and an open 'so far as it—', carry to the lines below (SI 2016/1007)" do
    read =
      rules(
        "UK_uksi_2016_1007",
        "1st November 2016",
        p(
          "P3",
          "article-2-b",
          "b",
          "subsection (1) of section 8 (bulk supply of water by water undertakers) as follows—",
          p(
            "P4",
            "article-2-b-i",
            "i",
            "so far as it inserts section 40E into the 1991 Act, for the purposes of sub-paragraph (ii);"
          ) <>
            p("P4", "article-2-b-ii", "ii", "so far as it inserts section 40I into the 1991 Act;")
        ) <>
          p(
            "P3",
            "article-2-c",
            "c",
            "section 9 (main connections into sewerage systems) as follows—",
            p(
              "P4",
              "article-2-c-i",
              "i",
              "subsection (1) so far as it—",
              p("P5", "article-2-c-i-aa", "aa", "substitutes section 110A;") <>
                p(
                  "P5",
                  "article-2-c-i-bb",
                  "bb",
                  "inserts sections 110B and 110J into the 1991 Act;"
                )
            ) <>
              p(
                "P4",
                "article-2-c-ii",
                "ii",
                "subsections (2) and (3) so far as they relate to sections 110B and 110J of the 1991 Act;"
              )
          ) <>
          p(
            "P3",
            "article-2-d",
            "d",
            "section 29 (standards of performance: water supply) so far as not already in force;"
          )
      )
      |> read()

    assert read[["s.8(1)"]] == true
    assert read[["s.9(1)"]] == true
    assert read[["s.9(2)", "s.9(3)"]] == true
    assert read[["s.29"]] == false

    for ref <- ["s.40E", "s.40I", "s.110A", "s.110B", "s.110J"],
        do: refute(Enum.any?(Map.keys(read), &(ref in &1)), "#{ref} is the 1991 Act's")
  end
end
