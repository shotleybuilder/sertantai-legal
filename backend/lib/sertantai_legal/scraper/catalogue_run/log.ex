defmodule SertantaiLegal.Scraper.CatalogueRun.Log do
  @moduledoc """
  The catalogue runs' log, `data/reports/catalogue-runs.jsonl`: one JSON
  line a run (`CatalogueRun`), appended by every whole-store catalogue
  whatever its scope; and the memory a run reaches, sampled while it runs.
  IO: the log file and git (the commit).
  """

  alias SertantaiLegal.Scraper.CatalogueRun

  @path "data/reports/catalogue-runs.jsonl"
  @every_ms 500

  @doc """
  Runs a catalogue's work and records it: `fun` returns `{value, sources,
  serial_us}` — `sources` each cache's `:hit | :read` per law (`%{name =>
  [...]}`, empty for no cache) and `serial_us` the microseconds of its
  in-order merge. `fields`: `:catalogue`, `:scope`, `:workers`. The run is
  timed, its memory sampled (`sample_peak/1`), its record appended to the
  log, and `{value, run}` returned for the task to print `CatalogueRun.line/1`.
  """
  @spec record(keyword(), (-> {value, %{String.t() => [:hit | :read]}, non_neg_integer()})) ::
          {value, CatalogueRun.t()}
        when value: term()
  def record(fields, fun) do
    started = DateTime.utc_now() |> DateTime.truncate(:second)
    {{us, {value, sources, serial_us}}, peak} = sample_peak(fn -> :timer.tc(fun) end)

    run =
      CatalogueRun.new(
        catalogue: Keyword.fetch!(fields, :catalogue),
        scope: Keyword.fetch!(fields, :scope),
        workers: Keyword.fetch!(fields, :workers),
        started_at: started,
        commit: commit(),
        caches: Map.new(sources, fn {name, s} -> {name, CatalogueRun.tally(s)} end),
        wall_s: seconds(us),
        serial_s: seconds(serial_us),
        peak_mb: peak
      )

    append(run, Keyword.get(fields, :log, @path))
    {value, run}
  end

  defp seconds(us), do: Float.round(us / 1_000_000, 1)

  @doc "Appends `run` as one JSON line to the log (`path`: the log, for tests)."
  @spec append(CatalogueRun.t(), String.t()) :: :ok
  def append(%CatalogueRun{} = run, path \\ @path) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(CatalogueRun.to_json(run)) <> "\n", [:append])
  end

  @doc """
  `fun`'s result and the peak of the VM's memory while it ran (MB): sampled
  every #{@every_ms} ms by a linked process, so a parallel read's peak is
  caught, not two points either side of it.
  """
  @spec sample_peak((-> result)) :: {result, non_neg_integer()} when result: term()
  def sample_peak(fun) do
    sampler = spawn_link(fn -> sample(mb()) end)
    result = fun.()
    send(sampler, {:stop, self()})

    receive do
      {:peak, peak} -> {result, max(peak, mb())}
    end
  end

  @doc "The commit the code runs at (`git rev-parse --short HEAD`); nil outside a git checkout."
  @spec commit() :: String.t() | nil
  def commit do
    case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      _ -> nil
    end
  end

  defp sample(peak) do
    receive do
      {:stop, from} -> send(from, {:peak, max(peak, mb())})
    after
      @every_ms -> sample(max(peak, mb()))
    end
  end

  defp mb, do: div(:erlang.memory(:total), 1_048_576)
end
