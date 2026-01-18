# Exclude :live tests by default (they make external HTTP calls)
# Run with: mix test --include live
ExUnit.start(exclude: [:live])
Ecto.Adapters.SQL.Sandbox.mode(SertantaiLegal.Repo, :manual)
