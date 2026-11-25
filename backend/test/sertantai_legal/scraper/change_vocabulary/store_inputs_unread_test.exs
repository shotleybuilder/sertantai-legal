defmodule SertantaiLegal.Scraper.ChangeVocabulary.StoreInputsUnreadTest do
  @moduledoc """
  A build reads only stored extent readings (the Extent reader stamps
  session: the fallback reading an unstored law's text is gone), so an
  affecting law with its text held and no `extent_rules` is a stale reason
  (`:extent_reader`, not read). The CLML store is a temporary root here
  (the app config's: not async).
  """
  use SertantaiLegal.DataCase, async: false

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Write
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store

  @held "UK_ukpga_2099_7010"

  setup do
    root = Path.join(System.tmp_dir!(), "clml-#{System.unique_integer([:positive])}")
    body = Path.join(root, "ukpga/2099/7010/body/data.xml.gz")
    File.mkdir_p!(Path.dirname(body))
    File.write!(body, :zlib.gzip("<Legislation/>"))
    old = Application.get_env(:sertantai_legal, :clml_store_dir)
    Application.put_env(:sertantai_legal, :clml_store_dir, root)

    on_exit(fn ->
      Application.put_env(:sertantai_legal, :clml_store_dir, old)
      File.rm_rf!(root)
    end)
  end

  test "an affecting law with its text held and no extent read: the extent reader (not read)" do
    law = "UK_uksi_2099_7011"
    assert Store.Inputs.readers(law, [@held], []) == [:extent_reader]
    assert Store.Inputs.readers(law, [], [@held]) == [:extent_reader]

    # a law with no text held can't be read: not a reason
    assert Store.Inputs.readers(law, ["UK_ukpga_2099_7012"], []) == []

    e = %Extent{default: "E+W+S", ref: "s.9", text: "This Act extends to Great Britain."}
    {:ok, _, _} = Write.write_read(@held, e, cached: true)
    assert Store.Inputs.readers(law, [@held], []) == []
  end
end
