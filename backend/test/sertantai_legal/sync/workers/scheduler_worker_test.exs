defmodule SertantaiLegal.Sync.Workers.SchedulerWorkerTest do
  use SertantaiLegal.DataCase, async: true
  use Oban.Testing, repo: SertantaiLegal.Repo

  alias SertantaiLegal.Sync.Workers.SchedulerWorker

  describe "enqueuing" do
    test "inserts a job on the default queue" do
      assert {:ok, job} = SchedulerWorker.new(%{}) |> Oban.insert()
      assert job.queue == "default"
      assert job.max_attempts == 1
    end
  end

  describe "perform/1" do
    test "completes successfully with no configs" do
      # No sync configurations exist in test DB
      assert :ok = perform_job(SchedulerWorker, %{})
    end
  end
end
