---
name: Zenoh P2P Publishing
description: How sertantai-legal publishes LRT, LAT, and AmendmentAnnotation tables to fractalaw over Zenoh P2P mesh. Covers architecture, configuration, adding new queryables, and troubleshooting.
---

# Zenoh P2P Publishing

## Overview

Sertantai-legal is a **Zenoh peer** that serves legislation data to fractalaw on demand. Fractalaw queries key expressions, sertantai-legal responds with JSON from Postgres. Change notifications are pushed via pub/sub.

```
Sertantai-legal (Elixir, always-on)          Fractalaw (Rust, intermittent)
┌──────────────────────────────┐             ┌────────────────────────┐
│ Zenoh.Session (peer mode)    │◄──zenoh──►  │ zenoh session (peer)   │
│ Zenoh.DataServer (queryables)│  query/reply │ subscribes + queries   │
│ Zenoh.ChangeNotifier (pub)   │──pub/sub──► │ receives notifications │
└──────────────────────────────┘             └────────────────────────┘
```

## Architecture

### OTP Supervision Tree

```
SertantaiLegal.Application
└── SertantaiLegal.Zenoh.Supervisor (rest_for_one)
    ├── Zenoh.Session         -- owns the Zenoh session lifecycle
    ├── Zenoh.DataServer      -- declares queryables, responds to queries
    └── Zenoh.ChangeNotifier  -- publishes data-changed events
```

**rest_for_one**: If Session crashes, DataServer and ChangeNotifier restart too (they need a fresh session_id).

### Key Files

| File | Purpose |
|------|---------|
| `backend/lib/sertantai_legal/zenoh/supervisor.ex` | Supervisor |
| `backend/lib/sertantai_legal/zenoh/session.ex` | Session GenServer — opens peer session, retry on failure |
| `backend/lib/sertantai_legal/zenoh/data_server.ex` | Queryables for LRT/LAT/amendments, JSON serialization |
| `backend/lib/sertantai_legal/zenoh/change_notifier.ex` | Publisher for data-changed events |
| `backend/lib/sertantai_legal/application.ex` | Conditional startup (line ~25) |
| `backend/config/dev.exs` | Dev config (enabled, tenant: "dev") |
| `backend/config/test.exs` | Test config (disabled) |
| `backend/config/runtime.exs` | Env var overrides |

## Key Expression Schema

```
fractalaw/@{tenant}/data/legislation/lrt                   -- all LRT records
fractalaw/@{tenant}/data/legislation/lrt/{law_name}        -- single LRT by name
fractalaw/@{tenant}/data/legislation/lat/{law_name}        -- LAT sections for a law
fractalaw/@{tenant}/data/legislation/amendments/{law_name} -- annotations for a law
fractalaw/@{tenant}/events/data-changed                    -- change notifications (pub/sub)
```

The `@` prefix on `{tenant}` creates a **hermetic namespace** — no wildcard can match across tenants at the protocol level.

## Configuration

### Local Development (config/dev.exs)

```elixir
config :sertantai_legal, :zenoh,
  enabled: true,
  tenant: "dev",
  connect_endpoints: []  # empty = multicast scouting only
```

### Tests (config/test.exs)

```elixir
config :sertantai_legal, :zenoh, enabled: false
```

### Production (env vars)

| Env Var | Default | Description |
|---------|---------|-------------|
| `SERTANTAI_LEGAL_ZENOH_ENABLED` | — | Set to `true` to enable |
| `SERTANTAI_LEGAL_ZENOH_TENANT` | `dev` | Tenant namespace |
| `SERTANTAI_LEGAL_ZENOH_CONNECT` | — | Comma-separated endpoints (e.g., `tcp/hive.local:7447`) |

Short-form `ZENOH_ENABLED`, `ZENOH_TENANT`, `ZENOH_CONNECT` also work (local dev convenience). The `SERTANTAI_LEGAL_` prefix takes precedence.

Infrastructure env template: `~/Desktop/infrastructure/docker/.env.example`

## How Queries Work

1. Fractalaw opens a Zenoh session and calls `session.get("fractalaw/@dev/data/legislation/lrt/UK_ukpga_1974_37")`
2. Zenoh routes the query to sertantai-legal's DataServer (matching queryable)
3. DataServer receives `%Zenohex.Query{}` via `handle_info`
4. DataServer spawns a Task to avoid blocking the GenServer
5. Task parses the key expression, runs an Ecto query, serializes to JSON
6. Task replies with `Zenohex.Query.reply(zq, key_expr, json_payload, final?: true)`

## Adding a New Queryable

To expose a new table or query pattern:

### 1. Add the key expression

In `data_server.ex`, add to the `keys` list in `declare_queryables/1`:

```elixir
keys = [
  "#{prefix}/lrt",
  "#{prefix}/lrt/*",
  "#{prefix}/lat/*",
  "#{prefix}/amendments/*",
  "#{prefix}/your_new_table/*"   # <-- add here
]
```

### 2. Add the route

In `handle_query/1`, add a match clause:

