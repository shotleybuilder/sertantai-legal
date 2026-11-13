defmodule SertantaiLegal.RestoreTest do
  use SertantaiLegal.DataCase, async: false

  alias SertantaiLegal.{Repo, Restore}

  describe "name/2" do
    test "a copy is named restore.<tag>__<table>" do
      assert Restore.name("live_status_20261111_1200", "legal_register") ==
               "restore.live_status_20261111_1200__legal_register"
    end

    test "a tag is made a plain identifier" do
      assert Restore.name("ep-store build", "legal_articles") ==
               "restore.ep_store_build__legal_articles"
    end

    test "a name over Postgres's 63 characters is refused, never truncated" do
      assert_raise ArgumentError, fn ->
        Restore.name(String.duplicate("t", 50), "legal_register")
      end
    end
  end

  describe "copy!/4" do
    test "the copy lands in the restore schema and is recorded in restore.points" do
      copy =
        Restore.copy!("restore_test", "legal_register", "SELECT 1 AS id UNION ALL SELECT $1", [2])

      assert copy == "restore.restore_test__legal_register"
      assert %{rows: [[2]]} = Repo.query!("SELECT count(*)::int FROM #{copy}")

      assert %{rows: [["restore_test", "legal_register", 2]]} =
               Repo.query!(
                 "SELECT tag, source, rows FROM restore.points WHERE copy = $1",
                 [copy]
               )

      assert %{rows: []} =
               Repo.query!(
                 "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'restore_test__legal_register'"
               )
    end
  end

  describe "copies outside Restore" do
    # a table created by a task lands in public, against the restore-point
    # policy; lat_reparse's snapshot is parked with the LAT parser (#189)
    @parked ["sertantai_legal/restore.ex", "sertantai_legal/scraper/lat_reparse.ex"]

    test "no task creates a copy table but through Restore.copy!/4" do
      lib = Path.expand("../../lib", __DIR__)

      offenders =
        for path <- Path.wildcard(Path.join(lib, "**/*.ex")),
            rel = Path.relative_to(path, lib),
            rel not in @parked,
            File.read!(path) =~ ~r/CREATE\s+TABLE\b[^\n]*\bAS\b/i,
            do: rel

      assert offenders == []
    end
  end
end
