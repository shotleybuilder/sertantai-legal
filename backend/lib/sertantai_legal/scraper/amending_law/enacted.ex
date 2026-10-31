defmodule SertantaiLegal.Scraper.AmendingLaw.Enacted do
  @moduledoc """
  A repeals Schedule as enacted (an Act) or made (an SI), where the revised
  text leaves it out (CV-06a, U12): legislation.gov.uk's revised text of
  the Employment Protection Act 1975 holds Sch. 18 as a title alone, and
  SI 1977/746's has no Sch. 3. The amendment reader reads the enacted
  Schedule only in their place — never over a revised Schedule with text.

  - `wanted/2`: the Schedules a law's pointers name that its revised text
    holds empty or not at all;
  - `path/2` the request, `store_path/2` where it is kept (`enacted/` in
    the law's folder: `ClmlStore.enacted_files/2`), `id/1` the Schedule a
    stored file is.

  Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  # an Act is enacted; an instrument made
  @made ~w(uksi ssi wsi nisr nisi ukmo ukci)

  # a Schedule left as its title ("SCHEDULE 18 Enactments Repealed Section 125.")
  @words 40

  @doc "True when `doc` holds Schedule `id` with no table and next to no text, or not at all."
  @spec empty?(Doc.t(), String.t()) :: boolean()
  def empty?(doc, id) do
    case Doc.element(doc, id) do
      nil ->
        true

      el ->
        xpath(el, ~x".//*[local-name()='tr']"l) == [] and
          length(String.split(Doc.text(el))) < @words
    end
  end

  @doc "The Schedule a pointer ref names: \"schedule-18\", \"schedule\" (a law's only one); nil for any other."
  @spec schedule_id(tuple()) :: String.t() | nil
  def schedule_id({:schedule, nil, _part, _para, _subs}), do: "schedule"
  def schedule_id({:schedule, n, _part, _para, _subs}), do: "schedule-#{n}"
  def schedule_id(_ref), do: nil

  @doc "The Schedules `refs` name that `doc` holds empty or not at all, each once."
  @spec wanted(Doc.t(), [tuple()]) :: [String.t()]
  def wanted(doc, refs) do
    refs
    |> Enum.map(&schedule_id/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.filter(&empty?(doc, &1))
    |> Enum.sort()
  end

  @doc "The legislation.gov.uk request for Schedule `id` of `law` as enacted or made."
  @spec path(String.t(), String.t()) :: String.t()
  def path(law, id) do
    [_, t, y, n] = String.split(law, "_", parts: 4)
    "/#{t}/#{y}/#{n}/#{segment(id)}/#{if t in @made, do: "made", else: "enacted"}/data.xml"
  end

  @doc "Where Schedule `id` of `law` as enacted is kept in the store."
  @spec store_path(String.t(), String.t()) :: String.t()
  def store_path(law, id) do
    [_, t, y, n] = String.split(law, "_", parts: 4)
    "/#{t}/#{y}/#{n}/enacted/#{segment(id)}/data.xml"
  end

  @doc "The Schedule a stored enacted file is (`…/enacted/schedule/18/data.xml.gz` → \"schedule-18\")."
  @spec id(String.t()) :: String.t() | nil
  def id(file) do
    case Regex.run(~r{/enacted/schedule(?:/([^/]+))?/data\.xml\.gz$}, file) do
      [_] -> "schedule"
      [_, n] -> "schedule-#{n}"
      nil -> nil
    end
  end

  defp segment("schedule"), do: "schedule"
  defp segment("schedule-" <> n), do: "schedule/#{n}"
end
