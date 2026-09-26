defmodule SertantaiLegal.Scraper.LatEvents do
  @moduledoc """
  `lat` sync events for fractalaw, stamped with the law's committed
  `row_count` and `lat_hash` (fractalatai #62).

  Call only after the LAT write has committed, so the hash describes what the
  queryable will serve. Events can still be dropped (the ChangeNotifier drops
  them while its publisher is not ready); the LAT manifest is the source of
  truth and self-heals missed events.
  """

  alias SertantaiLegal.Scraper.LatHash.Query
  alias SertantaiLegal.Zenoh.ChangeNotifier

  @doc "Publish a `lat` event for `law_name`, merging `extra` into its metadata."
  @spec notify(String.t(), String.t(), map()) :: :ok
  def notify(law_name, action, extra \\ %{}) do
    metadata =
      %{law_name: law_name}
      |> Map.merge(extra)
      |> Map.merge(Query.event_metadata(law_name))

    ChangeNotifier.notify("lat", action, metadata)
  end

  @doc "Publish one `lat` event per law named in `section_ids` (`<law_name>:<id>`)."
  @spec notify_laws([String.t()], String.t(), map()) :: :ok
  def notify_laws(section_ids, action, extra \\ %{}) do
    section_ids
    |> Enum.map(&(&1 |> String.split(":", parts: 2) |> hd()))
    |> Enum.uniq()
    |> Enum.each(&notify(&1, action, extra))
  end
end
