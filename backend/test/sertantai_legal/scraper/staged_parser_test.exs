defmodule SertantaiLegal.Scraper.StagedParserTest do
  @moduledoc """
  Tests for StagedParser detailed field formatting.

  The *_count_per_law_detailed fields should include target, affect, and applied status:
  - amending_stats_affects_count_per_law_detailed (🔺 this law affects others)
  - amended_by_stats_affected_by_count_per_law_detailed (🔻 this law is affected by others)
  - rescinding_stats_rescinding_count_per_law_detailed (🔺 this law rescinds others)
  - rescinded_by_stats_rescinded_by_count_per_law_detailed (🔻 this law is rescinded by others)

  Expected format:
    UK_uksi_2020_100 - 3
      reg. 1 inserted [Not yet]
      reg. 2 substituted [Yes]
  """

  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.StagedParser

  describe "build_target_affect_applied/1" do
    test "builds full format with target, affect, and applied" do
      amendment = %{
        target: "reg. 5(1)",
        affect: "words substituted",
        applied?: "Yes"
      }

      result = StagedParser.test_build_target_affect_applied(amendment)

      assert result == "reg. 5(1) words substituted [Yes]"
    end

    test "handles Not yet status" do
      amendment = %{
        target: "s. 15(1)",
        affect: "amended",
        applied?: "Not yet"
      }

      result = StagedParser.test_build_target_affect_applied(amendment)

      assert result == "s. 15(1) amended [Not yet]"
    end

    test "handles empty applied status" do
      amendment = %{
        target: "reg. 12(3)",
        affect: "inserted",
        applied?: ""
      }

      result = StagedParser.test_build_target_affect_applied(amendment)

      assert result == "reg. 12(3) inserted []"
    end

    test "handles nil target with affect" do
      amendment = %{
        target: nil,
        affect: "revoked",
        applied?: "Yes"
      }

      result = StagedParser.test_build_target_affect_applied(amendment)

      assert result == "revoked [Yes]"
    end

    test "handles empty target with affect" do
      amendment = %{
        target: "",
        affect: "repealed in part",
        applied?: "Not yet"
      }

      result = StagedParser.test_build_target_affect_applied(amendment)

      assert result == "repealed in part [Not yet]"
    end

    test "handles target only (no affect)" do
      amendment = %{
        target: "reg. 2(1)",
        affect: "",
        applied?: ""
      }

      result = StagedParser.test_build_target_affect_applied(amendment)

      assert result == "reg. 2(1)"
    end

    test "returns nil when both target and affect are empty" do
      amendment = %{
        target: "",
        affect: "",
        applied?: "Yes"
      }

      result = StagedParser.test_build_target_affect_applied(amendment)

      assert result == nil
    end

    test "returns nil for nil amendment" do
      result = StagedParser.test_build_target_affect_applied(nil)

      assert result == nil
    end

    test "handles map without applied? key" do
      amendment = %{target: "s. 1"}

      result = StagedParser.test_build_target_affect_applied(amendment)

      # Falls back to target-only clause
      assert result == "s. 1"
    end
  end

  # Tests for build_count_per_law_detailed/1 removed - legacy function replaced by JSONB

  describe "live status resolution (changes-primary, metadata-override)" do
    # Live status codes
    @live_in_force StagedParser.live_in_force()
    @live_part_revoked StagedParser.live_part_revoked()
    @live_revoked StagedParser.live_revoked()

    test "metadata says revoked → revoked (regardless of changes)" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_2015_200",
        live: @live_revoked,
        live_from_changes: @live_in_force
      }

      result = StagedParser.test_resolve_live_status(law)
      assert result.live == @live_revoked
    end

    test "metadata says in_force, changes says revoked → revoked" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_2016_300",
        live: @live_in_force,
        live_from_changes: @live_revoked
      }

      result = StagedParser.test_resolve_live_status(law)
      assert result.live == @live_revoked
      assert result.live_from_changes == @live_revoked
    end

    test "metadata says in_force, changes says partial → partial" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_2018_400",
        live: @live_in_force,
        live_from_changes: @live_part_revoked
      }

      result = StagedParser.test_resolve_live_status(law)
      assert result.live == @live_part_revoked
    end

    test "both say in_force → in_force" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_2024_100",
        live: @live_in_force,
        live_from_changes: @live_in_force
      }

      result = StagedParser.test_resolve_live_status(law)
      assert result.live == @live_in_force
      assert result.live_from_changes == @live_in_force
    end

    test "no changes data (nil) → uses metadata" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_2023_900",
        live: @live_revoked,
        live_from_changes: nil
      }

      result = StagedParser.test_resolve_live_status(law)
      assert result.live == @live_revoked
      # nil live_from_changes defaults to in_force internally
      assert result.live_from_changes == @live_in_force
    end

    test "both nil → defaults to in_force" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_2023_901",
        live: nil,
        live_from_changes: nil
      }

      result = StagedParser.test_resolve_live_status(law)
      assert result.live == @live_in_force
      assert result.live_from_changes == @live_in_force
    end
  end

  describe "on_progress callback" do
    test "notify_progress calls callback with event" do
      # Test that the notify_progress helper works correctly
      ref = make_ref()
      test_pid = self()

      callback = fn event -> send(test_pid, {ref, event}) end

      # Call the test helper that exposes notify_progress
      StagedParser.test_notify_progress(callback, {:stage_start, :metadata, 1, 6})

      assert_receive {^ref, {:stage_start, :metadata, 1, 6}}
    end

    test "notify_progress does nothing with nil callback" do
      # Should not crash when callback is nil
      assert :ok == StagedParser.test_notify_progress(nil, {:stage_start, :metadata, 1, 6})
    end

    test "build_stage_summary returns summary for metadata stage" do
      stage_result = %{status: :ok, data: %{si_code: ["code1", "code2"], md_subjects: ["subj1"]}}
      summary = StagedParser.test_build_stage_summary(:metadata, stage_result)
      assert summary == "2 SI codes, 1 subjects"
    end

    test "build_stage_summary returns summary for extent stage" do
      stage_result = %{status: :ok, data: %{extent: "UK"}}
      summary = StagedParser.test_build_stage_summary(:extent, stage_result)
      assert summary == "UK"
    end

    test "build_stage_summary returns summary for enacted_by stage" do
      stage_result = %{status: :ok, data: %{enacted_by: [%{name: "law1"}, %{name: "law2"}]}}
      summary = StagedParser.test_build_stage_summary(:enacted_by, stage_result)
      assert summary == "2 parent law(s)"
    end

    test "build_stage_summary returns summary for amending stage" do
      stage_result = %{
        status: :ok,
        data: %{
          amending_count: 3,
          rescinding_count: 1,
          stats_self_affects_count: 5
        }
      }

      summary = StagedParser.test_build_stage_summary(:amending, stage_result)
      assert summary == "Amends: 3, Rescinds: 1 (self: 5)"
    end

    test "build_stage_summary returns summary for amended_by stage" do
      stage_result = %{
        status: :ok,
        data: %{
          amended_by_count: 2,
          rescinded_by_count: 1
        }
      }

      summary = StagedParser.test_build_stage_summary(:amended_by, stage_result)
      assert summary == "Amended by: 2, Rescinded by: 1"
    end

    test "build_stage_summary returns summary for taxa stage" do
      stage_result = %{
        status: :ok,
        data: %{role: ["actor1", "actor2"], duty_type: ["type1"], popimar: ["p1", "p2", "p3"]}
      }

      summary = StagedParser.test_build_stage_summary(:taxa, stage_result)
      assert summary == "2 actors, 1 duty types, 3 POPIMAR"
    end

    test "build_stage_summary returns error message for failed stage" do
      stage_result = %{status: :error, data: nil, error: "HTTP 404: Not found"}
      summary = StagedParser.test_build_stage_summary(:metadata, stage_result)
      assert summary == "HTTP 404: Not found"
    end

    test "build_stage_summary returns nil for unknown status" do
      stage_result = %{status: :unknown, data: nil}
      summary = StagedParser.test_build_stage_summary(:metadata, stage_result)
      assert summary == nil
    end

    test "stages/0 returns all 6 stages in order" do
      stages = StagedParser.stages()

      assert stages == [
               :metadata,
               :extent,
               :enacted_by,
               :amending,
               :amended_by,
               :explanatory_note
             ]
    end
  end

  describe "assign_family_from_si_codes (Issue #84)" do
    test "assigns family from known SI code when family is nil" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_1975_1584",
        title_en: "Health and Safety (First-Aid) Regulations",
        si_code: ["HEALTH AND SAFETY"],
        family: nil
      }

      result = StagedParser.test_assign_family_from_si_codes(law)
      assert result.family == "💙 OH&S: Occupational / Personal Safety"
    end

    test "assigns family from ROAD TRAFFIC SI code" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_1988_370",
        title_en: "Road Traffic (Driving Licences) Regulations",
        si_code: ["ROAD TRAFFIC"],
        family: nil
      }

      result = StagedParser.test_assign_family_from_si_codes(law)
      assert result.family == "💙 TRANSPORT: Road Safety"
    end

    test "does not override existing family" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_2020_100",
        title_en: "Test Regulations",
        si_code: ["HEALTH AND SAFETY"],
        family: "💚 ENVIRONMENTAL PROTECTION"
      }

      result = StagedParser.test_assign_family_from_si_codes(law)
      assert result.family == "💚 ENVIRONMENTAL PROTECTION"
    end

    test "does not override non-empty family string" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_2020_101",
        title_en: "Test Regulations",
        si_code: ["ENVIRONMENT"],
        family: "💙 FIRE"
      }

      result = StagedParser.test_assign_family_from_si_codes(law)
      assert result.family == "💙 FIRE"
    end

    test "returns law unchanged when si_code is empty list" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_2020_102",
        title_en: "Test Regulations",
        si_code: [],
        family: nil
      }

      result = StagedParser.test_assign_family_from_si_codes(law)
      assert result.family == nil
    end

    test "returns law unchanged when SI code has no mapping" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_2020_103",
        title_en: "Test Regulations",
        si_code: ["COMPLETELY UNKNOWN CODE"],
        family: nil
      }

      result = StagedParser.test_assign_family_from_si_codes(law)
      assert result.family == nil
    end

    test "handles nil si_code gracefully" do
      law = %SertantaiLegal.Scraper.ParsedLaw{
        name: "UK_uksi_2020_104",
        title_en: "Test Regulations",
        si_code: nil,
        family: nil
      }

      result = StagedParser.test_assign_family_from_si_codes(law)
      assert result.family == nil
    end
  end

  describe "cancellation support" do
    # These tests verify the abort/cancellation callback behavior.
    # Tests that abort at stage_start avoid HTTP calls entirely.

    test "callback returning :abort at stage_start halts parsing immediately" do
      # Track which stages were started
      test_pid = self()
      ref = make_ref()

      # Callback that aborts at first stage_start (before any HTTP call)
      callback = fn event ->
        send(test_pid, {ref, event})

        case event do
          {:stage_start, :metadata, _, _} -> :abort
          _ -> :ok
        end
      end

      record = %{type_code: "uksi", Year: 2025, Number: "99999"}

      {:ok, result} =
        StagedParser.parse(record, on_progress: callback, stages: [:metadata, :extent])

      # Should have received stage_start for metadata
      assert_receive {^ref, {:stage_start, :metadata, 1, 2}}

      # Should NOT have received stage_start for extent (aborted before)
      refute_receive {^ref, {:stage_start, :extent, _, _}}, 100

      # Result should be marked as cancelled
      assert result.cancelled == true

      # Metadata should be skipped (aborted before it ran)
      assert result.stages[:metadata].status == :skipped
      assert result.stages[:metadata].error == "Cancelled by client"

      # Extent should also be skipped
      assert result.stages[:extent].status == :skipped
      assert result.stages[:extent].error == "Cancelled by client"
    end

    test "parse_complete event not sent when cancelled" do
      test_pid = self()
      ref = make_ref()

      callback = fn event ->
        send(test_pid, {ref, event})

        case event do
          {:stage_start, :metadata, _, _} -> :abort
          _ -> :ok
        end
      end

      record = %{type_code: "uksi", Year: 2025, Number: "99999"}

      {:ok, _result} = StagedParser.parse(record, on_progress: callback, stages: [:metadata])

      # Should NOT receive parse_complete event when cancelled
      refute_receive {^ref, {:parse_complete, _}}, 100
    end

    test "cancelled result has cancelled flag set to true" do
      callback = fn event ->
        case event do
          {:stage_start, _, _, _} -> :abort
          _ -> :ok
        end
      end

      record = %{type_code: "uksi", Year: 2025, Number: "99999"}

      {:ok, result} = StagedParser.parse(record, on_progress: callback, stages: [:metadata])

      assert result.cancelled == true
    end

    test "all remaining stages marked as cancelled when abort occurs" do
      test_pid = self()
      ref = make_ref()

      callback = fn event ->
        send(test_pid, {ref, event})

        case event do
          {:stage_start, :metadata, _, _} -> :abort
          _ -> :ok
        end
      end

      record = %{type_code: "uksi", Year: 2025, Number: "99999"}

      {:ok, result} =
        StagedParser.parse(record,
          on_progress: callback,
          stages: [:metadata, :extent, :enacted_by, :amending]
        )

      # All stages should be skipped with "Cancelled by client"
      assert result.stages[:metadata].status == :skipped
      assert result.stages[:metadata].error == "Cancelled by client"

      assert result.stages[:extent].status == :skipped
      assert result.stages[:extent].error == "Cancelled by client"

      assert result.stages[:enacted_by].status == :skipped
      assert result.stages[:enacted_by].error == "Cancelled by client"

      assert result.stages[:amending].status == :skipped
      assert result.stages[:amending].error == "Cancelled by client"
    end

    test "notify_progress returns callback result for abort detection" do
      # Verify the notify_progress helper returns the callback result
      abort_callback = fn _event -> :abort end
      ok_callback = fn _event -> :ok end

      assert StagedParser.test_notify_progress(abort_callback, {:stage_start, :metadata, 1, 7}) ==
               :abort

      assert StagedParser.test_notify_progress(ok_callback, {:stage_start, :metadata, 1, 7}) ==
               :ok

      assert StagedParser.test_notify_progress(nil, {:stage_start, :metadata, 1, 7}) == :ok
    end
  end
end
