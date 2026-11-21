defmodule SertantaiLegal.Scraper.LawStart.LaidDay do
  @moduledoc """
  The day an instrument was laid, from its CLML metadata: `<ukm:Laid
  Date="2018-11-28" Class="UnitedKingdomParliament"/>`. The metadata may
  hold one element per House or legislature; an instrument is laid once it
  is before each, so where the days differ the later is the day "on which
  these Regulations are laid". Pure.
  """

  @laid ~r/<ukm:Laid\b[^>]*?\bDate="(\d{4}-\d{2}-\d{2})"/

  @doc "The laid day the metadata `head` states (the latest of several); nil when it states none."
  @spec parse(String.t() | nil) :: Date.t() | nil
  def parse(nil), do: nil

  def parse(head) do
    @laid
    |> Regex.scan(head, capture: :all_but_first)
    |> Enum.flat_map(fn [iso] ->
      case Date.from_iso8601(iso) do
        {:ok, date} -> [date]
        _ -> []
      end
    end)
    |> Enum.max(Date, fn -> nil end)
  end
end
