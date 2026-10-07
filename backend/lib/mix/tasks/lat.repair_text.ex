defmodule Mix.Tasks.Lat.RepairText do
  @moduledoc """
  Targeted repair of LAT rows corrupted by the old list-text bug
  (`SertantaiLegal.Scraper.LatRepair`; LAT parser coverage session,
  2026-10-07). Each flagged provision is re-parsed from its
  legislation.gov.uk fragment and only rows whose words change are written —
  no whole-law re-parse, so other rows, their enrichment and legislative
  changes since the last parse are untouched.

      mix lat.repair_text                                  # dry run, all candidates
      mix lat.repair_text --laws UK_uksi_1992_3004,UK_ukpga_1974_37
      mix lat.repair_text --laws A,B --apply               # write
      mix lat.repair_text --limit 50                       # first N provisions

  Candidates: `data/reports/lat-parser-coverage/list-bug-candidates-2026-10-07.csv`
  (`--candidates PATH`), from `scan_lists.py`.

  Written as it goes, to `data/reports/lat-parser-coverage/repair-{plan|applied}-<date>.csv`
  (law_name, provision, section_id, old_text, new_text) with a `.done` list
  of provisions, so an interrupted run loses nothing and a re-run resumes.

  `--apply`, per provision in one transaction: the row's text is replaced and
  its carried columns (fractalaw enrichment, embeddings — not `legacy_id` or the
  note-derived `effective_from`/`changed_by`) reset
  to their defaults, as a re-parse does for a changed row; a `lat_changes`
  row records `text_changed` with cause `correction`. Each repaired law gets
  one `parsed` lat_event with cause `correction`, so the manifest reports it.
  `lat_hash` follows by trigger.
  """

  use Mix.Task

  alias NimbleCSV.RFC4180, as: CSV
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatParser, LatRepair}
  alias SertantaiLegal.Scraper.LatPersister.Carry
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  @shortdoc "Repair list-text-corrupted LAT rows by provision fragment"

  @dir Path.join(["data", "reports", "lat-parser-coverage"])
  @candidates Path.join(@dir, "list-bug-candidates-2026-10-07.csv")
  @header ~w(law_name provision section_id old_text new_text)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [laws: :string, limit: :integer, apply: :boolean, candidates: :string]
      )

    Mix.Task.run("app.start")

    out =
      Path.join(
        @dir,
        "repair-#{if opts[:apply], do: "applied", else: "plan"}-#{Date.utc_today()}.csv"
      )

    done_path = out <> ".done"
    File.mkdir_p!(@dir)
    unless File.exists?(out), do: File.write!(out, CSV.dump_to_iodata([@header]))
    done = read_done(done_path)

    {provisions, skipped} = opts |> candidate_rows() |> LatRepair.provisions()

    todo =
      provisions
      |> Enum.reject(fn {law, p} -> MapSet.member?(done, "#{law}|#{p}") end)
      |> then(&if opts[:limit], do: Enum.take(&1, opts[:limit]), else: &1)

    Mix.shell().info(
      "#{length(todo)} provisions to #{if opts[:apply], do: "repair", else: "check"} " <>
        "(#{MapSet.size(done)} done; #{length(skipped)} candidate rows not covered: schedules/structural) → #{out}"
    )

    totals =
      todo
      |> Enum.chunk_by(&elem(&1, 0))
      |> Enum.reduce(%{rows: 0, provisions: 0, failed: 0}, fn group, acc ->
        law_totals = repair_law(group, opts[:apply] || false, out, done_path)
        Map.merge(acc, law_totals, fn _k, a, b -> a + b end)
      end)

    Mix.shell().info(
      "\n#{totals.provisions} provisions processed, #{totals.rows} rows " <>
        "#{if opts[:apply], do: "repaired", else: "to repair (dry run)"}, #{totals.failed} fetches failed"
    )
  end

  defp repair_law([{law, _} | _] = group, apply?, out, done_path) do
    %{rows: [[law_id]]} =
      Repo.query!("SELECT id::text FROM legal_register WHERE country = 'uk' AND name = $1", [law])

    stored = stored_rows(law)
    op_key = Ecto.UUID.generate()

    totals =
      Enum.reduce(group, %{rows: 0, provisions: 0, failed: 0}, fn {^law, provision}, acc ->
        case fresh_rows(law, provision) do
          {:ok, fresh} ->
            held =
              Map.filter(stored, fn {sid, _} -> LatRepair.in_provision?(sid, law, provision) end)

            repairs = LatRepair.repairs(held, fresh)
            if apply? and repairs != [], do: apply!(law, op_key, repairs)

            rows = for {sid, old, new} <- repairs, do: [law, provision, sid, old || "", new || ""]
            File.write!(out, CSV.dump_to_iodata(rows), [:append])
            File.write!(done_path, "#{law}|#{provision}\n", [:append])
            %{acc | rows: acc.rows + length(repairs), provisions: acc.provisions + 1}

          {:error, reason} ->
            Mix.shell().error("  #{law} #{provision}: #{reason} (not marked done)")
            %{acc | failed: acc.failed + 1}
        end
      end)

    if apply? and totals.rows > 0, do: record_event!(law_id, op_key)
    Mix.shell().info("  #{law}: #{totals.rows} rows in #{totals.provisions} provisions")
    totals
  end

  defp fresh_rows(law, provision) do
    type_code = law |> String.split("_") |> Enum.at(1)

    law
    |> LatRepair.fragment_paths(provision)
    |> Enum.reduce_while({:error, "no fragment found"}, fn path, err ->
      case Client.fetch_xml(path <> "/data.xml") do
        {:ok, xml} ->
          rows = LatParser.parse(xml, %{law_name: law, type_code: type_code})

          fresh =
            for r <- rows,
                LatRepair.in_provision?(r.section_id, law, provision),
                into: %{},
                do: {r.section_id, r.text}

          {:halt, {:ok, fresh}}

        _ ->
          {:cont, err}
      end
    end)
  end

  defp apply!(law, op_key, repairs) do
    reset = Enum.map_join(carried_columns(), ", ", &"#{&1} = DEFAULT")

    Repo.transaction(fn ->
      for {sid, _old, new} <- repairs do
        Repo.query!(
          "UPDATE legal_articles SET text = $3, #{reset}, updated_at = now() WHERE law_name = $1 AND section_id = $2",
          [law, sid, new]
        )

        Repo.query!(
          """
          INSERT INTO lat_changes (law_name, op_key, section_id, old_section_id, change, cause, change_ids)
          VALUES ($1, $2, $3, NULL, 'text_changed', 'correction', ARRAY[]::text[])
          """,
          [law, op_key, sid]
        )
      end
    end)
  end

  defp record_event!(law_id, op_key) do
    Repo.query!(
      """
      INSERT INTO lat_events (law_id, country, law_name, event, source, actor, lat_hash, struct_hash, row_count, reason, op_key, cause)
      SELECT id, 'uk', name, 'parsed', 'mix lat.repair_text', 'list-text repair', lat_hash, struct_hash, lat_count,
             'list-text repair by provision fragment', $2, 'correction'
      FROM legal_register WHERE country = 'uk' AND id = $1::uuid
      """,
      [law_id, op_key]
    )
  end

  # Carried columns (as a re-parse sees them) to reset on a changed row.
  defp carried_columns do
    case :persistent_term.get({__MODULE__, :carried}, nil) do
      nil ->
        parser_keys =
          "<Legislation><Primary><Body><P1group><P1 id=\"section-1\"><Pnumber>1</Pnumber><P1para><Text>x</Text></P1para></P1></P1group></Body></Primary></Legislation>"
          |> LatParser.parse(%{law_name: "UK_ukpga_2000_1", type_code: "ukpga"})
          |> LatParser.to_insert_maps(Ecto.UUID.generate())
          |> hd()
          |> Map.keys()

        # note-derived fields (LatStatus.Apply) stay: a text repair doesn't change the notes
        cols = Carry.carried_columns(parser_keys) -- ["legacy_id", "effective_from", "changed_by"]
        :persistent_term.put({__MODULE__, :carried}, cols)
        cols

      cols ->
        cols
    end
  end

  defp stored_rows(law) do
    %{rows: rows} =
      Repo.query!("SELECT section_id, text FROM legal_articles WHERE law_name = $1", [law])

    Map.new(rows, fn [sid, text] -> {sid, text} end)
  end

  defp candidate_rows(opts) do
    laws = if opts[:laws], do: MapSet.new(String.split(opts[:laws], ",", trim: true))

    (opts[:candidates] || @candidates)
    |> File.stream!()
    |> CSV.parse_stream()
    |> Enum.map(fn [law, sid | _] -> {law, sid} end)
    |> Enum.filter(fn {law, _} -> laws == nil or MapSet.member?(laws, law) end)
  end

  defp read_done(path) do
    if File.exists?(path),
      do: path |> File.read!() |> String.split("\n", trim: true) |> MapSet.new(),
      else: MapSet.new()
  end
end
