defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.DrawTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Draw

  @items for i <- 1..200,
             do: %{id: i, law: "L#{rem(i, 7)}", kind: Enum.at([:a, :b, :c], rem(i, 3))}

  defp drawn(seed, fun) do
    Draw.seed(seed)
    fun.()
  end

  for {name, fun} <- [
        take_random: quote(do: &Draw.take_random(&1, 30, fn i -> i.id end)),
        shuffled: quote(do: &Draw.shuffled(&1, 30, fn i -> i.id end)),
        round_robin:
          quote(do: &Draw.round_robin(Enum.sort_by(&1, fn i -> i.id end), fn i -> i.kind end, 30)),
        equal_share:
          quote(do: &Draw.equal_share(Enum.sort_by(&1, fn i -> i.id end), fn i -> i.kind end, 30))
      ] do
    describe "#{name}/3" do
      test "the same seed draws the same sample" do
        draw = unquote(fun)

        assert drawn({901, 6, 6}, fn -> draw.(@items) end) ==
                 drawn({901, 6, 6}, fn -> draw.(@items) end)
      end

      test "another seed draws another sample" do
        draw = unquote(fun)

        refute drawn({901, 6, 6}, fn -> draw.(@items) end) ==
                 drawn({902, 6, 6}, fn -> draw.(@items) end)
      end

      test "the items' incoming order doesn't move the sample" do
        draw = unquote(fun)
        reversed = Enum.reverse(@items)

        assert drawn({901, 6, 6}, fn -> draw.(@items) end) ==
                 drawn({901, 6, 6}, fn -> draw.(reversed) end)
      end

      test "draws n distinct items" do
        draw = unquote(fun)
        sample = drawn({901, 6, 6}, fn -> draw.(@items) end)
        assert length(sample) == 30
        assert sample == Enum.uniq(sample)
      end
    end
  end

  test "round_robin takes one of each group in turn" do
    Draw.seed({1, 1, 1})
    assert @items |> Draw.round_robin(& &1.kind, 3) |> Enum.map(& &1.kind) == [:a, :b, :c]
  end

  test "equal_share gives every kind its share before the rest" do
    Draw.seed({1, 1, 1})
    sample = Draw.equal_share(@items, & &1.kind, 9)
    assert sample |> Enum.frequencies_by(& &1.kind) == %{a: 3, b: 3, c: 3}
  end

  test "a second draw after one seeding follows from the first" do
    Draw.seed({5, 5, 5})
    first = Draw.shuffled(@items, 10, & &1.id)
    second = Draw.shuffled(@items, 10, & &1.id)
    refute first == second

    Draw.seed({5, 5, 5})
    assert Draw.shuffled(@items, 10, & &1.id) == first
    assert Draw.shuffled(@items, 10, & &1.id) == second
  end
end
