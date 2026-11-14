defmodule SertantaiLegal.Scraper.CommencementCatalogue.Target do
  @moduledoc """
  Where a commencement catalogue run (`mix lat.commencement_patterns`, `mix
  lat.order_patterns`) writes its generated files, and where it reads the
  held review (`expected.json`, `leftovers.json`) from. A dry run never
  writes the fixtures: only `--accept` does, or `--out` naming them. Pure.
  """

  @type t :: %{write: String.t(), held: String.t(), dry_run?: boolean()}

  @doc """
  The directories for a run's options: `--out DIR` writes to and reads from
  DIR; `--accept` the fixtures; neither, a dry run, writes to `scratch` and
  reads the fixtures' held review.
  """
  @spec dirs(keyword(), String.t(), String.t()) :: t()
  def dirs(opts, fixtures, scratch) do
    cond do
      opts[:out] -> %{write: opts[:out], held: opts[:out], dry_run?: false}
      opts[:accept] -> %{write: fixtures, held: fixtures, dry_run?: false}
      true -> %{write: scratch, held: fixtures, dry_run?: true}
    end
  end

  @doc "The line a run prints about where its files went."
  @spec notice(t()) :: String.t()
  def notice(%{dry_run?: true, write: dir}),
    do: "dry run: generated files in #{dir}; the fixtures are untouched (--accept writes them)"

  def notice(%{write: dir}), do: "generated files in #{dir}"
end
