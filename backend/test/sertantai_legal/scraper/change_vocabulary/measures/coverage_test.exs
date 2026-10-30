defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.CoverageTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Coverage

  defp change(key, target, operation, sources, resolved \\ %{}) do
    %Change{
      key: key,
      target: target,
      claims: for(s <- sources, do: %Claim{source: s, attribute: :operation, value: operation}),
      resolved:
        Map.merge(%{operation: operation, date: nil, commenced_by: nil, by: "A"}, resolved)
    }
  end

  describe "stated_by/1 (from the claims of the change's operation)" do
    test "the law's text with legislation.gov.uk" do
      assert Coverage.stated_by(change("k", "s.1", :inserted, [:law_text, :feed])) ==
               :law_and_derived
    end

    test "the law's text alone" do
      assert Coverage.stated_by(change("k", "s.1", :inserted, [:law_text])) == :law_only
    end

    test "legislation.gov.uk alone, markup or feed" do
      assert Coverage.stated_by(change("k", "s.1", :inserted, [:markup, :feed])) == :derived_only
    end

    test "a gap filled from the law (a claim on another attribute) doesn't make the law a stater" do
      c = change("k", "s.1", :inserted, [:feed])

      c = %{
        c
        | claims: c.claims ++ [%Claim{source: :law_text, attribute: :territory, value: "E+W"}]
      }

      assert Coverage.stated_by(c) == :derived_only
    end
  end

  describe "text?/1" do
    test "text operations count; commencements and nil don't" do
      assert Coverage.text?(change("k", "s.1", :repealed_in_part, [:feed]))
      refute Coverage.text?(change("k", "s.1", :commenced, [:feed]))
      refute Coverage.text?(%Change{key: "k", target: "s.1", resolved: nil})
    end
  end

  describe "stated_by_split/1" do
    test "counts text changes only, by who states them" do
      changes = [
        change("a", "s.1", :inserted, [:law_text, :feed]),
        change("b", "s.2", :substituted, [:law_text]),
        change("c", "s.3", :repealed, [:feed]),
        change("d", "s.4", :repealed, [:markup]),
        change("e", "s.5", :commenced, [:feed])
      ]

      assert Coverage.stated_by_split(changes) == %{
               total: 4,
               law_and_derived: 1,
               law_only: 1,
               derived_only: 2,
               none: 0
             }
    end
  end

  describe "law_text_coverage/2 (CV-S06's table)" do
    test "places each derived-only change by the conflict report's entry for it" do
      changes = [
        change("a", "s.1", :inserted, [:law_text, :feed]),
        change("b", "s.2", :inserted, [:law_text]),
        change("c", "sch.2.para.1", :repealed, [:feed]),
        change("d", "art.Article 5(1)", :substituted, [:feed]),
        change("e", "s.9(1)", :substituted, [:feed]),
        change("f", "s.10", :substituted, [:feed]),
        change("g", "s.11", :substituted, [:feed]),
        change("h", "annex.XVII", :repealed, [:feed])
      ]

      conflicts = [
        %{kind: :uncovered, missing: :primary, key: "c", target: "sch.2.para.1"},
        %{kind: :uncovered, missing: :primary, key: "d", target: "art.Article 5(1)"},
        %{kind: :uncovered, missing: :primary, key: "e", target: "s.9(1)"},
        %{kind: :unread, key: "f", target: "s.10"},
        %{kind: :uncovered, missing: :primary, key: "h", target: "annex.XVII"},
        %{kind: :uncovered, missing: :derived, key: "b", target: "s.2"}
      ]

      assert Coverage.law_text_coverage(changes, conflicts) == %{
               total: 8,
               law_and_derived: 1,
               law_only: 1,
               read_no_rule_schedule: 2,
               read_no_rule_eu_article: 1,
               read_no_rule_body: 1,
               not_read: 1,
               other: 1
             }
    end
  end

  describe "dating/1 (CV-S08's coverage)" do
    test "text changes by what dates them" do
      changes = [
        change("a", "s.1", :inserted, [:feed]),
        change("b", "s.2", :inserted, [:feed], %{date: ~D[2020-01-01]}),
        change("c", "s.3", :inserted, [:feed], %{
          date: ~D[2020-01-01],
          commenced_by: "UK_uksi_2020_1"
        }),
        change("d", "s.4", :commenced, [:feed])
      ]

      assert Coverage.dating(changes) == %{
               total: 3,
               undated: 1,
               dated_no_commenced_by: 1,
               commenced_by_named: 1
             }
    end
  end

  describe "territory_groups/1 (CV-S05's table)" do
    test "groups the extent check's outcome counts" do
      counts = %{
        "bound:law" => 3093,
        "territory:law" => 24,
        "none:same" => 284,
        "none:same_or_not_named" => 15,
        "territory:feed" => 2,
        "territory:markup" => 1,
        "none:law_type_not_read" => 573,
        "none:law_no_powers" => 450,
        "none:unread_statement" => 328,
        "none:competence_only" => 149,
        "none:no_amending_law" => 42,
        "none:law_no_clause" => 4,
        "none:law_not_held" => 2
      }

      assert Coverage.territory_groups(counts) == %{
               total: 4967,
               law_text: 3117,
               follows_enactment: 299,
               feed_or_markup: 3,
               law_type_not_read: 573,
               no_powers: 450,
               unread_statement: 328,
               competence_only: 149,
               no_amending_law: 42,
               other: 6
             }
    end
  end
end
