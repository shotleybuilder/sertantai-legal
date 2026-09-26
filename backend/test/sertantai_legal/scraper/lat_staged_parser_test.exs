defmodule SertantaiLegal.Scraper.LatStagedParserTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatStagedParser

  @body File.read!("test/fixtures/legislation_gov_uk/body_uksi_1991_899.xml")
  @no_body File.read!("test/fixtures/legislation_gov_uk/body_uksi_1979_791_no_body.xml")

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

  describe "run_stages/5 on a law with no XML body (PDF only)" do
    setup do
      dir = Path.join(System.tmp_dir!(), "pdf-backlog-#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf!(dir) end)

      Req.Test.stub(SertantaiLegal.Scraper.LegislationGovUk.Client, fn conn ->
        Plug.Conn.send_resp(conn, 200, "%PDF-1.4 scanned")
      end)

      name = "UK_uksi_1979_#{System.unique_integer([:positive])}"

      law =
        SertantaiLegal.Legal.LegalRegister
        |> Ash.Changeset.for_create(:create, %{
          country: "uk",
          name: name,
          title_en: "Test Regulations",
          type_code: "uksi",
          year: 1979,
          number: "791"
        })
        |> Ash.create!()

      # Existing LAT that an empty parse must not wipe.
      row = %{
        section_id: "#{name}:reg.1",
        law_name: name,
        section_type: "article",
        part: nil,
        chapter: nil,
        heading_group: nil,
        schedule: nil,
        provision: "1",
        sub: nil,
        paragraph: nil,
        sub_paragraph: nil,
        extent_code: "E+W+S",
        sort_key: "00001",
        position: 1,
        depth: 1,
        hierarchy_path: "reg.1",
        text: "Existing text.",
        amendment_count: nil,
        modification_count: nil,
        commencement_count: nil,
        extent_count: nil
      }

      {:ok, _} = SertantaiLegal.Scraper.LatPersister.persist([row], name, law.id)

      events = :ets.new(:events, [:bag, :public])

      {:ok, result} =
        LatStagedParser.run_stages(name, "uksi", law.id, @no_body,
          on_progress: fn e -> :ets.insert(events, {e}) end,
          pdf_backlog_dir: dir
        )

      %{
        name: name,
        dir: dir,
        result: result,
        events: Enum.map(:ets.tab2list(events), &elem(&1, 0))
      }
    end

    test "fails the parse and queues the PDF to the backlog", %{result: r, dir: dir, name: name} do
      assert r.has_errors
      assert r.error =~ "no XML body"
      assert [file] = r.pdf_backlog
      assert file == Path.join([dir, name, "uksi_19790791_en.pdf"])
      assert File.exists?(file)
      assert {:failed, _} = LatStagedParser.record_outcome(r)
    end

    test "leaves the law's existing LAT untouched", %{name: name} do
      %{rows: [[n]]} = Repo.query!("SELECT count(*) FROM lat WHERE law_name = $1", [name])
      assert n == 1
    end

    test "reports parse_lat as an error and skips the persist stages", %{events: events} do
      assert Enum.any?(events, &match?({:stage_complete, :parse_lat, :error, _}, &1))
      assert Enum.any?(events, &match?({:stage_complete, :persist_lat, :skipped, _}, &1))
      assert Enum.any?(events, &match?({:stage_complete, :persist_annotations, :skipped, _}, &1))
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
