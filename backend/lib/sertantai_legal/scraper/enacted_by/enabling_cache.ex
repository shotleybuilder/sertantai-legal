defmodule SertantaiLegal.Scraper.EnactedBy.EnablingCache do
  @moduledoc """
  An SI's enabling provisions, fetched from its introduction (never the
  body), parsed by `EnactedBy.EnablingProvisions` and cached in
  `data/cache/enabling/<law>.json`.

  Shared by `mix live.enabling` (enabling-extent evidence) and `mix lat.scope
  --relevance` (#166: which Parts of a large Act its SIs are made under).
  """

  alias SertantaiLegal.Scraper.EnactedBy
  alias SertantaiLegal.Scraper.EnactedBy.EnablingProvisions

  @cache Path.join(["data", "cache", "enabling"])

  @doc "The cached provisions for `name`, fetching (and caching) them on a miss."
  @spec get(String.t()) :: [map()]
  def get(name) do
    path = Path.join(@cache, name <> ".json")

    case File.read(path) do
      {:ok, json} ->
        Jason.decode!(json)

      _ ->
        ps = fetch(name)
        File.mkdir_p!(@cache)
        File.write!(path, Jason.encode!(ps))
        ps
    end
  end

  defp fetch(name) do
    with ["UK", type, year | number] when number != [] <- String.split(name, "_"),
         {:ok, %{text: text, urls: urls}} <-
           EnactedBy.fetch_enacting_data(
             EnactedBy.introduction_path(type, year, Enum.join(number, "_"))
           ) do
      text
      |> EnablingProvisions.parse(urls)
      |> Enum.map(&%{"law" => &1.law, "sections" => &1.sections, "schedules" => &1.schedules})
    else
      _ -> []
    end
  end
end
