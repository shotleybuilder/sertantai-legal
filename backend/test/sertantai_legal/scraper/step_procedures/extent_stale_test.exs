defmodule SertantaiLegal.Scraper.StepProcedures.ExtentStaleTest do
  @moduledoc """
  The stale extent laws: read by other reader code, or read by a build
  with their text held and never read. The CLML store is a temporary root
  (the app config's: not async).
  """
  use SertantaiLegal.DataCase, async: false

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Write
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store
  alias SertantaiLegal.Scraper.StepProcedures.ExtentStale

  @held "UK_ukpga_2099_7020"
  @read "UK_ukpga_2099_7021"

  setup do
    root = Path.join(System.tmp_dir!(), "clml-#{System.unique_integer([:positive])}")
    body = Path.join(root, "ukpga/2099/7020/body/data.xml.gz")
    File.mkdir_p!(Path.dirname(body))
    File.write!(body, :zlib.gzip("<Legislation/>"))
    old = Application.get_env(:sertantai_legal, :clml_store_dir)
    Application.put_env(:sertantai_legal, :clml_store_dir, root)

    on_exit(fn ->
      Application.put_env(:sertantai_legal, :clml_store_dir, old)
      File.rm_rf!(root)
    end)
  end

  # a build is recorded only for a law in the register
  defp law do
    n = System.unique_integer([:positive])

    LegalRegister
    |> Ash.Changeset.for_create(:create, %{
      country: "uk",
      name: "UK_uksi_2099_#{n}",
      title_en: "T",
      type_code: "uksi",
      year: 2099,
      number: "#{n}"
    })
    |> Ash.create!()
    |> Map.fetch!(:name)
  end

  test "store-wide: old reader code, and a build's affecting law held but not read" do
    e = %Extent{default: "E+W", ref: "s.9", text: "This Act extends to England and Wales."}
    {:ok, _, _} = Write.write_read(@read, e, cached: true)
    {:ok, _} = Store.write(law(), [], %{affecting: [@held, @read, "UK_ukpga_2099_7023"]})

    s = ExtentStale.laws()
    assert @held in s.not_read
    refute @read in s.old_code
    # no text held: can't be read, so not stale
    refute "UK_ukpga_2099_7023" in ExtentStale.all(s)

    Repo.query!("UPDATE extent_rules SET reader_version = '0000older000' WHERE source_law = $1", [
      @read
    ])

    assert @read in ExtentStale.laws().old_code
  end

  test "mix lat.stale names the extent laws behind :extent_reader, each with --list" do
    {:ok, _} = Store.write(law(), [], %{affecting: [@held]})

    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    Mix.Tasks.Lat.Stale.run(["--list"])
    line = @held <> "\textent: not read"
    assert_received {:mix_shell, :info, [^line]}
  end
end
