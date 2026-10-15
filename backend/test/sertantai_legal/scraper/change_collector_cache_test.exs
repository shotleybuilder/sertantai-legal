defmodule SertantaiLegal.Scraper.ChangeCollectorCacheTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeCollector

  test "with_doc_cache/1: amending-law documents are cached for one law's collection only (LR-25)" do
    assert ChangeCollector.with_doc_cache(fn ->
             Process.put({ChangeCollector, :doc, "UK_ukpga_2000_27"}, :parsed)
             :result
           end) == :result

    refute Enum.any?(Process.get_keys(), &match?({ChangeCollector, :doc, _}, &1))
  end

  test "with_doc_cache/1 clears the cache when the collection raises" do
    assert_raise RuntimeError, fn ->
      ChangeCollector.with_doc_cache(fn ->
        Process.put({ChangeCollector, :doc, "UK_ukpga_2000_27"}, :parsed)
        raise "boom"
      end)
    end

    refute Enum.any?(Process.get_keys(), &match?({ChangeCollector, :doc, _}, &1))
  end
end
