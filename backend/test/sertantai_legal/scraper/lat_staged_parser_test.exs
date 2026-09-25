defmodule SertantaiLegal.Scraper.LatStagedParserTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatStagedParser

  @body File.read!("test/fixtures/legislation_gov_uk/body_uksi_1991_899.xml")

  describe "run_stages/5 when the LAT persist fails" do
    setup do
      # A law_id with no legal_register row makes LatPersister fail (FK).
      events = :ets.new(:events, [:bag, :public])
      on_progress = fn e -> :ets.insert(events, {e}) end

      result =
        LatStagedParser.run_stages(
          "UK_uksi_1991_899",
          "uksi",
          Ecto.UUID.generate(),
          @body,
          on_progress: on_progress
        )

      %{result: result, events: Enum.map(:ets.tab2list(events), &elem(&1, 0))}
    end

    test "skips both annotation stages", %{events: events} do
      assert {:stage_complete, :persist_lat, :error, _} =
               Enum.find(events, &match?({:stage_complete, :persist_lat, _, _}, &1))

      assert Enum.any?(events, &match?({:stage_complete, :parse_annotations, :skipped, _}, &1))
      assert Enum.any?(events, &match?({:stage_complete, :persist_annotations, :skipped, _}, &1))
    end

    test "persists no annotations", _ctx do
      %{rows: [[n]]} =
        Repo.query!(
          "SELECT count(*) FROM amendment_annotations WHERE law_name = 'UK_uksi_1991_899'"
        )

      assert n == 0
    end

    test "reports the LAT error on the result", %{result: {:ok, result}} do
      assert result.has_errors
      assert result.error =~ "LAT persist"
      assert result.annotations.skipped
    end
  end

  describe "record_outcome/1" do
    test "a clean parse is parsed" do
      r = %{has_errors: false, lat: %{inserted: 3}}
      assert LatStagedParser.record_outcome(r) == {:parsed, r}
    end

    test "any stage error is failed, with the error" do
      assert LatStagedParser.record_outcome(%{has_errors: true, error: "LAT persist: boom"}) ==
               {:failed, "LAT persist: boom"}
    end

    test "an error without a message is still failed" do
      assert {:failed, "parse failed"} = LatStagedParser.record_outcome(%{has_errors: true})
    end
  end
end
