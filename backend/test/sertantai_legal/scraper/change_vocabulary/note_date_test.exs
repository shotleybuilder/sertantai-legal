defmodule SertantaiLegal.Scraper.ChangeVocabulary.NoteDateTest do
  @moduledoc """
  A change no source dates, dated from the amending law's own commencement
  text at the provision its note names (CV-07; Jason 2026-10-22: "Use Notes
  as pointers when we have a gap. We can always get a date from the actual
  amending law.")
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.NoteDate
  alias SertantaiLegal.Scraper.Commencement.Rule

  defp rule(law, scope, when_),
    do:
      Rule.new(
        commences: law,
        scope: scope,
        when: when_,
        source: %{law: law, ref: "s.4", text: nil},
        treatment: :clause_date
      )

  defp change(claims),
    do: %Change{
      key: "d29p11050",
      target: "s.89",
      claims:
        for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: "d29p11050"})
    }

  defp commencement,
    do: %{
      "UK_ukpga_1989_22" => [
        rule("UK_ukpga_1989_22", ["sch.3"], {:date, ~D[1989-09-01]}),
        rule("UK_ukpga_1989_22", ["s.106"], {:date, ~D[1990-01-01]})
      ]
    }

  test "dated at the provision the note names, by the amending law's commencement" do
    c =
      change([
        {:markup, :operation, :inserted},
        {:markup, :cited, "UK_ukpga_1989_22"},
        {:markup, :affecting, ["sch.3.para.8(e)"]}
      ])

    assert [
             %Claim{source: :commencement, attribute: :date, value: ~D[1989-09-01]},
             %Claim{attribute: :via, value: :note}
           ] =
             NoteDate.claims(c, commencement())
  end

  test "an introducing section beside the paragraph: the paragraph decides" do
    c =
      change([
        {:markup, :operation, :inserted},
        {:markup, :cited, "UK_ukpga_1989_22"},
        {:markup, :affecting, ["s.106", "sch.3.para.8(e)"]}
      ])

    assert [%Claim{value: ~D[1989-09-01]} | _] = NoteDate.claims(c, commencement())
  end

  test "no gap, no pointer: nothing" do
    dated =
      change([
        {:markup, :operation, :inserted},
        {:markup, :cited, "UK_ukpga_1989_22"},
        {:markup, :affecting, ["sch.3.para.8(e)"]},
        {:feed, :date, ~D[1990-02-02]}
      ])

    assert NoteDate.claims(dated, commencement()) == []

    unpointed = change([{:markup, :operation, :inserted}, {:markup, :cited, "UK_ukpga_1989_22"}])
    assert NoteDate.claims(unpointed, commencement()) == []
  end

  test "named provisions disagreeing on the date: no date (a visible gap)" do
    c =
      change([
        {:markup, :operation, :inserted},
        {:markup, :cited, "UK_ukpga_1989_22"},
        {:markup, :affecting, ["sch.3.para.8(e)", "sch.4.para.1(a)"]}
      ])

    rules = %{
      "UK_ukpga_1989_22" => [
        rule("UK_ukpga_1989_22", ["sch.3"], {:date, ~D[1989-09-01]}),
        rule("UK_ukpga_1989_22", ["sch.4"], {:date, ~D[1991-01-01]})
      ]
    }

    assert NoteDate.claims(c, rules) == []
  end

  test "a feed record with no date: the provision the feed names points (SI 1995/2923 on Factories Act 1961 s.138)" do
    c = %Change{
      key: "key-x",
      target: "s.138",
      claims: [
        %Claim{source: :feed, attribute: :operation, value: :repealed, ref: "key-x"},
        %Claim{source: :feed, attribute: :by, value: "UK_ukpga_1989_22", ref: "key-x"},
        %Claim{source: :feed, attribute: :affecting, value: ["sch.3.para.8(e)"], ref: "key-x"}
      ]
    }

    assert [%Claim{value: ~D[1989-09-01]}, %Claim{attribute: :via, value: :feed}] =
             NoteDate.claims(c, commencement())
  end

  describe "the amending law's extent for a change no feed record carries (SI 2008/1597 reg.14(1), SI 2019/696)" do
    alias SertantaiLegal.Scraper.AmendingLaw.Extent

    @gb %Extent{default: "E+W+S"}

    defp markup_change(op),
      do:
        change([
          {:markup, :operation, op},
          {:markup, :cited, "UK_uksi_2019_696"},
          {:markup, :affecting, ["sch.12.para.12(3)(c)"]}
        ])

    test "claimed from the law the note cites" do
      assert [%Claim{source: :law_text, attribute: :extent, value: "E+W+S"}] =
               NoteDate.extent_claims(markup_change(:substituted), %{"UK_uksi_2019_696" => @gb})
    end

    test "with no provision named, the law's own extent" do
      c = change([{:markup, :operation, :substituted}, {:markup, :cited, "UK_uksi_2019_696"}])
      assert [%Claim{value: "E+W+S"}] = NoteDate.extent_claims(c, %{"UK_uksi_2019_696" => @gb})
    end

    test "not where a source already claims it, nor a competence alone for an insertion (V1-04)" do
      c = markup_change(:substituted)

      c = %{
        c
        | claims:
            c.claims ++ [%Claim{source: :law_text, attribute: :extent, value: "E+W", ref: "x"}]
      }

      assert NoteDate.extent_claims(c, %{"UK_uksi_2019_696" => @gb}) == []

      assert NoteDate.extent_claims(markup_change(:inserted), %{
               "UK_uksi_2019_696" => %Extent{competence: "E+W"}
             }) == []
    end
  end

  describe "why/2: every undated change accounted for (CV-S04)" do
    defp pointed(law \\ "UK_ukpga_1989_22", refs \\ ["sch.3.para.8(e)"]),
      do:
        change([
          {:markup, :operation, :inserted},
          {:markup, :cited, law},
          {:markup, :affecting, refs}
        ])

    test "dated, and by which pointer; not a gap where a source dates it" do
      assert NoteDate.why(pointed(), commencement()) == {:dated, ~D[1989-09-01], :note}

      dated = %{
        pointed()
        | claims: pointed().claims ++ change([{:feed, :date, ~D[1990-02-02]}]).claims
      }

      assert NoteDate.why(dated, commencement()) == :not_a_gap
    end

    test "no law named, no provision named, the law's rules not held" do
      assert NoteDate.why(change([{:markup, :operation, :inserted}]), commencement()) ==
               {:undated, :no_amending_law}

      assert NoteDate.why(pointed("UK_ukpga_1989_22", []), commencement()) ==
               {:undated, :no_pointer}

      assert NoteDate.why(pointed("UK_ukpga_2000_1"), commencement()) ==
               {:undated, :rules_not_held}
    end

    test "only rules that aren't the law's own text (a staged clause's start)" do
      staged = %{
        rule("UK_ukpga_1989_22", :all, {:date, ~D[1989-07-27]})
        | treatment: :clause_staged
      }

      assert NoteDate.why(pointed(), %{"UK_ukpga_1989_22" => [staged]}) ==
               {:undated, :no_text_rules}
    end

    test "an Act with no clause: in force on Royal Assent (Jason 2026-10-23)" do
      assent = %{
        rule("UK_ukpga_1989_22", :all, {:date, ~D[1989-07-27]})
        | treatment: :act_enactment
      }

      assert NoteDate.why(pointed(), %{"UK_ukpga_1989_22" => [assent]}) ==
               {:dated, ~D[1989-07-27], :note}
    end

    test "left to an order no rule dates; reached by no rule; provisions disagreeing" do
      appointed = %{
        "UK_ukpga_1989_22" => [rule("UK_ukpga_1989_22", ["sch.3"], {:appointed, "order"})]
      }

      assert NoteDate.why(pointed(), appointed) == {:undated, :appointed}

      other = %{
        "UK_ukpga_1989_22" => [rule("UK_ukpga_1989_22", ["s.1"], {:date, ~D[1989-09-01]})]
      }

      assert NoteDate.why(pointed(), other) == {:undated, :not_reached}

      both = pointed("UK_ukpga_1989_22", ["sch.3.para.8(e)", "s.106"])
      # the paragraph decides over a shallower section …
      assert {:dated, _, _} = NoteDate.why(both, commencement())

      # … two at one depth disagreeing give no date
      two = pointed("UK_ukpga_1989_22", ["sch.3.para.8(e)", "sch.4.para.1(a)"])

      rules = %{
        "UK_ukpga_1989_22" => [
          rule("UK_ukpga_1989_22", ["sch.3"], {:date, ~D[1989-09-01]}),
          rule("UK_ukpga_1989_22", ["sch.4"], {:date, ~D[1991-01-01]})
        ]
      }

      assert NoteDate.why(two, rules) == {:undated, :provisions_disagree}
    end
  end
end
