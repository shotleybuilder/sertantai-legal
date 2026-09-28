defmodule SertantaiLegal.Scraper.ApplicationClauseTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ApplicationClause

  describe "parse/1" do
    test "whole-instrument application clauses (real wording)" do
      assert ApplicationClause.parse("(2) These Regulations apply in relation to England only.") ==
               {:apply, ["E"]}

      assert ApplicationClause.parse("This Order applies to Wales.") == {:apply, ["W"]}

      assert ApplicationClause.parse(
               "These Regulations extend to England and Wales but apply only in relation to Wales."
             ) == {:apply, ["W"]}

      assert ApplicationClause.parse("These Regulations shall apply to Great Britain;") ==
               {:apply, ["E", "W", "S"]}

      assert ApplicationClause.parse("These Rules apply only in England and Wales.") ==
               {:apply, ["E", "W"]}

      assert ApplicationClause.parse(
               "These Regulations extend to England and Wales and apply to England only."
             ) == {:apply, ["E"]}

      assert ApplicationClause.parse(
               "The title of these Regulations is the X (Wales) Regulations 2020, they apply in relation to Wales and come into force on 1 April."
             ) == {:apply, ["W"]}
    end

    test "'They apply …' counts when the provision names the instrument" do
      assert ApplicationClause.parse(
               "(1) These Regulations may be cited as the Environmental Damage (Prevention and Remediation) Regulations 2009. (2) They apply in England and the areas specified in regulation 6."
             ) == {:apply, ["E"]}

      assert ApplicationClause.parse("They apply in England.") == nil
    end

    test "exclusions" do
      assert ApplicationClause.parse("These Regulations do not apply to Scotland.") ==
               {:exclude, ["S"]}

      assert ApplicationClause.parse("This Act shall not apply in Northern Ireland.") ==
               {:exclude, ["NI"]}
    end

    test "partial, qualified or comparative clauses are not whole-instrument application" do
      assert ApplicationClause.parse("This regulation applies in England only.") == nil
      assert ApplicationClause.parse("Regulation 4 of these Regulations applies to Wales.") == nil
      assert ApplicationClause.parse("Part 2 of this Act applies in Scotland.") == nil

      assert ApplicationClause.parse(
               "These Regulations apply to Scotland subject to the modifications in Schedule 2."
             ) == nil

      assert ApplicationClause.parse(
               "These Regulations apply in relation to Wales as they apply in relation to England."
             ) == nil

      assert ApplicationClause.parse(
               "These Regulations apply to every harbour area in Great Britain"
             ) ==
               nil

      assert ApplicationClause.parse("These Regulations do not extend to Northern Ireland.") ==
               nil

      assert ApplicationClause.parse(
               "Subject to regulation 8, these Regulations do not apply in England."
             ) == nil

      assert ApplicationClause.parse(
               "Subject to paragraph (3), these Regulations apply in relation to Wales but do not apply in relation to excepted energy buildings in Wales."
             ) == nil

      assert ApplicationClause.parse(
               "are in conformity with these Regulations as they apply in Northern Ireland; and"
             ) == nil

      assert ApplicationClause.parse(
               "These Regulations apply to and in relation to the premises and activities outside Great Britain"
             ) == nil

      assert ApplicationClause.parse(
               "These Regulations shall not apply in relation to the activities of a worker which are covered by the Work Equipment Regulations."
             ) == nil

      assert ApplicationClause.parse(
               "These Regulations apply in relation to the compulsory purchase of land in England only."
             ) == nil

      assert ApplicationClause.parse(nil) == nil
    end
  end

  describe "resolve/2" do
    test "an application clause gives the regions; an exclusion is taken from the extent" do
      assert ApplicationClause.resolve([{:apply, ["E"]}], ["E", "W"]) == ["E"]
      assert ApplicationClause.resolve([{:exclude, ["S"]}], ["E", "W", "S"]) == ["E", "W"]
      assert ApplicationClause.resolve([{:exclude, ["S"]}], nil) == nil
      assert ApplicationClause.resolve([], ["E"]) == nil
    end

    test "conflicting application clauses give no verdict" do
      assert ApplicationClause.resolve([{:apply, ["E"]}, {:apply, ["W"]}], nil) == nil
      assert ApplicationClause.resolve([{:apply, ["E"]}, {:apply, ["E"]}], nil) == ["E"]
    end
  end
end
