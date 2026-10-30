defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.VerdictsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Verdicts

  defp file(round, seed, items) do
    %{
      "step" => "label",
      "family" => "OH&S: Occupational",
      "stratum" => "R",
      "seed" => seed,
      "round" => round,
      "items" => items
    }
  end

  defp item(id, group, verdict, fault \\ nil) do
    %{"id" => id, "group" => group, "verdict" => verdict, "fault" => fault}
  end

  describe "read/1" do
    test "keeps a well-formed file" do
      assert {:ok, %{step: "label", seed: 153, round: 11, items: [_]}} =
               Verdicts.read(file(11, 153, [item("a", "L1", "ok")]))
    end

    test "refuses an unknown verdict or fault" do
      assert {:error, _} = Verdicts.read(file(1, 1, [item("a", "L1", "fine")]))
      assert {:error, _} = Verdicts.read(file(1, 1, [item("a", "L1", "wrong", "mine")]))
    end

    test "refuses a wrong verdict without its fault" do
      assert {:error, _} = Verdicts.read(file(1, 1, [item("a", "L1", "wrong")]))
    end

    test "refuses a file missing its seed or step" do
      assert {:error, _} = Verdicts.read(Map.delete(file(1, 1, []), "seed"))
      assert {:error, _} = Verdicts.read(Map.delete(file(1, 1, []), "step"))
    end
  end

  describe "pool/1" do
    test "an item checked twice counts once, the later round's verdict standing" do
      {:ok, r10} = Verdicts.read(file(10, 153, [item("a", "L1", "wrong", "own")]))
      {:ok, r11} = Verdicts.read(file(11, 153, [item("a", "L1", "ok")]))

      assert [%{id: "a", verdict: :ok}] = Verdicts.pool([r11, r10]).items
    end

    test "carries the seeds and rounds pooled" do
      {:ok, a} = Verdicts.read(file(10, 153, [item("a", "L1", "ok")]))
      {:ok, b} = Verdicts.read(file(11, 154, [item("b", "L2", "ok")]))

      assert %{seeds: [153, 154], rounds: [10, 11], steps: ["label"]} = Verdicts.pool([a, b])
    end
  end

  describe "tally/1" do
    setup do
      {:ok, f} =
        Verdicts.read(
          file(11, 153, [
            item("a", "L1", "ok"),
            item("b", "L1", "wrong", "upstream"),
            item("c", "L2", "wrong", "own"),
            item("d", "L3", "gap"),
            item("e", "L3", "doubtful"),
            item("f", "L4", "wrong", "known")
          ])
        )

      %{tally: f |> List.wrap() |> Verdicts.pool() |> Verdicts.tally()}
    end

    test "counts against the bound only the step's own faults", %{tally: t} do
      assert t.items == %{n: 6, wrong: 1}
    end

    test "a group is wrong when any of its items counts", %{tally: t} do
      assert t.groups == %{n: 4, wrong: 1}
    end

    test "end to end counts every wrong item, whoever's fault", %{tally: t} do
      assert t.end_to_end == %{n: 6, wrong: 3}
    end

    test "lists gaps and doubtful items apart", %{tally: t} do
      assert t.gaps == ["d"]
      assert t.doubtful == ["e"]
    end
  end

  describe "verdict/3" do
    test "passes when both bounds are under their limits" do
      t = %{items: %{n: 150, wrong: 0}, groups: %{n: 73, wrong: 0}}
      assert %{pass: true, items_upper: u} = Verdicts.verdict(t, 0.02, 0.05)
      assert Float.round(100 * u, 2) == 1.98
    end

    test "fails on either bound" do
      t = %{items: %{n: 150, wrong: 0}, groups: %{n: 150, wrong: 3}}
      assert %{pass: false} = Verdicts.verdict(t, 0.02, 0.05)
    end
  end
end
