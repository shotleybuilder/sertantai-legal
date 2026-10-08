defmodule Mix.Tasks.Lat.QaSample do
  @moduledoc """
  A reproducible, stratified random sample of LAT rows for an eyeball QA
  against the CLML store (LAT parser coverage II; spec
  `docs/LAT-QA-SAMPLE-SPEC.md`).

      mix lat.qa_sample                      # 100 rows, seed = today
      mix lat.qa_sample --n 150 --seed qa1

  Strata cover plain rows and every feature the coverage work changed
  (titles, territorial brackets, «…» amending text, excluded_extent,
  statuses, tables, signatures, structural rows, extent-qualified ids,
  rows with placed notes). Within a stratum rows are ordered by
  md5(seed || section_id), so a seed always gives the same sample; a row
  drawn by one stratum is not drawn again.

  Writes `data/reports/lat-parser-coverage-ii/qa/<seed>/packets.jsonl` (one
  JSON object per row: the stored row, its notes, the row's XML fragment and
  each note's Commentary from the stored document, the store path) and
  `manifest.json`. Read-only: nothing is written to the database and nothing
  is fetched (`store: :only`).
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatStagedParser

  @shortdoc "Stratified random sample of LAT rows + XML fragments for QA"

  # {name, share of n, SQL condition on the lat view}
  @strata [
    {"plain", 0.28, "true"},
    {"title", 0.08, "title IS NOT NULL AND section_type IN ('section', 'article')"},
    {"territorial_brackets", 0.08, "text ~ '\\[(E|W|S|NI)(\\+(E|W|S|NI))*: '"},
    {"amending_text", 0.08, "text LIKE '%«%'"},
    {"excluded_extent", 0.08, "excluded_extent IS NOT NULL"},
    {"repealed_saved", 0.05, "status = 'repealed_saved'"},
    {"in_force_partial", 0.05, "status = 'in_force_partial'"},
    {"repealed", 0.03, "status = 'repealed'"},
    {"table", 0.04, "section_type = 'table'"},
    {"signed", 0.03, "section_type = 'signed'"},
    {"structural", 0.05, "section_type IN ('part', 'chapter', 'heading', 'schedule')"},
    {"qualified_id", 0.05, "section_id ~ '\\[[A-Z+]+\\]'"},
    {"placed_notes", 0.10, "effective_from IS NOT NULL OR changed_by IS NOT NULL"}
  ]

  # PDF-sourced LAT (no body in the stored XML): nothing to compare against
  @excluded_laws ~w(UK_uksi_1979_791)

  @fragment_limit 8_000

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [n: :integer, seed: :string, out: :string])
    Mix.Task.run("app.start")

    n = opts[:n] || 100
    seed = opts[:seed] || Date.to_iso8601(Date.utc_today())

    out =
      opts[:out] || Path.join(["data", "reports", "lat-parser-coverage-ii", "qa", seed])

    File.mkdir_p!(out)

    picks = draw(n, seed)
    Mix.shell().info("#{length(picks)} rows drawn (seed #{seed}); building packets…")

    packets =
      picks
      |> Enum.group_by(fn {_stratum, id} -> law_of(id) end)
      |> Enum.flat_map(fn {law, rows} -> law_packets(law, rows) end)
      |> Enum.sort_by(& &1.section_id)

    File.write!(
      Path.join(out, "packets.jsonl"),
      Enum.map_join(packets, "\n", &Jason.encode!/1) <> "\n"
    )

    File.write!(
      Path.join(out, "manifest.json"),
      Jason.encode!(
        %{
          seed: seed,
          n: length(packets),
          strata: picks |> Enum.frequencies_by(&elem(&1, 0)),
          laws: packets |> Enum.map(& &1.law_name) |> Enum.uniq() |> length(),
          generated_at: DateTime.utc_now(),
          git_commit: git_commit()
        },
        pretty: true
      )
    )

    Mix.shell().info("#{length(packets)} packets → #{out}")
  end

  # Each stratum's quota, rows ordered by md5(seed || id), no row twice.
  defp draw(n, seed) do
    Enum.reduce(@strata, [], fn {name, share, condition}, acc ->
      taken = Enum.map(acc, &elem(&1, 1))
      k = max(1, round(n * share))

      %{rows: rows} =
        Repo.query!(
          """
          SELECT section_id FROM lat
          WHERE (#{condition}) AND NOT (law_name = ANY($2)) AND NOT (section_id = ANY($3))
          ORDER BY md5($1 || section_id) LIMIT $4
          """,
          [seed, @excluded_laws, taken, k],
          timeout: :infinity
        )

      acc ++ Enum.map(rows, fn [id] -> {name, id} end)
    end)
  end

  defp law_of(section_id), do: section_id |> String.split(":", parts: 2) |> hd()

  defp law_packets(law, rows) do
    ids = Enum.map(rows, &elem(&1, 1))
    stored = stored_rows(ids)
    notes = notes_for(ids)

    {xml_ids, xmls, store_paths} =
      case LatStagedParser.fetch_docs(law, store: :only) do
        {:ok, xmls, _} ->
          {:ok, parsed, _} = LatStagedParser.fetch_rows(law, store: :only)
          {located_ids(parsed), xmls, store_paths(law)}

        {:error, _} ->
          {%{}, [], store_paths(law)}
      end

    for {stratum, id} <- rows do
      {xml_id, located_by} = Map.get(xml_ids, id, {nil, nil})
      row_notes = Map.get(notes, id, [])

      %{
        stratum: stratum,
        law_name: law,
        section_id: id,
        row: Map.get(stored, id),
        xml_id: xml_id,
        # "own": the row's element; "enclosing": the nearest preceding row
        # with an id (tables have none — their provision holds them);
        # "signed": the SignedSection
        located_by: located_by,
        xml_fragment: fragment_for(xmls, xml_id, located_by),
        notes:
          Enum.map(row_notes, fn note ->
            Map.put(note, :commentary_xml, fragments(xmls, commentary_id(note.code)))
          end),
        store_paths: store_paths
      }
    end
  end

  @row_columns ~w(section_id law_name section_type sort_key position depth hierarchy_path
                  part chapter heading_group provision sub_provision paragraph sub_paragraph
                  schedule extent_code text title excluded_extent status effective_from
                  changed_by amendment_count modification_count commencement_count extent_count)

  defp stored_rows(ids) do
    %{columns: cols, rows: rows} =
      Repo.query!(
        "SELECT #{Enum.join(@row_columns, ", ")} FROM lat WHERE section_id = ANY($1)",
        [ids]
      )

    Map.new(rows, fn values ->
      row = cols |> Enum.zip(values) |> Map.new()
      {row["section_id"], row}
    end)
  end

  defp notes_for(ids) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT s.id, a.id, a.code, a.code_type, a.text, a.effect, a.effective_from,
               a.changed_by, a.affected_sections
        FROM amendment_annotations a
        JOIN unnest($1::text[]) AS s(id) ON s.id = ANY(a.affected_sections)
        """,
        [ids]
      )

    Enum.group_by(
      rows,
      &hd/1,
      fn [_, id, code, type, text, effect, from, by, sections] ->
        %{
          id: id,
          code: code,
          code_type: type,
          text: text,
          effect: effect,
          effective_from: from,
          changed_by: by,
          affected_sections: sections,
          # the row the note's status / effective_from apply to
          target: List.last(sections || [])
        }
      end
    )
  end

  # section_id → {xml id, how}: a row's own id, else (table, figure) the
  # nearest preceding row's; signature rows → their SignedSection.
  defp located_ids(parsed) do
    {pairs, _} =
      Enum.map_reduce(parsed, nil, fn row, last ->
        cond do
          row.xml_id -> {{row.section_id, {row.xml_id, "own"}}, row.xml_id}
          row.section_type == "signed" -> {{row.section_id, {nil, "signed"}}, last}
          true -> {{row.section_id, {last, "enclosing"}}, last}
        end
      end)

    Map.new(pairs)
  end

  defp fragment_for(xmls, _id, "signed"), do: tag_fragments(xmls, "SignedSection")
  defp fragment_for(_xmls, nil, _how), do: nil
  defp fragment_for(xmls, id, _how), do: fragments(xmls, id)

  defp tag_fragments(xmls, tag) do
    xmls
    |> Enum.flat_map(fn xml ->
      ~r/<#{tag}\b[^>]*>/
      |> Regex.scan(xml, return: :index)
      |> Enum.map(fn [{start, len}] -> element_at(xml, start, len, tag) end)
    end)
    |> case do
      [] -> nil
      found -> Enum.map(found, &truncate/1)
    end
  end

  # "F:key-abc" → "key-abc"; "F12" → "F12"
  defp commentary_id(code) do
    case String.split(code || "", ":", parts: 2) do
      [_type, ref] -> ref
      [ref] -> ref
    end
  end

  # Every element with that id across the law's documents (a provision and
  # its territorial alternative share one), raw, each cut at @fragment_limit.
  defp fragments(xmls, id) do
    xmls
    |> Enum.flat_map(&elements_with_id(&1, id))
    |> case do
      [] -> nil
      found -> Enum.map(found, &truncate/1)
    end
  end

  defp elements_with_id(xml, id) do
    ~r/<([A-Za-z][\w:]*)\b[^>]*\bid="#{Regex.escape(id)}"[^>]*>/
    |> Regex.scan(xml, return: :index)
    |> Enum.map(fn [{start, len}, {tag_start, tag_len}] ->
      tag = binary_part(xml, tag_start, tag_len)
      element_at(xml, start, len, tag)
    end)
  end

  # The element from its start tag to the matching close tag.
  defp element_at(xml, start, len, tag) do
    if String.ends_with?(binary_part(xml, start, len), "/>") do
      binary_part(xml, start, len)
    else
      rest = binary_part(xml, start + len, byte_size(xml) - start - len)
      stop = close_offset(rest, tag, 1, 0)
      binary_part(xml, start, len + stop)
    end
  end

  defp close_offset(_rest, _tag, 0, acc), do: acc

  defp close_offset(rest, tag, depth, acc) do
    case Regex.run(~r/<(\/?)#{Regex.escape(tag)}\b[^>]*?(\/?)>/, rest, return: :index) do
      nil ->
        acc + byte_size(rest)

      [{pos, len}, {cpos, clen}, {spos, slen}] ->
        closing = clen > 0 and binary_part(rest, cpos, clen) == "/"
        self_closing = slen > 0 and binary_part(rest, spos, slen) == "/"

        depth =
          cond do
            closing -> depth - 1
            self_closing -> depth
            true -> depth + 1
          end

        next = pos + len
        close_offset(binary_part(rest, next, byte_size(rest) - next), tag, depth, acc + next)
    end
  end

  defp truncate(fragment) when byte_size(fragment) <= @fragment_limit, do: fragment

  defp truncate(fragment) do
    cut = fragment |> String.slice(0, @fragment_limit)
    cut <> " …[truncated: #{byte_size(fragment)} bytes]"
  end

  defp store_paths(law) do
    case String.split(law, "_", parts: 4) do
      [_uk, type, year, number] ->
        Path.wildcard(Path.join(["data", "cache", "clml", type, year, number, "**", "*.xml.gz"]))

      _ ->
        []
    end
  end

  defp git_commit do
    case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      _ -> nil
    end
  end
end
