defmodule SertantaiLegalWeb.LoadFromCookieTest do
  use SertantaiLegalWeb.ConnCase, async: true

  alias SertantaiLegalWeb.LoadFromCookie

  @cookie_name "sertantai_token"

  describe "call/2" do
    test "injects Bearer header from cookie when no Authorization present", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie(@cookie_name, "test-token-value")
        |> LoadFromCookie.call([])

      assert ["Bearer test-token-value"] = get_req_header(conn, "authorization")
    end

    test "does not override existing Bearer header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer original-token")
        |> put_req_cookie(@cookie_name, "cookie-token")
        |> LoadFromCookie.call([])

      assert ["Bearer original-token"] = get_req_header(conn, "authorization")
    end

    test "does nothing when no cookie present", %{conn: conn} do
      conn = LoadFromCookie.call(conn, [])

      assert [] = get_req_header(conn, "authorization")
    end

    test "does nothing for empty cookie value", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie(@cookie_name, "")
        |> LoadFromCookie.call([])

      assert [] = get_req_header(conn, "authorization")
    end
  end
end
