defmodule SertantaiLegal.Scraper.ChangeCollector.CompactTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeCollector.{Compact, Record}

  @law "UK_ukpga_1991_22"
  @order Enum.map(
           ["pt.III", "h.48", "s.48", "s.48(1)", "s.48(2)", "h.49", "s.49", "s.50"],
           &"#{@law}:#{&1}"
         )

  defp rec(sid, ev \\ "key-a", via \\ ["ref"], pointer \\ nil),
    do: %Record{
      law_name: @law,
      source: "effect",
      evidence: ev,
      section_id: sid,
      via: via,
      pointer: pointer
    }

  defp sid(s), do: "#{@law}:#{s}"

  test "consecutive rows of one change, join and pointer: one record from first to last" do
    recs = for s <- ["s.48", "s.48(1)", "s.48(2)", "h.49", "s.49"], do: rec(sid(s))

    assert [%Record{section_id: "UK_ukpga_1991_22:s.48", section_id_to: "UK_ukpga_1991_22:s.49"}] =
             Compact.compact(recs, @order)
  end

  test "a gap in document order splits the run; a single row keeps no end" do
    recs = for s <- ["s.48", "s.48(1)", "s.49"], do: rec(sid(s))

    assert Compact.compact(recs, @order) |> Enum.map(&{&1.section_id, &1.section_id_to}) == [
             {sid("s.48"), sid("s.48(1)")},
             {sid("s.49"), nil}
           ]
  end

  test "different joins, pointers or changes are never merged" do
    recs = [
      rec(sid("s.48")),
      rec(sid("s.48(1)"), "key-a", ["markup"]),
      rec(sid("s.48(2)"), "key-b")
    ]

    assert length(Compact.compact(recs, @order)) == 3
  end

  test "records with no row pass through" do
    assert [%Record{section_id: nil}] = Compact.compact([rec(nil)], @order)
  end

  test "expand/2 is the inverse: the same row set (the fidelity gate)" do
    recs =
      for(s <- ["pt.III", "h.48", "s.48", "s.48(2)", "s.50"], do: rec(sid(s))) ++
        [rec(sid("s.49"), "key-b", ["markup"]), rec(nil, "key-z", [])]

    key = &{&1.evidence, &1.section_id, &1.via, &1.pointer}

    assert recs
           |> Compact.compact(@order)
           |> Compact.expand(@order)
           |> Enum.map(key)
           |> Enum.sort() ==
             recs |> Enum.map(key) |> Enum.sort()
  end

  test "CR-06: one clause dating consecutive rows differently is two changes, never merged (1990/43 s.164(2))" do
    full = %{rec(sid("s.48")) | effective_from: ~D[1991-01-01]}
    partial = %{rec(sid("s.48(1)")) | effective_from: nil, in_force: [%{"date" => "1991-01-01"}]}

    assert length(Compact.compact([full, partial], @order)) == 2
  end
end
