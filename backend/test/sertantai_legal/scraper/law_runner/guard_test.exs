defmodule SertantaiLegal.Scraper.LawRunner.GuardTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawRunner.Guard

  defp probe(fields),
    do: Map.merge(%{mem_available_kb: 29_000_000, busy: 0.5, cores: 6, heavy: []}, fields)

  test "a quiet machine: the maximum" do
    assert {4, why} = Guard.decide(probe(%{}))
    assert why =~ "4 at once"
  end

  test "a VM running: one at a time" do
    assert {1, why} = Guard.decide(probe(%{heavy: ["qemu-system-x86_64"]}))
    assert why =~ "qemu-system-x86_64"
  end

  test "memory bounds it: (available − reserve) ÷ a law's peak, at least one" do
    assert {2, _} = Guard.decide(probe(%{mem_available_kb: 10_000_000}))
    assert {1, _} = Guard.decide(probe(%{mem_available_kb: 3_000_000}))
  end

  test "busy cores bound it: the cores not already busy" do
    assert {2, _} = Guard.decide(probe(%{busy: 3.2}))
    assert {1, _} = Guard.decide(probe(%{busy: 7.0}))
  end

  test "state not readable: one at a time" do
    assert {1, _} = Guard.decide(probe(%{mem_available_kb: nil}))
  end
end
