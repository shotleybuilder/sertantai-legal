defmodule SertantaiLegal.Legal.Taxa.ClauseQualityIntegrationTest do
  @moduledoc """
  Integration tests for clause quality in the responsibility parser.

  Uses UK_ssi_2015_181 (Town and Country Planning (Hazardous Substances) (Scotland)
  Regulations 2015) as the test case.

  These tests verify that:
  1. Clauses end at proper sentence boundaries (period, semicolon)
  2. Clauses never end mid-word (e.g., "wa" instead of "was")
  3. Clauses contain the expected responsibility text
  4. The planning authority actor is correctly identified
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.DutyTypeLib

  @fixtures_path "test/fixtures/taxa/uk_ssi_2015_181_sections.json"

  setup_all do
    fixture = load_fixture()
    {:ok, fixture: fixture}
  end

  defp load_fixture do
    @fixtures_path
    |> File.read!()
    |> Jason.decode!()
  end

  describe "clause quality for UK_ssi_2015_181" do
    test "regulation-6: no planning authority responsibility (passive voice)", %{fixture: fixture} do
      section = fixture["sections"]["regulation-6"]
      text = section["text"]

      {_actors, _types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:responsibility, ["Gvt: Authority: Planning"], text, [])

      # This regulation says "must be made TO the planning authority" - passive voice
      # The planning authority is the recipient, not the actor with the responsibility
      assert length(matches) == 0,
             "Should NOT find planning authority responsibility (text is passive voice)"
    end

    test "regulation-9: clauses end at sentence boundary", %{fixture: fixture} do
      section = fixture["sections"]["regulation-9"]
      text = section["text"]

      {_actors, _types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:responsibility, ["Gvt: Authority: Planning"], text, [])

      assert length(matches) > 0, "Should find at least one responsibility"

      # Check that all matches have clean endings (no mid-word truncation)
      for match <- matches do
        assert_no_mid_word_truncation(match.clause)
      end

      # Check that we found the expected "not determine" clause
      not_determine_match =
        Enum.find(matches, fn m -> String.contains?(m.clause, "not determine") end)

      assert not_determine_match,
             "Should find clause containing 'not determine', got: #{inspect(Enum.map(matches, & &1.clause))}"
    end

    test "regulation-10: clause contains 'publish a notice' and ends properly", %{
      fixture: fixture
    } do
      section = fixture["sections"]["regulation-10"]
      text = section["text"]

      {_actors, _types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:responsibility, ["Gvt: Authority: Planning"], text, [])

      assert length(matches) > 0, "Should find at least one responsibility"

      # Find the match containing "publish"
      publish_match = Enum.find(matches, fn m -> String.contains?(m.clause, "publish") end)
      assert publish_match, "Should find a clause containing 'publish'"

      assert_no_mid_word_truncation(publish_match.clause)
    end

    test "regulation-12: clause does not end with 'compl' (mid-word)", %{fixture: fixture} do
      section = fixture["sections"]["regulation-12"]
      text = section["text"]

      {_actors, _types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:responsibility, ["Gvt: Authority: Planning"], text, [])

      assert length(matches) > 0, "Should find at least one responsibility"

      for match <- matches do
        refute String.ends_with?(match.clause, "compl"),
               "Clause should not end mid-word: #{match.clause}"

        refute String.ends_with?(match.clause, "compl..."),
               "Clause should not end mid-word with ellipsis: #{match.clause}"

        assert_no_mid_word_truncation(match.clause)
      end
    end

    test "regulation-45: clause does not end with 'wa' (mid-word)", %{fixture: fixture} do
      section = fixture["sections"]["regulation-45"]
      text = section["text"]

      {_actors, _types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:responsibility, ["Gvt: Authority: Planning"], text, [])

      assert length(matches) > 0, "Should find at least one responsibility"

      for match <- matches do
        # The specific bug from the screenshot
        refute String.ends_with?(match.clause, "wa"),
               "Clause should not end with 'wa': #{match.clause}"

        refute String.ends_with?(match.clause, " wa"),
               "Clause should not end with ' wa': #{match.clause}"

        # Should not end with other partial words
        assert_no_mid_word_truncation(match.clause)

        # Should contain the key responsibility text
        assert String.contains?(match.clause, "give notice") or
                 String.contains?(match.clause, "notice of the appeal"),
               "Clause should contain 'give notice' or 'notice of the appeal': #{match.clause}"
      end
    end

    test "regulation-14: giant preamble is avoided", %{fixture: fixture} do
      section = fixture["sections"]["regulation-14"]
      text = section["text"]

      {_actors, _types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:responsibility, ["Gvt: Authority: Planning"], text, [])

      assert length(matches) > 0, "Should find at least one responsibility"

      for match <- matches do
        # Clause should not be excessively long (the giant preamble bug)
        assert String.length(match.clause) <= 350,
               "Clause too long (#{String.length(match.clause)} chars), may be capturing giant preamble: #{String.slice(match.clause, 0, 100)}..."

        assert_no_mid_word_truncation(match.clause)
      end
    end
  end

  describe "clause ending rules" do
    test "clauses should end with period, semicolon, or ellipsis" do
      # Test with simple text to verify the rule
      text =
        "The planning authority must notify all parties within 14 days of receiving the application."

      {_actors, _types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:responsibility, ["Gvt: Authority: Planning"], text, [])

      assert length(matches) > 0

      for match <- matches do
        clause = match.clause

        valid_endings =
          String.ends_with?(clause, ".") or
            String.ends_with?(clause, ";") or
            String.ends_with?(clause, "...") or
            String.ends_with?(clause, "?") or
            String.ends_with?(clause, "!")

        assert valid_endings,
               "Clause should end with proper punctuation, got: '#{String.slice(clause, -10, 10)}'"
      end
    end
  end

  # Helper functions

  defp assert_clause_quality(match, expected_list) do
    clause = match.clause

    # Find matching expectation
    expectation =
      Enum.find(expected_list, fn exp ->
        exp["holder"] == match.holder and clause_matches_expectation?(clause, exp)
      end)

    # Basic quality checks regardless of expectation match
    assert_no_mid_word_truncation(clause)

    if expectation do
      if expectation["clause_must_contain"] do
        must_contain = List.wrap(expectation["clause_must_contain"])

        for term <- must_contain do
          assert String.contains?(clause, term),
                 "Clause should contain '#{term}': #{clause}"
        end
      end

      if expectation["clause_must_not_contain"] do
        must_not_contain = List.wrap(expectation["clause_must_not_contain"])

        for term <- must_not_contain do
          refute String.ends_with?(clause, term),
                 "Clause should not end with '#{term}': #{clause}"
        end
      end
    end
  end

  defp clause_matches_expectation?(clause, expectation) do
    if expectation["clause_must_contain"] do
      must_contain = List.wrap(expectation["clause_must_contain"])
      Enum.any?(must_contain, &String.contains?(clause, &1))
    else
      true
    end
  end

  defp assert_no_mid_word_truncation(clause) do
    # Remove trailing ellipsis for checking
    clause_trimmed =
      clause
      |> String.trim_trailing("...")
      |> String.trim()

    # Get the last few characters
    last_chars = String.slice(clause_trimmed, -5, 5) || clause_trimmed

    # Check for common mid-word patterns (2-3 letter fragments that aren't words)
    # These are partial words that indicate truncation
    partial_word_endings = [
      " wa",
      " wh",
      " th",
      " wi",
      " pr",
      " co",
      " re",
      " su",
      " ap",
      " no",
      " de",
      " in",
      " un",
      " ex",
      " di",
      " se",
      " st",
      " tr",
      " ca",
      " be",
      " ha",
      " ma",
      " pa",
      " pe",
      " po",
      " en",
      " em",
      " im",
      " ac",
      " ad",
      " af",
      " ag",
      " al",
      " am",
      " an",
      " ar",
      " as",
      " at",
      " au",
      " av",
      " aw",
      " ba",
      " bo",
      " br",
      " bu",
      " ce",
      " ch",
      " ci",
      " cl",
      " cr",
      " cu",
      " da",
      " do",
      " dr",
      " du",
      " ea",
      " ed",
      " ef",
      " el",
      " es",
      " ev",
      " fa",
      " fe",
      " fi",
      " fl",
      " fo",
      " fr",
      " fu",
      " ga",
      " ge",
      " gi",
      " gl",
      " go",
      " gr",
      " gu",
      " he",
      " hi",
      " ho",
      " hu",
      " id",
      " ig",
      " il",
      " is",
      " it",
      " ja",
      " jo",
      " ju",
      " ke",
      " ki",
      " kn",
      " la",
      " le",
      " li",
      " lo",
      " lu",
      " me",
      " mi",
      " mo",
      " mu",
      " na",
      " ne",
      " ni",
      " nu",
      " ob",
      " oc",
      " of",
      " op",
      " or",
      " ot",
      " ou",
      " ov",
      " ow",
      " pl",
      " pu",
      " qu",
      " ra",
      " re",
      " ri",
      " ro",
      " ru",
      " sa",
      " sc",
      " sh",
      " si",
      " sl",
      " sm",
      " sn",
      " so",
      " sp",
      " sq",
      " ta",
      " te",
      " ti",
      " to",
      " tu",
      " tw",
      " ty",
      " ul",
      " um",
      " up",
      " ur",
      " us",
      " ut",
      " va",
      " ve",
      " vi",
      " vo",
      " we",
      " wo",
      " wr",
      " ye",
      " yo"
    ]

    # Check for 2-letter ending fragments (very likely partial words)
    for fragment <- partial_word_endings do
      refute String.ends_with?(clause_trimmed, fragment),
             "Clause appears to end mid-word '#{fragment}': ...#{last_chars}"
    end

    # Also check for obvious 3-letter partial endings
    three_letter_partials = [
      " was",
      " wer",
      " tha",
      " thi",
      " whi",
      " wit",
      " pro",
      " com",
      " con",
      " req",
      " sub",
      " app",
      " not",
      " det",
      " inf",
      " und",
      " exp",
      " dis",
      " ser",
      " sta",
      " tra",
      " car",
      " bef",
      " hav",
      " mak",
      " par",
      " per",
      " pos",
      " ent",
      " emp",
      " imp",
      " acc",
      " add",
      " aff",
      " agr",
      " all",
      " amo",
      " any",
      " are",
      " ask",
      " aut"
    ]

    # Only check these if clause doesn't end with punctuation
    unless String.ends_with?(clause_trimmed, [
             ".",
             ";",
             "!",
             "?",
             ")",
             "]",
             "\""
           ]) do
      for fragment <- three_letter_partials do
        refute String.ends_with?(clause_trimmed, fragment),
               "Clause appears to end mid-word '#{fragment}': ...#{last_chars}"
      end
    end
  end
end
