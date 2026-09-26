defmodule SertantaiLegal.Scraper.PdfBacklog.TranscriptTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatParser
  alias SertantaiLegal.Scraper.PdfBacklog.{Clml, Transcript}

  @transcript """
  ---
  law_name: UK_uksi_2099_1
  extent: E+W+S
  transcribed_by: test
  ---
  <!-- preamble omitted -->

  ## Citation and extent
  1.—(1) These Regulations may be cited as the Test Regulations.
  (2) These Regulations shall apply to Great Britain.

  ## Interpretation
  2.—(1) In these Regulations—
  "the Act" means the Test Act;
  "licence" means a licence under the Act.
  (2) Proceedings may be postponed—
  (a) until a notice is given, or
  (b) until the period expires,
  whichever event first happens.

  3. Any notice shall—
  (a) be in writing; and
  (b) be sent to the Conservator.

  4. For paragraph (1) there shall be substituted—
  > "(1) to the manufacture of acetylene so long as—
  > (a) the pressure does not exceed 22 pounds"

  # SIGNED
  In Witness whereof the Seal is affixed.
  P. J. Clarke.

  # SCHEDULE 1: Forms
  ## Form 1: Claim for compensation (England and Wales)
  ## Form 2: Claim for compensation (Scotland)

  # SCHEDULE 2: Particulars
  1. Full name and address of applicant.
  2. Species and number of trees.
  """

  defp rows(text) do
    {:ok, t} = Transcript.parse(text)
    LatParser.parse(Clml.to_clml(t), %{law_name: t.meta["law_name"], type_code: "uksi"})
  end

  defp by_id(rows), do: Map.new(rows, &{&1.section_id |> String.split(":") |> List.last(), &1})

  describe "parse/1 + Clml.to_clml/1 through LatParser" do
    setup do
      %{rows: by_id(rows(@transcript))}
    end

    test "numbered regulations, paragraphs and lettered items get LAT section ids", %{rows: r} do
      for id <- ~w[reg.1 reg.1(1) reg.1(2) reg.2(1) reg.2(2) reg.2(2)(a) reg.2(2)(b) reg.3
                   reg.3(a) reg.3(b) reg.4] do
        assert Map.has_key?(r, id), "missing #{id}; got #{inspect(Map.keys(r))}"
      end

      assert r["reg.3(a)"].section_type == "paragraph"
      assert r["reg.2(2)(a)"].text == "until a notice is given, or"
    end

    test "continuation lines join their provision; trailing text follows lettered items",
         %{rows: r} do
      assert r["reg.2(1)"].text ==
               ~s[In these Regulations— "the Act" means the Test Act; "licence" means a licence under the Act.]

      assert r["reg.2(2)"].text == "Proceedings may be postponed— whichever event first happens."
    end

    test "quoted (inserted) text stays in its provision, not new provisions", %{rows: r} do
      assert r["reg.4"].text =~ ~s[substituted— "(1) to the manufacture]
      assert r["reg.4"].text =~ "(a) the pressure does not exceed 22 pounds\""
      refute Map.has_key?(r, "reg.4(1)")
    end

    test "schedules: headings become heading rows, numbered items become paragraphs",
         %{rows: r} do
      assert r["sch.1"].section_type == "schedule"
      assert r["sch.2.reg.2"].text == "Species and number of trees."

      headings =
        for {_, row} <- r, row.section_type == "heading", row.schedule == "1", do: row.text

      assert Enum.sort(headings) == [
               "Form 1: Claim for compensation (England and Wales)",
               "Form 2: Claim for compensation (Scotland)"
             ]
    end

    test "signed section and extent", %{rows: r} do
      assert [signed] = for({_, row} <- r, row.section_type == "signed", do: row)
      assert signed.text == "In Witness whereof the Seal is affixed. P. J. Clarke."
      assert r["reg.1(1)"].extent_code == "E+W+S"
    end
  end

  describe "parse/1 errors" do
    test "a paragraph before any regulation" do
      assert {:error, msg} = Transcript.parse("(1) Orphan.")
      assert msg =~ "line 1"
    end

    test "a lettered item with no parent" do
      assert {:error, msg} = Transcript.parse("## Heading\n(a) Orphan.")
      assert msg =~ "line 2"
    end

    test "an unknown section directive" do
      assert {:error, msg} = Transcript.parse("# APPENDIX\n1. Text.")
      assert msg =~ "APPENDIX"
    end

    test "no provisions at all" do
      assert {:error, msg} = Transcript.parse("---\nlaw_name: X\n---\n")
      assert msg =~ "no provisions"
    end
  end

  describe "qa/1" do
    test "a clean transcript has no warnings" do
      {:ok, t} = Transcript.parse(@transcript)
      assert Transcript.qa(t) == []
    end

    test "flags numbering gaps and uncertain readings" do
      {:ok, t} =
        Transcript.parse("""
        1.—(1) One.
        (3) Three [?].
        3. Skipped two.
        (a) a.
        (c) c.
        """)

      assert Transcript.qa(t) == [
               "body: regulation 3 follows 1",
               "reg.1: paragraph (3) follows (1)",
               "reg.3: item (c) follows (a)",
               "reg.1(3): uncertain reading [?]"
             ]
    end
  end
end
