defmodule SertantaiLegal.Scraper.LegislationGovUk.FeedCacheTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LegislationGovUk.{ChangesFeed, ClmlStore, FeedCache}

  @feed File.read!("test/fixtures/changes_feed/uksi_1996_972.feed")

  setup do
    base = Path.join(System.tmp_dir!(), "feed_cache_test_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(base) end)
    opts = [root: Path.join(base, "clml"), dir: Path.join(base, "cache")]
    :ok = ClmlStore.put(ChangesFeed.page_path("uksi", "1996", "972", 1), @feed, root: opts[:root])
    {:ok, opts: opts}
  end

  test "the stored pages' effects, the same parsed or from the cache", %{opts: opts} do
    {:ok, parsed} = ChangesFeed.fetch("uksi", "1996", "972", store: :only, root: opts[:root])
    assert parsed != []

    assert FeedCache.effects("uksi", "1996", "972", opts) == {:ok, parsed}
    assert [cached] = File.ls!(opts[:dir])
    assert FeedCache.effects("uksi", "1996", "972", opts) == {:ok, parsed}
    assert File.ls!(opts[:dir]) == [cached]
  end

  test "a page stored since is parsed again", %{opts: opts} do
    {:ok, first} = FeedCache.effects("uksi", "1996", "972", opts)
    file = Path.join(opts[:dir], "uksi_1996_972.bin")
    before = File.read!(file)

    # the same effects with one dropped: a different page
    fewer = Regex.replace(~r/<entry>.*?<\/entry>/s, @feed, "", global: false)
    :ok = ClmlStore.put(ChangesFeed.page_path("uksi", "1996", "972", 1), fewer, root: opts[:root])

    {:ok, second} = FeedCache.effects("uksi", "1996", "972", opts)
    assert File.read!(file) != before
    assert length(second) < length(first)
  end

  test "no stored pages: the feed's own answer, nothing cached", %{opts: opts} do
    assert {:error, _} = FeedCache.effects("uksi", "2001", "1", opts)
    refute File.exists?(Path.join(opts[:dir], "uksi_2001_1.bin"))
  end
end
