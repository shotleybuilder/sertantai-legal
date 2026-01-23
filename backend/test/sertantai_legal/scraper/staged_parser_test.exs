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

  describe "build_count_per_law_detailed/1" do
    test "returns nil for empty list" do
      result = StagedParser.test_build_count_per_law_detailed([])

      assert result == nil
    end

    test "builds detailed format with single law and single amendment" do
      amendments = [
        %{
          name: "UK_uksi_2016_1154",
          target: "reg. 5(1)",
          affect: "words substituted",
          applied?: "Yes"
        }
      ]

      result = StagedParser.test_build_count_per_law_detailed(amendments)

      assert result == """
             UK_uksi_2016_1154 - 1
              reg. 5(1) words substituted [Yes]\
             """
    end

    test "groups multiple amendments to same law" do
      amendments = [
        %{
          name: "UK_uksi_2016_1154",
          target: "reg. 5(1)",
          affect: "words substituted",
          applied?: "Yes"
        },
        %{
          name: "UK_uksi_2016_1154",
          target: "reg. 12(3)",
          affect: "inserted",
          applied?: "Yes"
        }
      ]

      result = StagedParser.test_build_count_per_law_detailed(amendments)

      # Should show count of 2 and both detail lines
      assert result =~ "UK_uksi_2016_1154 - 2"
      assert result =~ "reg. 5(1) words substituted [Yes]"
      assert result =~ "reg. 12(3) inserted [Yes]"
    end

    test "separates multiple laws with newlines" do
      amendments = [
        %{
          name: "UK_uksi_2016_1154",
          target: "reg. 5(1)",
          affect: "words substituted",
          applied?: "Yes"
        },
        %{
          name: "UK_ukpga_1974_37",
          target: "s. 15(1)",
          affect: "amended",
          applied?: "Not yet"
        }
      ]

      result = StagedParser.test_build_count_per_law_detailed(amendments)

      # Should have two law sections
      assert result =~ "UK_uksi_2016_1154 - 1"
      assert result =~ "UK_ukpga_1974_37 - 1"
      assert result =~ "reg. 5(1) words substituted [Yes]"
      assert result =~ "s. 15(1) amended [Not yet]"
    end

    test "sorts laws by amendment count descending" do
      amendments = [
        %{name: "UK_uksi_2016_1154", target: "reg. 1", affect: "amended", applied?: "Yes"},
        %{name: "UK_ukpga_1974_37", target: "s. 1", affect: "amended", applied?: "Yes"},
        %{name: "UK_ukpga_1974_37", target: "s. 2", affect: "amended", applied?: "Yes"},
        %{name: "UK_ukpga_1974_37", target: "s. 3", affect: "amended", applied?: "Yes"}
      ]

      result = StagedParser.test_build_count_per_law_detailed(amendments)

      # HSWA (3 amendments) should come before EPR (1 amendment)
      lines = String.split(result, "\n")
      first_law_line = Enum.at(lines, 0)

      assert first_law_line =~ "UK_ukpga_1974_37 - 3"
    end

    test "deduplicates identical detail entries" do
      amendments = [
        %{name: "UK_uksi_2016_1154", target: "reg. 5(1)", affect: "amended", applied?: "Yes"},
        %{name: "UK_uksi_2016_1154", target: "reg. 5(1)", affect: "amended", applied?: "Yes"}
      ]

      result = StagedParser.test_build_count_per_law_detailed(amendments)

      # Count should be 2, but only one unique detail line
      assert result =~ "UK_uksi_2016_1154 - 2"

      detail_count =
        result
        |> String.split("\n")
        |> Enum.count(&(&1 =~ "reg. 5(1) amended"))

      assert detail_count == 1
    end

    test "handles revocation amendments" do
      amendments = [
        %{
          name: "UK_uksi_2010_500",
          target: "whole instrument",
          affect: "revoked",
          applied?: "Yes"
        }
      ]

      result = StagedParser.test_build_count_per_law_detailed(amendments)

      assert result =~ "UK_uksi_2010_500 - 1"
      assert result =~ "whole instrument revoked [Yes]"
    end

    test "handles repealed in part" do
      amendments = [
        %{
          name: "UK_ukpga_2005_10",
          target: "s. 1",
          affect: "repealed in part",
          applied?: "Not yet"
        }
      ]

      result = StagedParser.test_build_count_per_law_detailed(amendments)

      assert result =~ "UK_ukpga_2005_10 - 1"
      assert result =~ "s. 1 repealed in part [Not yet]"
    end

    test "falls back to count-only when all targets are empty" do
      amendments = [
        %{name: "UK_uksi_2016_1154", target: "", affect: "", applied?: ""},
        %{name: "UK_uksi_2016_1154", target: nil, affect: nil, applied?: nil}
      ]

      result = StagedParser.test_build_count_per_law_detailed(amendments)

      # Should just show count line without details
      assert result == "UK_uksi_2016_1154 - 2"
    end
  end

  describe "detailed field format integration" do
    # These tests verify the detailed fields work correctly when amendments
    # are parsed from the Amending module.

    test "amending_stats_affects_count_per_law_detailed format" do
      # Simulates amendments this law makes to other laws
      amendments = [
        %{
          name: "UK_uksi_2016_1154",
          title_en: "The Environmental Permitting Regulations 2016",
          path: "/id/uksi/2016/1154",
          target: "reg. 5(1)",
          affect: "words substituted",
          applied?: "Yes"
        },
        %{
          name: "UK_uksi_2016_1154",
          title_en: "The Environmental Permitting Regulations 2016",
          path: "/id/uksi/2016/1154",
          target: "reg. 12(3)",
          affect: "inserted",
          applied?: "Yes"
        },
        %{
          name: "UK_ukpga_1974_37",
          title_en: "Health and Safety at Work etc. Act 1974",
          path: "/id/ukpga/1974/37",
          target: "s. 15(1)",
          affect: "amended",
          applied?: "Not yet"
        }
      ]

      result = StagedParser.test_build_count_per_law_detailed(amendments)

      # Verify format matches expected detailed output:
      # "2 - The Environmental Permitting Regulations 2016\nhttps://legislation.gov.uk/id/uksi/2016/1154"
      assert result =~ "2 - The Environmental Permitting Regulations 2016"
      assert result =~ "https://legislation.gov.uk/id/uksi/2016/1154"
      assert result =~ " reg. 5(1) words substituted [Yes]"
      assert result =~ " reg. 12(3) inserted [Yes]"
      assert result =~ "1 - Health and Safety at Work etc. Act 1974"
      assert result =~ "https://legislation.gov.uk/id/ukpga/1974/37"
      assert result =~ " s. 15(1) amended [Not yet]"
    end

    test "amended_by_stats_affected_by_count_per_law_detailed format" do
      # Simulates amendments made TO this law BY other laws
      amendments = [
        %{
          name: "UK_uksi_2024_100",
          title_en: "The Example Amendment Regulations 2024",
          path: "/id/uksi/2024/100",
          target: "reg. 2(1)",
          affect: "words substituted",
          applied?: "Yes"
        },
        %{
          name: "UK_uksi_2023_50",
          title_en: "The Earlier Amendment Regulations 2023",
          path: "/id/uksi/2023/50",
          target: "reg. 3",
          affect: "inserted",
          applied?: "Not yet"
        }
      ]

      result = StagedParser.test_build_count_per_law_detailed(amendments)

      assert result =~ "1 - The Example Amendment Regulations 2024"
      assert result =~ "https://legislation.gov.uk/id/uksi/2024/100"
      assert result =~ " reg. 2(1) words substituted [Yes]"
      assert result =~ "1 - The Earlier Amendment Regulations 2023"
      assert result =~ "https://legislation.gov.uk/id/uksi/2023/50"
      assert result =~ " reg. 3 inserted [Not yet]"
    end

    test "rescinding_stats_rescinding_count_per_law_detailed format" do
      # Simulates revocations this law makes to other laws
      revocations = [
        %{
          name: "UK_uksi_2010_500",
          title_en: "The Old Regulations 2010",
          path: "/id/uksi/2010/500",
          target: "whole instrument",
          affect: "revoked",
          applied?: "Yes"
        },
        %{
          name: "UK_ukpga_2005_10",
          title_en: "Some Act 2005",
          path: "/id/ukpga/2005/10",
          target: "s. 1",
          affect: "repealed in part",
          applied?: "Not yet"
        }
      ]

      result = StagedParser.test_build_count_per_law_detailed(revocations)

      assert result =~ "1 - The Old Regulations 2010"
      assert result =~ "https://legislation.gov.uk/id/uksi/2010/500"
      assert result =~ " whole instrument revoked [Yes]"
      assert result =~ "1 - Some Act 2005"
      assert result =~ "https://legislation.gov.uk/id/ukpga/2005/10"
      assert result =~ " s. 1 repealed in part [Not yet]"
    end

    test "rescinded_by_stats_rescinded_by_count_per_law_detailed format" do
      # Simulates revocations made TO this law BY other laws
      revocations = [
        %{
          name: "UK_uksi_2024_200",
          title_en: "The Revoking Regulations 2024",
          path: "/id/uksi/2024/200",
          target: "reg. 5",
          affect: "revoked",
          applied?: "Yes"
        },
        %{
          name: "UK_uksi_2024_200",
          title_en: "The Revoking Regulations 2024",
          path: "/id/uksi/2024/200",
          target: "reg. 6",
          affect: "revoked",
          applied?: "Yes"
        }
      ]

      result = StagedParser.test_build_count_per_law_detailed(revocations)

      assert result =~ "2 - The Revoking Regulations 2024"
      assert result =~ "https://legislation.gov.uk/id/uksi/2024/200"
      assert result =~ " reg. 5 revoked [Yes]"
      assert result =~ " reg. 6 revoked [Yes]"
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

    test "build_stage_summary returns summary for repeal_revoke stage" do
      stage_result = %{status: :ok, data: %{revoked: true}}
      summary = StagedParser.test_build_stage_summary(:repeal_revoke, stage_result)
      assert summary == "REVOKED"

      stage_result2 = %{status: :ok, data: %{revoked: false}}
      summary2 = StagedParser.test_build_stage_summary(:repeal_revoke, stage_result2)
      assert summary2 == "Active"
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

    test "stages/0 returns all 7 stages in order" do
      stages = StagedParser.stages()

      assert stages == [
               :metadata,
               :extent,
               :enacted_by,
               :amending,
               :amended_by,
               :repeal_revoke,
               :taxa
             ]
    end
  end
end
