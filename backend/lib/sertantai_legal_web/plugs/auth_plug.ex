defmodule SertantaiLegalWeb.AuthPlug do
  @moduledoc """
  JWT validation plug for sertantai-legal.

  Validates EdDSA (Ed25519) Bearer tokens issued by sertantai-auth. The public
  key is fetched from auth's JWKS endpoint and cached by `JwksClient`.

  ## JWT Claims (from sertantai-auth)

      %{
        "sub" => "user?id=<uuid>",     # User identifier (AshAuthentication format)
        "org_id" => "<uuid>",           # Organization ID
        "role" => "owner",              # User role within org
        "iss" => "AshAuthentication v4.12.0",
        "exp" => 1772573910,           # Expiry timestamp
        "iat" => 1771364310,           # Issued at
        "nbf" => 1771364310            # Not before
      }

  ## Conn Assigns

  On success, sets:
  - `conn.assigns.current_user_id` - UUID extracted from sub claim
  - `conn.assigns.organization_id` - Organization UUID from org_id claim
  - `conn.assigns.user_role` - Role string from role claim
  - `conn.assigns.jwt_claims` - Full decoded claims map
  """

  import Plug.Conn

  alias SertantaiLegal.Auth.JwksClient

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with {:ok, token} <- extract_token(conn),
         {:ok, claims} <- verify_token(token),
         {:ok, user_id} <- extract_user_id(claims) do
      conn
      |> assign(:current_user_id, user_id)
      |> assign(:organization_id, claims["org_id"])
      |> assign(:user_role, claims["role"])
      |> assign(:jwt_claims, claims)
    else
      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Unauthorized", reason: reason}))
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, "Missing or invalid Authorization header"}
    end
  end

  defp verify_token(token) do
    with {:ok, jwk} <- JwksClient.public_key() do
      case JOSE.JWT.verify_strict(jwk, ["EdDSA"], token) do
        {true, %JOSE.JWT{fields: claims}, _jws} ->
          validate_claims(claims)

        {false, _, _} ->
          {:error, "Invalid token signature"}
      end
    else
      {:error, :no_key} ->
        {:error, "Auth service unavailable (no signing key)"}
    end
  rescue
    _ -> {:error, "Malformed token"}
  end

  defp validate_claims(claims) do
    now = System.system_time(:second)

    cond do
      not is_integer(claims["exp"]) ->
        {:error, "Token missing expiry"}

      claims["exp"] < now ->
        {:error, "Token expired"}

      true ->
        {:ok, claims}
    end
  end

  defp extract_user_id(%{"sub" => "user?id=" <> user_id}), do: {:ok, user_id}
  defp extract_user_id(%{"sub" => sub}) when is_binary(sub), do: {:ok, sub}
  defp extract_user_id(_claims), do: {:error, "Token missing sub claim"}
end
