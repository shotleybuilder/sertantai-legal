defmodule SertantaiLegal.Scraper.EnactedBy.EnablingCacheTitlesTest do
  @moduledoc """
  The register's titles resolve an enabling Act the words name, and win
  over a marker linking another law (Waste, Water and Climate: Extent
  reader, Decision 1). A title the register holds for two laws identifies
  neither: the marker stands. The CLML store is a temporary root holding
  SSI 2008/339's made introduction (the app config's: not async).
  """
  use SertantaiLegal.DataCase, async: false

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Scraper.EnactedBy.EnablingCache

  @held "UK_ssi_2008_339"

  setup do
    root = Path.join(System.tmp_dir!(), "clml-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "ssi/2008/339"))
    File.cp_r!("data/cache/clml/ssi/2008/339/made", Path.join(root, "ssi/2008/339/made"))
    old = Application.get_env(:sertantai_legal, :clml_store_dir)
    Application.put_env(:sertantai_legal, :clml_store_dir, root)

    on_exit(fn ->
      Application.put_env(:sertantai_legal, :clml_store_dir, old)
      File.rm_rf!(root)
    end)
  end

  defp register(type, number) do
    LegalRegister
    |> Ash.Changeset.for_create(:create, %{
      country: "uk",
      name: "UK_#{type}_2002_#{number}",
      title_en: "Freedom of Information (Scotland) Act",
      type_code: type,
      year: 2002,
      number: "#{number}"
    })
    |> Ash.create!()
  end

  test "a title the register holds for two laws identifies neither: the marker stands (SSI 2008/339)" do
    register("asp", 13)
    register("ukpga", 13)

    assert EnablingCache.from_store(@held) ==
             {:ok, [%{"law" => "UK_asp_2002_13", "sections" => ["64"], "schedules" => []}]}
  end
end
