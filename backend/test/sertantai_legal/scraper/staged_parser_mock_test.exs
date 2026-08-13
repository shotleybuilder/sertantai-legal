defmodule SertantaiLegal.Scraper.StagedParserMockTest do
  @moduledoc """
  Mock-based tests for the full StagedParser and TaxaParser pipelines.

  These tests replace the former staged_parser_live_test.exs which hit
  legislation.gov.uk. All HTTP calls are intercepted via Req.Test stubs
  with local fixture XML/HTML files.

  Uses async: false because StagedParser spawns a Task.async for the taxa
  stage, which needs Req.Test in shared mode to see the stubs.
  """
  use ExUnit.Case, async: false

  alias SertantaiLegal.Scraper.StagedParser
  alias SertantaiLegal.Scraper.TaxaParser
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  # All 7 stages including taxa (taxa is not in the default @stages list)
  @all_stages [:metadata, :extent, :enacted_by, :amending, :amended_by, :explanatory_note, :taxa]

  setup do
    # Shared mode so Task.async (taxa parallel stage) can see stubs
    Req.Test.set_req_test_to_shared()

    Req.Test.stub(Client, fn conn ->
      path = conn.request_path

      cond do
        # ── uksi/1991/899 fixtures ──────────────────────────────────────
        String.contains?(path, "/uksi/1991/899/body/data.xml") ->
          xml = fixture("body_uksi_1991_899.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/1991/899/introduction") ->
          xml = fixture("introduction_uksi_1991_899.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/1991/899/contents/data.xml") ->
          xml = fixture("contents_uksi_1991_899.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/1991/899/note/data.xml") ->
          xml = fixture("note_uksi_1991_899.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/1991/899/notes/data.xml") ->
          Plug.Conn.send_resp(conn, 404, "Not found")

        String.contains?(path, "/changes/affecting/uksi/1991/899") ->
          Req.Test.text(conn, empty_changes_html())

        String.contains?(path, "/changes/affected/uksi/1991/899") ->
          Req.Test.text(conn, empty_changes_html())

        # ── uksi/2016/680 fixtures ──────────────────────────────────────
        String.contains?(path, "/uksi/2016/680/body/data.xml") ->
          xml = fixture("body_uksi_2016_680.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/2016/680/introduction") ->
          xml = fixture("introduction_uksi_2016_680.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/2016/680/contents/data.xml") ->
          xml = fixture("contents_uksi_2016_680.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/2016/680/note/data.xml") ->
          xml = fixture("note_uksi_2016_680.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/2016/680/notes/data.xml") ->
          Plug.Conn.send_resp(conn, 404, "Not found")

        String.contains?(path, "/changes/affecting/uksi/2016/680") ->
          Req.Test.text(conn, empty_changes_html())

        String.contains?(path, "/changes/affected/uksi/2016/680") ->
          Req.Test.text(conn, empty_changes_html())

        # ── uksi/2025/622 fixtures ──────────────────────────────────────
        String.contains?(path, "/uksi/2025/622/body/data.xml") ->
          xml = fixture("body_uksi_2025_622.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/2025/622/introduction") ->
          xml = fixture("introduction_uksi_2025_622.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/2025/622/contents/data.xml") ->
          xml = fixture("contents_uksi_2025_622.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/2025/622/note/data.xml") ->
          xml = fixture("note_uksi_2025_622.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/2025/622/notes/data.xml") ->
          Plug.Conn.send_resp(conn, 404, "Not found")

        String.contains?(path, "/changes/affecting/uksi/2025/622") ->
          Req.Test.text(conn, empty_changes_html())

        String.contains?(path, "/changes/affected/uksi/2025/622") ->
          Req.Test.text(conn, empty_changes_html())

        # ── Catch-all 404 ───────────────────────────────────────────────
        true ->
          Plug.Conn.send_resp(conn, 404, "Not found: #{path}")
      end
    end)

    on_exit(fn ->
      Req.Test.set_req_test_to_private()
    end)

    :ok
  end

  # ── TaxaParser.run/3 tests ──────────────────────────────────────────────

  describe "TaxaParser.run/3 - mocked" do
    test "UK_uksi_1991_899 returns role with Ind: Worker" do
      {:ok, result} = TaxaParser.run("uksi", "1991", "899")

      assert result.taxa_text_source == "body", "Should use body text, not introduction"
      assert result.taxa_text_length > 0, "Should have fetched text"
      assert is_list(result.role), "role should be a list"
      assert "Ind: Worker" in result.role, "Should detect 'Ind: Worker' in body text"
    end

    test "UK_uksi_2016_680 returns role with Ind: Worker" do
      {:ok, result} = TaxaParser.run("uksi", "2016", "680")

      assert result.taxa_text_source == "body"
      assert result.taxa_text_length > 0, "Body should have content"
      assert "Ind: Worker" in result.role
    end

    test "uses body text as primary source, not introduction" do
      {:ok, result} = TaxaParser.run("uksi", "2016", "680")

      assert result.taxa_text_source == "body"
      assert result.taxa_text_length > 500

      # Should find multiple actors from body
      assert length(result.role) > 3, "Should find multiple actors from body text"
    end
  end

  # ── StagedParser.parse/1 full pipeline tests ────────────────────────────

  describe "StagedParser.parse/1 - mocked" do
    test "UK_uksi_1991_899 full parse returns role with Ind: Worker" do
      record = %{type_code: "uksi", Year: 1991, Number: "899", name: "UK_uksi_1991_899"}

      {:ok, result} = StagedParser.parse(record, stages: @all_stages)

      # Taxa stage should succeed
      assert result.stages[:taxa].status == :ok, "Taxa stage should succeed"

      # Final record should have role populated
      assert is_list(result.record[:role]), "role should be a list"
      assert "Ind: Worker" in result.record[:role], "Should have 'Ind: Worker' in final record"

      # role_gvt should be a list (may be empty for laws without government actors)
      assert is_list(result.law.role_gvt), "role_gvt should be a list"
    end

    test "amendments 404 does not crash subsequent stages" do
      record = %{type_code: "uksi", Year: 1991, Number: "899", name: "UK_uksi_1991_899"}

      {:ok, result} = StagedParser.parse(record, stages: @all_stages)

      # All stages should complete (not crash)
      assert Map.has_key?(result.stages, :extent)
      assert Map.has_key?(result.stages, :enacted_by)
      assert Map.has_key?(result.stages, :amending)
      assert Map.has_key?(result.stages, :amended_by)
    end

    test "full parse populates all taxa fields" do
      record = %{type_code: "uksi", Year: 2016, Number: "680", name: "UK_uksi_2016_680"}

      {:ok, result} = StagedParser.parse(record, stages: @all_stages)

      # Check taxa stage
      assert result.stages[:taxa].status == :ok

      # Check all taxa fields are populated in the ParsedLaw struct
      assert is_list(result.law.role)
      assert is_list(result.law.role_gvt)
      assert is_list(result.law.duty_type)
      assert is_list(result.law.duty_holder)
      assert is_list(result.law.rights_holder)
      assert is_list(result.law.responsibility_holder)
      assert is_list(result.law.power_holder)
      assert is_list(result.law.popimar)

      # Role should have multiple entries for this complex law
      assert length(result.law.role) >= 5
    end
  end

  # ── Regression tests ────────────────────────────────────────────────────

  describe "regression tests" do
    test "role field is not empty when body text contains actors" do
      laws_with_known_roles = [
        {"uksi", "1991", "899", ["Ind: Worker"]},
        {"uksi", "2016", "680", ["Ind: Worker"]}
      ]

      for {type_code, year, number, expected_roles} <- laws_with_known_roles do
        {:ok, result} = TaxaParser.run(type_code, year, number)

        for expected_role <- expected_roles do
          assert expected_role in result.role,
                 "#{type_code}/#{year}/#{number} should have '#{expected_role}' in role, got: #{inspect(result.role)}"
        end
      end
    end

    test "enacted_by names use UK_type_year_number format" do
      record = %{type_code: "uksi", Year: 2025, Number: "622", name: "UK_uksi_2025_622"}

      {:ok, result} = StagedParser.parse(record, stages: @all_stages)

      assert result.stages[:enacted_by].status == :ok

      # enacted_by is a list of name strings for DB links
      enacted_by = result.law.enacted_by
      assert is_list(enacted_by), "enacted_by should be a list"
      assert length(enacted_by) > 0, "Should have at least one enacted_by"

      # All enacted_by entries should be UK_ format name strings
      for name <- enacted_by do
        assert is_binary(name), "enacted_by entry should be a string"

        assert String.starts_with?(name, "UK_"),
               "enacted_by name should start with UK_, got: #{name}"
      end

      # enacted_by_meta should have the rich metadata
      enacted_by_meta = result.law.enacted_by_meta
      assert is_list(enacted_by_meta), "enacted_by_meta should be a list"
      assert length(enacted_by_meta) > 0, "Should have at least one enacted_by_meta"

      for entry <- enacted_by_meta do
        assert is_map(entry), "enacted_by_meta entry should be a map"
        assert Map.has_key?(entry, "name"), "enacted_by_meta should have name"
        assert Map.has_key?(entry, "uri"), "enacted_by_meta should have uri"
      end
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  defp fixture(name) do
    Path.join([File.cwd!(), "test/fixtures/legislation_gov_uk", name])
    |> File.read!()
  end

  defp empty_changes_html do
    "<html><body><table><tbody></tbody></table></body></html>"
  end
end
