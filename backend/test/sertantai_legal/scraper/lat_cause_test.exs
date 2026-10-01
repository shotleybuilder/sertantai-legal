defmodule SertantaiLegal.Scraper.LatCauseTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatCause

  defp facts(overrides) do
    Map.merge(
      %{
        first?: false,
        explicit: nil,
        scope_changed?: false,
        same_source?: false,
        new_change_ids?: false,
        status_changed?: false,
        content_changed?: true
      },
      Map.new(overrides)
    )
  end

  describe "decide/1" do
    test "a law's first LAT is initial (first observed, not necessarily as made)" do
      assert LatCause.decide(facts(first?: true, new_change_ids?: true)) == "initial"
    end

    test "an explicit correction or scope wins over inference" do
      assert LatCause.decide(facts(explicit: "correction", same_source?: true)) == "correction"
      assert LatCause.decide(facts(explicit: "scope")) == "scope"
    end

    test "different fetched paths (scope widened/narrowed) → scope" do
      assert LatCause.decide(facts(scope_changed?: true, new_change_ids?: true)) == "scope"
    end

    test "the same source CLML → parser (exact: only legal's code changed)" do
      assert LatCause.decide(facts(same_source?: true, status_changed?: true)) == "parser"
    end

    test "a changed source with evidence (new notes or a status change) → legislative" do
      assert LatCause.decide(facts(new_change_ids?: true)) == "legislative"

      assert LatCause.decide(facts(status_changed?: true, content_changed?: false)) ==
               "legislative"
    end

    test "no evidence and unchanged content → parser (nothing legal changed)" do
      assert LatCause.decide(facts(content_changed?: false)) == "parser"
    end

    test "a changed source with changed content but no evidence → unattributed (never versioned)" do
      assert LatCause.decide(facts([])) == "unattributed"
    end

    test "every outcome is one of the agreed causes" do
      assert LatCause.causes() == ~w(initial legislative parser scope correction unattributed)
    end
  end

  describe "source_hash/1 and valid_date/1" do
    @xml ~s(<Legislation><ukm:Metadata><dct:valid>2024-01-01</dct:valid></ukm:Metadata><Body/></Legislation>)

    test "SHA-256 hex of the fetched documents, order-sensitive" do
      assert LatCause.source_hash([@xml]) ==
               :crypto.hash(:sha256, @xml) |> Base.encode16(case: :lower)

      refute LatCause.source_hash(["a", "b"]) == LatCause.source_hash(["b", "a"])
      assert LatCause.source_hash([]) == nil
    end

    test "valid_date: the latest <dct:valid> across documents; nil when absent" do
      other = String.replace(@xml, "2024-01-01", "2025-03-31")
      assert LatCause.valid_date([@xml, other]) == ~D[2025-03-31]
      assert LatCause.valid_date(["<Legislation/>"]) == nil
    end
  end
end
