defmodule SertantaiLegal.Legal.Taxa.ResponsibilityPatternComparisonTest do
  @moduledoc """
  Comparison tests for V1 vs V2 responsibility patterns.

  Uses UK_ssi_2015_181 as the case study to compare:
  - V1: Original patterns (unbounded pre-modal capture)
  - V2: Improved patterns (limited pre-modal, capture groups for action)

  Run with: mix test test/sertantai_legal/legal/taxa/responsibility_pattern_comparison_test.exs
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.{
    DutyTypeDefnGovernment,
    DutyTypeDefnGovernmentV2,
    ActorLib
  }

  # Sample text from UK_ssi_2015_181 regulation-14 that causes the giant preamble issue
  @regulation_14_text """
  Subject to paragraph (2), a planning authority must consult the following bodies
  before determining an application— the safety regulator; the Police Service of Scotland;
  Scottish Natural Heritage; a community council established in accordance with the
  provisions of Part IV of the Local Government (Scotland) Act 1973, any part of whose
  area is within or adjoins the land to which the application relates; the Scottish Fire
  and Rescue Service; the Scottish Environment Protection Agency; a person to whom a
  licence has been granted under section 7(2) of the Gas Act 1986 (licence to convey gas
  through pipes) whose apparatus is situated on, over or under the land to which the
  application relates or on, over or under adjoining land; a person to whom a licence
  has been granted under section 6(1)(b) or (c) of the Electricity Act 1989 (transmission
  and distribution licences) whose apparatus is situated on, over or under the land to
  which the application relates or on, under or over adjoining land; where the land to
  which the application relates, or any part of that land, is within 2 kilometres of a
  royal palace, park or residence, the Scottish Ministers; where the land to which the
  application relates, or any part of that land, is within 2 kilometres of the area of
  any other planning authority or a hazardous substances authority within the meaning
  of section 39(1) of the Planning (Hazardous Substances) Act 1990, that authority;
  where the land to which the application relates, or any part of that land, is land
  in an area of coal working or former or proposed coal working notified to the planning
  authority by the British Coal Corporation or the Coal Authority, the Coal Authority;
  where the land to which the application relates, or any part of that land, is land
  which is used for disposal or storage of controlled waste, the relevant waste disposal
  authority (where that authority is not also the planning authority); where it appears
  to the planning authority that the development is likely to affect land in the area
  of the Cairngorms National Park Authority, that Authority; and where it appears to
  the planning authority that the development is likely to affect land in the area of
  the Loch Lomond and Trossachs National Park, any local authority who would have been
  responsible for exercising the functions of a planning authority under the principal
  Act in relation to the application were it not for article 7 of the Loch Lomond and
  The Trossachs National Park Designation, Transitional and Consequential Provisions
  (Scotland) Order 2002. The planning authority need not consult a body or person
  referred to in paragraph (1) if that body or person has notified the planning authority
  in writing that it does not wish to be consulted, but this paragraph does not apply
  in respect of the safety regulator, Scottish Natural Heritage or the Scottish
  Environment Protection Agency. The planning authority must give notice of the application
  to every person who is an owner or occupier of any land.
  """

  @regulation_16_text """
  Where a planning authority proposes to grant planning permission for a hazardous
  substances development and the safety regulator or the Scottish Environment Protection
  Agency has advised against that or has recommended that conditions be imposed on the
  grant which the authority does not propose to impose, the authority must notify the
  Scottish Ministers, in writing, of the application and provide them with a copy of
  the application and any information, plans and other documents contained in or
  accompanying it. The planning authority must not determine the application until
  the period of 21 days has elapsed.
  """

  # Note: Actor patterns require:
  # 1. Specific phrasing like "The authority" or "the regulator" (not "planning authority")
  # 2. Leading whitespace/punctuation boundary (patterns have [[:blank:][:punct:]] prefix)
  @simple_text "In this case, the authority must consult the relevant bodies before determining the application."

  describe "pattern comparison" do
    test "compares V1 vs V2 on regulation-14 text" do
      # Get actor regex for "authority"
      actors_regex = ActorLib.custom_actor_library(["Gvt: Authority"], :government)
      {_actor, actor_pattern} = List.first(actors_regex)

      v1_patterns = DutyTypeDefnGovernment.responsibility(actor_pattern)
      v2_patterns = DutyTypeDefnGovernmentV2.responsibility(actor_pattern)

      v1_matches = run_patterns(v1_patterns, @regulation_14_text)
      v2_matches = run_patterns(v2_patterns, @regulation_14_text)

      # Log for comparison
      IO.puts("\n=== REGULATION-14 COMPARISON ===")
      IO.puts("\nV1 matches (#{length(v1_matches)}):")

      Enum.each(v1_matches, fn match ->
        IO.puts("  [#{String.length(match)} chars] #{truncate(match, 100)}")
      end)

      IO.puts("\nV2 matches (#{length(v2_matches)}):")

      Enum.each(v2_matches, fn match ->
        IO.puts("  [#{String.length(match)} chars] #{truncate(match, 100)}")
      end)

      # V2 should produce shorter, more focused matches
      if length(v1_matches) > 0 and length(v2_matches) > 0 do
        v1_avg_length = Enum.sum(Enum.map(v1_matches, &String.length/1)) / length(v1_matches)
        v2_avg_length = Enum.sum(Enum.map(v2_matches, &String.length/1)) / length(v2_matches)

        IO.puts("\nV1 average match length: #{round(v1_avg_length)} chars")
        IO.puts("V2 average match length: #{round(v2_avg_length)} chars")

        # V2 should have shorter matches (less preamble)
        assert v2_avg_length < v1_avg_length,
               "V2 should produce shorter matches than V1"
      end

      # Both should find matches
      assert length(v1_matches) > 0, "V1 should find matches"
      assert length(v2_matches) > 0, "V2 should find matches"
    end

    test "compares V1 vs V2 on regulation-16 text" do
      actors_regex = ActorLib.custom_actor_library(["Gvt: Authority"], :government)
      {_actor, actor_pattern} = List.first(actors_regex)

      v1_patterns = DutyTypeDefnGovernment.responsibility(actor_pattern)
      v2_patterns = DutyTypeDefnGovernmentV2.responsibility(actor_pattern)

      v1_matches = run_patterns(v1_patterns, @regulation_16_text)
      v2_matches = run_patterns(v2_patterns, @regulation_16_text)

      IO.puts("\n=== REGULATION-16 COMPARISON ===")
      IO.puts("\nV1 matches (#{length(v1_matches)}):")

      Enum.each(v1_matches, fn match ->
        IO.puts("  [#{String.length(match)} chars] #{truncate(match, 100)}")
      end)

      IO.puts("\nV2 matches (#{length(v2_matches)}):")

      Enum.each(v2_matches, fn match ->
        IO.puts("  [#{String.length(match)} chars] #{truncate(match, 100)}")
      end)

      assert length(v1_matches) > 0, "V1 should find matches"
      assert length(v2_matches) > 0, "V2 should find matches"
    end

    test "compares V1 vs V2 on simple text" do
      actors_regex = ActorLib.custom_actor_library(["Gvt: Authority"], :government)
      {_actor, actor_pattern} = List.first(actors_regex)

      v1_patterns = DutyTypeDefnGovernment.responsibility(actor_pattern)
      v2_patterns = DutyTypeDefnGovernmentV2.responsibility(actor_pattern)

      v1_matches = run_patterns(v1_patterns, @simple_text)
      v2_matches = run_patterns(v2_patterns, @simple_text)

      IO.puts("\n=== SIMPLE TEXT COMPARISON ===")
      IO.puts("\nV1 matches: #{inspect(v1_matches)}")
      IO.puts("V2 matches: #{inspect(v2_matches)}")

      # Both should work on simple text
      assert length(v1_matches) > 0, "V1 should find matches in simple text"
      assert length(v2_matches) > 0, "V2 should find matches in simple text"

      # V2 should capture the action
      v2_match = List.first(v2_matches)

      assert String.contains?(v2_match, "consult"),
             "V2 should capture the action 'consult'"
    end

    test "V2 captures action after modal" do
      actors_regex = ActorLib.custom_actor_library(["Gvt: Authority"], :government)
      {_actor, actor_pattern} = List.first(actors_regex)

      v2_patterns = DutyTypeDefnGovernmentV2.responsibility(actor_pattern)

      # Use text that matches actor pattern (needs leading boundary + "the authority")
      text = "In this case, the authority must notify all interested parties within 14 days."
      v2_matches = run_patterns(v2_patterns, text)

      IO.puts("\n=== ACTION CAPTURE TEST ===")
      IO.puts("Text: #{text}")
      IO.puts("V2 matches: #{inspect(v2_matches)}")

      assert length(v2_matches) > 0
      match = List.first(v2_matches)

      # Should contain the action, not just end at "must"
      assert String.contains?(match, "notify"),
             "V2 should capture 'notify' in the match"
    end
  end

  describe "Ministers patterns" do
    test "compares V1 vs V2 for Ministers" do
      actors_regex = ActorLib.custom_actor_library(["Gvt: Minister"], :government)
      {_actor, actor_pattern} = List.first(actors_regex)

      v1_patterns = DutyTypeDefnGovernment.responsibility(actor_pattern)
      v2_patterns = DutyTypeDefnGovernmentV2.responsibility(actor_pattern)

      text = "The Scottish Ministers must make regulations to prescribe the form of application."

      v1_matches = run_patterns(v1_patterns, text)
      v2_matches = run_patterns(v2_patterns, text)

      IO.puts("\n=== MINISTERS COMPARISON ===")
      IO.puts("Text: #{text}")
      IO.puts("V1 matches: #{inspect(v1_matches)}")
      IO.puts("V2 matches: #{inspect(v2_matches)}")

      assert length(v2_matches) > 0
      v2_match = List.first(v2_matches)

      assert String.contains?(v2_match, "make regulations"),
             "V2 should capture 'make regulations'"
    end
  end

  # Helper to run patterns against text and collect matches
  defp run_patterns(patterns, text) do
    patterns
    |> Enum.flat_map(fn pattern ->
      pattern_str =
        case pattern do
          {p, _remove?} -> p
          p -> p
        end

      case Regex.compile(pattern_str, "m") do
        {:ok, regex} ->
          case Regex.run(regex, text) do
            nil ->
              []

            [match | captures] ->
              # If there are capture groups, prefer them
              if captures != [] do
                captures
              else
                [match]
              end
          end

        {:error, _} ->
          []
      end
    end)
    |> Enum.uniq()
  end

  defp truncate(str, max_len) do
    if String.length(str) > max_len do
      String.slice(str, 0, max_len) <> "..."
    else
      str
    end
  end
end
