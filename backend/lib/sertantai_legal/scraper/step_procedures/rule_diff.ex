defmodule SertantaiLegal.Scraper.StepProcedures.RuleDiff do
  @moduledoc """
  A fix's reach over the commencement store: the rules a law's fresh
  reading adds and the stored ones it no longer gives, each rule counted
  as often as it appears (`mix lat.commencement --read … --preview`).
  `diff/2` is pure; `stored/2` reads a source law's stored rules of the
  given treatments, as `Commencement.Store.write/3` would replace them.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.Commencement.Rule

  @type t :: %{added: [Rule.t()], gone: [Rule.t()]}

  @doc "The rules `fresh` adds to `stored`, and those it drops."
  @spec diff([Rule.t()], [Rule.t()]) :: t()
  def diff(stored, fresh), do: %{added: fresh -- stored, gone: stored -- fresh}

  @doc "Whether the reading changes nothing."
  @spec same?(t()) :: boolean()
  def same?(%{added: [], gone: []}), do: true
  def same?(_diff), do: false

  @doc "`source_law`'s stored rules of `treatments`."
  @spec stored(String.t(), [atom()]) :: [Rule.t()]
  def stored(source_law, treatments) do
    %{rows: rows, columns: cols} =
      Repo.query!(
        "SELECT * FROM commencement_rules WHERE source_law = $1 AND treatment = ANY($2)",
        [source_law, Enum.map(treatments, &to_string/1)]
      )

    atoms = Enum.map(cols, &String.to_atom/1)
    for r <- rows, do: atoms |> Enum.zip(r) |> Map.new() |> Rule.from_row()
  end
end
