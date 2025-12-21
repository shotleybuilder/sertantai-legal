defmodule SertantaiLegalWeb.HelloController do
  use SertantaiLegalWeb, :controller

  @doc """
  Simple hello endpoint to test API connectivity.
  Returns a friendly greeting message.
  """
  def index(conn, _params) do
    json(conn, %{
      message: "Hello from Sertantai Legal API!",
      environment: Application.get_env(:sertantai_legal, :environment, :dev),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
end
