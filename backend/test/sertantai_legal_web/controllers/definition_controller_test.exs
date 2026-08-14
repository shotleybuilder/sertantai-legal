defmodule SertantaiLegalWeb.DefinitionControllerTest do
  use SertantaiLegalWeb.ConnCase

  # No auth required — definitions are public reference data.
  # Seed test data in setup since test DB starts empty.

  setup %{conn: conn} do
    # Insert a legal_register entry for JOINs
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    law_id = Ecto.UUID.dump!(Ecto.UUID.generate())

    SertantaiLegal.Repo.insert_all("legal_register", [
      %{
        id: law_id,
        name: "UK_uksi_1992_3004",
        country: "uk",
        jurisdiction: "uk",
        title_en: "Workplace (Health, Safety and Welfare) Regulations",
        year: 1992,
        number: "3004",
        type_code: "uksi",
        created_at: now,
        updated_at: now
      }
    ])

    # Insert test definitions
    defs = [
      %{term: "workplace", definition: "any premises or part of premises which are not domestic premises", scope: "law", section_id: "regulation-2", references_other_law: false},
      %{term: "traffic route", definition: "a route for pedestrian traffic, vehicles or both", scope: "law", section_id: "regulation-2", references_other_law: false},
      %{term: "mine", definition: "a mine within the meaning of the Mines and Quarries Act 1954", scope: "law", section_id: "regulation-2", references_other_law: true},
      %{term: "new workplace", definition: "a workplace used for the first time after 31st December 1992", scope: "law", section_id: "regulation-2", references_other_law: false},
      %{term: "public road", definition: "a highway maintainable at public expense", scope: "law", section_id: "regulation-2", references_other_law: true},
      %{term: "quarry", definition: "a quarry within the meaning of the Quarries Regulations 1999", scope: "law", section_id: "regulation-2", references_other_law: true},
      %{term: "disabled person", definition: "has the meaning given by section 1 of the Disability Discrimination Act 1995", scope: "law", section_id: "regulation-2", references_other_law: true},
      %{term: "worker", definition: "any person employed under a contract of employment", scope: nil, section_id: "regulation-2", references_other_law: false},
      %{term: "working day", definition: "any day other than a Saturday, Sunday, or bank holiday", scope: "law", section_id: "regulation-2", references_other_law: false}
    ]

    def_rows =
      Enum.map(defs, fn d ->
        %{
          id: Ecto.UUID.dump!(Ecto.UUID.generate()),
          law_name: "UK_uksi_1992_3004",
          term: d.term,
          term_welsh: nil,
          definition: d.definition,
          section_id: d.section_id,
          scope: d.scope,
          references_other_law: d.references_other_law,
          inserted_at: now,
          updated_at: now
        }
      end)

    SertantaiLegal.Repo.insert_all("legislative_definitions", def_rows)

    {:ok, conn: conn}
  end

  describe "GET /api/definitions?term=" do
    test "returns definitions for a known term", %{conn: conn} do
      conn = get(conn, "/api/definitions", %{term: "workplace"})

      response = json_response(conn, 200)
      assert is_list(response["data"])
      assert response["count"] > 0

      first = hd(response["data"])
      assert first["term"] == "workplace"
      assert is_binary(first["definition"])
      assert is_binary(first["law_name"])
      assert is_binary(first["law_title"])
      assert is_integer(first["year"])
    end

    test "returns empty list for unknown term", %{conn: conn} do
      conn = get(conn, "/api/definitions", %{term: "zzz_nonexistent_term_zzz"})

      response = json_response(conn, 200)
      assert response["data"] == []
      assert response["count"] == 0
    end

    test "includes scope and references_other_law fields", %{conn: conn} do
      conn = get(conn, "/api/definitions", %{term: "mine"})

      response = json_response(conn, 200)
      assert response["count"] > 0

      for def <- response["data"] do
        assert Map.has_key?(def, "scope")
        assert Map.has_key?(def, "references_other_law")
        assert Map.has_key?(def, "section_id")
      end
    end
  end

  describe "GET /api/definitions?law=" do
    test "returns all definitions in a known law", %{conn: conn} do
      conn = get(conn, "/api/definitions", %{law: "UK_uksi_1992_3004"})

      response = json_response(conn, 200)
      assert response["count"] == 9

      terms = Enum.map(response["data"], & &1["term"]) |> Enum.sort()
      assert "workplace" in terms
      assert "traffic route" in terms
    end

    test "returns empty list for unknown law", %{conn: conn} do
      conn = get(conn, "/api/definitions", %{law: "UK_uksi_9999_9999"})

      response = json_response(conn, 200)
      assert response["data"] == []
      assert response["count"] == 0
    end
  end

  describe "GET /api/definitions?term=&law=" do
    test "returns specific definition for term+law", %{conn: conn} do
      conn =
        get(conn, "/api/definitions", %{term: "workplace", law: "UK_uksi_1992_3004"})

      response = json_response(conn, 200)
      assert response["count"] == 1

      def = hd(response["data"])
      assert def["term"] == "workplace"
      assert def["law_name"] == "UK_uksi_1992_3004"
      assert String.contains?(def["definition"], "premises")
    end
  end

  describe "GET /api/definitions (no params)" do
    test "returns 400 error", %{conn: conn} do
      conn = get(conn, "/api/definitions")

      response = json_response(conn, 400)
      assert response["error"] =~ "required"
    end
  end

  describe "GET /api/definitions/search?q=" do
    test "returns matching terms with law counts", %{conn: conn} do
      conn = get(conn, "/api/definitions/search", %{q: "work"})

      response = json_response(conn, 200)
      assert is_list(response["data"])
      assert response["count"] > 0

      first = hd(response["data"])
      assert is_binary(first["term"])
      assert is_integer(first["law_count"])
      assert String.starts_with?(first["term"], "work")
    end

    test "respects limit parameter", %{conn: conn} do
      conn = get(conn, "/api/definitions/search", %{q: "wo", limit: "3"})

      response = json_response(conn, 200)
      assert response["count"] <= 3
    end

    test "returns 400 for query shorter than 2 chars", %{conn: conn} do
      conn = get(conn, "/api/definitions/search", %{q: "w"})
      assert json_response(conn, 400)["error"] =~ "2 characters"
    end

    test "returns 400 for missing q parameter", %{conn: conn} do
      conn = get(conn, "/api/definitions/search")
      assert json_response(conn, 400)["error"] =~ "Missing"
    end
  end
end
