defmodule SertantaiLegal.Scraper.LegislationGovUk.ClmlStoreTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @xml """
  <Legislation><ukm:Metadata><dc:title>X</dc:title><dct:valid>2024-03-01</dct:valid></ukm:Metadata></Legislation>
  """

  setup do
    root = Path.join(System.tmp_dir!(), "clml_store_test_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, root: root}
  end

  describe "cacheable?/1" do
    test "legislation documents: body, fragments, introduction, contents" do
      for path <- [
            "/uksi/1992/3004/body/data.xml",
            "/uksi/1992/3004/regulation/2/data.xml",
            "/ukpga/2006/46/part/15/data.xml",
            "/uksi/1992/3004/introduction/data.xml",
            "/uksi/1992/3004/made/introduction/data.xml",
            "/eudr/2000/54/article/8/data.xml"
          ] do
        assert ClmlStore.cacheable?(path), path
      end
    end

    test "not changes feeds, new-legislation lists, search or non-XML" do
      for path <- [
            "/changes/affected/ukpga/1965/56/data.feed",
            "/new/all/2024-01-15",
            "/search?title=x",
            "/uksi/1992/3004/data.rdf",
            "/uksi/1992/3004/data.pdf"
          ] do
        refute ClmlStore.cacheable?(path), path
      end
    end
  end

  describe "put/get" do
    test "a stored document comes back with its dct:valid and fetch time", %{root: root} do
      path = "/uksi/1992/3004/regulation/2/data.xml"
      :ok = ClmlStore.put(path, @xml, root: root)

      assert {:ok, @xml, meta} = ClmlStore.get(path, root: root)
      assert meta.dct_valid == ~D[2024-03-01]
      assert %DateTime{} = meta.fetched_at
      assert File.exists?(Path.join(root, "uksi/1992/3004/regulation/2/data.xml.gz"))
    end

    test "a 404 is stored as a marker", %{root: root} do
      path = "/uksi/1992/3004/rule/2/data.xml"
      :ok = ClmlStore.put_missing(path, root: root)

      assert {:missing, %{dct_valid: nil}} = ClmlStore.get(path, root: root)
    end

    test "nothing stored", %{root: root} do
      assert ClmlStore.get("/uksi/1992/3004/body/data.xml", root: root) == :none
    end

    test "a re-put replaces the stored copy (a 404 marker too)", %{root: root} do
      path = "/uksi/2020/1/body/data.xml"
      :ok = ClmlStore.put_missing(path, root: root)
      :ok = ClmlStore.put(path, @xml, root: root)

      assert {:ok, @xml, _} = ClmlStore.get(path, root: root)
    end
  end

  describe "fresh?/3" do
    @now ~U[2026-10-07 12:00:00Z]

    test "fresh when the stored dct:valid is at least the law's latest known valid date" do
      meta = %{dct_valid: ~D[2024-03-01], fetched_at: ~U[2025-01-01 00:00:00Z]}

      assert ClmlStore.fresh?(meta, ~D[2024-03-01], now: @now)
      assert ClmlStore.fresh?(meta, ~D[2023-12-31], now: @now)
      refute ClmlStore.fresh?(meta, ~D[2024-06-01], now: @now)
    end

    test "with no date on the law (or the document), fresh within 30 days of fetching" do
      recent = %{dct_valid: ~D[2024-03-01], fetched_at: ~U[2026-09-20 00:00:00Z]}
      old = %{dct_valid: nil, fetched_at: ~U[2026-08-01 00:00:00Z]}

      assert ClmlStore.fresh?(recent, nil, now: @now)
      refute ClmlStore.fresh?(old, nil, now: @now)
      refute ClmlStore.fresh?(old, ~D[2024-01-01], now: @now)
    end
  end

  describe "dct_valid/1" do
    test "the latest <dct:valid> in a document, or nil" do
      assert ClmlStore.dct_valid(@xml) == ~D[2024-03-01]
      assert ClmlStore.dct_valid("<Legislation/>") == nil
    end
  end
end
