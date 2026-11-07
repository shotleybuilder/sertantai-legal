defmodule SertantaiLegal.Scraper.ChangeVocabulary.StoreInputsDbTest do
  @moduledoc """
  Change staleness end to end (CV-S11): a build written with its inputs
  (`Store.write/3`), read back by `Store.builds/0`, matches the inputs taken
  again (`Store.Inputs.of/3`) until one moves.
  """
  use SertantaiLegal.DataCase, async: true

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeStaleness
  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Store, as: ExtentStore
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Store, Version}
  alias SertantaiLegal.Scraper.Commencement.Rule
  alias SertantaiLegal.Scraper.Commencement.Store, as: CommencementStore

  defp law do
    n = System.unique_integer([:positive])

    LegalRegister
    |> Ash.Changeset.for_create(:create, %{
      country: "uk",
      name: "UK_ssi_2099_#{n}",
      title_en: "T",
      type_code: "ssi",
      year: 2099,
      number: "#{n}"
    })
    |> Ash.create!()
    |> Map.fetch!(:name)
  end

  defp reasons(law) do
    b = Store.builds()[law]
    now = Store.Inputs.of(law, b.affecting || [], b.commencement_sources || [])
    ChangeStaleness.reasons(b, %{code_version: Version.current(), inputs: now})
  end

  test "fresh after the build; stale on the input that moved" do
    law = law()
    {:ok, _} = Store.write(law, [], Store.Inputs.of(law, ["UK_ssi_2099_0"], []))
    assert reasons(law) == []

    Repo.query!(
      """
      INSERT INTO amendment_rules (amends, targets, operation, level, source_law, treatment, read_at)
      VALUES ($1, '{reg.1}', 'repealed', 'provision', 'UK_ssi_2099_0', 'stated',
              (now() AT TIME ZONE 'utc') + interval '1 second')
      """,
      [law]
    )

    assert reasons(law) == [:amendment_rules]
  end

  test "a build recorded before the fingerprints were is stale on those it lacks" do
    law = law()
    {:ok, _} = Store.write(law, [], %{clml_valid: "2026-07-16", amendment_rules: nil})
    assert reasons(law) == [:lat_rows, :law_text, :feed, :commencement_rules, :extent_rules]
  end

  defp commencement(commences, source_law),
    do:
      Rule.new(
        commences: commences,
        scope: ["s.1"],
        when: {:date, ~D[2099-04-01]},
        source: %{law: source_law, ref: "art.2", text: "comes into force on …"},
        treatment: :order_date
      )

  defp age(table, source_law, version),
    do:
      Repo.query!("UPDATE #{table} SET reader_version = $2 WHERE source_law = $1", [
        source_law,
        version
      ])

  describe "readings made by other reader code (#193)" do
    test "rules read by this code: none; by other code, or before it was recorded: the reader" do
      law = law()
      CommencementStore.write("UK_uksi_2099_7001", [commencement(law, "UK_uksi_2099_7001")])
      assert Store.Inputs.readers(law, [], []) == []

      age("commencement_rules", "UK_uksi_2099_7001", "0000older000")
      assert Store.Inputs.readers(law, [], []) == [:commencement_reader]

      age("commencement_rules", "UK_uksi_2099_7001", nil)
      assert Store.Inputs.readers(law, [], []) == [:commencement_reader]
    end

    test "the rules commencing a law whose commencement the build read count, not rules from it" do
      law = law()
      amending = "UK_ukpga_2099_7002"
      CommencementStore.write("UK_uksi_2099_7003", [commencement(amending, "UK_uksi_2099_7003")])
      age("commencement_rules", "UK_uksi_2099_7003", "0000older000")

      assert Store.Inputs.readers(law, [], []) == []
      assert Store.Inputs.readers(law, [], [amending]) == [:commencement_reader]

      # and the fingerprint moves with a re-read of them (a later read_at:
      # the sandbox's now() is the transaction's)
      before = Store.Inputs.of(law, [], [amending]).commencement_rules

      Repo.query!(
        "UPDATE commencement_rules SET read_at = read_at + interval '1 second' WHERE source_law = $1",
        ["UK_uksi_2099_7003"]
      )

      refute Store.Inputs.of(law, [], [amending]).commencement_rules == before
    end

    test "an extent reading by other code; a re-read the same stamps it and keeps read_at" do
      law = law()
      act = "UK_ukpga_2099_7004"
      e = %Extent{default: "E+W", ref: "s.9", text: "This Act extends to England and Wales."}
      {:ok, _, _} = ExtentStore.write_read(act, e, cached: true)
      assert Store.Inputs.readers(law, [act], []) == []

      age("extent_rules", act, "0000older000")
      assert Store.Inputs.readers(law, [act], []) == [:extent_reader]
      assert Store.Inputs.readers(law, [], [act]) == [:extent_reader]

      read_at = Store.Inputs.of(law, [act], []).extent_rules
      {:ok, _, _} = ExtentStore.write_read(act, e, cached: true)
      assert Store.Inputs.readers(law, [act], []) == []
      assert Store.Inputs.of(law, [act], []).extent_rules == read_at
    end

    test "a build that read stale readings is stale on that reader, after its inputs" do
      law = law()
      CommencementStore.write("UK_uksi_2099_7005", [commencement(law, "UK_uksi_2099_7005")])
      {:ok, _} = Store.write(law, [], Store.Inputs.of(law, [], []))
      assert reasons(law) == []

      age("commencement_rules", "UK_uksi_2099_7005", "0000older000")
      b = Store.builds()[law]

      current = %{
        code_version: Version.current(),
        inputs: Store.Inputs.of(law, [], []),
        readers: Store.Inputs.readers(law, [], [])
      }

      assert ChangeStaleness.reasons(b, current) == [:commencement_reader]
    end
  end

  test "mix lat.stale --strict fails on a built law that read stale readings (#193)" do
    law = law()
    CommencementStore.write("UK_uksi_2099_7006", [commencement(law, "UK_uksi_2099_7006")])
    {:ok, _} = Store.write(law, [], Store.Inputs.of(law, [], []))
    age("commencement_rules", "UK_uksi_2099_7006", "0000older000")

    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    assert catch_exit(Mix.Tasks.Lat.Stale.run(["--strict", "--list"])) == {:shutdown, 1}
    line = law <> "\tchanges: commencement_reader"
    assert_received {:mix_shell, :info, [^line]}
  end
end
