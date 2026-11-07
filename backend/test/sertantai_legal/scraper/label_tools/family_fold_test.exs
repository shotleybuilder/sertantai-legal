defmodule SertantaiLegal.Scraper.LabelTools.FamilyFoldTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LabelTools.FamilyFold

  test "results come back in the laws' order, however the folds finish" do
    laws = for i <- 1..12, do: "UK_x_#{i}"

    fold = fn law ->
      Process.sleep(:rand.uniform(30))
      [law]
    end

    assert FamilyFold.rows(laws, fold: fold, workers: 4) == Enum.map(laws, &{&1, [&1]})
  end

  test "a law that can't be folded keeps its place as its error" do
    fold = fn
      "bad" -> {:error, :no_clml}
      law -> [law]
    end

    assert [{"a", ["a"]}, {"bad", {:error, :no_clml}}, {"b", ["b"]}] =
             FamilyFold.rows(~w(a bad b), fold: fold, workers: 2)
  end

  test "a law whose fold raises fails the run, named, after the rest have run" do
    me = self()

    fold = fn
      "boom" ->
        raise "bad law"

      law ->
        send(me, {:folded, law})
        [law]
    end

    assert_raise RuntimeError, ~r/laws not folded: boom: bad law/, fn ->
      FamilyFold.rows(~w(a boom b), fold: fold, workers: 2)
    end

    assert_received {:folded, "a"}
    assert_received {:folded, "b"}
  end

  test "a law's rows come back sharing one list of its changes, not a copy each" do
    changes = for i <- 1..50, do: %{key: "k#{i}", target: "s.#{i}"}

    fold = fn law ->
      for i <- 1..20, do: %{id: "#{law}-#{i}", changes: changes, reaching: Enum.take(changes, 2)}
    end

    [{"a", [first | rest] = rows}] = FamilyFold.rows(["a"], fold: fold, workers: 1)

    assert rows == fold.("a")
    for r <- rest, do: assert(:erts_debug.same(r.changes, first.changes))
  end
end
