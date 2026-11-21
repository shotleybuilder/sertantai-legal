defmodule SertantaiLegal.Scraper.LawStart.DateOfEnactmentTest do
  @moduledoc """
  An Act's Royal Assent date from its own introduction's `DateOfEnactment`,
  for an Act whose register row and CLML metadata give none (the Planning
  (Wales) Act 2015: "{6 July 2015}").
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.DateOfEnactment

  defp intro(text),
    do:
      "<Legislation><Primary><PrimaryPrelims><Title>An Act</Title>" <>
        "<DateOfEnactment><DateText>#{text}</DateText></DateOfEnactment>" <>
        "</PrimaryPrelims></Primary></Legislation>"

  test "braces round the date (anaw 2015/4)" do
    assert DateOfEnactment.parse(intro("{6 July 2015}")) == ~D[2015-07-06]
  end

  test "square brackets, an ordinal day, line breaks inside" do
    assert DateOfEnactment.parse(intro("[12th July 2011]")) == ~D[2011-07-12]
    assert DateOfEnactment.parse(intro("\n  [8th  March\n 2012]\n")) == ~D[2012-03-08]
  end

  test "no element, an empty one, or a day that is no date: nil" do
    assert DateOfEnactment.parse("<Legislation><Body/></Legislation>") == nil
    assert DateOfEnactment.parse(intro("")) == nil
    assert DateOfEnactment.parse(intro("[31st June 2011]")) == nil
    assert DateOfEnactment.parse(nil) == nil
  end

  test "a date elsewhere in the introduction is not the enactment's" do
    xml = "<Legislation><P>made on 6 July 2015</P></Legislation>"
    assert DateOfEnactment.parse(xml) == nil
  end

  # Fire and OH&S: Store and build: 2019 c.16 and c.26's introductions hold
  # an empty DateText and the date in their own metadata
  test "an empty DateText: the introduction's own metadata EnactmentDate" do
    xml =
      ~s(<Legislation><ukm:Metadata><ukm:EnactmentDate Date="2019-04-08"/></ukm:Metadata>) <>
        "<Primary><PrimaryPrelims><DateOfEnactment><DateText/></DateOfEnactment>" <>
        "</PrimaryPrelims></Primary></Legislation>"

    assert DateOfEnactment.parse(xml) == ~D[2019-04-08]
  end

  test "the text wins over the metadata where both speak" do
    xml =
      String.replace(
        intro("{6 July 2015}"),
        "<Legislation>",
        ~s(<Legislation><ukm:EnactmentDate Date="2015-07-07"/>)
      )

    assert DateOfEnactment.parse(xml) == ~D[2015-07-06]
  end

  test "a Welsh Measure: the day Her Majesty in Council approved it, from its enacting words (MWA 2010/8)" do
    xml =
      ~s|<PrimaryPrelims><DateOfEnactment><DateText/></DateOfEnactment><PrimaryPreamble><IntroductoryText><P><Text><Strong>This Measure, passed by the National Assembly for Wales on 2 November 2010 and approved by Her Majesty in Council on 15 December 2010, enacts the following provisions:–</Strong></Text></P></IntroductoryText></PrimaryPreamble></PrimaryPrelims>|

    assert DateOfEnactment.parse(xml) == ~D[2010-12-15]
  end
end
