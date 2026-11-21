defmodule SertantaiLegal.Scraper.Commencement.OrderReadTest do
  @moduledoc """
  One reading of a commencement order (the Commencement reader's speed
  fixes): what `--read-orders` writes is what the `--fresh` check previews
  and what the leftovers gate reads.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{OrderRead, Rule}

  @gas %{law: "UK_ukpga_1995_45", title: "Gas Act", year: "1995"}

  defp order_xml(type \\ "UnitedKingdomStatutoryInstrument"),
    do:
      ~s|<Legislation xmlns:ukm="http://www.legislation.gov.uk/namespaces/metadata"><ukm:Metadata><ukm:SecondaryMetadata><ukm:DocumentClassification><ukm:DocumentMainType Value="#{type}"/></ukm:DocumentClassification></ukm:SecondaryMetadata></ukm:Metadata><Secondary><Body><P1 id="article-2"><P1para><Text>The day appointed for the purpose of section 18(2) of the Gas Act 1995 shall be 1st March 1996.</Text></P1para></P1></Body></Secondary></Legislation>|

  defp own,
    do:
      Rule.new(
        commences: "UK_ukpga_1995_45",
        scope: :all,
        except: ["s.18", "s.13"],
        when: {:appointed, "by order"},
        source: %{law: "UK_ukpga_1995_45", ref: "s.18(2)", text: "This Act, except— …"},
        treatment: :by_order
      )

  test "an order's \"day appointed for the purpose of\" is given what the Act leaves to it, as --read-orders writes it (SI 1996/218)" do
    assert %{doc: %{law_name: "UK_uksi_1996_218"}, commences?: true, rules: [rule]} =
             OrderRead.from_docs("UK_uksi_1996_218", [order_xml()], @gas, [own()])

    assert %{scope: :all, except: ["s.18", "s.13"], when: {:date, ~D[1996-03-01]}} = rule
  end

  test "an order held as another instrument commences nothing under the name it is held by (SI 2005/423)" do
    assert %{doc: %{}, commences?: false, rules: []} =
             OrderRead.from_docs(
               "UK_uksi_1996_218",
               [order_xml("WelshStatutoryInstrument")],
               @gas,
               [own()]
             )
  end

  test "an order not held is no document and no rules" do
    assert OrderRead.read("UK_uksi_1800_99999", @gas, []) == %{
             doc: nil,
             commences?: false,
             rules: []
           }
  end

  test "an order is never its own Act's order (NISR 2012/286)" do
    assert %{commences?: false, rules: []} =
             OrderRead.from_docs("UK_ukpga_1995_45", [order_xml()], @gas, [own()])
  end
end
