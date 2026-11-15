# Exclude :live tests by default (they make external HTTP calls)
# Run with: mix test --include live
# :pending — cases a later session turns green (e.g. LAT refactor fixtures): mix test --only pending
# :clml_store — reads the local CLML store (data/cache/clml, gitignored);
# skipped where it is absent, as in CI
store = if File.dir?("data/cache/clml"), do: [], else: [:clml_store]
ExUnit.start(exclude: [:live, :pending] ++ store)
Ecto.Adapters.SQL.Sandbox.mode(SertantaiLegal.Repo, :manual)
