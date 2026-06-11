defmodule SertantaiLegal.Sync.Workers.SyncWorkerTest do
  use SertantaiLegal.DataCase, async: true
  use Oban.Testing, repo: SertantaiLegal.Repo

  alias SertantaiLegal.Sync.Workers.SyncWorker

  describe "new/1" do
    test "creates a job with correct args and queue" do
      config_id = Ecto.UUID.generate()

      changeset =
        SyncWorker.new(%{"sync_config_id" => config_id, "operation" => "sync"})

      assert changeset.changes.queue == "sync"
      assert changeset.changes.args == %{"sync_config_id" => config_id, "operation" => "sync"}
      assert changeset.changes.max_attempts == 3
    end

    test "supports clean operation" do
      config_id = Ecto.UUID.generate()

      changeset =
        SyncWorker.new(%{"sync_config_id" => config_id, "operation" => "clean"})

      assert changeset.changes.args["operation"] == "clean"
    end

    test "supports clean_and_sync operation" do
      config_id = Ecto.UUID.generate()

      changeset =
        SyncWorker.new(%{"sync_config_id" => config_id, "operation" => "clean_and_sync"})

      assert changeset.changes.args["operation"] == "clean_and_sync"
    end
  end

  describe "enqueuing" do
    test "inserts a job" do
      config_id = Ecto.UUID.generate()

      assert {:ok, _job} =
               SyncWorker.new(%{"sync_config_id" => config_id, "operation" => "sync"})
               |> Oban.insert()

      assert_enqueued(worker: SyncWorker, queue: :sync)
    end

    test "uniqueness prevents duplicate jobs for same config" do
      config_id = Ecto.UUID.generate()
      args = %{"sync_config_id" => config_id, "operation" => "sync"}

      {:ok, job1} = SyncWorker.new(args) |> Oban.insert()
      {:ok, job2} = SyncWorker.new(args) |> Oban.insert()

      # Oban uniqueness returns the existing job
      assert job1.id == job2.id
    end

    test "different operations are separate jobs" do
      config_id = Ecto.UUID.generate()

      {:ok, sync_job} =
        SyncWorker.new(%{"sync_config_id" => config_id, "operation" => "sync"})
        |> Oban.insert()

      {:ok, clean_job} =
        SyncWorker.new(%{"sync_config_id" => config_id, "operation" => "clean"})
        |> Oban.insert()

      refute sync_job.id == clean_job.id
    end

    test "different configs are separate jobs" do
      config_a = Ecto.UUID.generate()
      config_b = Ecto.UUID.generate()

      {:ok, job_a} =
        SyncWorker.new(%{"sync_config_id" => config_a, "operation" => "sync"})
        |> Oban.insert()

      {:ok, job_b} =
        SyncWorker.new(%{"sync_config_id" => config_b, "operation" => "sync"})
        |> Oban.insert()

      refute job_a.id == job_b.id
    end
  end

  describe "perform/1 — config validation" do
    test "discards job when config not found" do
      fake_id = Ecto.UUID.generate()

      result =
        perform_job(SyncWorker, %{
          "sync_config_id" => fake_id,
          "operation" => "sync"
        })

      assert {:discard, "Sync configuration not found"} = result
    end
  end
end