```elixir
^prefix <> "/your_new_table/" <> param ->
  fetch_your_new_table(param)
```

### 3. Add the fetch function

```elixir
defp fetch_your_new_table(param) do
  records =
    from(r in YourResource, where: r.some_field == ^param)
    |> Repo.all()
    |> Enum.map(&serialize_your_resource/1)

  {:ok, Jason.encode!(records)}
end
```

### 4. Add serialization

Pick only the fields fractalaw needs:

```elixir
defp serialize_your_resource(r) do
  %{
    id: r.id,
    field_a: r.field_a,
    field_b: r.field_b,
    updated_at: r.updated_at
  }
end
```

## Publishing Change Notifications

When data is modified, notify connected peers so they re-query:

```elixir
# After a scrape import:
SertantaiLegal.Zenoh.ChangeNotifier.notify("uk_lrt", "scrape_import", %{count: 15})

# After CSV enrichment:
SertantaiLegal.Zenoh.ChangeNotifier.notify("uk_lrt", "csv_enrichment", %{
  law_name: "UK_ukpga_1974_37"
})

# After LAT parsing:
SertantaiLegal.Zenoh.ChangeNotifier.notify("lat", "parse_complete", %{
  law_name: "UK_ukpga_1974_37",
  section_count: 234
})
```

The notification is a small JSON message published to `fractalaw/@{tenant}/events/data-changed`. Fractalaw subscribes to this and re-queries the relevant key expressions.

## zenohex API Quick Reference

```elixir
# Session
{:ok, session_id} = Zenohex.Session.open()                    # default config
{:ok, session_id} = Zenohex.Session.open(json5_config)         # custom config

# Publisher
{:ok, pub_id} = Zenohex.Session.declare_publisher(session_id, key_expr)
:ok = Zenohex.Publisher.put(pub_id, binary_payload)
:ok = Zenohex.Publisher.undeclare(pub_id)

# Queryable (receives %Zenohex.Query{} via handle_info)
{:ok, qid} = Zenohex.Session.declare_queryable(session_id, key_expr, self())
# In handle_info:
Zenohex.Query.reply(query.zenoh_query, key_expr, payload, final?: true)

# Subscriber (receives %Zenohex.Sample{} via handle_info)
{:ok, sub_id} = Zenohex.Session.declare_subscriber(session_id, key_expr, self())

# Config
config = Zenohex.Config.default()
config = Zenohex.Config.update_in(config, ["mode"], fn _ -> "peer" end)

# Scouting (discover peers on LAN)
Zenohex.scout(:peer, Zenohex.Config.default(), 3000)
```

**Critical**: All IDs (session, publisher, subscriber, queryable) must be retained in state. If GC'd, the underlying Rust resource is dropped.

## Troubleshooting

### Session won't open

Check logs for `[Zenoh] Failed to open session`. The Session GenServer retries every 5 seconds up to 30 attempts.

- **No peers found**: Normal if fractalaw isn't running. Sertantai operates independently.
- **Port conflict**: Zenoh uses UDP 7446 for multicast scouting. Check nothing else binds it.

### DataServer: "Session not ready after 30 attempts"

The Session GenServer failed to open within 60 seconds. Check:
- Is zenohex NIF loaded? (`mix deps.compile zenohex`)
- Are there Rust/NIF errors in the logs?

### Queryable not responding

- Verify the key expression matches exactly. Zenoh wildcards: `*` matches one chunk, `**` matches multiple.
- Check that the queryable ID is retained in DataServer state (not GC'd).
- Test with scouting: `mix run -e 'Zenohex.scout(:peer, Zenohex.Config.default(), 3000) |> IO.inspect()'`

### Large responses (all LRT = ~19K records)

The full LRT queryable returns ~19K records as a single JSON payload. This works but is large. If performance is an issue, consider:
- Adding pagination support via query parameters (`Zenohex.Query.parameters`)
- Splitting into per-family queryables
- Switching to Arrow IPC for bulk transfers (would need an Elixir Arrow library)

### Zenoh disabled but module compiled

Zenoh modules compile regardless of config. They only start if `Application.get_env(:sertantai_legal, :zenoh)[:enabled]` is truthy. This is by design — no conditional compilation needed.

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Forgetting to retain queryable/publisher IDs | Store in GenServer state; GC drops the Rust resource |
| Using `{:error, _}` match on `declare_queryable` | Spec only returns `{:ok, id}` — dialyzer will flag it |
| Blocking the DataServer GenServer with slow queries | Spawn a Task for each query (already done) |
| Hardcoding tenant ID | Always read from `Application.get_env(:sertantai_legal, :zenoh)[:tenant]` |
| Testing with Zenoh enabled | Set `config :sertantai_legal, :zenoh, enabled: false` in test.exs |

## Related

- [Zenoh plan](http://10.203.1.170:8080/.claude/plans/zenoh.md) — Full architecture doc from fractalaw
- [zenohex docs](https://hexdocs.pm/zenohex/) — Elixir API reference
- [Zenoh protocol](https://zenoh.io/) — Protocol docs
