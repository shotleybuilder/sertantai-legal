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
end
