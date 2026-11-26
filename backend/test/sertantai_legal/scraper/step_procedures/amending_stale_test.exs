defmodule SertantaiLegal.Scraper.StepProcedures.AmendingStaleTest do
  @moduledoc """
  The amending laws behind the build's `:amending_reader` reason, as the
  step reads them (`mix lat.amending --read --stale`, `lat.reread`,
  `lat.stale`): each built law's text amenders (`Amendment.TextAmenders`),
  text held, whose index is not current for it, by cause. It agrees with
  `Store.Inputs.readers/3` law by law. The CLML store is a temporary root
  (the app config's: not async); the index files written are removed after.
  """
  use SertantaiLegal.DataCase, async: false

  alias SertantaiLegal.Scraper.Amendment.{Index, Rule, Store}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store, as: ChangeStore
  alias SertantaiLegal.Scraper.StepProcedures.AmendingStale

  @a "UK_ukpga_2099_7040"
  @b "UK_ukpga_2099_7041"
  @c "UK_ukpga_2099_7042"
  @unheld "UK_ukpga_2099_7043"
  @law "UK_uksi_2099_7044"
  @other "UK_uksi_2099_7045"
  @entries %{elements: [], references: %{}, parts: %{}}

  setup do
    root = Path.join(System.tmp_dir!(), "clml-#{System.unique_integer([:positive])}")

    for n <- ~w(7040 7041 7042) do
      body = Path.join(root, "ukpga/2099/#{n}/body/data.xml.gz")
      File.mkdir_p!(Path.dirname(body))
      File.write!(body, :zlib.gzip("<Legislation/>"))
    end

    old = Application.get_env(:sertantai_legal, :clml_store_dir)
    Application.put_env(:sertantai_legal, :clml_store_dir, root)

    on_exit(fn ->
      Application.put_env(:sertantai_legal, :clml_store_dir, old)
      File.rm_rf!(root)
      for l <- [@a, @b, @c], do: File.rm("data/cache/amendment-index/#{l}.json")
    end)

    :ok
  end

  defp rule(source, amends),
    do:
      Rule.new(
        amends: amends,
        targets: ["reg.2"],
        operation: :repealed,
        level: :provision,
        source: %{law: source, ref: "s.4", text: "Regulation 2 is revoked."},
        treatment: :instruction
      )

  test "each built law's text amenders not current for it, by cause; the same laws as the build's reason" do
    # @a never read; @b read for another law only; @c current; @unheld not held
    for s <- [@a, @b, @c, @unheld], do: {:ok, 1} = Store.write(s, [rule(s, @law)])
    :ok = Index.write(@b, @entries, [@other])
    :ok = Index.write(@c, @entries, [@law, @other])

    stale = AmendingStale.for_laws([@law, @other], fn _ -> [] end)

    assert stale == %{not_read: [@a], old_code: [], not_for_law: [@b]}
    assert AmendingStale.all(stale) == [@a, @b]

    assert ChangeStore.Inputs.readers(@law, [], []) == [:amending_reader]
    assert ChangeStore.Inputs.readers(@other, [], []) == []
  end

  test "an index read by other reader code is old code" do
    {:ok, 1} = Store.write(@a, [rule(@a, @law)])
    :ok = Index.write(@a, @entries, [@law])
    path = "data/cache/amendment-index/#{@a}.json"
    stamped = path |> File.read!() |> Jason.decode!() |> Map.put("reader", "old")
    File.write!(path, Jason.encode!(stamped))

    assert AmendingStale.for_laws([@law], fn _ -> [] end) ==
             %{not_read: [], old_code: [@a], not_for_law: []}
  end

  test "a law amended by modification only, or commenced only, is not stale" do
    effects = fn
      @law -> [%{type: "modified", affecting: @a}, %{type: "coming into force", affecting: @b}]
      _ -> []
    end

    assert AmendingStale.for_laws([@law], effects) ==
             %{not_read: [], old_code: [], not_for_law: []}
  end
end
