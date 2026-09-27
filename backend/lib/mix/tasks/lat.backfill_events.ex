defmodule Mix.Tasks.Lat.BackfillEvents do
  @moduledoc """
  Backfill `lat_events` from the LAT session log, enrichment verdicts and
  current LAT (see `SertantaiLegal.Legal.LatEvent.Backfill`). Idempotent:
  previous `backfill_*` events are replaced; live events are never touched.

      mix lat.backfill_events
  """

  use Mix.Task

  alias SertantaiLegal.Legal.LatEvent.Backfill

  @shortdoc "Backfill lat_events history (idempotent)"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Backfill.run()
    |> Enum.each(fn {step, n} ->
      Mix.shell().info("#{String.pad_trailing(to_string(step), 18)} #{n}")
    end)
  end
end
