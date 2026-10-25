defmodule SertantaiLegal.Scraper.LawRunnerTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawRunner

  test "every law's result, handed to on_result in the caller as each finishes" do
    me = self()
    laws = for i <- 1..12, do: "UK_x_#{i}"

    results =
      LawRunner.run(laws, &String.upcase/1, fn law, r -> send(me, {:seen, law, r, self()}) end,
        workers: 4
      )

    assert results == Map.new(laws, &{&1, String.upcase(&1)})

    for law <- laws do
      assert_received {:seen, ^law, _, pid}
      assert pid == me
    end
  end

  test "a law that raises or exits is its own error; the run goes on" do
    fun = fn
      "boom" -> raise "bad law"
      "exit" -> exit(:gone)
      law -> {:ok, law}
    end

    results = LawRunner.run(~w(a boom exit b), fun, fn _, _ -> :ok end, workers: 2)

    assert results["a"] == {:ok, "a"} and results["b"] == {:ok, "b"}
    assert {:error, {:exception, "boom", "bad law"}} = results["boom"]
    assert {:error, {:exit, "exit", _}} = results["exit"]
  end

  test "laws run at once, up to workers" do
    {:ok, agent} = Agent.start_link(fn -> {0, 0} end)

    fun = fn _ ->
      Agent.update(agent, fn {now, peak} -> {now + 1, max(peak, now + 1)} end)
      Process.sleep(30)
      Agent.update(agent, fn {now, peak} -> {now - 1, peak} end)
    end

    LawRunner.run(for(i <- 1..10, do: "L#{i}"), fun, fn _, _ -> :ok end, workers: 3)
    assert {0, 3} = Agent.get(agent, & &1)
  end

  describe "how many at once" do
    import ExUnit.CaptureIO

    test "the guard decides when the caller names no workers (it says why)" do
      out =
        capture_io(fn ->
          assert LawRunner.run(~w(a b c), &String.upcase/1, fn _, _ -> :ok end) ==
                   %{"a" => "A", "b" => "B", "c" => "C"}
        end)

      assert out =~ "laws read"
    end

    test "one law runs alone, without asking the guard" do
      out =
        capture_io(fn ->
          assert LawRunner.run(~w(a), &String.upcase/1, fn _, _ -> :ok end) == %{"a" => "A"}
        end)

      assert out == ""
    end
  end

  test "the heaviest laws start first (opts[:weight])" do
    me = self()

    LawRunner.run(~w(a bbb cc), fn law -> send(me, {:started, law}) end, fn _, _ -> :ok end,
      workers: 1,
      weight: &String.length/1
    )

    assert_received {:started, "bbb"}
    started = for _ <- 1..2, do: receive(do: ({:started, l} -> l))
    assert started == ["cc", "a"]
  end
end
