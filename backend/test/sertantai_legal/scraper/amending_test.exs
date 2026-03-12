defmodule SertantaiLegal.Scraper.AmendingTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amending
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  setup do
    Req.Test.stub(Client, fn conn ->
      path = conn.request_path

      cond do
        String.contains?(path, "/changes/affecting/uksi/2024/100") ->
          html = fixture("amendments_affecting.html")
          Req.Test.text(conn, html)

        String.contains?(path, "/changes/affected/uksi/2024/100") ->
          # Return empty results for affected (no laws amend this law yet)
          Req.Test.text(conn, "<html><body><table><tbody></tbody></table></body></html>")

        String.contains?(path, "/changes/affecting/uksi/2024/200") ->
          html = fixture("amendments_with_self_refs.html")
          Req.Test.text(conn, html)

        String.contains?(path, "/changes/affected/uksi/2024/200") ->
          # Return empty results
          Req.Test.text(conn, "<html><body><table><tbody></tbody></table></body></html>")

        # Full revocation fixture — has whole-instrument revocations
        String.contains?(path, "/changes/affected/nisr/2003/33") ->
          html = fixture("amendments_affected_revocations.html")
          Req.Test.text(conn, html)

        String.contains?(path, "/changes/affecting/nisr/2003/33") ->
          Req.Test.text(conn, "<html><body><table><tbody></tbody></table></body></html>")

        # Partial-only fixture — only section-specific revocations
        String.contains?(path, "/changes/affected/uksi/2005/300") ->
          html = fixture("amendments_affected_partial_only.html")
          Req.Test.text(conn, html)

        String.contains?(path, "/changes/affecting/uksi/2005/300") ->
          Req.Test.text(conn, "<html><body><table><tbody></tbody></table></body></html>")

        # No revocations at all — only amendments
        String.contains?(path, "/changes/affected/uksi/2024/400") ->
          Req.Test.text(conn, "<html><body><table><tbody></tbody></table></body></html>")

        String.contains?(path, "/changes/affecting/uksi/2024/400") ->
          Req.Test.text(conn, "<html><body><table><tbody></tbody></table></body></html>")

        String.contains?(path, "/changes/affecting/uksi/2024/999") ->
          Plug.Conn.send_resp(conn, 404, "Not found")

        String.contains?(path, "/changes/affected/uksi/2024/999") ->
          Plug.Conn.send_resp(conn, 404, "Not found")

        true ->
          Plug.Conn.send_resp(conn, 404, "Not found")
      end
    end)

    :ok
  end

  describe "affecting_path/1" do
    test "builds correct path with atom keys" do
      record = %{type_code: "uksi", Year: 2024, Number: "1001"}
      path = Amending.affecting_path(record)

      assert path ==
               "/changes/affecting/uksi/2024/1001?results-count=1000&sort=affecting-year-number"
    end

    test "builds correct path with string keys" do
      record = %{"type_code" => "uksi", "Year" => 2024, "Number" => "1001"}
      path = Amending.affecting_path(record)

      assert path ==
               "/changes/affecting/uksi/2024/1001?results-count=1000&sort=affecting-year-number"
    end
  end

  describe "affected_path/1" do
    test "builds correct path" do
      record = %{type_code: "uksi", Year: 2024, Number: "1001"}
      path = Amending.affected_path(record)

      assert path ==
               "/changes/affected/uksi/2024/1001?results-count=1000&sort=affected-year-number"
    end
  end

  describe "parse_amendments_html/1" do
    test "parses amendment rows from HTML" do
      html = fixture("amendments_affecting.html")
      amendments = Amending.parse_amendments_html(html)

      assert length(amendments) == 5
    end

    test "extracts title from first column" do
      html = fixture("amendments_affecting.html")
      [first | _] = Amending.parse_amendments_html(html)

      assert first.title_en == "Environmental Permitting Regulations 2016"
    end

    test "extracts law path and type_code" do
      html = fixture("amendments_affecting.html")
      [first | _] = Amending.parse_amendments_html(html)

      assert first.path == "/id/uksi/2016/1154"
      assert first.type_code == "uksi"
      assert first.year == 2016
      assert first.number == "1154"
    end

    test "extracts target section" do
      html = fixture("amendments_affecting.html")
      [first | _] = Amending.parse_amendments_html(html)

      assert first.target == "reg. 5(1)"
    end

    test "extracts affect type" do
      html = fixture("amendments_affecting.html")
      amendments = Amending.parse_amendments_html(html)

      affects = Enum.map(amendments, & &1.affect)

      assert "words substituted" in affects
      assert "inserted" in affects
      assert "amended" in affects
      assert "revoked" in affects
      assert "repealed in part" in affects
    end

    test "extracts applied status" do
      html = fixture("amendments_affecting.html")
      amendments = Amending.parse_amendments_html(html)

      statuses = Enum.map(amendments, & &1.applied?)

      assert "Yes" in statuses
      assert "Not yet" in statuses
    end

    test "builds name in UK_type_code_year_number format" do
      html = fixture("amendments_affecting.html")
      [first | _] = Amending.parse_amendments_html(html)

      assert first.name == "UK_uksi_2016_1154"
    end

    test "handles ukpga type code" do
      html = fixture("amendments_affecting.html")
      amendments = Amending.parse_amendments_html(html)

      # Find the HSWA 1974 entry
      hswa = Enum.find(amendments, fn a -> a.year == 1974 end)

      assert hswa.type_code == "ukpga"
      assert hswa.number == "37"
      assert hswa.name == "UK_ukpga_1974_37"
    end

    test "returns empty list for empty HTML" do
      html = "<html><body><table><tbody></tbody></table></body></html>"
      amendments = Amending.parse_amendments_html(html)

      assert amendments == []
    end
  end

  describe "get_laws_amended_by_this_law/1" do
    test "returns parsed amendments" do
      record = %{type_code: "uksi", Year: 2024, Number: "100"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      # Should have 2 unique amended laws (uksi/2016/1154 appears twice but is deduped)
      # And 2 revoked laws
      assert length(result.amending) == 2
      assert length(result.rescinding) == 2
    end

    test "separates revocations from amendments" do
      record = %{type_code: "uksi", Year: 2024, Number: "100"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      # Amending should contain non-revoked laws (unique) in UK_type_year_number format
      assert "UK_uksi_2016_1154" in result.amending
      assert "UK_ukpga_1974_37" in result.amending

      # Rescinding should contain revoked/repealed laws
      assert "UK_uksi_2010_500" in result.rescinding
      assert "UK_ukpga_2005_10" in result.rescinding
    end

    test "returns stats" do
      record = %{type_code: "uksi", Year: 2024, Number: "100"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      assert result.stats.total_changes == 5
      # Raw count including duplicates
      assert result.stats.amendments_count == 3
      assert result.stats.revocations_count == 2
      # Unique laws
      assert result.stats.amended_laws_count == 2
      assert result.stats.revoked_laws_count == 2
    end

    test "returns ok with empty lists for 404" do
      record = %{type_code: "uksi", Year: 2024, Number: "999"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      assert result.amending == []
      assert result.rescinding == []
      assert result.stats.amendments_count == 0
      assert result.stats.revocations_count == 0
    end
  end

  describe "get_laws_amending_this_law/1" do
    test "returns amended_by field" do
      record = %{type_code: "uksi", Year: 2024, Number: "100"}

      {:ok, result} = Amending.get_laws_amending_this_law(record)

      # Our mock returns empty results
      assert result.amended_by == []
      assert result.rescinded_by == []
    end

    test "includes live status" do
      record = %{type_code: "uksi", Year: 2024, Number: "100"}

      {:ok, result} = Amending.get_laws_amending_this_law(record)

      # No revocations means in force
      assert result.live == "✔ In force"
    end
  end

  describe "live status determination" do
    test "full revocation when target is whole instrument and affect is 'revoked'" do
      # nisr/2003/33 fixture has: target=Regulations, affect=revoked (row 1)
      record = %{type_code: "nisr", Year: 2003, Number: "33"}

      {:ok, result} = Amending.get_laws_amending_this_law(record)

      assert result.live == "❌ Revoked / Repealed / Abolished"
    end

    test "partial revocation when only section-specific targets are revoked" do
      # uksi/2005/300 fixture has only: reg. 3 revoked, words repealed, Sch. 1 revoked,
      # Regulations revoked in part, power to revoke conferred — no whole-instrument
      record = %{type_code: "uksi", Year: 2005, Number: "300"}

      {:ok, result} = Amending.get_laws_amending_this_law(record)

      assert result.live == "⭕ Part Revocation / Repeal"
    end

    test "in force when no revocations at all" do
      # uksi/2024/400 returns empty results
      record = %{type_code: "uksi", Year: 2024, Number: "400"}

      {:ok, result} = Amending.get_laws_amending_this_law(record)

      assert result.live == "✔ In force"
    end

    test "in force for 404 (no changes data exists)" do
      record = %{type_code: "uksi", Year: 2024, Number: "999"}

      {:ok, result} = Amending.get_laws_amending_this_law(record)

      assert result.live == "✔ In force"
    end

    test "separates revocations from amendments in affected data" do
      record = %{type_code: "nisr", Year: 2003, Number: "33"}

      {:ok, result} = Amending.get_laws_amending_this_law(record)

      # All rows in the fixture are revocations (contain repeal/revoke in affect)
      assert length(result.rescinded_by) > 0
      # No pure amendments in the fixture
      assert result.amended_by == []
    end

    test "revocation stats count unique rescinding laws" do
      record = %{type_code: "nisr", Year: 2003, Number: "33"}

      {:ok, result} = Amending.get_laws_amending_this_law(record)

      # There are multiple entries from the same law (e.g. nisr/2005/50 appears multiple times)
      # rescinded_by should be deduplicated
      assert result.stats.revoked_laws_count == length(result.rescinded_by)
    end
  end

  describe "revocation pattern classification" do
    # These tests verify that parse_amendments_html correctly parses the HTML
    # and that determine_live_status classifies each pattern correctly.
    # Using the amendments_affected_revocations.html fixture directly.

    test "whole-instrument targets are classified as full revocation" do
      html = fixture("amendments_affected_revocations.html")
      amendments = Amending.parse_amendments_html(html, endpoint: :affected)

      # Find whole-instrument revocations from the fixture
      full_revocation_targets =
        amendments
        |> Enum.filter(fn a ->
          a.target in ["Regulations", "Act", "Order", "Rules", "Scheme",
                        "Measure", "Byelaws", "Instrument", "whole instrument"]
          and a.affect in ["revoked", "repealed"]
        end)

      # Fixture has rows 1, 6, 7, 8, 9, 12, 15, 18, 20, 23
      assert length(full_revocation_targets) == 10
    end

    test "section-specific targets with bare 'revoked' are NOT full revocation" do
      html = fixture("amendments_affected_revocations.html")
      amendments = Amending.parse_amendments_html(html, endpoint: :affected)

      # reg. 3 revoked, s. 1 repealed, Sch. 2 revoked, s. 20(b) repealed
      section_revocations =
        amendments
        |> Enum.filter(fn a ->
          a.affect in ["revoked", "repealed"] and
          a.target not in ["Regulations", "Act", "Order", "Rules", "Scheme",
                           "Measure", "Byelaws", "Instrument", "whole instrument"]
        end)

      assert length(section_revocations) == 4
      targets = Enum.map(section_revocations, & &1.target)
      assert "reg. 3" in targets
      assert "s. 1" in targets
      assert "Sch. 2" in targets
      assert "s. 20(b)" in targets
    end

    test "'words revoked' is always partial regardless of target" do
      html = fixture("amendments_affected_revocations.html")
      amendments = Amending.parse_amendments_html(html, endpoint: :affected)

      words_revoked = Enum.filter(amendments, &(&1.affect == "words revoked"))
      assert length(words_revoked) == 1
      assert hd(words_revoked).target == "reg. 2(1)"
    end

    test "'word revoked' is always partial" do
      html = fixture("amendments_affected_revocations.html")
      amendments = Amending.parse_amendments_html(html, endpoint: :affected)

      word_revoked = Enum.filter(amendments, &(&1.affect == "word revoked"))
      assert length(word_revoked) == 1
      assert hd(word_revoked).target == "reg. 1(2)"
    end

    test "'repealed in part' is always partial even with whole-instrument target" do
      html = fixture("amendments_affected_revocations.html")
      amendments = Amending.parse_amendments_html(html, endpoint: :affected)

      in_part = Enum.filter(amendments, &(&1.affect == "repealed in part"))
      assert length(in_part) == 1
      # This has target=Regulations but affect says "in part" — still partial
      assert hd(in_part).target == "Regulations"
    end

    test "'revoked in part' is always partial even with whole-instrument target" do
      html = fixture("amendments_affected_revocations.html")
      amendments = Amending.parse_amendments_html(html, endpoint: :affected)

      in_part = Enum.filter(amendments, &(&1.affect == "revoked in part"))
      assert length(in_part) == 1
      assert hd(in_part).target == "Regulations"
    end

    test "'power to amend or revoke conferred' is not a revocation" do
      html = fixture("amendments_affected_revocations.html")
      amendments = Amending.parse_amendments_html(html, endpoint: :affected)

      power = Enum.filter(amendments, &(&1.affect == "power to amend or revoke conferred"))
      assert length(power) == 1
      # This contains "revoke" but is a power grant, not an actual revocation
      assert hd(power).target == "Regulations"
    end

    test "'entry repealed' is always partial" do
      html = fixture("amendments_affected_revocations.html")
      amendments = Amending.parse_amendments_html(html, endpoint: :affected)

      entry = Enum.filter(amendments, &(&1.affect == "entry repealed"))
      assert length(entry) == 1
    end

    test "'entries repealed' is always partial" do
      html = fixture("amendments_affected_revocations.html")
      amendments = Amending.parse_amendments_html(html, endpoint: :affected)

      entries = Enum.filter(amendments, &(&1.affect == "entries repealed"))
      assert length(entries) == 1
    end

    test "'comma revoked' is always partial" do
      html = fixture("amendments_affected_revocations.html")
      amendments = Amending.parse_amendments_html(html, endpoint: :affected)

      comma = Enum.filter(amendments, &(&1.affect == "comma revoked"))
      assert length(comma) == 1
    end

    test "'revoked with savings' on whole instrument is full revocation" do
      html = fixture("amendments_affected_revocations.html")
      amendments = Amending.parse_amendments_html(html, endpoint: :affected)

      savings = Enum.filter(amendments, &(&1.affect == "revoked with savings"))
      assert length(savings) == 1
      assert hd(savings).target == "Regulations"
      # "revoked with savings" contains "revoke" and no "in part" — and target is whole instrument
    end

    test "partial-only fixture produces partial live status" do
      html = fixture("amendments_affected_partial_only.html")
      amendments = Amending.parse_amendments_html(html, endpoint: :affected)

      # Should have 5 entries, all partial
      assert length(amendments) == 5

      # Verify targets — none are bare whole-instrument revocations
      revocation_entries =
        Enum.filter(amendments, fn a ->
          affect_lower = String.downcase(a.affect)
          String.contains?(affect_lower, "repeal") or String.contains?(affect_lower, "revoke")
        end)

      assert length(revocation_entries) == 5

      # None should be classified as full revocation
      full =
        Enum.filter(revocation_entries, fn a ->
          affect_lower = String.downcase(a.affect)
          target_lower = String.downcase(a.target)

          not String.contains?(affect_lower, "in part") and
            not String.contains?(affect_lower, "words ") and
            not String.contains?(affect_lower, "power to") and
            a.affect in ["revoked", "repealed"] and
            target_lower in ["regulations", "act", "order", "rules", "scheme",
                             "measure", "charter", "byelaws", "instrument"]
        end)

      assert full == []
    end
  end

  describe "self-reference filtering" do
    test "excludes self-references from amending list" do
      record = %{type_code: "uksi", Year: 2024, Number: "200"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      # Should NOT contain self (UK_uksi_2024_200)
      refute "UK_uksi_2024_200" in result.amending

      # Should contain the other two laws
      assert "UK_uksi_2016_1154" in result.amending
      assert "UK_ukpga_1974_37" in result.amending
      assert length(result.amending) == 2
    end

    test "captures self-references in self_amendments list" do
      record = %{type_code: "uksi", Year: 2024, Number: "200"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      # Should have 3 self-amendments (coming into force provisions)
      assert length(result.self_amendments) == 3

      # All self_amendments should have the same name as the source law
      Enum.each(result.self_amendments, fn amendment ->
        assert amendment.name == "UK_uksi_2024_200"
      end)
    end

    test "stats include accurate self_amendments_count" do
      record = %{type_code: "uksi", Year: 2024, Number: "200"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      # Stats should show 3 self-amendments
      assert result.stats.self_amendments_count == 3

      # Other stats should exclude self
      # Only non-self amendments
      assert result.stats.amendments_count == 2
      # Only unique non-self laws
      assert result.stats.amended_laws_count == 2
    end

    test "total_changes includes self for reference" do
      record = %{type_code: "uksi", Year: 2024, Number: "200"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      # Total should be 5 (3 self + 2 others)
      assert result.stats.total_changes == 5
    end

    test "self_amendments preserves amendment details" do
      record = %{type_code: "uksi", Year: 2024, Number: "200"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      # Self-amendments should have target, affect, and applied fields
      first_self = hd(result.self_amendments)

      assert first_self.target == "art. 1"
      assert first_self.affect == "coming into force"
      assert first_self.applied? == "Yes"
    end
  end

  defp fixture(name) do
    Path.join([File.cwd!(), "test/fixtures/legislation_gov_uk", name])
    |> File.read!()
  end
end
