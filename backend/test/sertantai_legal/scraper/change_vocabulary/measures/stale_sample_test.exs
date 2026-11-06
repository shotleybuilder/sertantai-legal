defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.StaleSampleTest do
  @moduledoc """
  The change register's staleness hand sample (Maritime Safety: Store and
  build): built and unbuilt laws drawn on a seed, each with its verdict and
  what decided it.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.StaleSample

  @built for i <- 1..40, do: "UK_uksi_2000_#{i}"
  @unbuilt for i <- 1..20, do: "UK_ukpga_1990_#{i}"

  test "one seed draws one sample, whatever the order given; another seed another" do
    a = StaleSample.draw(@built, @unbuilt, 20, 10, 1111)

    assert {b, u} = a
    assert length(b) == 20 and length(u) == 10
    assert Enum.all?(b, &(&1 in @built)) and Enum.all?(u, &(&1 in @unbuilt))
    assert a == StaleSample.draw(Enum.reverse(@built), Enum.reverse(@unbuilt), 20, 10, 1111)
    refute a == StaleSample.draw(@built, @unbuilt, 20, 10, 1112)
  end

  test "a family short of laws gives what it has" do
    assert {b, []} = StaleSample.draw(Enum.take(@built, 3), [], 20, 10, 1)
    assert length(b) == 3
  end

  test "a built item carries its event, the code and inputs now, and the verdict" do
    event = %{at: ~U[2026-11-06 10:00:00Z], provenance: %{"code_version" => "abc"}}

    assert StaleSample.item("L1", [:feed], event, "def", %{feed: "x"}) == %{
             "law" => "L1",
             "built" => true,
             "verdict" => ["feed"],
             "event_at" => "2026-11-06T10:00:00Z",
             "event" => %{"code_version" => "abc"},
             "current_code_version" => "def",
             "inputs_now" => %{"feed" => "x"}
           }
  end

  test "an unbuilt item is its law and no_build" do
    assert StaleSample.item("L2", [:no_build], nil, "def", nil) ==
             %{"law" => "L2", "built" => false, "verdict" => ["no_build"]}
  end
end
