defmodule SertantaiLegal.Scraper.LawRunner.Guard do
  @moduledoc """
  How many laws a corpus run may read at once, from the machine's state
  just before it starts (run time, 2026-10-25). A 5-wide run once crashed
  the machine while a VM was open (Jason 2026-10-25); so a run looks
  before going parallel:

  - **memory**: `MemAvailable` less a reserve, divided by the measured peak
    of one law (the largest Acts: ~1.7 GB in their own process, ukpga
    2010/4);
  - **load**: the cores not already busy, measured over half a second
    (`/proc/stat`; the 1-minute load average lags, still counting a run
    that has just finished);
  - **heavy processes**: a VM (`qemu`, VirtualBox, VMware, GNOME Boxes)
    running means one law at a time.

  Never more than `max` (default 4 of the machine's cores, leaving it
  usable). `decide/2` is pure; `probe/0` reads `/proc` and the process
  list; `workers/1` does both and says what it decided and why.
  """

  @max 4
  @per_law_kb 1_800_000
  @reserve_kb 6_000_000
  @heavy ~r/^(?:qemu|qemu-system-\S+|VirtualBox|VBoxHeadless|VirtualBoxVM|vmware-vmx|gnome-boxes)$/

  @type probe :: %{
          mem_available_kb: non_neg_integer() | nil,
          busy: float() | nil,
          cores: pos_integer(),
          heavy: [String.t()]
        }

  @doc """
  `{workers, why}` for a probe. `opts`: `:max`, `:per_law_kb`,
  `:reserve_kb`.
  """
  @spec decide(probe(), keyword()) :: {pos_integer(), String.t()}
  def decide(probe, opts \\ []) do
    max = Keyword.get(opts, :max, @max)
    per_law = Keyword.get(opts, :per_law_kb, @per_law_kb)
    reserve = Keyword.get(opts, :reserve_kb, @reserve_kb)

    cond do
      probe.heavy != [] ->
        {1, "one at a time: #{Enum.join(Enum.uniq(probe.heavy), ", ")} running"}

      probe.mem_available_kb == nil or probe.busy == nil ->
        {1, "one at a time: system state not readable"}

      true ->
        by_memory = div(max(probe.mem_available_kb - reserve, 0), per_law)
        by_load = probe.cores - ceil(probe.busy)
        workers = [max, by_memory, by_load] |> Enum.min() |> max(1)

        {workers,
         "#{workers} at once: #{gb(probe.mem_available_kb)} GB available (#{gb(reserve)} kept), " <>
           "~#{gb(per_law)} GB a law; #{probe.busy} of #{probe.cores} cores busy; max #{max}"}
    end
  end

  @doc "The machine's state now."
  @spec probe() :: probe()
  def probe do
    %{
      mem_available_kb: mem_available(),
      busy: busy(),
      cores: System.schedulers_online(),
      heavy: heavy()
    }
  end

  @doc """
  Workers for a run: `opts[:workers]` when given (the caller's choice),
  else `decide(probe())`. Prints the decision.
  """
  @spec workers(keyword()) :: pos_integer()
  def workers(opts \\ []) do
    {workers, why} =
      case Keyword.get(opts, :workers) do
        n when is_integer(n) and n > 0 -> {n, "#{n} at once (--workers)"}
        _ -> decide(probe(), opts)
      end

    Mix.shell().info("laws read #{why}")
    workers
  end

  defp mem_available do
    with {:ok, text} <- File.read("/proc/meminfo"),
         [_, kb] <- Regex.run(~r/^MemAvailable:\s+(\d+)\s+kB/m, text) do
      String.to_integer(kb)
    else
      _ -> nil
    end
  end

  # cores busy over half a second: (1 − idle share) × cores
  defp busy do
    with {t1, i1} <- cpu_times(),
         :ok <- Process.sleep(500),
         {t2, i2} <- cpu_times(),
         true <- t2 > t1 do
      Float.round((1 - (i2 - i1) / (t2 - t1)) * System.schedulers_online(), 1)
    else
      _ -> nil
    end
  end

  # the "cpu" line of /proc/stat: {total jiffies, idle + iowait}
  defp cpu_times do
    with {:ok, text} <- File.read("/proc/stat"),
         [line | _] <- String.split(text, "\n"),
         ["cpu" | fields] <- String.split(line) do
      nums = Enum.map(fields, &String.to_integer/1)
      {Enum.sum(nums), Enum.at(nums, 3, 0) + Enum.at(nums, 4, 0)}
    else
      _ -> nil
    end
  end

  defp heavy do
    case System.cmd("ps", ["-eo", "comm="], stderr_to_stdout: true) do
      {out, 0} -> out |> String.split("\n", trim: true) |> Enum.filter(&(&1 =~ @heavy))
      _ -> []
    end
  rescue
    _ -> []
  end

  defp gb(kb), do: Float.round(kb / 1_000_000, 1)
end
