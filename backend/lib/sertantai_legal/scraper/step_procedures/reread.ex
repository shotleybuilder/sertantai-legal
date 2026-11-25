defmodule SertantaiLegal.Scraper.StepProcedures.Reread do
  @moduledoc """
  The re-read chain a family's stale readings need: each stale
  commencement rule goes to the substep that re-reads it, in the order the
  readers depend on, then the stale extent readings, then the family's
  rebuild and its staleness report (`docs/lat-change-pipeline/COMMENCEMENT-READER.md`
  §4–5, `EXTENT-READER.md` §4). Pure: the stale rules come from
  `StepProcedures.RereadStale`, the stale extent laws from
  `StepProcedures.ExtentStale`, and `run/2` takes the runner.

  Substeps, in order:
  - `:own`: a law with LAT, its own clause (`--read`), read by its source law;
  - `:amending`: a law with no LAT, its own clause from the CLML
    (`--read-amending --workers 1`);
  - `:orders`: the Act an order commences (`--read-orders --held`), after
    `:own`, as an order's "appointed for" is resolved against the Act's rules;
  - `:effects`: the law the feed's rules commence (`--effects`);
  - `:extents`: the amending laws whose extent the family's builds read
    on other reader code, or never read (`lat.amending --extents`, the
    enabling cache only, one law at a time; parents first, in the write);
  - `:build` and `:stale`: the family's rebuild and `mix lat.stale`.
  """

  defmodule Step do
    @moduledoc "One substep of the re-read chain: its name, the laws it reads and its mix arguments."
    @enforce_keys [:substep, :laws, :args]
    defstruct [:substep, :laws, :args]

    @type t :: %__MODULE__{substep: atom(), laws: [String.t()], args: [String.t()]}
  end

  @type stale_rule :: %{
          source_law: String.t(),
          commences: String.t(),
          treatment: String.t(),
          lat?: boolean()
        }

  @reads [:own, :amending, :orders, :effects]
  @orders ~w(order_date order_schedule)

  @doc """
  The chain for `stale` rules and `extent_laws` of `family`: re-read
  substeps that have laws, then build and stale; empty when nothing is stale.
  """
  @spec chain([stale_rule()], String.t(), [String.t()]) :: [Step.t()]
  def chain(stale, family, extent_laws \\ [])
  def chain([], _family, []), do: []

  def chain(stale, family, extent_laws) do
    by = Enum.group_by(stale, &substep/1, &law/1)

    reads =
      for s <- @reads,
          laws = by |> Map.get(s, []) |> Enum.uniq() |> Enum.sort(),
          laws != [],
          do: %Step{substep: s, laws: laws, args: args(s, laws)}

    reads ++
      extents(extent_laws) ++
      [
        %Step{substep: :build, laws: [], args: ["lat.vocabulary", "--build", "--family", family]},
        %Step{substep: :stale, laws: [], args: ["lat.stale", "--family", family]}
      ]
  end

  @doc "Runs `steps` in turn with `runner` (`{exit, seconds}`), stopping after the first non-zero exit."
  @spec run([Step.t()], (Step.t() -> {integer(), integer()})) :: [{atom(), integer(), integer()}]
  def run(steps, runner) do
    Enum.reduce_while(steps, [], fn step, done ->
      {exit, secs} = runner.(step)
      done = [{step.substep, exit, secs} | done]
      if exit == 0, do: {:cont, done}, else: {:halt, done}
    end)
    |> Enum.reverse()
  end

  defp extents([]), do: []

  defp extents(laws) do
    laws = laws |> Enum.uniq() |> Enum.sort()
    [%Step{substep: :extents, laws: laws, args: args(:extents, laws)}]
  end

  defp substep(%{treatment: t}) when t in @orders, do: :orders
  defp substep(%{treatment: "feed_commencement"}), do: :effects
  defp substep(%{lat?: true}), do: :own
  defp substep(_rule), do: :amending

  defp law(%{treatment: t} = r) when t in @orders or t == "feed_commencement", do: r.commences
  defp law(r), do: r.source_law

  defp args(:own, laws), do: ["lat.commencement", "--read", "--law", Enum.join(laws, ",")]

  defp args(:amending, laws),
    do: ["lat.commencement", "--read-amending", "--law", Enum.join(laws, ","), "--workers", "1"]

  defp args(:orders, laws),
    do: ["lat.commencement", "--read-orders", "--law", Enum.join(laws, ","), "--held"]

  defp args(:extents, laws),
    do: [
      "lat.amending",
      "--extents",
      "--amending",
      Enum.join(laws, ","),
      "--cached",
      "--workers",
      "1"
    ]

  defp args(:effects, laws), do: ["lat.commencement", "--effects", "--law", Enum.join(laws, ",")]
end
