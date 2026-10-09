defmodule Mix.Tasks.Lat.ChangeDiff do
  @moduledoc """
  What LR-07 changes in the LAT's change metadata, without persisting
  anything: each law is parsed with its effects (`LatStagedParser.fetch_changes/2`)
  and `ChangeFacts.resolve/5` compared with the stored notes' effect /
  effective_from / changed_by and the stored rows' status / effective_from /
  changed_by.

      mix lat.change_diff --laws UK_ukpga_1995_21 --store only
      mix lat.change_diff --all --store only --out data/reports/lat-refactor/lr07-change-diff.csv

  Written as it goes (`<out>.done`, as `lat.text_diff`): one CSV line per
  changed field (law_name, kind, id, field, old, new, source, cause, class).
  `cause` separates LR-07 from parse drift: the same parse resolved from
  notes alone (no effects — the old rules) is the baseline; `lr07` when
  the effects change the value, `parse` when the baseline already gives
  it (note placement, text). At the
  end `<out>.classes.csv` counts by class, and `<out>.sources.csv` counts
  each fact's source (effect / note / markup) over every note and row.
  """

  use Mix.Task

  alias NimbleCSV.RFC4180, as: CSV
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{ChangeFacts, LatStagedParser}

  @shortdoc "Classified diff of change metadata from effects against stored LAT (no persist)"

  @header ~w(law_name kind id field old new source cause class)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [laws: :string, all: :boolean, out: :string, store: :string]
      )

    Mix.Task.run("app.start")

    out =
      opts[:out] ||
        Path.join(["data", "reports", "lat-refactor", "change-diff-#{Date.utc_today()}.csv"])

    done_path = out <> ".done"
    sources_path = out <> ".sources.jsonl"
    File.mkdir_p!(Path.dirname(out))
    fresh? = not File.exists?(done_path)

    if fresh? do
      File.write!(out, CSV.dump_to_iodata([@header]))
      File.write!(sources_path, "")
    end

    done =
      if fresh?,
        do: MapSet.new(),
        else: done_path |> File.read!() |> String.split("\n", trim: true) |> MapSet.new()

    laws =
      cond do
        opts[:laws] -> String.split(opts[:laws], ",", trim: true)
        opts[:all] -> laws_with_lat()
        true -> Mix.raise("Give --laws A,B or --all")
      end
      |> Enum.reject(&MapSet.member?(done, &1))

    mode =
      case opts[:store] do
        nil -> :prefer
        m when m in ~w(prefer only refresh) -> String.to_atom(m)
        m -> Mix.raise("--store must be prefer, only or refresh, got #{m}")
      end

    Mix.shell().info("#{length(laws)} laws (#{MapSet.size(done)} already done) → #{out}")

    for law <- laws do
      case diff_law(law, mode) do
        {:ok, lines, sources} ->
          File.write!(out, CSV.dump_to_iodata(lines), [:append])

          File.write!(sources_path, Jason.encode!(%{law: law, sources: sources}) <> "\n", [
            :append
          ])

          File.write!(done_path, law <> "\n", [:append])
          Mix.shell().info("  #{law}: #{length(lines)} changed")

        {:error, reason} ->
          Mix.shell().error("  #{law}: #{reason} (not marked done)")
      end
    end

    summarise(out, sources_path)
  end

  defp diff_law(law, mode) do
    with {:ok, %{rows: rows, notes: notes, effects: effects}} <-
           LatStagedParser.fetch_changes(law, store: mode) do
      by_id = for e <- effects, e.effect_id != nil, into: %{}, do: {e.effect_id, e}
      notes = Enum.map(notes, &%{&1 | code_type: to_string(&1.code_type)})
      holders = rows |> Enum.map(& &1.section_id) |> ChangeFacts.holders()
      opts = [holders: holders, known_laws: known_laws()]
      {facts, out} = ChangeFacts.resolve(rows, notes, by_id, law, opts)

      # the baseline: notes alone, as before LR-07
      {base_facts, base_out} =
        ChangeFacts.resolve(
          Enum.map(rows, &Map.put(&1, :effect_ids, [])),
          Enum.map(notes, &Map.put(&1, :effect_ids, [])),
          %{},
          law,
          opts
        )

      stored_notes = stored_notes(law)
      stored_rows = stored_rows(law)

      note_lines =
        [notes, facts, base_facts]
        |> Enum.zip()
        |> Enum.flat_map(fn {n, f, b} ->
          case stored_notes[{n.code_type, n.code}] do
            nil ->
              []

            old ->
              for {field, ov, nv, bv} <- [
                    {"effect", old.effect, f.effect, b.effect},
                    {"effective_from", old.effective_from, f.effective_from, b.effective_from},
                    {"changed_by", old.changed_by, f.changed_by, b.changed_by}
                  ],
                  ov != nv,
                  do: line(law, "note", n.code, field, ov, nv, f.source, cause(nv, bv))
          end
        end)

      row_lines =
        Enum.flat_map(out, fn {sid, r} ->
          case stored_rows[sid] do
            nil ->
              []

            old ->
              b = base_out[sid]

              for {field, ov, nv, bv, source} <- [
                    {"status", old.status, r.status, b.status, r.status_source},
                    {"effective_from", old.effective_from, r.effective_from, b.effective_from,
                     r.change_source},
                    {"changed_by", old.changed_by, r.changed_by, b.changed_by, r.change_source}
                  ],
                  ov != nv,
                  do: line(law, "row", sid, field, ov, nv, source, cause(nv, bv))
          end
        end)

      sources = %{
        notes: Enum.frequencies_by(facts, &to_string(&1.source)),
        row_status: out |> Map.values() |> Enum.frequencies_by(&to_string(&1.status_source)),
        row_change: out |> Map.values() |> Enum.frequencies_by(&to_string(&1.change_source))
      }

      {:ok, note_lines ++ row_lines, sources}
    end
  end

  defp cause(new, base), do: if(new == base, do: "parse", else: "lr07")

  defp line(law, kind, id, field, old, new, source, cause),
    do: [
      law,
      kind,
      id,
      field,
      str(old),
      str(new),
      str(source),
      cause,
      "#{cause}: " <> class(kind, field, old, new, source)
    ]

  defp class(_kind, "status", old, new, source),
    do: "status: #{old || "nil"} → #{new} (#{source})"

  defp class(kind, "effect", old, new, _source), do: "#{kind} effect: #{old || "nil"} → #{new}"

  defp class(kind, field, nil, _new, source), do: "#{kind} #{field}: filled (#{source})"
  defp class(kind, field, _old, nil, source), do: "#{kind} #{field}: emptied (#{source})"

  defp class(kind, "effective_from", %Date{} = old, %Date{} = new, source),
    do:
      "#{kind} effective_from: #{if Date.compare(new, old) == :gt, do: "later", else: "earlier"} (#{source})"

  defp class(kind, "changed_by", old, new, source),
    do: "#{kind} changed_by: #{law_type(old)} → #{law_type(new)} (#{source})"

  defp class(kind, field, _old, _new, source), do: "#{kind} #{field}: changed (#{source})"

  defp law_type(name), do: name |> String.split("_") |> Enum.at(1)

  defp str(nil), do: ""
  defp str(%Date{} = d), do: Date.to_iso8601(d)
  defp str(v), do: to_string(v)

  defp stored_notes(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT code_type, code, effect, effective_from, changed_by FROM amendment_annotations WHERE law_name = $1",
        [law]
      )

    Map.new(rows, fn [ct, code, effect, from, by] ->
      {{ct, code}, %{effect: effect, effective_from: from, changed_by: by}}
    end)
  end

  defp stored_rows(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, status, effective_from, changed_by FROM legal_articles WHERE law_name = $1",
        [law]
      )

    Map.new(rows, fn [sid, status, from, by] ->
      {sid, %{status: status, effective_from: from, changed_by: by}}
    end)
  end

  # register names, once per run (Welsh SIs cited as plain "S.I.")
  defp known_laws do
    case :persistent_term.get({__MODULE__, :known}, nil) do
      nil ->
        %{rows: rows} = Repo.query!("SELECT name FROM legal_register", [], timeout: :infinity)
        known = rows |> List.flatten() |> MapSet.new()
        :persistent_term.put({__MODULE__, :known}, known)
        known

      known ->
        known
    end
  end

  defp laws_with_lat do
    %{rows: rows} =
      Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY law_name", [],
        timeout: :infinity
      )

    List.flatten(rows)
  end

  defp summarise(out, sources_path) do
    [_header | lines] = out |> File.read!() |> CSV.parse_string(skip_headers: false)

    summary =
      lines
      |> Enum.group_by(&List.last/1)
      |> Enum.map(fn {class, hits} ->
        laws = hits |> Enum.map(&hd/1) |> Enum.uniq() |> length()
        [_, _, id | _] = hd(hits)
        [class, length(hits), laws, id]
      end)
      |> Enum.sort_by(&(-Enum.at(&1, 1)))

    File.write!(
      out <> ".classes.csv",
      CSV.dump_to_iodata([~w(class lines laws example) | summary])
    )

    Mix.shell().info("\n#{length(lines)} changed fields; by class (#{out}.classes.csv):")

    Enum.each(summary, fn [c, n, l, ex] ->
      Mix.shell().info("  #{n}\t#{l} laws\t#{c}\t(#{ex})")
    end)

    totals =
      sources_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!(&1)["sources"])
      |> Enum.reduce(%{}, fn s, acc ->
        Map.merge(acc, s, fn _k, a, b -> Map.merge(a, b, fn _, x, y -> x + y end) end)
      end)

    Mix.shell().info("\nsources: #{inspect(totals)}")
  end
end
