# Oban Sync Refactor — Async Job Queue for Baserow Sync

## Context

The Baserow sync pipeline (`Engine.run`) pushes legal register data from PostgreSQL to customer Baserow workspaces. Currently it runs synchronously — either via `mix sync.run` (blocks terminal) or via `Task.start` from the SyncController (fire-and-forget, no retry, no progress). This means:

- **No crash recovery** — if the VM dies mid-sync, the job is lost
- **No progress visibility** — no way to see what phase sync is in
- **No automatic retry** — transient failures require manual re-run
- **No scheduling** — `SyncConfiguration.sync_frequency` (:daily/:weekly) has no implementation

Oban provides persistent job queuing with retries, uniqueness, scheduling, and telemetry — all backed by PostgreSQL (no Redis needed).

## Approach

Wrap `Engine.run` and a new `Engine.clean` in an Oban Worker. Keep Engine unchanged — Oban is the scheduling/retry layer, Engine is the business logic.

## Implementation Steps

### Step 1: Add Oban dependency

**File:** `backend/mix.exs`

Add `{:oban, "~> 2.18"}` to deps. Run `mix deps.get`.

### Step 2: Oban migration

Generate with `mix ecto.gen.migration add_oban_jobs_table`. This is a plain Ecto migration — compatible alongside Ash migrations in `priv/repo/migrations/`.

```elixir
defmodule SertantaiLegal.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration
  def up, do: Oban.Migration.up(version: 14)
  def down, do: Oban.Migration.down(version: 14)
end
```

### Step 3: Configure Oban

**File:** `backend/config/config.exs` — add after existing app config:

```elixir
config :sertantai_legal, Oban,
  repo: SertantaiLegal.Repo,
  queues: [default: 10, sync: 2],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 7 * 24 * 60 * 60},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 */6 * * *", SertantaiLegal.Sync.Workers.SchedulerWorker}
     ]}
  ]
```

**File:** `backend/config/test.exs` — add:

```elixir
config :sertantai_legal, Oban, testing: :manual
```

**Design notes:**
- `sync` queue concurrency: 2 — allows two orgs to sync in parallel without hammering Baserow
- Pruner: 7 days — audit trail lives in SyncJob (Ash resource), not Oban
- Lifeline: 30 min — rescues orphaned jobs after VM crash (syncs typically complete in <5 min)
- Cron: every 6 hours runs SchedulerWorker to check for due recurring syncs (Gemini: 15 min overkill for daily/weekly)
- `testing: :manual` — jobs insert but don't execute; existing 1443 tests unaffected

### Step 4: Supervision tree

**File:** `backend/lib/sertantai_legal/application.ex`

Add `{Oban, Application.fetch_env!(:sertantai_legal, Oban)}` after `SertantaiLegal.Repo`, before `DNSCluster`:

```elixir
children =
  [
    SertantaiLegalWeb.Telemetry,
    SertantaiLegal.Repo,
    {Oban, Application.fetch_env!(:sertantai_legal, Oban)},  # NEW
    {DNSCluster, ...},
    ...
  ]
```

### Step 5: SyncWorker

**New file:** `backend/lib/sertantai_legal/sync/workers/sync_worker.ex`

```elixir
defmodule SertantaiLegal.Sync.Workers.SyncWorker do
  use Oban.Worker,
    queue: :sync,
    max_attempts: 3,
    unique: [period: 300, fields: [:args], keys: [:sync_config_id, :operation],
             states: [:available, :scheduled, :executing, :retryable]]

  alias SertantaiLegal.Sync.Engine

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"sync_config_id" => config_id, "operation" => op}}) do
    # Guard: check config still exists and is active (Gemini review item #3)
    with {:ok, config} <- load_and_validate_config(config_id) do
      # ... proceed with sync
    else
      {:error, :inactive} -> {:discard, "Config deactivated"}
      {:error, :not_found} -> {:discard, "Config deleted"}
    end

    broadcast(config_id, :started, %{operation: op})

    result = case op do
      "clean_and_sync" -> with {:ok, _} <- Engine.clean(config_id), do: Engine.run(config_id)
      "clean" -> Engine.clean(config_id)
      _sync -> Engine.run(config_id)
    end

    case result do
      {:ok, job} ->
        broadcast(config_id, :completed, Map.take(job, [:rows_created, :rows_updated, :rows_deleted]))
        :ok
      {:error, reason} ->
        broadcast(config_id, :failed, %{reason: inspect(reason)})
        {:error, reason}
    end
  end

  defp broadcast(config_id, event, payload) do
    Phoenix.PubSub.broadcast(SertantaiLegal.PubSub, "sync:#{config_id}", {:sync_progress, event, payload})
  end
end
```

