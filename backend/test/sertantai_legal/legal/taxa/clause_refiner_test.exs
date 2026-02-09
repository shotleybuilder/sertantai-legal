defmodule SertantaiLegal.Legal.Taxa.ClauseRefinerTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.ClauseRefiner

  describe "refine/3" do
    test "returns nil for nil input" do
      assert ClauseRefiner.refine(nil, "RESPONSIBILITY") == nil
    end

    test "returns nil for empty string input" do
      assert ClauseRefiner.refine("", "RESPONSIBILITY") == nil
    end

    test "handles simple truncated clause ending at modal" do
      # From UK_ssi_2015_181 - common pattern where clause ends at "must"
      raw = "the authority must"
      result = ClauseRefiner.refine(raw, "RESPONSIBILITY")

      # Should keep the subject and modal, add ellipsis since no action
      # Note: "the" may be stripped as a leading article fragment
      assert String.contains?(result, "authority must")
      assert String.ends_with?(result, "...")
    end

    test "handles clause with Ministers" do
      raw = "Ministers must"
      result = ClauseRefiner.refine(raw, "RESPONSIBILITY")

      assert result == "Ministers must..."
    end

    test "extracts subject from long preamble" do
      # Simulates regulation-14 pattern - huge preamble ending at modal
      raw = """
      Agency; a person to whom a licence has been granted under section 7(2) of the
      Gas Act 1986 (licence to convey gas through pipes) whose apparatus is situated on,
      over or under the land to which the application relates. The planning authority must
      """

      result = ClauseRefiner.refine(raw, "RESPONSIBILITY")

      # Should extract just the relevant sentence with the actor
      assert String.contains?(result, "planning authority must")
      # Should be truncated to reasonable length
      assert String.length(result) <= 300
    end

    test "finds last modal when multiple modals present" do
      raw = "The Minister may make regulations. The authority must"
      result = ClauseRefiner.refine(raw, "RESPONSIBILITY")

      # Should focus on the LAST modal (must) since patterns end at modal
      assert String.contains?(result, "authority must")
    end

    test "handles 'may not' as a modal" do
      raw = "The authority may not"
      result = ClauseRefiner.refine(raw, "RESPONSIBILITY")

      assert String.contains?(result, "may not")
    end

    test "handles 'shall' modal" do
      raw = "It shall be the duty of the Minister"
      result = ClauseRefiner.refine(raw, "RESPONSIBILITY")

      assert String.contains?(result, "shall")
    end

    test "truncates very long clauses" do
      # Create a clause longer than 300 chars
      long_preamble = String.duplicate("word ", 100)
      raw = "#{long_preamble}The authority must"
      result = ClauseRefiner.refine(raw, "RESPONSIBILITY")

      assert String.length(result) <= 300
      assert String.ends_with?(result, "...")
    end

    test "preserves sentence ending punctuation" do
      raw = "The Minister must notify the parties."
      result = ClauseRefiner.refine(raw, "RESPONSIBILITY")

      # Should preserve the period, not add ellipsis
      assert String.ends_with?(result, ".")
      refute String.ends_with?(result, "...")
    end
  end

  describe "find_last_modal_position/1" do
    test "finds single modal" do
      {start, length, modal} = ClauseRefiner.find_last_modal_position("The authority must")
      assert modal == "must"
      assert start == 14
      assert length == 4
    end

    test "finds last modal when multiple present" do
      {_start, _length, modal} =
        ClauseRefiner.find_last_modal_position("The Minister may regulate. The authority must")

      assert modal == "must"
    end

    test "returns nil when no modal present" do
      assert ClauseRefiner.find_last_modal_position("The authority is responsible") == nil
    end

    test "finds 'may not' as single modal" do
      {_start, length, modal} = ClauseRefiner.find_last_modal_position("The authority may not")
      assert modal == "may not"
      assert length == 7
    end

    test "finds 'may only' as single modal" do
      {_start, length, modal} = ClauseRefiner.find_last_modal_position("The authority may only")
      assert modal == "may only"
      assert length == 8
    end
  end

  describe "extract_subject/2" do
    test "extracts from sentence start" do
      text = "Some context. The planning authority must"
      # Modal starts at position 28
      modal_start = String.length("Some context. The planning authority ")
      result = ClauseRefiner.extract_subject(text, modal_start)

      # Should extract "The planning authority" (may have trailing space)
      assert String.trim(result) == "The planning authority"
    end

    test "handles text without clear sentence start" do
      text = "the planning authority must"
      modal_start = String.length("the planning authority ")
      result = ClauseRefiner.extract_subject(text, modal_start)

      # Leading "the" may be stripped as a fragment; "planning authority" is the key part
      assert String.contains?(result, "planning authority")
    end

    test "limits subject to window size" do
      # Create very long text before modal
      long_text = String.duplicate("a ", 200) <> "The authority must"
      # position of "must"
      modal_start = String.length(long_text) - 4
      result = ClauseRefiner.extract_subject(long_text, modal_start)

      # Should be trimmed to reasonable size
      assert String.length(result) <= 120
    end
  end

  describe "extract_action/3" do
    test "extracts action from raw clause when present" do
      raw = "The authority must notify the parties within 14 days."
      modal_end = String.length("The authority must ")
      result = ClauseRefiner.extract_action(raw, modal_end, nil)

      assert result == "notify the parties within 14 days."
    end

    test "returns empty when no action in raw and no section text" do
      raw = "The authority must"
      modal_end = String.length(raw)
      result = ClauseRefiner.extract_action(raw, modal_end, nil)

      assert result == ""
    end

    test "extracts action from section text when raw has no action" do
      raw = "The authority must"
      section_text = "Some preamble. The authority must notify the parties. More text."
      modal_end = String.length(raw)

      result = ClauseRefiner.extract_action(raw, modal_end, section_text)

      assert String.contains?(result, "notify the parties")
    end

    test "stops at sentence boundary" do
      raw = "The authority must notify the parties. Additional unrelated text here."
      modal_end = String.length("The authority must ")
      result = ClauseRefiner.extract_action(raw, modal_end, nil)

      assert result == "notify the parties."
      refute String.contains?(result, "Additional")
    end

    test "does not end mid-word when no sentence boundary" do
      # Simulates V2 pattern capture that cuts off at 200 chars mid-word
      raw =
        "The planning authority must give notice of the appeal to each person on whom the hazardous substances contravention notice wa"

      modal_end = String.length("The planning authority must ")
      result = ClauseRefiner.extract_action(raw, modal_end, nil)

      # Should not end with "wa" (partial word)
      refute String.ends_with?(result, "wa")
      # Should end at a complete word
      assert String.ends_with?(result, "notice") or
               String.ends_with?(result, "contravention") or
               String.ends_with?(result, "substances")
    end

    test "removes trailing short fragments" do
      raw = "The authority must notify all relevant persons wa"
      modal_end = String.length("The authority must ")
      result = ClauseRefiner.extract_action(raw, modal_end, nil)

      refute String.ends_with?(result, "wa")
      assert String.contains?(result, "persons")
    end
  end

  describe "combine_clause/3" do
    test "combines subject, modal, and action" do
      result = ClauseRefiner.combine_clause("The authority", "must", "notify the parties.")
      assert result == "The authority must notify the parties."
    end

    test "adds ellipsis when action is empty" do
      result = ClauseRefiner.combine_clause("The authority", "must", "")
      assert result == "The authority must..."
    end

    test "adds ellipsis when action lacks terminal punctuation" do
      result = ClauseRefiner.combine_clause("The authority", "must", "notify the parties")
      assert result == "The authority must notify the parties..."
    end

    test "does not add ellipsis when action ends with period" do
      result = ClauseRefiner.combine_clause("The authority", "must", "notify the parties.")
      assert result == "The authority must notify the parties."
      refute String.ends_with?(result, "...")
    end
  end

  describe "truncate_smart/2" do
    test "returns text unchanged if under limit" do
      text = "Short text."
      assert ClauseRefiner.truncate_smart(text, 300) == text
    end

    test "truncates at sentence boundary when possible" do
      text = "First sentence here. Second sentence that goes on and on and on."
      result = ClauseRefiner.truncate_smart(text, 30)

      assert result == "First sentence here."
    end

    test "truncates with ellipsis when no good boundary" do
      text = "This is a very long sentence without any breaks that goes on and on"
      result = ClauseRefiner.truncate_smart(text, 30)

      assert String.ends_with?(result, "...")
      assert String.length(result) <= 30
    end
  end

  describe "UK_ssi_2015_181 real examples" do
    # These are actual clause captures from the case study law

    test "regulation-14 giant preamble" do
      raw = """
      Agency; a person to whom a licence has been granted under section 7(2) of the
      Gas Act 1986 (licence to convey gas through pipes) whose apparatus is situated on,
      over or under the land to which the application relates or on, over or under adjoining
      land; a person to whom a licence has been granted under section 6(1)(b) or (c) of the
      Electricity Act 1989 (transmission and distribution licences) whose apparatus is
      situated on, over or under the land to which the application relates or on, under or
      over adjoining land; where the land to which the application relates, or any part of
      that land, is within 2 kilometres of a royal palace, park or residence, the Scottish
      Ministers; where the land to which the application relates, or any part of that land,
      is within 2 kilometres of the area of any other planning authority or a hazardous
      substances authority. The planning authority must
      """

      result = ClauseRefiner.refine(raw, "RESPONSIBILITY")

      # Should extract just the sentence with the actor
      assert String.contains?(result, "planning authority must")
      # Should NOT contain the licence preamble
      refute String.contains?(result, "Gas Act 1986")
      # Should be under max length
      assert String.length(result) <= 300
    end

    test "regulation-16 SEPA advice clause" do
      raw = """
      Scottish Environment Protection Agency has advised against that or has recommended
      that conditions be imposed on the grant which the authority does not propose to
      impose, the authority must
      """

      result = ClauseRefiner.refine(raw, "RESPONSIBILITY")

      # Should capture the relevant part about authority notification
      assert String.contains?(result, "authority must")
    end

    test "regulation-20 Ministers direction clause" do
      raw = """
      Ministers in accordance with a direction given under section 18 of the principal
      Act a planning authority must
      """

      result = ClauseRefiner.refine(raw, "RESPONSIBILITY")

      # The sentence structure here is odd - but should still extract something sensible
      assert String.contains?(result, "must")
    end

    test "regulation-21 simple Ministers must" do
      raw = "Ministers must"
      result = ClauseRefiner.refine(raw, "RESPONSIBILITY")

      assert result == "Ministers must..."
    end
  end
end
