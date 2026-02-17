defmodule SertantaiLegalWeb.AuthPlug do
  @moduledoc """
  JWT validation plug for sertantai-legal.

  Validates Bearer tokens issued by sertantai-auth using the shared token secret.
  Extracts user_id and org_id from JWT claims and assigns them to the connection.

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
    secret = Application.get_env(:sertantai_legal, :shared_token_secret)

    unless secret do
      raise "shared_token_secret not configured. Set it in config or SHARED_TOKEN_SECRET env var."
    end

    jwk = JOSE.JWK.from_oct(secret)

    case JOSE.JWT.verify_strict(jwk, ["HS256"], token) do
      {true, %JOSE.JWT{fields: claims}, _jws} ->
        validate_claims(claims)

      {false, _, _} ->
        {:error, "Invalid token signature"}
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
