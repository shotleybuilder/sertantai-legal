defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.HandSampleTest do
  @moduledoc """
  The measures' hand-check sample (Maritime Safety: Measures): text
  changes drawn on a seed, each with the classes the measures give it.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.HandSample

  defp change(key, target, operation, sources, resolved \\ %{}) do
    %Change{
      key: key,
      target: target,
      claims: for(s <- sources, do: %Claim{source: s, attribute: :operation, value: operation}),
      resolved:
        struct(
          %Evidence.Resolved{
            operation: operation,
            level: :provision,
            territory: nil,
            date: nil,
            by: "A",
            retained: false,
            partial: false,
            saved: false,
            sources: %{}
          },
          resolved
        )
    }
  end

  defp law(name, n),
    do:
      {name,
       for(i <- 1..n, do: change("k#{i}", "s.#{i}", :inserted, [:law_text, :feed])) ++
         [change("c", "s.0", :commenced, [:feed])]}

  test "the population is the text changes of each law" do
    pop = HandSample.population([law("L1", 3), law("L2", 2)])

    assert length(pop) == 5

    assert Enum.all?(pop, fn {_law, c, _conflicts, _strata} ->
             c.resolved.operation == :inserted
           end)
  end

  test "one seed draws one sample; another seed another" do
    pop = HandSample.population([law("L1", 30), law("L2", 30)])
    key = fn items -> Enum.map(items, &{&1["law"], &1["target"]}) end

    a = pop |> HandSample.draw(10, 7) |> key.()
    assert a == pop |> HandSample.draw(10, 7) |> key.()
    assert a == pop |> Enum.reverse() |> HandSample.draw(10, 7) |> key.()
    refute a == pop |> HandSample.draw(10, 8) |> key.()
  end

  test "each item carries the measures' classes" do
    dated = change("k1", "s.1", :substituted, [:feed], %{date: ~D[2020-01-01]})
    [item] = [{"L1", [dated]}] |> HandSample.population() |> HandSample.draw(1, 1)

    assert %{
             "n" => 1,
             "law" => "L1",
             "target" => "s.1",
             "classes" => %{
               "stated_by" => "derived_only",
               "dating" => "dated_no_commenced_by",
               "law_text_coverage" => _,
               "merge_stratum" => _
             }
           } = item

    assert item["resolved"]["date"] == "2020-01-01"
  end

  test "the sources map has string keys, so its JSON order replicates" do
    c = change("k1", "s.1", :substituted, [:feed], %{sources: %{operation: :feed, date: nil}})
    [item] = [{"L1", [c]}] |> HandSample.population() |> HandSample.draw(1, 1)

    assert item["resolved"]["sources"] == %{"operation" => "feed", "date" => nil}
  end
end
