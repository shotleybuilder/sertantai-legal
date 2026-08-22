defmodule SertantaiLegalWeb.DefinitionsAdminControllerTest do
  use SertantaiLegalWeb.ConnCase

  import SertantaiLegal.AuthHelpers

  alias SertantaiLegal.Repo

  setup :setup_auth

  setup %{conn: conn} do
    admin_conn = put_admin_auth_header(conn)
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    # Insert two legal_register entries in different families
    law1_id = Ecto.UUID.dump!(Ecto.UUID.generate())
    law2_id = Ecto.UUID.dump!(Ecto.UUID.generate())
    parent_id = Ecto.UUID.dump!(Ecto.UUID.generate())

    Repo.insert_all("legal_register", [
      %{
        id: law1_id,
        name: "UK_uksi_1999_3242",
        country: "uk",
        jurisdiction: "uk",
        family: "💙 OH&S",
        title_en: "Management of Health and Safety at Work Regulations",
        year: 1999,
        number: "3242",
        type_code: "uksi",
        is_making: true,
        live: "✔ In force",
        created_at: now,
        updated_at: now
      },
      %{
        id: law2_id,
        name: "UK_uksi_2013_2996",
        country: "uk",
        jurisdiction: "uk",
        family: "💚 FOOD",
        title_en: "Food Safety and Hygiene (England) Regulations",
        year: 2013,
        number: "2996",
        type_code: "uksi",
        is_making: true,
        live: "✔ In force",
        created_at: now,
        updated_at: now
      },
      %{
        id: parent_id,
        name: "UK_ukpga_1990_16",
        country: "uk",
        jurisdiction: "uk",
        family: "💚 FOOD",
        title_en: "Food Safety Act 1990",
        year: 1990,
        number: "16",
        type_code: "ukpga",
        is_making: true,
        live: "✔ In force",
        definitions_parsed_at: now,
        created_at: now,
        updated_at: now
      }
    ])

    # Insert definitions — mix of substantive, cross-ref, and citation
    def1_id = Ecto.UUID.generate()
    def2_id = Ecto.UUID.generate()
    def3_id = Ecto.UUID.generate()
    def4_id = Ecto.UUID.generate()
    root_id = Ecto.UUID.generate()

    defs = [
      %{
        id: Ecto.UUID.dump!(def1_id),
        law_name: "UK_uksi_1999_3242",
        term: "workplace",
        definition: "any premises or part of premises",
        section_id: "regulation-2",
        references_other_law: false,
        citation: false,
        inserted_at: now,
        updated_at: now
      },
      %{
        id: Ecto.UUID.dump!(def2_id),
        law_name: "UK_uksi_1999_3242",
        term: "employee",
        definition: "has the meaning given by section 230(1) of the Employment Rights Act 1996",
        section_id: "regulation-2",
        references_other_law: true,
        citation: false,
        referenced_law_citation: "Employment Rights Act 1996",
        inserted_at: now,
        updated_at: now
      },
      %{
        id: Ecto.UUID.dump!(def3_id),
        law_name: "UK_uksi_2013_2996",
        term: "act",
        definition: "the Food Safety Act 1990",
        section_id: "regulation-2",
        references_other_law: false,
        citation: true,
        inserted_at: now,
        updated_at: now
      },
      %{
        id: Ecto.UUID.dump!(def4_id),
        law_name: "UK_uksi_2013_2996",
        term: "food authority",
        definition: "has the meaning given by section 5 of the Act",
        section_id: "regulation-2",
        references_other_law: true,
        citation: false,
        referenced_law_citation: "Food Safety Act 1990",
        inserted_at: now,
        updated_at: now
      },
      %{
        id: Ecto.UUID.dump!(root_id),
        law_name: "UK_ukpga_1990_16",
        term: "food",
        definition: "includes drink and any substance used for human consumption",
        section_id: "section-1",
        references_other_law: false,
        citation: false,
        inserted_at: now,
        updated_at: now
      }
    ]

    Repo.insert_all("legislative_definitions", defs)

    {:ok, conn: admin_conn, def2_id: def2_id, def4_id: def4_id, root_id: root_id}
  end

  # ── Stats ────────────────────────────────────────────────────────

  describe "GET /api/definitions/admin/stats" do
    test "returns per-family stats with totals", %{conn: conn} do
      conn = get(conn, "/api/definitions/admin/stats")
      response = json_response(conn, 200)

      assert is_map(response["totals"])
      assert is_list(response["families"])
      assert response["totals"]["total_defs"] >= 5

      # Check family entries exist
      families = Enum.map(response["families"], & &1["family"])
      assert "💙 OH&S" in families
      assert "💚 FOOD" in families
    end

    test "includes effective_pct for each family", %{conn: conn} do
      conn = get(conn, "/api/definitions/admin/stats")
      response = json_response(conn, 200)

      for fam <- response["families"] do
        assert Map.has_key?(fam, "effective_pct")
        assert Map.has_key?(fam, "cross_refs")
        assert Map.has_key?(fam, "linked")
        assert Map.has_key?(fam, "total_defs")
      end
    end

    test "OH&S family has correct cross-ref count", %{conn: conn} do
      conn = get(conn, "/api/definitions/admin/stats")
      response = json_response(conn, 200)

      ohs = Enum.find(response["families"], &(&1["family"] == "💙 OH&S"))
      assert ohs["cross_refs"] == 1
      assert ohs["total_defs"] == 2
    end

    test "requires admin auth", %{conn: _conn} do
      # Use unauthenticated connection
      conn = build_conn() |> get("/api/definitions/admin/stats")
      assert conn.status in [401, 403]
    end
  end

  # ── Diagnostic ───────────────────────────────────────────────────

  describe "GET /api/definitions/admin/diagnostic" do
    test "returns summary and findings", %{conn: conn} do
      conn = get(conn, "/api/definitions/admin/diagnostic")
      response = json_response(conn, 200)

      assert is_map(response["summary"])
      assert is_list(response["findings"])
      assert Map.has_key?(response["summary"], "total")
      assert Map.has_key?(response["summary"], "by_category")
    end

    test "accepts family filter", %{conn: conn} do
      conn = get(conn, "/api/definitions/admin/diagnostic", %{family: "💙 OH&S"})
      response = json_response(conn, 200)

      # All findings should be from OH&S laws
      for finding <- response["findings"] do
        assert finding["law_name"] == "UK_uksi_1999_3242"
      end
    end

    test "findings have required fields", %{conn: conn} do
      conn = get(conn, "/api/definitions/admin/diagnostic")
      response = json_response(conn, 200)

      for finding <- response["findings"] do
        assert Map.has_key?(finding, "definition_id")
        assert Map.has_key?(finding, "law_name")
        assert Map.has_key?(finding, "term")
        assert Map.has_key?(finding, "category")
      end
    end
  end

  # ── Parse ────────────────────────────────────────────────────────

  describe "POST /api/definitions/admin/parse" do
    @tag :capture_log
    test "accepts law_name parameter", %{conn: conn} do
      conn = post(conn, "/api/definitions/admin/parse", %{law_name: "UK_uksi_1999_3242"})
      response = json_response(conn, 200)

      assert response["status"] == "started"
      assert response["scope"] == "law"
      assert response["law_name"] == "UK_uksi_1999_3242"
    end

    @tag :capture_log
    test "accepts family parameter", %{conn: conn} do
      conn = post(conn, "/api/definitions/admin/parse", %{family: "💙 OH&S"})
      response = json_response(conn, 200)

      assert response["status"] == "started"
      assert response["scope"] == "family"
      assert response["family"] == "💙 OH&S"
    end

    test "returns 400 without required params", %{conn: conn} do
      conn = post(conn, "/api/definitions/admin/parse", %{})
      assert json_response(conn, 400)["error"] =~ "law_name"
    end
  end

  # ── Resolve ──────────────────────────────────────────────────────

  describe "POST /api/definitions/admin/resolve" do
    @tag :capture_log
    test "starts resolver and returns status", %{conn: conn} do
      conn = post(conn, "/api/definitions/admin/resolve", %{force: false})
      response = json_response(conn, 200)

      assert response["status"] == "started"
      assert response["force"] == false
    end

    @tag :capture_log
    test "accepts force flag", %{conn: conn} do
      conn = post(conn, "/api/definitions/admin/resolve", %{force: true})
      response = json_response(conn, 200)

      assert response["force"] == true
    end

    @tag :capture_log
    test "defaults to non-force when no params", %{conn: conn} do
      conn = post(conn, "/api/definitions/admin/resolve", %{})
      response = json_response(conn, 200)

      assert response["force"] == false
    end
  end
end
