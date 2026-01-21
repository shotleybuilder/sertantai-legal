defmodule SertantaiLegal.Scraper.TagsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Tags

  describe "set_tags/1" do
    test "returns record unchanged if Tags already has 2+ items" do
      record = %{Title_EN: "Some Act", Tags: ["Health", "Safety"]}
      assert Tags.set_tags(record) == record
    end

    test "sets Tags from Title_EN" do
      record = %{Title_EN: "Health and Safety at Work etc. Act 1974"}
      result = Tags.set_tags(record)
      assert is_list(result[:Tags])
      assert "Health" in result[:Tags]
      assert "Safety" in result[:Tags]
      assert "Work" in result[:Tags]
    end

    test "returns record unchanged if Title_EN is nil" do
      record = %{Title_EN: nil}
      result = Tags.set_tags(record)
      refute Map.has_key?(result, :Tags)
    end

    test "returns record unchanged if Title_EN is empty" do
      record = %{Title_EN: ""}
      result = Tags.set_tags(record)
      refute Map.has_key?(result, :Tags)
    end
  end

  describe "extract_tags/1" do
    test "extracts meaningful words from title" do
      tags = Tags.extract_tags("Health and Safety at Work etc. Act 1974")
      assert "Health" in tags
      assert "Safety" in tags
      assert "Work" in tags
      assert "Etc" in tags
      assert "Act" in tags
    end

    test "removes stop words" do
      tags = Tags.extract_tags("The Control of Substances Hazardous to Health Regulations 2002")
      assert "Control" in tags
      assert "Substances" in tags
      assert "Hazardous" in tags
      assert "Health" in tags
      assert "Regulations" in tags
      # Stop words should be removed
      refute "the" in tags
      refute "The" in tags
      refute "of" in tags
      refute "to" in tags
    end

    test "capitalizes all words" do
      tags = Tags.extract_tags("environmental protection act")
      assert tags == ["Environmental", "Protection", "Act"]
    end

    test "removes numbers and punctuation" do
      tags = Tags.extract_tags("The Water Supply (Water Quality) Regulations 2016")
      assert "Water" in tags
      assert "Supply" in tags
      assert "Quality" in tags
      assert "Regulations" in tags
      # Numbers should be removed
      refute "2016" in tags
    end

    test "handles empty string" do
      assert Tags.extract_tags("") == []
    end

    test "handles string with only stop words" do
      # After removing all stop words, we should get empty results
      tags = Tags.extract_tags("the and of to")
      assert tags == []
    end

    test "normalizes multiple spaces" do
      tags = Tags.extract_tags("Health   Safety    Work")
      assert tags == ["Health", "Safety", "Work"]
    end

    test "handles complex title with parentheses and hyphens" do
      tags =
        Tags.extract_tags("The Environmental Permitting (England and Wales) Regulations 2016")

      assert "Environmental" in tags
      assert "Permitting" in tags
      assert "England" in tags
      assert "Wales" in tags
      assert "Regulations" in tags
    end
  end
end
