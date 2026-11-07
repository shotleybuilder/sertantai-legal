defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.Dump do
  @moduledoc """
  Every held law's stored extent reading as the census reads it (CV-S05d
  `dump.exs`, #192): one JSON line per law with its default,
  application, list and apply rows, catalogue sentences and the sweep's
  uncaught sentences with their sweep form. The census's only reach
  into the extent reader (`Extent.ReadCache`, `SweepForm`); the census
  itself shares no code with it. Keys are written in a fixed order.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache
  alias SertantaiLegal.Scraper.AmendingLaw.SweepForm

  @doc "The JSON lines for `laws` (default every held law), and the count of laws asked."
  @spec run([String.t()] | nil) :: {[String.t()], non_neg_integer()}
  def run(laws \\ nil) do
    laws = laws || ReadCache.held()

    lines =
      laws
      |> Task.async_stream(&line/1, max_concurrency: 4, timeout: :infinity)
      |> Enum.flat_map(fn
        {:ok, nil} -> []
        {:ok, l} -> [l]
      end)

    {lines, length(laws)}
  end

  defp line(law) do
    case ReadCache.law(law) do
      nil -> nil
      r -> r |> reading(law) |> Jason.encode!()
    end
  end

  defp reading(r, law) do
    Jason.OrderedObject.new([
      {"law", law},
      {"default", r.read.default},
      {"application", r.read.application},
      {"lists", rows(r.read.lists)},
      {"applies", rows(r.read.applies)},
      {"sentences", sentences(r)}
    ])
  end

  defp rows(l),
    do:
      for(
        {k, p, refs} <- l,
        do: Jason.OrderedObject.new([{"kind", k}, {"place", p}, {"refs", refs}])
      )

  defp sentences(r) do
    for(
      {ref, s, c} <- r.classes,
      do: Jason.OrderedObject.new([{"ref", ref}, {"class", c}, {"s", s}])
    ) ++
      for {ref, s, net} <- r.uncaught do
        Jason.OrderedObject.new([
          {"ref", ref},
          {"class", "sweep:" <> SweepForm.form(s)},
          {"net", net},
          {"s", s}
        ])
      end
  end
end
