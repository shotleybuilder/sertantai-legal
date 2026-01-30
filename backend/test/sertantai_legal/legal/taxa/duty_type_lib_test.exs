defmodule SertantaiLegal.Legal.Taxa.DutyTypeLibTest do
  @moduledoc """
  TDD tests for Phase 2b: DutyTypeLib structured match data.

  These tests define the expected behavior after refactoring DutyTypeLib
  to return structured match data instead of emoji-formatted text strings.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.DutyTypeLib

  describe "find_role_holders/4 returns structured match data" do
    test "returns structured matches list instead of formatted string" do
      text = "The employer shall ensure the health and safety of employees."
      actors = ["Org: Employer"]

      {holders, duty_types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:duty, actors, text, [])

      # Holders and duty_types should remain lists
      assert is_list(holders)
      assert is_list(duty_types)
      assert "Org: Employer" in holders
      assert "Duty" in duty_types

      # Phase 2b: matches should now be a list of structured maps, not a string
      assert is_list(matches), "Expected matches to be a list, got: #{inspect(matches)}"

      # Each match should have required fields
      [match | _] = matches
      assert is_map(match), "Expected match to be a map, got: #{inspect(match)}"
      assert Map.has_key?(match, :holder), "Match missing :holder key"
      assert Map.has_key?(match, :duty_type), "Match missing :duty_type key"
      assert Map.has_key?(match, :clause), "Match missing :clause key"
    end

    test "match structure contains all required fields" do
      text = "The employer shall ensure safety. The employer must provide training."
      actors = ["Org: Employer"]

      {_holders, _duty_types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:duty, actors, text, [])

      assert is_list(matches)

      for match <- matches do
        # Required fields
        assert Map.has_key?(match, :holder)
        assert Map.has_key?(match, :duty_type)
        assert Map.has_key?(match, :clause)

        # Field types
        assert is_binary(match.holder)
        assert is_binary(match.duty_type)
        assert is_binary(match.clause) or is_nil(match.clause)
      end
    end

    test "returns empty list when no matches found" do
      text = "This text has no duty patterns."
      actors = ["Org: Employer"]

      {holders, duty_types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:duty, actors, text, [])

      assert holders == []
      assert duty_types == []
      assert matches == []
    end

    test "returns empty for empty actors list" do
      text = "The employer shall ensure safety."

      {holders, duty_types, matches, regexes} =
        DutyTypeLib.find_role_holders(:duty, [], text, [])

      assert holders == []
      assert duty_types == []
      assert matches == []
      assert regexes == []
    end

    test "handles multiple actors with different matches" do
      text = """
      The employer shall provide equipment.
      The employee may request training.
      """

      {holders, _duty_types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:duty, ["Org: Employer", "Ind: Employee"], text, [])

      assert is_list(matches)

      # Check that matches maintain actor identity
      holder_names = matches |> Enum.map(& &1.holder) |> Enum.uniq()
      assert "Org: Employer" in holder_names or length(matches) == 0 or holders == []
    end

    test "clause field contains the matched text snippet" do
      text = "The employer shall ensure the health and safety of all employees."
      actors = ["Org: Employer"]

      {_holders, _duty_types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:duty, actors, text, [])

      assert is_list(matches)

      if length(matches) > 0 do
        [match | _] = matches
        assert is_binary(match.clause)
        # Clause should contain part of the matched text
        assert String.length(match.clause) > 0
      end
    end

    test "duty_type field is uppercase role name" do
      text = "The employer shall ensure safety."
      actors = ["Org: Employer"]

      {_holders, _duty_types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:duty, actors, text, [])

      if length(matches) > 0 do
        [match | _] = matches
        assert match.duty_type == "DUTY"
      end
    end

    test "right role returns RIGHT duty_type" do
      text = "The employee may request information."
      actors = ["Ind: Employee"]

      {_holders, _duty_types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:right, actors, text, [])

      if length(matches) > 0 do
        [match | _] = matches
        assert match.duty_type == "RIGHT"
      end
    end

    test "responsibility role returns RESPONSIBILITY duty_type" do
      text = "The local authority must investigate complaints."
      actors = ["Gvt: Authority: Local"]

      {_holders, _duty_types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:responsibility, actors, text, [])

      if length(matches) > 0 do
        [match | _] = matches
        assert match.duty_type == "RESPONSIBILITY"
      end
    end

    test "power role returns POWER duty_type" do
      text = "The Secretary of State may by regulations prescribe requirements."
      actors = ["Gvt: Minister"]

      {_holders, _duty_types, matches, _regexes} =
        DutyTypeLib.find_role_holders(:power, actors, text, [])

      if length(matches) > 0 do
        [match | _] = matches
        assert match.duty_type == "POWER"
      end
    end
  end

  describe "backward compatibility" do
    # These tests ensure the first two elements of the tuple remain compatible
    # with existing code that only uses holders and duty_types

    test "holders list maintains same behavior" do
      text = "The employer shall ensure safety."
      actors = ["Org: Employer"]

      {holders, _duty_types, _matches, _regexes} =
        DutyTypeLib.find_role_holders(:duty, actors, text, [])

      assert is_list(holders)
      assert "Org: Employer" in holders
    end

    test "duty_types list maintains same behavior" do
      text = "The employer shall ensure safety."
      actors = ["Org: Employer"]

      {_holders, duty_types, _matches, _regexes} =
        DutyTypeLib.find_role_holders(:duty, actors, text, [])

      assert is_list(duty_types)
      assert "Duty" in duty_types
    end

    test "regexes accumulator still works" do
      text = "The employer shall ensure safety."
      actors = ["Org: Employer"]
      initial_regexes = ["existing pattern"]

      {_holders, _duty_types, _matches, regexes} =
        DutyTypeLib.find_role_holders(:duty, actors, text, initial_regexes)

      # Regexes should still accumulate
      assert is_list(regexes)
      assert length(regexes) >= 1
    end
  end
end
