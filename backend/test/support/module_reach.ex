defmodule SertantaiLegal.ModuleReach do
  @moduledoc """
  The app's source files a set of files reaches, followed through module
  references in the compiled code (the version-coverage and census
  independence tests). Files in `stop` are boundaries: reached, never
  followed.
  """

  @doc "Every `lib/` file `files` reach, the files themselves included; `stop` files are not followed."
  @spec reach([String.t()], [String.t()]) :: MapSet.t(String.t())
  def reach(files, stop \\ []) do
    {:ok, mods} = :application.get_key(:sertantai_legal, :modules)
    by_file = Map.new(mods, &{source(&1), &1})
    walk(files, MapSet.new(), by_file, {MapSet.new(mods), stop})
  end

  @doc "A module's source file, relative to the working directory."
  @spec source(module()) :: String.t()
  def source(mod),
    do: mod.module_info(:compile)[:source] |> to_string() |> Path.relative_to_cwd()

  defp walk([], seen, _by_file, _ctx), do: seen

  defp walk([f | rest], seen, by_file, {mods, stop} = ctx) do
    case {MapSet.member?(seen, f) or f in stop, by_file[f]} do
      {false, mod} when mod != nil ->
        walk(refs(mod, mods) ++ rest, MapSet.put(seen, f), by_file, ctx)

      _ ->
        walk(rest, seen, by_file, ctx)
    end
  end

  # the app modules a module's compiled code names
  defp refs(mod, mods) do
    {:ok, {_, [atoms: atoms]}} = :beam_lib.chunks(:code.which(mod), [:atoms])

    for {_, a} <- atoms,
        MapSet.member?(mods, a),
        f = source(a),
        String.starts_with?(f, "lib/"),
        do: f
  end
end
