defmodule SertantaiLegal.Auth.JwksClient do
  @moduledoc """
  Fetches and caches the EdDSA public key from sertantai-auth's JWKS endpoint.

  On startup, fetches the JSON Web Key Set from `{auth_url}/.well-known/jwks.json`,
  extracts the signing key, and caches it as a `JOSE.JWK` struct. The key is
  refreshed periodically (every hour) to handle key rotation.

  In test mode, skips the HTTP fetch — tests provide their own keypair via
  `set_test_key/1`.

  When `auth_url` is not configured, runs in degraded mode — JWT tenant auth
  is disabled but the service continues (admin-only mode via GitHub OAuth).

  ## Usage

      # Get the cached public key for JWT verification
      {:ok, jwk} = SertantaiLegal.Auth.JwksClient.public_key()

      # Force a refresh (e.g. after a verification failure)
      SertantaiLegal.Auth.JwksClient.refresh()
  """

  use GenServer

  require Logger

  @refresh_interval :timer.hours(1)
  @retry_interval :timer.seconds(30)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns the cached JWKS public key as a JOSE.JWK struct."
  @spec public_key() :: {:ok, JOSE.JWK.t()} | {:error, :no_key}
  def public_key do
    GenServer.call(__MODULE__, :public_key)
  end

  @doc "Forces an immediate re-fetch of the JWKS."
  @spec refresh() :: :ok
  def refresh do
    GenServer.cast(__MODULE__, :refresh)
  end

  @doc "Sets a test key directly (test mode only)."
  @spec set_test_key(JOSE.JWK.t()) :: :ok
  def set_test_key(jwk) do
    GenServer.call(__MODULE__, {:set_test_key, jwk})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    if Application.get_env(:sertantai_legal, :test_mode, false) do
      Logger.info("JWKS Client started in test mode (no HTTP fetch)")
      {:ok, %{key: nil}}
    else
      # Fetch asynchronously so we don't block the supervision tree
      send(self(), :fetch)
      {:ok, %{key: nil}}
    end
  end

  @impl true
  def handle_call(:public_key, _from, state) do
    case state.key do
      nil -> {:reply, {:error, :no_key}, state}
      jwk -> {:reply, {:ok, jwk}, state}
    end
  end

  def handle_call({:set_test_key, jwk}, _from, state) do
    {:reply, :ok, %{state | key: jwk}}
  end

  @impl true
  def handle_cast(:refresh, state) do
    case fetch_jwks() do
      {:ok, jwk} ->
        schedule_refresh(@refresh_interval)
        {:noreply, %{state | key: jwk}}

      {:error, :no_auth_url} ->
        {:noreply, state}

      {:error, reason} ->
        Logger.warning("JWKS refresh failed: #{inspect(reason)}, keeping existing key")
        schedule_refresh(@retry_interval)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:fetch, state) do
    case fetch_jwks() do
      {:ok, jwk} ->
        Logger.info("JWKS public key fetched successfully")
        schedule_refresh(@refresh_interval)
        {:noreply, %{state | key: jwk}}

      {:error, :no_auth_url} ->
        Logger.info("auth_url not configured — running without JWKS (admin-only mode)")
        {:noreply, state}

      {:error, reason} ->
        Logger.warning("JWKS fetch failed: #{inspect(reason)}, retrying in 30s")
        schedule_refresh(@retry_interval)
        {:noreply, state}
    end
  end

  # Private

  defp fetch_jwks do
    auth_url = Application.get_env(:sertantai_legal, :auth_url)

    unless auth_url do
      {:error, :no_auth_url}
    else
      url = "#{auth_url}/.well-known/jwks.json"

      case Req.get(url, receive_timeout: 10_000, retry: false, plug: req_plug()) do
        {:ok, %Req.Response{status: 200, body: %{"keys" => [key | _]}}} ->
          jwk = JOSE.JWK.from_map(key)
          {:ok, jwk}

        {:ok, %Req.Response{status: 200, body: %{"keys" => []}}} ->
          {:error, :no_keys_in_jwks}

        {:ok, %Req.Response{status: status}} ->
          {:error, {:unexpected_status, status}}

        {:error, %Req.TransportError{reason: reason}} ->
          {:error, {:transport, reason}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp schedule_refresh(interval) do
    Process.send_after(self(), :fetch, interval)
  end

  defp req_plug do
    Application.get_env(:sertantai_legal, :jwks_req_plug)
  end
end
