defmodule SertantaiLegal.Scraper.Commencement.Order.HeldAs do
  @moduledoc """
  Whether an order's held document is the order its name says. The
  document's own type (`ukm:DocumentMainType`) must be the type its name
  gives. legislation.gov.uk answers a request for the UK SI 2005/423 with
  the Welsh SI 2005/423, so the store holds that Welsh order under both
  names. An order held as another instrument commences nothing under the
  name it is held by. Pure.

  Only the instrument types orders are made as are checked; a type not
  listed here, or a document stating none, is never refused.
  """

  @types %{
    "uksi" => "UnitedKingdomStatutoryInstrument",
    "wsi" => "WelshStatutoryInstrument",
    "ssi" => "ScottishStatutoryInstrument",
    "nisr" => "NorthernIrelandStatutoryRule",
    "nisi" => "NorthernIrelandOrderInCouncil"
  }

  @main_type ~r/<ukm:DocumentMainType\s+Value="([A-Za-z]+)"/

  @doc "Whether `xml`, held for `law` (\"UK_uksi_2005_423\"), is that law's own document."
  @spec itself?(String.t(), String.t()) :: boolean()
  def itself?(law, xml) do
    with [_, type, _, _] <- String.split(law, "_", parts: 4),
         want when is_binary(want) <- Map.get(@types, type),
         [_, held] <- Regex.run(@main_type, xml) do
      held == want or held not in Map.values(@types)
    else
      _ -> true
    end
  end
end
