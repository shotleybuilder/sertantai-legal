defmodule SertantaiLegal.Scraper.CatalogueCacheTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.CatalogueCache

  setup do
    dir =
      Path.join(System.tmp_dir!(), "catalogue_cache_test_#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, opts: [dir: dir]}
  end

  defp fetch(version, inputs, result, opts),
    do: CatalogueCache.fetch("cat", "UK_ukpga_2001_1", version, inputs, fn -> result end, opts)

  test "a hit is the result stored", %{opts: opts} do
    assert fetch("v1", {:rows, [1]}, %{n: 1}, opts) == {%{n: 1}, :read}
    assert fetch("v1", {:rows, [1]}, :not_computed, opts) == {%{n: 1}, :hit}
  end

  test "changed inputs read again", %{opts: opts} do
    fetch("v1", {:rows, [1]}, :first, opts)
    assert fetch("v1", {:rows, [2]}, :second, opts) == {:second, :read}
  end

  test "a moved code version reads again", %{opts: opts} do
    fetch("v1", {:rows, [1]}, :first, opts)
    assert fetch("v2", {:rows, [1]}, :second, opts) == {:second, :read}
  end

  test "a file that won't decode reads again", %{opts: opts} do
    fetch("v1", {:rows, [1]}, :first, opts)
    File.write!(Path.join([opts[:dir], "cat", "UK_ukpga_2001_1.bin"]), "not a term")
    assert fetch("v1", {:rows, [1]}, :second, opts) == {:second, :read}
  end

  test "cache: false always computes and stores nothing", %{opts: opts} do
    assert fetch("v1", {:rows, [1]}, :first, [{:cache, false} | opts]) == {:first, :read}
    refute File.exists?(Path.join([opts[:dir], "cat", "UK_ukpga_2001_1.bin"]))
  end

  test "a file's digest, nil for none" do
    assert CatalogueCache.file_digest(nil) == nil
    assert CatalogueCache.file_digest("no/such/file") == nil
    assert byte_size(CatalogueCache.file_digest(__ENV__.file)) == 16
  end

  test "the cache line" do
    assert CatalogueCache.summary([:hit, :read, :hit]) == "cache: 2 hits, 1 read"
  end
end
