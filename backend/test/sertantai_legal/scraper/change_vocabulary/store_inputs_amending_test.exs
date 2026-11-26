defmodule SertantaiLegal.Scraper.ChangeVocabulary.StoreInputsAmendingTest do
  @moduledoc """
  A build reads only stored amendment rules (the Amending-law reader stamps
  session, 2026-11-26: the fallback reading a stale amending law's text is
  gone), so an amending law of the build's text changes, its text held,
  whose index is not current for the law (stale, or never read) is a stale
  reason (`:amending_reader`). A law affecting it only by commencement is
  none. The CLML store is a temporary root here (the app config's: not
  async); the index file written is removed after.
  """
  use SertantaiLegal.DataCase, async: false

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Write
  alias SertantaiLegal.Scraper.Amendment.{Index, Rule, Store}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store, as: ChangeStore

  @held "UK_ukpga_2099_7020"
  @law "UK_uksi_2099_7021"
  @entries %{elements: [], references: %{}, parts: %{}}

  setup do
    root = Path.join(System.tmp_dir!(), "clml-#{System.unique_integer([:positive])}")
    body = Path.join(root, "ukpga/2099/7020/body/data.xml.gz")
    File.mkdir_p!(Path.dirname(body))
    File.write!(body, :zlib.gzip("<Legislation/>"))
    old = Application.get_env(:sertantai_legal, :clml_store_dir)
    Application.put_env(:sertantai_legal, :clml_store_dir, root)
    index = "data/cache/amendment-index/#{@held}.json"

    on_exit(fn ->
      Application.put_env(:sertantai_legal, :clml_store_dir, old)
      File.rm_rf!(root)
      File.rm(index)
    end)

    # its extent read, so only the amending reason is in question
    e = %Extent{default: "E+W+S", ref: "s.9", text: "This Act extends to Great Britain."}
    {:ok, _, _} = Write.write_read(@held, e, cached: true)
    :ok
  end

  defp rule,
    do:
      Rule.new(
        amends: @law,
        targets: ["reg.2"],
        operation: :substituted,
        level: :words,
        source: %{law: @held, ref: "s.4", text: "In regulation 2, for “x” substitute “y”."},
        treatment: :instruction
      )

  test "a law affecting the build only by commencement is no amending reason" do
    assert ChangeStore.Inputs.readers(@law, [@held], [@held]) == []
  end

  test "an amending law of the build's rules, never read or read for other laws or by other code: the amending reader" do
    {:ok, 1} = Store.write(@held, [rule()])
    assert ChangeStore.Inputs.readers(@law, [@held], [@held]) == [:amending_reader]

    # read by this reader, from this text, for another law only
    :ok = Index.write(@held, @entries, ["UK_uksi_2099_7099"])
    assert ChangeStore.Inputs.readers(@law, [@held], [@held]) == [:amending_reader]

    # read for the law: current
    :ok = Index.write(@held, @entries, [@law])
    assert ChangeStore.Inputs.readers(@law, [@held], [@held]) == []
  end
end
