defmodule SertantaiLegal.Scraper.ChangeVocabulary.Show do
  @moduledoc """
  The debug view of named provisions (`mix lat.vocabulary --show`): each
  provision as the build gives it, the changes reaching it, and the label
  stored for it today. The task prints them.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Build, Change, LabelSource, LabelSwitch}
  alias SertantaiLegal.Scraper.LatRef

  @period ~w(valid_from valid_to status in_force_from changed_by territory)a

  @doc """
  The named provisions as the build resolves them (`Build.start/1`, never
  the old register): each one's extent, the law's start and its containers.
  """
  @spec provisions(String.t(), [String.t()]) :: %{String.t() => map()}
  def provisions(law, ids) do
    start = Build.start(law).date || raise ArgumentError, "no law start for #{law}"
    rows = Build.rows(law)
    containers = LabelSource.containers(law)

    Map.new(ids, fn id ->
      {id,
       %{
         extent: get_in(rows, [id, :extent]),
         start: start,
         containers: Map.get(containers, id, [])
       }}
    end)
  end

  @doc "The changes reaching `id`: on it, on the whole law (`*`) or on an ancestor."
  @spec reaching([Change.t()], String.t()) :: [Change.t()]
  def reaching(changes, id) do
    reach = [id, "*" | tl(LatRef.ancestors(id))]
    Enum.filter(changes, &(&1.target in reach))
  end

  @doc "`id`'s label stored today, its periods in order."
  @spec stored(String.t(), String.t()) :: [map()]
  def stored(law, id) do
    sid = "#{law}:#{id}"

    for p <- LabelSwitch.stored(law), p.section_id == sid, do: Map.take(p, @period)
  end
end
