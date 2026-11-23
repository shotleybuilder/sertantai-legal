defmodule SertantaiLegal.Scraper.Commencement.AmendingPicksTest do
  @moduledoc """
  The amending Acts and the orders their notes cite that `mix
  lat.commencement`'s round-wide modes read come from the change register
  (the built laws' stored changes and their rows' notes), never from the
  old label path's register (Commencement reader decouple, 2026-11-23).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.AmendingPicks

  test "acts/1: every Act among the held amenders, whichever way it was sorted; never an SI" do
    picked = %{
      read: [{"UK_ukpga_1995_25", 9}, {"UK_uksi_2018_667", 12}],
      orders: [{"UK_uksi_1996_186", 4}],
      lat: [{"UK_ukpga_1974_37", 3}, {"UK_asp_2003_2", 1}],
      not_held: [{"UK_nia_2016_2", 1}, {"EU_dir_2000_60", 1}]
    }

    assert AmendingPicks.acts(picked) ==
             ["UK_asp_2003_2", "UK_nia_2016_2", "UK_ukpga_1974_37", "UK_ukpga_1995_25"]
  end

  defp note(code, text, law),
    do: %{code: code, text: text, citation_law: law, affected_sections: nil}

  test "cited/2: the orders a text change's note cites after its amending provision, per picked Act" do
    notes = [
      note(
        "F:a1",
        "Reg. 18(14A) inserted (6.4.2014) by Enterprise and Regulatory Reform Act 2013 (c. 24), s. 103(3), Sch. 3 para. 6; S.I. 2014/253, art. 3(h)",
        "UK_ukpga_2013_24"
      ),
      note(
        "F:a2",
        "Words in s. 2 substituted (1.10.2014) by Enterprise and Regulatory Reform Act 2013 (c. 24), s. 70(1); S.I. 2014/2481, art. 2; S.I. 2014/253, art. 4",
        "UK_ukpga_2013_24"
      ),
      # an Act not picked: its notes are not read
      note(
        "F:a3",
        "S. 4 repealed (1.4.1999) by Some Act 1998 (c. 9), s. 1; S.I. 1999/1, art. 2",
        "UK_ukpga_1998_9"
      ),
      # a modification note is not a text change's
      note(
        "C:a4",
        "S. 36A: power to apply conferred (1.4.2015) by Food (Scotland) Act 2015 (asp 1), s. 49(2); S.S.I. 2015/99, art. 2",
        "UK_ukpga_2013_24"
      )
    ]

    assert AmendingPicks.cited(notes, ["UK_ukpga_2013_24"]) ==
             %{"UK_ukpga_2013_24" => ["UK_uksi_2014_2481", "UK_uksi_2014_253"]}
  end

  test "cited/2: a note citing no order picks none" do
    notes = [
      note("F:b1", "S. 1 substituted (1.1.2000) by Act 1999 (c. 1), s. 2", "UK_ukpga_1999_1")
    ]

    assert AmendingPicks.cited(notes, ["UK_ukpga_1999_1"]) == %{}
  end
end
