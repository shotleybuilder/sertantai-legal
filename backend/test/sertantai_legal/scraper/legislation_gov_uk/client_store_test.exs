defmodule SertantaiLegal.Scraper.LegislationGovUk.ClientStoreTest do
  # Req.Test stubs are process-scoped; async is fine
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LegislationGovUk.{Client, ClmlStore}

  @xml "<Legislation><dct:valid>2024-03-01</dct:valid><Body/></Legislation>"
  @path "/uksi/1992/3004/regulation/2/data.xml"

  setup do
    root = Path.join(System.tmp_dir!(), "client_store_test_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(root) end)

    counter = :counters.new(1, [])

    Req.Test.stub(Client, fn conn ->
      :counters.add(counter, 1, 1)

      if String.contains?(conn.request_path, "/rule/") do
        Plug.Conn.send_resp(conn, 404, "not found")
      else
        conn
        |> Plug.Conn.put_resp_content_type("application/xml")
        |> Plug.Conn.send_resp(200, @xml)
      end
    end)

    {:ok, root: root, requests: fn -> :counters.get(counter, 1) end}
  end

  test "default (:write) fetches live and stores what comes back", %{root: root, requests: n} do
    assert {:ok, @xml} = Client.fetch_xml(@path, root: root)
    assert n.() == 1
    assert {:ok, @xml, %{dct_valid: ~D[2024-03-01]}} = ClmlStore.get(@path, root: root)
  end

  test ":prefer uses a fresh stored copy without a request", %{root: root, requests: n} do
    :ok = ClmlStore.put(@path, @xml, root: root)

    assert {:ok, @xml} =
             Client.fetch_xml(@path, root: root, store: :prefer, law_valid: ~D[2024-01-01])

    assert n.() == 0
  end

  test ":prefer fetches when the stored copy is older than the law's valid date", %{
    root: root,
    requests: n
  } do
    :ok =
      ClmlStore.put(@path, "<Legislation><dct:valid>2020-01-01</dct:valid></Legislation>",
        root: root
      )

    assert {:ok, @xml} =
             Client.fetch_xml(@path, root: root, store: :prefer, law_valid: ~D[2024-03-01])

    assert n.() == 1
    assert {:ok, @xml, _} = ClmlStore.get(@path, root: root)
  end

  test "a 404 is stored, and :prefer returns it without a request", %{root: root, requests: n} do
    path = "/uksi/1992/3004/rule/2/data.xml"

    assert {:error, 404, _} = Client.fetch_xml(path, root: root)
    assert {:missing, _} = ClmlStore.get(path, root: root)

    assert {:error, 404, _} = Client.fetch_xml(path, root: root, store: :prefer)
    assert n.() == 1
  end

  test ":only never makes a request: a stored copy (even stale) or an error", %{
    root: root,
    requests: n
  } do
    :ok =
      ClmlStore.put(@path, "<Legislation><dct:valid>2020-01-01</dct:valid></Legislation>",
        root: root
      )

    assert {:ok, _} = Client.fetch_xml(@path, root: root, store: :only, law_valid: ~D[2024-03-01])

    assert {:error, 0, "not in local store: " <> _} =
             Client.fetch_xml("/uksi/2000/1/body/data.xml", root: root, store: :only)

    assert n.() == 0
  end

  test "paths that aren't legislation documents are never stored", %{root: root} do
    assert {:ok, _} = Client.fetch_xml("/changes/affected/ukpga/1965/56/data.xml", root: root)
    assert ClmlStore.get("/changes/affected/ukpga/1965/56/data.xml", root: root) == :none
  end

  test ":refresh fetches live even when a fresh copy is stored", %{root: root, requests: n} do
    :ok = ClmlStore.put(@path, @xml, root: root)

    assert {:ok, @xml} = Client.fetch_xml(@path, root: root, store: :refresh)
    assert n.() == 1
  end
end
