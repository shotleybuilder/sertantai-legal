defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCacheTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @xml ~s(<Legislation><Primary><Body><P1 id="section-9"><P1para><Text>This Act extends to England and Wales only.</Text></P1para></P1></Body></Primary></Legislation>)

  setup do
    base = Path.join(System.tmp_dir!(), "read_cache_test_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(base) end)
    root = Path.join(base, "clml")
    :ok = ClmlStore.put("/ukpga/2001/1/body/data.xml", @xml, root: root)
    {:ok, opts: [root: root, dir: Path.join(base, "reads")]}
  end

  test "the reading is the same from the cache as computed", %{opts: opts} do
    first = ReadCache.law("UK_ukpga_2001_1", opts)
    assert first.read.default == "E+W"
    assert File.exists?(Path.join(opts[:dir], "UK_ukpga_2001_1.bin"))

    files = ClmlStore.law_files("UK_ukpga_2001_1", root: opts[:root])
    assert ReadCache.law("UK_ukpga_2001_1", opts) == first
    assert ReadCache.compute("UK_ukpga_2001_1", files) == first
  end

  test "a changed text is read again", %{opts: opts} do
    assert ReadCache.law("UK_ukpga_2001_1", opts).read.default == "E+W"

    :ok =
      ClmlStore.put(
        "/ukpga/2001/1/body/data.xml",
        String.replace(@xml, "England and Wales only", "Scotland only"),
        root: opts[:root]
      )

    assert ReadCache.law("UK_ukpga_2001_1", opts).read.default == "S"
  end

  # a cached term holding an atom this VM has never made: the placeholder's
  # bytes swapped for a fresh name of the same length, so the test itself
  # never creates the atom
  defp with_unseen_atom(term) do
    fresh = "u" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
    placeholder = String.duplicate("p", byte_size(fresh))
    bin = :erlang.term_to_binary(swap(term, String.to_atom(placeholder)))

    {:binary.replace(
       bin,
       <<119, byte_size(fresh), placeholder::binary>>,
       <<119, byte_size(fresh), fresh::binary>>
     ), fresh}
  end

  defp swap({key, reading}, atom), do: {key, Map.put(reading, :unseen, atom)}

  test "a cached reading holding atoms not yet made is a hit, not read again (#192)", %{
    opts: opts
  } do
    ReadCache.law("UK_ukpga_2001_1", opts)
    path = Path.join(opts[:dir], "UK_ukpga_2001_1.bin")
    {bin, fresh} = path |> File.read!() |> :erlang.binary_to_term() |> with_unseen_atom()
    File.write!(path, bin)

    assert Atom.to_string(ReadCache.law("UK_ukpga_2001_1", opts).unseen) == fresh
    assert File.read!(path) == bin
  end

  test "no text held: nil, nothing cached", %{opts: opts} do
    assert ReadCache.law("UK_ukpga_2001_2", opts) == nil
    refute File.exists?(Path.join(opts[:dir], "UK_ukpga_2001_2.bin"))
  end
end