**Key design:**
- `unique` prevents duplicate jobs for same config+operation within 5 minutes
- `max_attempts: 3` — Baserow provider already retries transient HTTP errors internally (3x exponential backoff). Oban retries cover process-level failures (OOM, VM crash)
- PubSub broadcast enables admin UI to show live progress
- `clean_and_sync` operation chains clean → sync (replaces `mix sync.run --clean`)

### Step 6: SchedulerWorker

**New file:** `backend/lib/sertantai_legal/sync/workers/scheduler_worker.ex`

Runs every 6 hours via Cron plugin. Checks active SyncConfigurations with `sync_frequency != :manual`, enqueues sync jobs for those due (elapsed time > frequency interval). SyncWorker uniqueness prevents double-enqueuing.

```elixir
defmodule SertantaiLegal.Sync.Workers.SchedulerWorker do
  use Oban.Worker, queue: :default, max_attempts: 1

  @intervals %{daily: 86_400, weekly: 604_800}

  @impl Oban.Worker
  def perform(_job) do
    # Query active, non-manual configs
    # For each, check last_synced_at vs interval
    # Enqueue SyncWorker if due
    :ok
  end
end
```

### Step 7: Extract Engine.clean/1

**File:** `backend/lib/sertantai_legal/sync/engine.ex`

Move the clean logic from `Mix.Tasks.Sync.Run.clean_baserow/1` into `Engine.clean/1`:

```elixir
def clean(sync_config_id) do
  with {:ok, sync_config} <- load_sync_config(sync_config_id),
       credentials = decrypt_credentials(sync_config),
       provider_config = build_provider_config(sync_config, credentials),
       {:ok, provider_config} <- authenticate_provider(sync_config.provider, provider_config) do
    # Delete all rows from LRT/LAT/Actor Tuples tables
    # Clear row mappings for this config
    {:ok, %{tables_cleaned: n, mappings_cleared: m}}
  end
end
```

### Step 8: Multi-tenant workspace validation

**File:** `backend/lib/sertantai_legal/sync/engine.ex`

Add `validate_workspace/2` in `execute_sync` after `authenticate_provider`, before `prepare_tables`:

1. GET each configured table via Baserow API (`/api/database/tables/{id}/`)
2. Extract workspace ID from response
3. Verify all tables belong to the same workspace
4. If `target_config["workspace_id"]` is set, verify it matches

Fail fast with `{:error, "Table #{id} belongs to workspace #{actual}, expected #{expected}"}`.

