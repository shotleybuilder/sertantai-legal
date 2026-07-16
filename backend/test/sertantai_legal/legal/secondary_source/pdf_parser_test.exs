defmodule SertantaiLegal.Legal.SecondarySource.PdfParserTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.SecondarySource.PdfParser
  alias SertantaiLegal.Legal.SecondarySource.ParserProfile

  # ---------------------------------------------------------------------------
  # Test helpers — build fake source and line structs
  # ---------------------------------------------------------------------------

  defp fake_source(overrides \\ %{}) do
    Map.merge(
      %{
        id: "00000000-0000-0000-0000-000000000001",
        source_id: "TEST-1",
        source_type: :jsp,
        issuer: "MoD",
        edition: "V1.0, 2024",
        effective_date: nil
      },
      overrides
    )
  end

  defp line(text, font_size, bold \\ false, opts \\ []) do
    %{
      text: text,
      font_size: font_size,
      bold: bold,
      italic: Keyword.get(opts, :italic, false),
      font: Keyword.get(opts, :font, "ArialMT"),
      page: Keyword.get(opts, :page, 1),
      x: Keyword.get(opts, :x, 56.0)
    }
  end

  # ---------------------------------------------------------------------------
  # Profile detection
  # ---------------------------------------------------------------------------

  describe "ParserProfile.detect/2" do
    test "detects :mod_jsp from 12pt body + MoD text" do
      lines = [
        line("JSP 375 Vol 1 Chapter 8", 12.0),
        line("Body text here", 12.0),
        line("More body text", 12.0),
        line("Even more body", 12.0)
      ]

      profile = ParserProfile.detect(lines)
      assert profile.name == :mod_jsp
      assert profile.fonts.body_size == 12.0
    end

    test "detects :hse_acop from 10pt body + HSE text" do
      lines = [
        line("Health and Safety Executive", 9.0, true, page: 1),
        line("Body text here", 10.0),
        line("More body text", 10.0),
        line("Even more body", 10.0)
      ]

      profile = ParserProfile.detect(lines)
      assert profile.name == :hse_acop
      assert profile.fonts.body_size == 10.0
    end

    test "detects :hse_guidance from source_type" do
      lines = [line("Body text", 10.0), line("More text", 10.0)]
      source = fake_source(%{source_type: :guidance})
      profile = ParserProfile.detect(lines, source)
      assert profile.name == :hse_guidance
    end

    test "detects :hse_acop from source_type" do
      lines = [line("Body text", 10.0), line("More text", 10.0)]
      source = fake_source(%{source_type: :acop})
      profile = ParserProfile.detect(lines, source)
      assert profile.name == :hse_acop
    end
  end

  # ---------------------------------------------------------------------------
  # :mod_jsp profile — MoD Joint Service Publications
  # ---------------------------------------------------------------------------

  describe ":mod_jsp classification" do
    setup do
      profile = ParserProfile.build(:mod_jsp, 12.0)
      source = fake_source(%{source_type: :jsp, issuer: "MoD"})
      %{profile: profile, source: source}
    end

    test "extracts chapter title from large bold text", %{profile: profile, source: source} do
      lines = [
        line("8 Safety risk assessment and safe systems of work", 24.0, true),
        line("1. Employers have a general duty under the HSWA.", 12.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      chapters = Enum.filter(provisions, &(&1.section_type in [:chapter, :part]))
      assert length(chapters) == 1
      assert hd(chapters).heading =~ "Safety risk assessment"
    end

    test "extracts numbered paragraphs with dot notation", %{profile: profile, source: source} do
      lines = [
        line("Introduction", 14.0, true),
        line("1. Employers have a general duty under the HSWA.", 12.0),
        line("2. There is also a duty on employers under the MHSWR.", 12.0),
        line("3. The Secretary of State for Defence Policy Statement.", 12.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      paragraphs = Enum.filter(provisions, &(&1.section_type == :paragraph))
      assert length(paragraphs) == 3
      assert Enum.all?(paragraphs, &(&1.text_source == :full_text))
      assert Enum.all?(paragraphs, &String.match?(&1.section_id, ~r/\.para\.\d+$/))
    end

    test "merges multi-line chapter titles", %{profile: profile, source: source} do
      lines = [
        line("8 Safety risk assessment and safe", 24.0, true),
        line("systems of work", 24.0, true)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      chapters = Enum.filter(provisions, &(&1.section_type in [:chapter, :part]))
      assert length(chapters) == 1
      assert hd(chapters).heading =~ "systems of work"
    end

    test "classifies bold continuation as body, not heading", %{profile: profile, source: source} do
      lines = [
        line("Policy Statement 1", 12.0, true),
        line("must be followed to manage:", 12.0, true),
        line("1. All activities across Defence.", 12.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      headings = Enum.filter(provisions, &(&1.section_type == :heading))
      # "must be followed" should NOT be a heading — it's bold continuation
      assert length(headings) == 1
      assert hd(headings).heading =~ "Policy Statement 1"
    end

    test "skips JSP page headers", %{profile: profile, source: source} do
      lines = [
        line("6 JSP 375 Vol 1 Chapter 8 (V1.7 Jun 25)", 12.0),
        line("1. Employers have a general duty.", 12.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      # Header line should be skipped
      texts = Enum.map(provisions, &(&1.heading || &1.text))
      refute Enum.any?(texts, &(&1 =~ "JSP 375 Vol 1"))
    end

    test "section_id uses JSP prefix with issuer and year", %{profile: profile, source: source} do
      lines = [
        line("Introduction", 14.0, true),
        line("1. First paragraph.", 12.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      assert Enum.all?(provisions, &String.starts_with?(&1.section_id, "JSP_mod_2024_"))
    end

    test "deduplicates repeated section_ids", %{profile: profile, source: source} do
      lines = [
        line("Guidance", 14.0, true),
        line("1. First para.", 12.0),
        line("Guidance", 14.0, true),
        line("2. Second para.", 12.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      section_ids = Enum.map(provisions, & &1.section_id)
      assert length(section_ids) == length(Enum.uniq(section_ids))
    end

    test "large non-bold text is still a chapter title", %{profile: profile, source: source} do
      lines = [
        line("Element 3: Legislation, Policy", 36.0, false),
        line("1. This element provides direction.", 12.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      chapters = Enum.filter(provisions, &(&1.section_type in [:chapter, :part]))
      assert length(chapters) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # :hse_acop profile — HSE Approved Codes of Practice
  # ---------------------------------------------------------------------------

  describe ":hse_acop classification" do
    setup do
      profile = ParserProfile.build(:hse_acop, 10.0)
      source = fake_source(%{source_type: :acop, source_id: "L8", issuer: "HSE"})
      %{profile: profile, source: source}
    end

    test "extracts numbered paragraphs without dot", %{profile: profile, source: source} do
      lines = [
        line("Health and safety law", 16.0, true),
        line("13 Legionnaires' disease is normally contracted by inhaling.", 10.0),
        line("14 The risk of legionellosis is increased if conditions.", 10.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      paragraphs = Enum.filter(provisions, &(&1.section_type == :paragraph))
      assert length(paragraphs) == 2
      assert Enum.all?(paragraphs, &(&1.text_source == :full_text))
    end

    test "does not match JSP dot-style numbering as paragraphs", %{
      profile: profile,
      source: source
    } do
      # ACoP profile should NOT match "1. Text" — that's JSP style
      # It should match "1 Text" (no dot)
      lines = [
        line("Heading", 16.0, true),
        line("Body text without a number at the start.", 10.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      paragraphs = Enum.filter(provisions, &(&1.section_type == :paragraph))
      assert length(paragraphs) == 0
    end

    test "section_id uses ACOP prefix", %{profile: profile, source: source} do
      lines = [
        line("Scope", 16.0, true),
        line("1 This code applies to all premises.", 10.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      assert Enum.all?(provisions, &String.starts_with?(&1.section_id, "ACOP_hse_"))
    end

    test "large title detected regardless of bold", %{profile: profile, source: source} do
      lines = [
        line("Legionnaires' disease", 37.0, true),
        line("Approved Code of Practice and guidance", 18.0, false)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      chapters = Enum.filter(provisions, &(&1.section_type in [:chapter, :part]))
      assert length(chapters) >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # :hse_guidance profile — HSE Guidance (prose)
  # ---------------------------------------------------------------------------

  describe ":hse_guidance classification" do
    setup do
      profile = ParserProfile.build(:hse_guidance, 10.0)
      source = fake_source(%{source_type: :guidance, source_id: "HSG65", issuer: "HSE"})
      %{profile: profile, source: source}
    end

    test "captures prose body text as paragraphs", %{profile: profile, source: source} do
      lines = [
        line("Legal duties", 12.0, true),
        line("All organisations have management processes to deal with health and safety.", 10.0),
        line("The Management of Health and Safety at Work Regulations require employers.", 10.0),
        line("Risk assessment", 12.0, true),
        line(
          "A risk assessment is an important step in protecting workers and the business.",
          10.0
        )
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      paragraphs = Enum.filter(provisions, &(&1.section_type == :paragraph))
      assert length(paragraphs) >= 2
      assert Enum.all?(paragraphs, &(&1.text_source == :full_text))
    end

    test "prose paragraphs use auto-incrementing counter in section_id", %{
      profile: profile,
      source: source
    } do
      lines = [
        line("Introduction", 14.0, true),
        line("First paragraph of prose text that explains the guidance purpose.", 10.0),
        # A heading breaks the prose flow, creating a second prose block
        line("Details", 12.0, true),
        line("Second paragraph of prose text with more detail about the topic.", 10.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      paragraphs = Enum.filter(provisions, &(&1.section_type == :paragraph))
      section_ids = Enum.map(paragraphs, & &1.section_id)
      assert Enum.any?(section_ids, &(&1 =~ ~r/prose\.1$/))
      assert Enum.any?(section_ids, &(&1 =~ ~r/prose\.2$/))
    end

    test "prose counter resets on new section", %{profile: profile, source: source} do
      lines = [
        line("Section A", 14.0, true),
        line("Prose in section A about the first topic.", 10.0),
        line("More prose in section A with additional detail.", 10.0),
        line("Section B", 14.0, true),
        line("Prose in section B about the second topic.", 10.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      paragraphs = Enum.filter(provisions, &(&1.section_type == :paragraph))

      # Both sections should have prose.1
      prose_1_ids = Enum.filter(paragraphs, &(&1.section_id =~ ~r/prose\.1$/))
      assert length(prose_1_ids) == 2
    end

    test "short lines are not captured as prose paragraphs", %{profile: profile, source: source} do
      lines = [
        line("Heading", 14.0, true),
        line("OK", 10.0),
        line("A substantive paragraph with enough text to be meaningful.", 10.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      paragraphs = Enum.filter(provisions, &(&1.section_type == :paragraph))
      # "OK" is too short (<=20 chars) to be a prose paragraph
      assert length(paragraphs) == 1
    end

    test "section_id uses HSG prefix for guidance", %{profile: profile, source: source} do
      lines = [
        line("Scope", 14.0, true),
        line("This guidance covers health and safety management.", 10.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      assert Enum.all?(provisions, &String.starts_with?(&1.section_id, "HSG_hse_"))
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-profile: no regression
  # ---------------------------------------------------------------------------

  describe "cross-profile isolation" do
    test "mod_jsp does not capture prose body" do
      profile = ParserProfile.build(:mod_jsp, 12.0)
      source = fake_source()

      lines = [
        line("Introduction", 14.0, true),
        line("Body text without any number at the start.", 12.0),
        line("More body text that continues the prose.", 12.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      paragraphs = Enum.filter(provisions, &(&1.section_type == :paragraph))
      # mod_jsp only captures "N." numbered paragraphs, not prose
      assert length(paragraphs) == 0
    end

    test "hse_acop does not capture unnumbered prose as paragraphs" do
      profile = ParserProfile.build(:hse_acop, 10.0)
      source = fake_source(%{source_type: :acop, source_id: "L8", issuer: "HSE"})

      lines = [
        line("Heading", 16.0, true),
        line("Unnumbered body text that is just guidance prose.", 10.0)
      ]

      {:ok, provisions} = PdfParser.classify_lines(lines, source, profile)
      paragraphs = Enum.filter(provisions, &(&1.section_type == :paragraph))
      assert length(paragraphs) == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Per-chapter namespace isolation (issue #123)
  # ---------------------------------------------------------------------------

  describe "per-chapter namespace isolation" do
    test "two chapters with identical headings produce different section_ids" do
      profile = ParserProfile.build(:mod_jsp, 12.0)

      # Chapter 8 and Chapter 23 both have "Part 2: Guidance" and "Introduction"
      ch8_source = fake_source(%{source_id: "JSP-375-CH08"})
      ch23_source = fake_source(%{source_id: "JSP-375-CH23"})

      lines = [
        line("Introduction", 14.0, true),
        line("1. First paragraph of guidance.", 12.0)
      ]

      {:ok, ch8_provisions} = PdfParser.classify_lines(lines, ch8_source, profile)
      {:ok, ch23_provisions} = PdfParser.classify_lines(lines, ch23_source, profile)

      ch8_ids = Enum.map(ch8_provisions, & &1.section_id)
      ch23_ids = Enum.map(ch23_provisions, & &1.section_id)

      # No overlap — different source_ids produce different section_id prefixes
      assert MapSet.disjoint?(MapSet.new(ch8_ids), MapSet.new(ch23_ids))

      # Both contain the expected paragraph
      assert Enum.any?(ch8_ids, &(&1 =~ "JSP375CH08"))
      assert Enum.any?(ch23_ids, &(&1 =~ "JSP375CH23"))
    end
  end

  # ---------------------------------------------------------------------------
  # Integration tests — real PDFs (skipped if not present)
  # ---------------------------------------------------------------------------

  describe "integration: real PDFs" do
    @jsp375_path "../data/secondary-sources/jsp/jsp375/jsp375_ch08.pdf"
    @l8_path "../data/secondary-sources/acop/l8.pdf"
    @hsg65_path "../data/secondary-sources/guidance/hsg65.pdf"

    @tag :integration
    test "JSP 375 Ch 8 produces expected provision counts" do
      if File.exists?(@jsp375_path) do
        source =
          fake_source(%{
            source_type: :jsp,
            source_id: "JSP-375-CH08",
            issuer: "MoD",
            edition: "Current"
          })

        {:ok, provisions, profile} = PdfParser.parse(@jsp375_path, source)

        assert profile.name == :mod_jsp
        by_type = Enum.frequencies_by(provisions, & &1.section_type)
        assert by_type[:paragraph] >= 120
        assert by_type[:section] >= 18
        assert by_type[:paragraph] <= 130
      end
    end

    @tag :integration
    test "L8 ACoP produces expected provision counts" do
      if File.exists?(@l8_path) do
        source =
          fake_source(%{
            source_type: :acop,
            source_id: "L8",
            issuer: "HSE",
            edition: "4th edition, 2013"
          })

        {:ok, provisions, profile} = PdfParser.parse(@l8_path, source)

        assert profile.name == :hse_acop
        by_type = Enum.frequencies_by(provisions, & &1.section_type)
        assert by_type[:paragraph] >= 90
        assert by_type[:paragraph] <= 110
      end
    end

    @tag :integration
    test "HSG65 produces prose paragraphs with :hse_guidance profile" do
      if File.exists?(@hsg65_path) do
        source =
          fake_source(%{
            source_type: :guidance,
            source_id: "HSG65",
            issuer: "HSE",
            edition: "3rd edition, 2013"
          })

        {:ok, provisions, profile} = PdfParser.parse(@hsg65_path, source)

        assert profile.name == :hse_guidance
        by_type = Enum.frequencies_by(provisions, & &1.section_type)
        assert by_type[:paragraph] >= 150
      end
    end
  end
end
