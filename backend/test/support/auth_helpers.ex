defmodule SertantaiLegal.AuthHelpers do
  @moduledoc """
  Test helpers for JWT authentication.

  Generates valid JWT tokens locally using JOSE, matching the format
  produced by sertantai-auth's AshAuthentication. No running auth
  service needed.

  ## Usage

      # In tests:
      import SertantaiLegal.AuthHelpers

      test "requires auth", %{conn: conn} do
        conn = conn |> put_auth_header() |> get("/api/sessions")
        assert json_response(conn, 200)
      end

      test "custom claims", %{conn: conn} do
        token = build_token(%{"role" => "member", "org_id" => "custom-org-id"})
        conn = conn |> put_req_header("authorization", "Bearer \#{token}") |> get("/api/sessions")
        assert json_response(conn, 200)
      end
  """

  @default_user_id "test-user-00000000-0000-0000-0000-000000000001"
  @default_org_id "test-org-00000000-0000-0000-0000-000000000001"

  @doc """
  Builds a signed JWT token with the given claims merged over defaults.

  Default claims match the format produced by sertantai-auth:
  - `sub`: `"user?id=<uuid>"` (AshAuthentication format)
  - `org_id`: test organization UUID
  - `role`: `"owner"`
  - `iss`: `"AshAuthentication v4.12.0"`
  - `exp`: 1 hour from now
  - `iat`/`nbf`: now
  """
  def build_token(overrides \\ %{}) do
    now = System.system_time(:second)

    claims =
      %{
        "sub" => "user?id=#{@default_user_id}",
        "org_id" => @default_org_id,
        "role" => "owner",
        "iss" => "AshAuthentication v4.12.0",
        "aud" => "~> 4.12",
        "exp" => now + 3600,
        "iat" => now,
        "nbf" => now,
        "jti" => Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
      }
      |> Map.merge(overrides)

    secret = Application.get_env(:sertantai_legal, :shared_token_secret)
    jwk = JOSE.JWK.from_oct(secret)
    jws = %{"alg" => "HS256"}

    {_, token} = JOSE.JWT.sign(jwk, jws, claims) |> JOSE.JWS.compact()
    token
  end

  @doc """
  Builds an expired JWT token for testing expiry handling.
  """
  def build_expired_token(overrides \\ %{}) do
    build_token(Map.merge(%{"exp" => System.system_time(:second) - 3600}, overrides))
  end

  @doc """
  Adds a valid Authorization header to the connection.

  Accepts optional claim overrides.
  """
  def put_auth_header(conn, overrides \\ %{}) do
    token = build_token(overrides)
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  @doc """
  Returns the default test user ID.
  """
  def default_user_id, do: @default_user_id

  @doc """
  Returns the default test organization ID.
  """
  def default_org_id, do: @default_org_id
end
