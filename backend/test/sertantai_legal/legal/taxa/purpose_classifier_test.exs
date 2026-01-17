defmodule SertantaiLegal.Legal.Taxa.PurposeClassifierTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.PurposeClassifier

  describe "classify/1" do
    test "returns Amendment for amendment text" do
      texts = [
        "The following amendments shall be made",
        "for 'prescribed' substitute 'specified'",
        "omit the words 'or regulation'",
        "there is inserted after paragraph (a)",
        "shall be amended as follows"
      ]

      for text <- texts do
        assert PurposeClassifier.classify(text) == ["Amendment"],
               "Expected Amendment for: #{text}"
      end
    end

    test "returns Enactment+Citation+Commencement for commencement text" do
      texts = [
        "This Act may be cited as the Environment Act 2024",
        "These Regulations come into force on 1st January 2025",
        "The commencement date is set by order"
      ]

      for text <- texts do
        purposes = PurposeClassifier.classify(text)

        assert "Enactment+Citation+Commencement" in purposes,
               "Expected Enactment+Citation+Commencement for: #{text}"
      end
    end

    test "returns Interpretation+Definition for definition text" do
      texts = [
        "In these Regulations— 'employer' means a person who",
        ~s("hazardous substance" means any substance which),
        "For the purposes of this Act, 'worker' includes"
      ]

      for text <- texts do
        purposes = PurposeClassifier.classify(text)

        assert "Interpretation+Definition" in purposes,
               "Expected Interpretation+Definition for: #{text}"
      end
    end

    test "returns Application+Scope for application text" do
      texts = [
        "These Regulations apply to all employers",
        "This Part does not apply to domestic premises",
        "The provisions shall have effect in relation to"
      ]

      for text <- texts do
        purposes = PurposeClassifier.classify(text)

        assert "Application+Scope" in purposes,
               "Expected Application+Scope for: #{text}"
      end
    end

    test "returns Extent for extent text" do
      texts = [
        "This Act extends to England and Wales only",
        "These Regulations do not extend to Scotland",
        "Corresponding provisions for Northern Ireland"
      ]

      for text <- texts do
        purposes = PurposeClassifier.classify(text)

        assert "Extent" in purposes,
               "Expected Extent for: #{text}"
      end
    end

    test "returns Exemption for exemption text" do
      texts = [
        "This requirement shall not apply in any case where the",
        "by a certificate in writing exempt any person",
        "The exemption applies to small businesses"
      ]

      for text <- texts do
        purposes = PurposeClassifier.classify(text)

        assert "Exemption" in purposes,
               "Expected Exemption for: #{text}"
      end
    end

    test "returns Repeal+Revocation for repeal text" do
      texts = [
        "The 2010 Regulations are hereby revoked.",
        "The following Acts are repealed—",
        ". . . . . . . "
      ]

      for text <- texts do
        purposes = PurposeClassifier.classify(text)

        assert "Repeal+Revocation" in purposes,
               "Expected Repeal+Revocation for: #{text}"
      end
    end

    test "returns Transitional Arrangement for transitional text" do
      texts = [
        "transitional provision for existing licences",
        "transitional arrangements apply until"
      ]

      for text <- texts do
        purposes = PurposeClassifier.classify(text)

        assert "Transitional Arrangement" in purposes,
               "Expected Transitional Arrangement for: #{text}"
      end
    end

    test "returns Charge+Fee for fee text" do
      texts = [
        "The fee is payable on application",
        "fees and charges may be levied",
        "may charge a fee for the service"
      ]

      for text <- texts do
        purposes = PurposeClassifier.classify(text)

        assert "Charge+Fee" in purposes,
               "Expected Charge+Fee for: #{text}"
      end
    end

    test "returns Offence for offence text" do
      texts = [
        "It is an offence to fail to comply",
        "Offences under this regulation",
        "liable to a penalty not exceeding"
      ]

      for text <- texts do
        purposes = PurposeClassifier.classify(text)

        assert "Offence" in purposes,
               "Expected Offence for: #{text}"
      end
    end

    test "returns Enforcement+Prosecution for enforcement text" do
      texts = [
        "proceedings may be brought",
        "on conviction on indictment"
      ]

      for text <- texts do
        purposes = PurposeClassifier.classify(text)

        assert "Enforcement+Prosecution" in purposes,
               "Expected Enforcement+Prosecution for: #{text}"
      end
    end

    test "returns Defence+Appeal for defence text" do
      texts = [
        "It is a defence for a person to prove",
        "may appeal against the decision",
        "shall not be guilty if"
      ]

      for text <- texts do
        purposes = PurposeClassifier.classify(text)

        assert "Defence+Appeal" in purposes,
               "Expected Defence+Appeal for: #{text}"
      end
    end

    test "returns Power Conferred for power text" do
      texts = [
        "the functions conferred by this Act",
        "power to make regulations under",
        "The power under subsection (1)"
      ]

      for text <- texts do
        purposes = PurposeClassifier.classify(text)

        assert "Power Conferred" in purposes,
               "Expected Power Conferred for: #{text}"
      end
    end

    test "returns Process+Rule+Constraint+Condition as default" do
      # Text that doesn't match any specific pattern
      text = "The quick brown fox jumps over the lazy dog"
      assert PurposeClassifier.classify(text) == ["Process+Rule+Constraint+Condition"]
    end

    test "returns empty list for nil or empty input" do
      assert PurposeClassifier.classify(nil) == []
      assert PurposeClassifier.classify("") == []
    end

    test "Amendment takes precedence over other patterns" do
      # Text that could match multiple patterns but includes amendment
      text = "These Regulations are amended as follows and come into force on 1st January"
      assert PurposeClassifier.classify(text) == ["Amendment"]
    end

    test "returns multiple purposes when text matches multiple patterns" do
      text = "These Regulations come into force on 1st January. An offence is committed if"
      purposes = PurposeClassifier.classify(text)

      assert "Enactment+Citation+Commencement" in purposes
      assert "Offence" in purposes
    end
  end

  describe "classify_title/1" do
    test "detects Amendment from title" do
      titles = [
        "The Environmental Protection (Amendment) Regulations 2024",
        "Health and Safety at Work Act 1974 (Amendment) Order 2024",
        "The Control of Substances (Amendment No. 2) Regulations 2024"
      ]

      for title <- titles do
        assert PurposeClassifier.classify_title(title) == ["Amendment"],
               "Expected Amendment for title: #{title}"
      end
    end

    test "detects Repeal+Revocation from title" do
      titles = [
        "The Environmental Protection (Revocation) Regulations 2024",
        "Health and Safety Act (Repeal) Order 2024"
      ]

      for title <- titles do
        assert PurposeClassifier.classify_title(title) == ["Repeal+Revocation"],
               "Expected Repeal+Revocation for title: #{title}"
      end
    end

    test "detects Enactment+Citation+Commencement from title" do
      titles = [
        "The Environment Act 2021 (Commencement No. 3) Regulations 2024",
        "Health and Safety at Work Act 1974 (Commencement) Order 2024"
      ]

      for title <- titles do
        assert PurposeClassifier.classify_title(title) == ["Enactment+Citation+Commencement"],
               "Expected Enactment+Citation+Commencement for title: #{title}"
      end
    end

    test "detects Application+Scope from title" do
      assert PurposeClassifier.classify_title("The Regulations (Application) Order 2024") ==
               ["Application+Scope"]
    end

    test "detects Transitional Arrangement from title" do
      assert PurposeClassifier.classify_title("The Act (Transitional Provisions) Order 2024") ==
               ["Transitional Arrangement"]
    end

    test "detects Extent from title" do
      titles = [
        "The Act (Extent) Order 2024",
        "The Regulations (Extension to Scotland) Order 2024"
      ]

      for title <- titles do
        assert PurposeClassifier.classify_title(title) == ["Extent"],
               "Expected Extent for title: #{title}"
      end
    end

    test "returns empty list for regular titles" do
      assert PurposeClassifier.classify_title("The Environmental Protection Regulations 2024") ==
               []
    end

    test "returns empty list for nil or empty input" do
      assert PurposeClassifier.classify_title(nil) == []
      assert PurposeClassifier.classify_title("") == []
    end
  end

  describe "sort_purposes/1" do
    test "sorts purposes by priority" do
      input = [
        "Amendment",
        "Offence",
        "Enactment+Citation+Commencement",
        "Interpretation+Definition"
      ]

      expected = [
        "Enactment+Citation+Commencement",
        "Interpretation+Definition",
        "Offence",
        "Amendment"
      ]

      assert PurposeClassifier.sort_purposes(input) == expected
    end

    test "handles empty list" do
      assert PurposeClassifier.sort_purposes([]) == []
    end

    test "handles single item" do
      assert PurposeClassifier.sort_purposes(["Amendment"]) == ["Amendment"]
    end
  end

  describe "all_purposes/0" do
    test "returns all valid purpose values" do
      purposes = PurposeClassifier.all_purposes()

      assert length(purposes) == 15
      assert "Amendment" in purposes
      assert "Enactment+Citation+Commencement" in purposes
      assert "Interpretation+Definition" in purposes
      assert "Application+Scope" in purposes
      assert "Process+Rule+Constraint+Condition" in purposes
    end

    test "all values use + separator not comma" do
      purposes = PurposeClassifier.all_purposes()

      # None should contain ", " pattern (comma followed by space)
      for purpose <- purposes do
        refute String.contains?(purpose, ", "),
               "Purpose #{purpose} should not contain comma separator"
      end
    end
  end
end
