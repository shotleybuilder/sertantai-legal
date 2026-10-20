defmodule SertantaiLegal.Scraper.Amendment.ReaderTest do
  @moduledoc "AR-03: an amending provision read once into rules for the laws its notes point to."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.{Evaluator, Reader}

  @clean_air Reader.law_ref("UK_ukpga_1956_52", "Clean Air Act", "s")

  defp doc(body),
    do:
      Doc.new("UK_ukpga_1968_62", [
        ~s(<Legislation><Primary><Body><P1 id="section-1"><P1para><Text>In this Act “<Term id="t">the principal Act</Term>” means the Clean Air Act 1956.</Text></P1para></P1>#{body}</Body></Primary></Legislation>)
      ])

  defp reached(rules, sid),
    do: for(r <- rules, {:ok, t} <- [Evaluator.reach(r, "UK_ukpga_1956_52:" <> sid)], do: t)

  test "a paragraph substituted by paragraphs: the quote is numbered from the provision holding it (Clean Air Act 1968 s.5(1))" do
    d =
      doc(
        ~S|<P1 id="section-5"><P1para><P2 id="section-5-1"><P2para><Text>In section 7(1) of the principal Act for paragraph (b) there shall be substituted the following paragraphs:—</Text><BlockAmendment><P3><Pnumber>b</Pnumber><P3para><Text>new b</Text></P3para></P3><P3><Pnumber>c</Pnumber><P3para><Text>new c</Text></P3para></P3></BlockAmendment></P2para></P2></P1para></P1>|
      )

    rules =
      Reader.instruction(
        d,
        "section-5-1",
        %{"the principal act" => %{law: "UK_ukpga_1956_52", title: "Clean Air Act 1956"}},
        [@clean_air]
      )

    assert "UK_ukpga_1956_52:s.7(1)(c)" in reached(rules, "s.7(1)(c)")
    assert "UK_ukpga_1956_52:s.7(1)(b)" in reached(rules, "s.7(1)(b)")
  end

  test "a law the text doesn't name gets no rule" do
    d =
      doc(
        ~S|<P1 id="section-6"><P1para><Text>In section 3 of the Gas Act 1986, for “x” substitute “y”.</Text></P1para></P1>|
      )

    assert Reader.instruction(d, "section-6", %{}, [@clean_air]) == []
  end
end
