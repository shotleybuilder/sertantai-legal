defmodule SertantaiLegal.Scraper.ChangeVocabulary.ConflictsTest do
  @moduledoc """
  The conflict report (CV-04): where the law's text and legislation.gov.uk
  disagree — inside a change, unjoined twins, and changes one side alone
  states. Cases from TCPA 1990 and HSWA 1974 (measured 2026-10-22).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Conflicts, Evidence}

  defp change(key, target, claims) do
    %Change{
      key: key,
      target: target,
      claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})
    }
    |> Evidence.resolve("E+W")
  end

  test "like for like: a substitution the markup shows as an insertion is no conflict; a whole repeal against one in part is" do
    sub =
      change("k1", "s.280", [
        {:law_text, :operation, :substituted},
        {:law_text, :by, "UK_ukpga_2003_21"},
        {:markup, :operation, :inserted}
      ])

    rep =
      change("k2", "s.9", [
        {:law_text, :operation, :repealed},
        {:law_text, :by, "UK_ukpga_2003_21"},
        {:feed, :operation, :repealed_in_part}
      ])

    assert Conflicts.values(sub) == []

    assert [{:operation, {:law_text, :repealed}, {:feed, :repealed_in_part}}] =
             Conflicts.values(rep)
  end

  test "the order commencing a change is not the law making it: no conflict" do
    c =
      change("k3", "s.78(4BA)", [
        {:feed, :operation, :commenced},
        {:feed, :by, "UK_anaw_2015_4"},
        {:commencement, :commenced_by, "UK_wsi_2016_52"},
        {:feed, :date, ~D[2016-03-16]}
      ])

    assert c.resolved.by == "UK_anaw_2015_4"
    assert c.resolved.commenced_by == "UK_wsi_2016_52"
    assert Change.credit(c) == "UK_wsi_2016_52"
    assert Conflicts.values(c) == []
  end

  test "a text-only change beside a legislation.gov.uk-only change by the same law, one level apart, is unjoined" do
    p =
      change("UK_ukpga_2005_14:schedule-13", "s.78(7)", [
        {:law_text, :operation, :repealed},
        {:law_text, :level, :provision},
        {:law_text, :by, "UK_ukpga_2005_14"}
      ])

    d =
      change("key-b", "s.78(7)(c)", [
        {:feed, :operation, :repealed},
        {:feed, :by, "UK_ukpga_2005_14"},
        {:feed, :date, ~D[2006-04-01]}
      ])

    # its amending provision (Sch. 13 para. 4) was read: no rule there
    other =
      change("key-c", "s.80", [
        {:feed, :operation, :inserted},
        {:feed, :by, "UK_ukpga_2005_14"},
        {:feed, :date, ~D[2006-04-01]},
        {:feed, :affecting, ["sch.13.para.4"]}
      ])

    # its amending provision (s.40) was not read: coverage
    unread =
      change("key-d", "s.81", [
        {:feed, :operation, :inserted},
        {:feed, :by, "UK_ukpga_2005_14"},
        {:feed, :affecting, ["s.40(2)"]}
      ])

    alone =
      change("UK_ukpga_2005_14:section-9", "s.12", [
        {:law_text, :operation, :inserted},
        {:law_text, :by, "UK_ukpga_2005_14"}
      ])

    report = Conflicts.report([p, d, other, alone, unread])

    assert [%{kind: :unjoined, target: "s.78(7)", twins: [{"key-b", "s.78(7)(c)", :repealed}]}] =
             Enum.filter(report, &(&1.kind == :unjoined))

    uncovered =
      report |> Enum.filter(&(&1.kind == :uncovered)) |> Enum.map(&{&1.target, &1.missing})

    # s.80: the law's text was read, no rule for it; s.12: no record from legislation.gov.uk
    assert Enum.sort(uncovered) == [{"s.12", :derived}, {"s.80", :primary}]
    assert [%{kind: :unread, target: "s.81"}] = Enum.filter(report, &(&1.kind == :unread))
  end

  test "our own inference of an affecting law's territory is not legislation.gov.uk's: no conflict" do
    c =
      change("k5", "s.4(6)", [
        {:law_text, :territory, "E+W"},
        {:law_text, :by, "UK_ukpga_2005_15"},
        {:law, :territory, "E+W+S"}
      ])

    assert Conflicts.values(c) == []
  end
end
