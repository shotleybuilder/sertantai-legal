defmodule Mix.Tasks.Lat.ParseSnapshot do
  @moduledoc """
  The zero-diff gate for behaviour-preserving parser refactors (LR-04):
  every law parsed offline with its effects (`LatStagedParser.fetch_changes/2`),
  saved whole — every row field and every note field (with the effects
  joined to it) — then compared field by field after a change. (Change
  labels are the timeline's, LR-25: `mix lat.timeline` reports them.)

      mix lat.parse_snapshot --all --dir data/reports/lat-refactor/lr04-snapshot
      mix lat.parse_snapshot --all --dir data/reports/lat-refactor/lr04-snapshot --compare

  Write mode saves `<dir>/<law>.etf.gz` per law (resumes: laws already
  saved are skipped). `--compare` parses afresh and compares with the saved
  snapshot; every difference is a line in `<dir>.compare.csv` (law_name,
  part, index, id, field, base, new) and the run ends with the total, which
  must be 0. Notes are compared in note-id order: the ids
  are the output, the list order is not. `--store` as `lat.text_diff` (default `only`: no requests);
  `--laws A,B` instead of `--all`.
  """

  use Mix.Task

  alias NimbleCSV.RFC4180, as: CSV
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatStagedParser

  @shortdoc "Snapshot every law's full parse, or compare a fresh parse with the snapshot"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [laws: :string, all: :boolean, dir: :string, store: :string, compare: :boolean]
      )

    Mix.Task.run("app.start")

    dir = opts[:dir] || Mix.raise("Give --dir DIR")
    File.mkdir_p!(dir)

    mode =
      case opts[:store] || "only" do
        m when m in ~w(prefer only refresh) -> String.to_atom(m)
        m -> Mix.raise("--store must be prefer, only or refresh, got #{m}")
      end

    laws =
      cond do
        opts[:laws] -> String.split(opts[:laws], ",", trim: true)
        opts[:all] -> laws_with_lat()
        true -> Mix.raise("Give --laws A,B or --all")
      end

    if opts[:compare], do: compare(laws, dir, mode), else: write(laws, dir, mode)
  end

  defp write(laws, dir, mode) do
    todo = Enum.reject(laws, &File.exists?(path(dir, &1)))
    Mix.shell().info("#{length(todo)} laws to snapshot (#{length(laws) - length(todo)} saved)")

    {ok, failed} =
      todo
      |> stream(mode)
      |> Enum.reduce({0, []}, fn
        {law, {:ok, snap}}, {n, failed} ->
          File.write!(path(dir, law), :erlang.term_to_binary(snap, [:compressed]))
          {n + 1, failed}

        {law, {:error, reason}}, {n, failed} ->
          {n, [{law, reason} | failed]}
      end)

    report_failed(failed)
    Mix.shell().info("#{ok} laws saved to #{dir}")
  end

  defp compare(laws, dir, mode) do
    out = String.trim_trailing(dir, "/") <> ".compare.csv"
    File.write!(out, CSV.dump_to_iodata([~w(law_name part index id field base new)]))
    saved = Enum.filter(laws, &File.exists?(path(dir, &1)))
    Mix.shell().info("#{length(saved)} laws to compare (#{length(laws) - length(saved)} unsaved)")

    {total, laws_differing, failed} =
      saved
      |> stream(mode)
      |> Enum.reduce({0, 0, []}, fn
        {law, {:ok, snap}}, {total, n, failed} ->
          base = dir |> path(law) |> File.read!() |> :erlang.binary_to_term()
          lines = diff(law, base, snap)

          if lines != [] do
            File.write!(out, CSV.dump_to_iodata(lines), [:append])
            Mix.shell().info("  #{law}: #{length(lines)} differences")
          end

          {total + length(lines), n + if(lines == [], do: 0, else: 1), failed}

        {law, {:error, reason}}, {total, n, failed} ->
          {total, n, [{law, reason} | failed]}
      end)

    report_failed(failed)
    Mix.shell().info("\n#{total} differences in #{laws_differing} laws (#{out})")
  end

  defp stream(laws, mode) do
    laws
    |> Task.async_stream(&{&1, snapshot(&1, mode)},
      max_concurrency: System.schedulers_online(),
      timeout: :infinity,
      ordered: false
    )
    |> Stream.map(fn {:ok, result} -> result end)
  end

  defp snapshot(law, mode) do
    with {:ok, %{rows: rows, notes: notes}} <- LatStagedParser.fetch_changes(law, store: mode) do
      notes = Enum.map(notes, &%{&1 | code_type: to_string(&1.code_type)})
      {:ok, %{rows: rows, notes: notes}}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  # Every field of every row / note (by position).
  defp diff(law, base, new) do
    base = by_note_id(base)
    new = by_note_id(new)

    lists =
      for part <- [:rows, :notes] do
        b = Map.fetch!(base, part)
        n = Map.fetch!(new, part)

        count =
          if length(b) != length(n),
            do: [[law, part, "", "", "count", length(b), length(n)]],
            else: []

        count ++
          (Enum.zip(b, n)
           |> Enum.with_index()
           |> Enum.flat_map(fn {{bi, ni}, i} -> fields(law, part, i, id(bi), bi, ni) end))
      end

    lists |> Enum.concat() |> Enum.map(fn line -> Enum.map(line, &str/1) end)
  end

  # Notes in note-id order: ids are the output ({law}:{code_type}:{seq}),
  # the list order is not (LR-04: it followed the VM's atom table before
  # CommentaryParser grouped by name)
  defp by_note_id(%{notes: notes} = snap), do: %{snap | notes: Enum.sort_by(notes, & &1.id)}

  defp fields(_law, _part, _i, _id, same, same), do: []

  defp fields(law, part, i, id, b, n) when is_map(b) and is_map(n) do
    b = if is_struct(b), do: Map.from_struct(b), else: b
    n = if is_struct(n), do: Map.from_struct(n), else: n

    for k <- Enum.uniq(Map.keys(b) ++ Map.keys(n)),
        Map.get(b, k, :missing) != Map.get(n, k, :missing),
        do: [law, part, i, id, k, Map.get(b, k, :missing), Map.get(n, k, :missing)]
  end

  defp fields(law, part, i, id, b, n), do: [[law, part, i, id, "", b, n]]

  defp id(%{section_id: sid}), do: sid
  defp id(%{code: code}), do: code
  defp id(_), do: ""

  defp str(v) when is_binary(v), do: v
  defp str(v) when is_atom(v) or is_integer(v), do: to_string(v)
  defp str(v), do: inspect(v, limit: 50, printable_limit: 500)

  defp path(dir, law), do: Path.join(dir, law <> ".etf.gz")

  defp report_failed([]), do: :ok

  defp report_failed(failed) do
    Mix.shell().error("#{length(failed)} laws failed:")
    Enum.each(failed, fn {law, reason} -> Mix.shell().error("  #{law}: #{reason}") end)
  end

  defp laws_with_lat do
    %{rows: rows} =
      Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY law_name", [],
        timeout: :infinity
      )

    List.flatten(rows)
  end
end
