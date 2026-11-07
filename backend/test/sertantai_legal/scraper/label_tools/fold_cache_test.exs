defmodule SertantaiLegal.Scraper.LabelTools.FoldCacheTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LabelTools.FoldCache

  @inputs %{
    version: "v1",
    build: 41,
    timeline: "t-md5",
    articles: "a-md5",
    register: {~D[2001-01-01], "A Law"},
    clml: {100, 1_700_000_000}
  }

  # two rows sharing the law's changes, each reaching some of them
  defp folded do
    changes = [
      %{key: "k1", target: "s.1"},
      %{key: "k2", target: "s.2"},
      %{key: "k3", target: "*"}
    ]

    for {id, reach} <- [{"s.1", [0, 2]}, {"s.2", [1, 2]}] do
      %{
        id: id,
        sid: "UK_x:" <> id,
        changes: changes,
        reaching: Enum.map(reach, &Enum.at(changes, &1))
      }
    end
  end

  setup do
    dir = Path.join(System.tmp_dir!(), "fold-cache-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  defp counting_fold(result) do
    me = self()

    fn law ->
      send(me, {:folded, law})
      result
    end
  end

  describe "key/1" do
    test "the same inputs give the same key" do
      assert FoldCache.key(@inputs) == FoldCache.key(Map.new(@inputs))
    end

    test "any input moving moves the key" do
      for {field, value} <- [
            version: "v2",
            build: 42,
            timeline: "t2",
            articles: "a2",
            register: {~D[2001-01-01], "Renamed"},
            clml: {101, 1_700_000_000}
          ] do
        refute FoldCache.key(%{@inputs | field => value}) == FoldCache.key(@inputs), "#{field}"
      end
    end
  end

  describe "pack/1 and unpack/1" do
    test "round-trip to an equal term, the changes stored once" do
      rows = folded()
      assert rows |> FoldCache.pack() |> FoldCache.unpack() == rows
      assert {:packed, [_, _, _], _} = FoldCache.pack(rows)
    end

    test "no rows round-trip" do
      assert [] |> FoldCache.pack() |> FoldCache.unpack() == []
    end
  end

  describe "rows/2" do
    test "folds once; the second call reads the cache", %{dir: dir} do
      opts = [dir: dir, inputs: fn _ -> @inputs end, fold: counting_fold(folded())]

      assert FoldCache.rows("UK_x", opts) == folded()
      assert_received {:folded, "UK_x"}
      assert FoldCache.rows("UK_x", opts) == folded()
      refute_received {:folded, _}
    end

    test "an input that moved folds again", %{dir: dir} do
      opts = [dir: dir, fold: counting_fold(folded())]
      FoldCache.rows("UK_x", [inputs: fn _ -> @inputs end] ++ opts)
      assert_received {:folded, _}

      FoldCache.rows("UK_x", [inputs: fn _ -> %{@inputs | build: 42} end] ++ opts)
      assert_received {:folded, _}
    end

    test "an error is returned, never stored", %{dir: dir} do
      opts = [dir: dir, inputs: fn _ -> @inputs end, fold: counting_fold({:error, :no_clml})]

      assert FoldCache.rows("UK_x", opts) == {:error, :no_clml}
      assert FoldCache.rows("UK_x", opts) == {:error, :no_clml}
      assert_received {:folded, _}
      assert_received {:folded, _}
    end

    test "a file that isn't a cache entry is a miss, folded again", %{dir: dir} do
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "UK_x.etf"), "not a term")
      opts = [dir: dir, inputs: fn _ -> @inputs end, fold: counting_fold(folded())]

      assert FoldCache.rows("UK_x", opts) == folded()
      assert_received {:folded, _}
    end

    test "cache: false always folds and writes nothing", %{dir: dir} do
      opts = [dir: dir, inputs: fn _ -> @inputs end, fold: counting_fold(folded()), cache: false]

      FoldCache.rows("UK_x", opts)
      FoldCache.rows("UK_x", opts)
      assert_received {:folded, _}
      assert_received {:folded, _}
      refute File.exists?(dir)
    end
  end
end
