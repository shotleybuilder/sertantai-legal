# Exclude :live tests by default (they make external HTTP calls)
# Run with: mix test --include live
# :pending — cases a later session turns green (e.g. LAT refactor fixtures): mix test --only pending
ExUnit.start(exclude: [:live, :pending])
Ecto.Adapters.SQL.Sandbox.mode(SertantaiLegal.Repo, :manual)
