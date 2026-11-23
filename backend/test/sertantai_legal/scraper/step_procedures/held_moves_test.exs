defmodule SertantaiLegal.Scraper.StepProcedures.HeldMovesTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.StepProcedures.HeldMoves

  defp fixtures do
    %{
      "patterns" => %{
        "patterns" => %{
          "p_ok" => %{"examples" => ["a", "b"]},
          "p_pend" => %{"examples" => ["c"]}
        }
      },
      "examples" => %{
        "a" => %{"law" => "UK_1", "sentence" => "A"},
        "b" => %{"law" => "UK_1", "sentence" => "B"},
        "c" => %{"law" => "UK_2", "sentence" => "C"}
      },
      "expected" => %{
        "patterns" => %{"p_ok" => "accepted", "p_pend" => "pending: not read"},
        "examples" => %{
          "a" => %{"class" => "dated", "rules" => ["r1"]},
          "b" => %{"class" => "dated", "rules" => ["r2"]},
          "c" => %{"class" => "none", "rules" => []}
        }
      },
      "laws" => %{"UK_1" => %{"rows" => 1}, "UK_2" => %{"rows" => 2}}
    }
  end

  # "b" now reads differently; "c" would too, but its pattern is pending
  defp reading(_laws),
    do: fn
      %{"sentence" => "B"} -> %{"class" => "dated", "rules" => ["r2", "r3"]}
      %{"sentence" => "C"} -> %{"class" => "dated", "rules" => ["x"]}
      %{"sentence" => "A"} -> %{"class" => "dated", "rules" => ["r1"]}
      %{"sentence" => "N"} -> %{"class" => "staged", "rules" => ["n"]}
    end

  describe "moves/2" do
    test "the held, non-pending examples whose reading moved, with the held and the new reading" do
      assert HeldMoves.moves(fixtures(), reading(nil)) == %{
               "b" => %{
                 held: %{"class" => "dated", "rules" => ["r2"]},
                 now: %{"class" => "dated", "rules" => ["r2", "r3"]}
               }
             }
    end

    test "no move when every reading is as held" do
      assert HeldMoves.moves(fixtures(), fn e -> fixtures()["expected"]["examples"][key(e)] end) ==
               %{}
    end
  end

  test "write_moves/2 puts the new readings into expected" do
    f = HeldMoves.write_moves(fixtures(), HeldMoves.moves(fixtures(), reading(nil)))
    assert f["expected"]["examples"]["b"] == %{"class" => "dated", "rules" => ["r2", "r3"]}
    assert f["expected"]["examples"]["a"] == fixtures()["expected"]["examples"]["a"]
    assert f["patterns"] == fixtures()["patterns"]
  end

  describe "add_new/4" do
    defp dry do
      %{
        "patterns" => %{
          "patterns" => %{
            "p_ok" => %{"examples" => ["a"]},
            "p_new" => %{"examples" => ["b", "n"]},
            "p_new2" => %{"examples" => ["m"]}
          }
        },
        "examples" => %{
          "b" => %{"law" => "UK_1", "sentence" => "B"},
          "n" => %{"law" => "UK_3", "sentence" => "N"},
          "m" => %{"law" => "UK_1", "sentence" => "A"}
        },
        "laws" => %{"UK_1" => %{"rows" => 1}, "UK_3" => %{"rows" => 3}}
      }
    end

    test "new patterns come in with their examples, laws and readings; an example moving leaves its old pattern" do
      {f, summary} =
        HeldMoves.add_new(fixtures(), dry(), %{"p_new2" => "pending: a form"}, &reading/1)

      assert f["patterns"]["patterns"]["p_new"] == %{"examples" => ["b", "n"]}
      assert f["patterns"]["patterns"]["p_ok"] == %{"examples" => ["a"]}
      assert f["expected"]["patterns"]["p_new"] == "accepted"
      assert f["expected"]["patterns"]["p_new2"] == "pending: a form"
      assert f["examples"]["n"] == %{"law" => "UK_3", "sentence" => "N"}
      assert f["laws"]["UK_3"] == %{"rows" => 3}
      assert f["expected"]["examples"]["n"] == %{"class" => "staged", "rules" => ["n"]}
      assert f["expected"]["examples"]["b"] == %{"class" => "dated", "rules" => ["r2", "r3"]}
      assert summary.new == ["p_new", "p_new2"]
      assert summary.emptied == []
    end

    test "a pattern left with no example is dropped, from patterns and statuses" do
      dry = put_in(dry(), ["patterns", "patterns", "p_new"], %{"examples" => ["a", "b"]})
      {f, summary} = HeldMoves.add_new(fixtures(), dry, %{}, &reading/1)
      refute Map.has_key?(f["patterns"]["patterns"], "p_ok")
      refute Map.has_key?(f["expected"]["patterns"], "p_ok")
      assert summary.emptied == ["p_ok"]
    end

    test "the orders catalogue has no laws file" do
      {f, _} =
        HeldMoves.add_new(
          Map.delete(fixtures(), "laws"),
          Map.delete(dry(), "laws"),
          %{},
          &reading/1
        )

      refute Map.has_key?(f, "laws")
    end
  end

  defp key(%{"sentence" => s}), do: String.downcase(s)
end
