defmodule SertantaiLegal.Scraper.CategorizerTest do
  use ExUnit.Case

  alias SertantaiLegal.Scraper.Categorizer
  alias SertantaiLegal.Scraper.Storage

  @test_session_id "categorizer-test-#{:rand.uniform(100_000)}"

  setup do
    Storage.delete_session(@test_session_id)
    on_exit(fn -> Storage.delete_session(@test_session_id) end)
    :ok
  end

  describe "categorize_records/1" do
    test "categorizes records into three groups" do
      records = [
        # Group 1: Has SI code that matches
        %{Title_EN: "Test Regulations 2024", si_code: ["87"]},
        # Group 2: Environment term but no SI code
        %{Title_EN: "Air Quality Regulations 2024", si_code: nil},
        # Group 3: Excluded by title
        %{Title_EN: "Railway Test Order 2024", si_code: nil},
        # Group 3: No match
        %{Title_EN: "Income Tax Act 2024", si_code: nil}
      ]

      result = Categorizer.categorize_records(records)

      assert Map.has_key?(result, :group1)
      assert Map.has_key?(result, :group2)
      assert Map.has_key?(result, :group3)
      assert Map.has_key?(result, :title_excluded)
    end

    test "group1 contains records with matching SI codes" do
      records = [
        %{Title_EN: "Test Regulations 2024", si_code: ["87"]},
        %{Title_EN: "Other Regulations 2024", si_code: ["110"]}
      ]

      result = Categorizer.categorize_records(records)

      # Both have valid SI codes
      assert length(result.group1) == 2
    end

    test "group2 contains term-matched records without SI codes" do
      records = [
        %{Title_EN: "Environmental Protection Act 2024", si_code: nil},
        %{Title_EN: "Health and Safety Regulations 2024", si_code: []}
      ]

      result = Categorizer.categorize_records(records)

      # Both have EHS terms but no SI codes
      assert length(result.group2) == 2
    end

    test "group3 contains excluded records" do
      records = [
        %{Title_EN: "Income Tax Act 2024", si_code: nil},
        %{Title_EN: "Education Act 2024", si_code: nil}
      ]

      result = Categorizer.categorize_records(records)

      # Neither matches EHS terms
      assert length(result.group3) == 2
    end

    test "title_excluded contains title-filtered records" do
      records = [
        %{Title_EN: "Railway Test Order 2024", si_code: nil},
        %{Title_EN: "Parking Charges Order 2024", si_code: nil}
      ]

      result = Categorizer.categorize_records(records)

      assert length(result.title_excluded) == 2
    end

    test "handles empty input" do
      result = Categorizer.categorize_records([])

      assert result.group1 == []
      assert result.group2 == []
      assert result.group3 == []
      assert result.title_excluded == []
    end
  end

  describe "categorize/1" do
    test "reads raw.json, categorizes, and saves group files" do
      # Setup: save raw.json
      records = [
        %{Title_EN: "Environmental Act 2024", si_code: ["87"]},
        %{Title_EN: "Air Quality Regulations 2024", si_code: nil},
        %{Title_EN: "Income Tax Act 2024", si_code: nil}
      ]

      :ok = Storage.save_json(@test_session_id, :raw, records)

      # Categorize
      {:ok, counts} = Categorizer.categorize(@test_session_id)

      # Check counts
      assert counts.group1_count == 1
      assert counts.group2_count == 1
      assert counts.group3_count == 1

      # Check files exist
      assert Storage.file_exists?(@test_session_id, :group1)
      assert Storage.file_exists?(@test_session_id, :group2)
      assert Storage.file_exists?(@test_session_id, :group3)
    end

    test "returns error when raw.json doesn't exist" do
      {:error, reason} = Categorizer.categorize("nonexistent-session")
      assert reason =~ "Failed to read"
    end
  end

  describe "save_categorized/2" do
    test "saves group files and returns counts" do
      categorized = %{
        group1: [%{Title_EN: "Law 1"}],
        group2: [%{Title_EN: "Law 2"}, %{Title_EN: "Law 3"}],
        group3: [%{Title_EN: "Law 4"}],
        title_excluded: [%{Title_EN: "Railway Order"}]
      }

      {:ok, counts} = Categorizer.save_categorized(@test_session_id, categorized)

      assert counts.group1_count == 1
      assert counts.group2_count == 2
      # group3 count includes title_excluded
      assert counts.group3_count == 2
      assert counts.title_excluded_count == 1
    end

    test "saves metadata file" do
      categorized = %{
        group1: [],
        group2: [],
        group3: [],
        title_excluded: []
      }

      {:ok, _counts} = Categorizer.save_categorized(@test_session_id, categorized)

      assert Storage.file_exists?(@test_session_id, :metadata)
    end

    test "indexes group3 records with numeric keys" do
      categorized = %{
        group1: [],
        group2: [],
        group3: [%{Title_EN: "Law 1"}, %{Title_EN: "Law 2"}],
        title_excluded: [%{Title_EN: "Railway Order"}]
      }

      {:ok, _counts} = Categorizer.save_categorized(@test_session_id, categorized)

      {:ok, group3} = Storage.read_json(@test_session_id, :group3)

      # Should be indexed as map
      assert is_map(group3)
      # 3 total records (2 from group3 + 1 title_excluded)
      assert map_size(group3) == 3
    end
  end
end
