defmodule SertantaiLegal.Scraper.EnactedBy.EnablingCacheParserTest do
  @moduledoc """
  Each enabling cache entry records the parser that wrote it
  (`EnablingCache.ParserVersion`): one by older code, or from before
  entries recorded it (a bare list), is re-parsed from the introduction
  held, never fetched (the Extent reader stamps session). The CLML store
  is a temporary root holding one SI's made introduction (the app config's:
  not async); the cache is a temporary folder.
  """
  use SertantaiLegal.DataCase, async: false

  alias SertantaiLegal.Scraper.EnactedBy.EnablingCache
  alias SertantaiLegal.Scraper.EnactedBy.EnablingCache.ParserVersion

  # an SI whose made introduction is held (made under the European
  # Communities Act 1972 s.2)
  @held "UK_uksi_2008_1597"

  setup do
    # its introduction, copied from the CLML store into a temporary root
    root = Path.join(System.tmp_dir!(), "clml-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "uksi/2008/1597"))
    File.cp_r!("data/cache/clml/uksi/2008/1597/made", Path.join(root, "uksi/2008/1597/made"))
    old = Application.get_env(:sertantai_legal, :clml_store_dir)
    Application.put_env(:sertantai_legal, :clml_store_dir, root)

    on_exit(fn ->
      Application.put_env(:sertantai_legal, :clml_store_dir, old)
      File.rm_rf!(root)
    end)
  end

  defp dir do
    d = Path.join(System.tmp_dir!(), "enabling-#{System.unique_integer([:positive])}")
    File.mkdir_p!(d)
    on_exit(fn -> File.rm_rf!(d) end)
    d
  end

  defp write(dir, name, term),
    do: File.write!(Path.join(dir, name <> ".json"), Jason.encode!(term))

  defp read(dir, name), do: dir |> Path.join(name <> ".json") |> File.read!() |> Jason.decode!()

  describe "entries carry the parser that wrote them (the Extent reader stamps session)" do
    test "an entry from before (a bare list) is re-parsed from the introduction held, never fetched" do
      d = dir()
      write(d, @held, [%{"law" => "UK_ukpga_2099_1", "sections" => ["9"], "schedules" => []}])

      # (what this parser reads in it here: the register's titles are the
      # test database's)
      assert {:ok, parsed} = EnablingCache.from_store(@held)
      assert EnablingCache.cached(@held, dir: d) == {:ok, parsed}

      assert %{"parser" => v, "provisions" => ^parsed} = read(d, @held)
      assert v == ParserVersion.current()
    end

    test "an entry by another parser is re-parsed; by this one, read as it is" do
      d = dir()
      odd = [%{"law" => "UK_ukpga_2099_1", "sections" => ["9"], "schedules" => []}]

      write(d, @held, %{"parser" => "0000older000", "provisions" => odd})
      assert {:ok, parsed} = EnablingCache.from_store(@held)
      refute parsed == odd
      assert EnablingCache.cached(@held, dir: d) == {:ok, parsed}

      write(d, @held, %{"parser" => ParserVersion.current(), "provisions" => odd})
      assert EnablingCache.cached(@held, dir: d) == {:ok, odd}
    end

    test "behind with no introduction held: kept as cached" do
      d = dir()
      odd = [%{"law" => "UK_ukpga_2099_1", "sections" => ["9"], "schedules" => []}]
      write(d, "UK_uksi_2099_9999", odd)
      assert EnablingCache.cached("UK_uksi_2099_9999", dir: d) == {:ok, odd}
      assert EnablingCache.cached("UK_uksi_2099_9998", dir: d) == :none
    end
  end
end