Also add workspace validation to SyncConfiguration create/update Ash actions (Gemini review item #4) — validate at config save time, not just at sync time.

### Step 9: Update mix sync.run

**File:** `backend/lib/mix/tasks/sync.run.ex`

Change to enqueue Oban job instead of calling Engine directly:

```elixir
def run(args) do
  Mix.Task.run("app.start")
  {opts, rest, _} = OptionParser.parse(args, switches: [clean: :boolean, wait: :boolean, ...])

  operation = if opts[:clean], do: "clean_and_sync", else: "sync"

  # Keep prod guard for clean
  if opts[:clean] and Mix.env() == :prod, do: confirm_or_abort()

  {:ok, oban_job} = SyncWorker.new(%{"sync_config_id" => config_id, "operation" => operation})
    |> Oban.insert()

  Mix.shell().info("Job enqueued (Oban ##{oban_job.id})")

  if opts[:wait], do: wait_for_completion(oban_job.id)
end
```

New `--wait` flag: polls Oban job state, prints progress, blocks until completed/failed. Without `--wait`, exits immediately.

### Step 10: Update SyncController.trigger_sync

**File:** `backend/lib/sertantai_legal_web/controllers/sync_controller.ex:215`

Replace `Task.start(fn -> Engine.run(config.id) end)` with:

```elixir
SyncWorker.new(%{"sync_config_id" => config.id, "operation" => "sync"})
|> Oban.insert()
```

Persistent queue replaces fire-and-forget Task.

### Step 11: Telemetry (lightweight)

**File:** `backend/lib/sertantai_legal/sync/engine.ex`

Add `:telemetry.execute` calls at phase boundaries in `execute_sync`:

```elixir
:telemetry.execute([:sync, :phase, :complete], %{duration: duration}, %{
  phase: :lrt, sync_config_id: sync_config.id,
  rows_created: created, rows_updated: updated, rows_deleted: deleted
})
```

**File:** `backend/lib/sertantai_legal/metrics/telemetry_handler.ex`

Extend `attach/0` to include `[:sync, :phase, :complete]` and `[:sync, :job, :complete]`.

### Step 12: Tests

**New files:**
- `backend/test/sertantai_legal/sync/workers/sync_worker_test.exs`
- `backend/test/sertantai_legal/sync/workers/scheduler_worker_test.exs`

Using `Oban.Testing`:
- Assert job enqueued with correct args/queue
- Assert uniqueness prevents duplicates
- Test `perform/1` directly with mocked Engine (Mox or test fixtures)
- Test SchedulerWorker only enqueues for active, due configs

## Files Changed

| File | Action | Purpose |
|------|--------|---------|
| `backend/mix.exs` | Modify | Add `{:oban, "~> 2.18"}` |
| `backend/priv/repo/migrations/*_add_oban_jobs.exs` | Create | Oban DB tables |
| `backend/config/config.exs` | Modify | Oban config (repo, queues, plugins, cron) |
| `backend/config/test.exs` | Modify | `testing: :manual` |
| `backend/lib/sertantai_legal/application.ex` | Modify | Add Oban to supervision tree |
| `backend/lib/sertantai_legal/sync/workers/sync_worker.ex` | Create | Main Oban worker |
| `backend/lib/sertantai_legal/sync/workers/scheduler_worker.ex` | Create | Cron-driven recurring sync |
| `backend/lib/sertantai_legal/sync/engine.ex` | Modify | Extract `clean/1`, add workspace validation, add telemetry |
| `backend/lib/mix/tasks/sync.run.ex` | Modify | Enqueue Oban job, add `--wait` flag |
| `backend/lib/sertantai_legal_web/controllers/sync_controller.ex` | Modify | Replace `Task.start` with `Oban.insert` |
| `backend/lib/sertantai_legal/metrics/telemetry_handler.ex` | Modify | Attach sync telemetry events |
| `backend/test/.../workers/sync_worker_test.exs` | Create | Worker tests |
| `backend/test/.../workers/scheduler_worker_test.exs` | Create | Scheduler tests |

## Gemini Review Feedback (incorporated)

1. **Retry idempotency** — DeltaDetector already handles this: on retry, previously-synced rows are classified as "unchanged" (mapping exists, timestamp not newer). No duplicate creates. Confirmed safe.
2. **SchedulerWorker frequency** — Changed from `*/15` to `0 */6 * * *` (every 6 hours). Daily/weekly syncs don't need 15-min granularity.
3. **Config deactivation guard** — SyncWorker.perform/1 must check `sync_config.is_active` before proceeding. Return `:discard` (don't retry) if inactive.
4. **Workspace validation at save time** — Add validation in SyncConfiguration create/update actions too, not just at sync time.
5. **No secrets in Oban args** — Confirmed: only `sync_config_id` (UUID) in args. Credentials decrypted inside Engine.

## Risks

- **Process dict JWT**: Oban workers run in isolated processes — `Process.put/get` for Baserow JWT works identically. No change needed.
- **Long syncs**: Lifeline rescues after 30 min. If syncs exceed this, bump the threshold.
- **Test suite**: `testing: :manual` is inert — jobs insert but never execute. 1443 existing tests unaffected.
- **Ash + Ecto migrations coexist**: Oban uses plain Ecto migrations in the same `priv/repo/migrations/` dir. No conflict — Ash only manages its declared resources.

## Verification

1. `mix deps.get && mix ecto.migrate` — Oban tables created
2. `mix test` — all 1443+ tests pass
3. `mix sync.run --wait` — enqueues + waits for Oban job to complete
4. `mix sync.run --clean --wait` — clean + sync via Oban
5. Trigger sync via API: `POST /api/sync/configurations/:id/sync` — returns immediately, job runs async
6. Kill beam mid-sync → restart → Lifeline rescues the job within 30 min
7. Check `oban_jobs` table: job completes with state `completed`, errors empty
