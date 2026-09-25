defmodule SertantaiLegalWeb.WorkflowRoutesTest do
  use SertantaiLegalWeb.ConnCase, async: false

  @key "workflow-test-key"

  setup do
    System.put_env("WORKFLOW_API_KEY", @key)
    on_exit(fn -> System.delete_env("WORKFLOW_API_KEY") end)
    :ok
  end

  test "workflow LAT routes reject requests without the workflow key", %{conn: conn} do
    conn = get(conn, "/api/workflow/lat/sessions")
    assert conn.status == 401
  end

  test "workflow LAT routes accept the workflow key", %{conn: conn} do
    conn = conn |> put_req_header("x-api-key", @key) |> get("/api/workflow/lat/sessions")
    assert conn.status == 200
  end

  test "the SSE parse route is guarded by the workflow key", %{conn: conn} do
    conn = get(conn, "/api/workflow/lat/sessions/none/parse-stream?name=UK_x")
    assert conn.status == 401
  end
end
