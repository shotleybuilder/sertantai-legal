defmodule SertantaiLegal.Scraper.AmendingLaw.Enacted do
  @moduledoc """
  A repeals Schedule as enacted (an Act) or made (an SI), where the revised
  text leaves it out (CV-06a, U12): legislation.gov.uk's revised text of
  the Employment Protection Act 1975 holds Sch. 18 as a title alone, and
  SI 1977/746's has no Sch. 3. The amendment reader reads the enacted
  Schedule only in their place — never over a revised Schedule with text.

  - `wanted/2`: the Schedules a law's pointers name that its revised text
    holds empty or not at all, and the sections, regulations and Schedule
    paragraphs they name that it holds repealed (its number and dots: EPA
    1990 Sch. 15 para. 14, which inserted HSWA s.5(5)–(7); the Offshore
    Safety Act 1992 s.4, HSWA s.15(6)(e): CV-06 S7);
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

  @doc """
  True when `doc` holds Schedule `id` with no table and next to no text, or
  not at all; a provision (`section-4`, `schedule-15-paragraph-14`) when
  held as its number and dots alone.
  """
  @spec empty?(Doc.t(), String.t()) :: boolean()
  def empty?(doc, id) do
    if schedule?(id), do: schedule_empty?(doc, id), else: repealed?(doc, id)
  end

  defp schedule?(id), do: id =~ ~r/^schedule(?:-[^-]+)?$/

  defp repealed?(doc, id) do
    case Doc.element(doc, id) do
      nil -> false
      el -> Doc.text(el) =~ ~r/^\s*[\dA-Za-z]*\s*(?:\.\s*){3,}$/
    end
  end

  defp schedule_empty?(doc, id) do
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

  @doc "The provision a pointer ref names, at its top (\"section-4\", \"schedule-15-paragraph-14\"); nil for a Schedule or any other."
  @spec provision_id(tuple()) :: String.t() | nil
  def provision_id({:schedule, n, _part, para, _subs}) when is_binary(para),
    do: if(n, do: "schedule-#{n}-paragraph-#{para}", else: "schedule-paragraph-#{para}")

  def provision_id({kind, n, _subs}) when kind in [:section, :regulation, :article, :rule],
    do: "#{kind}-#{n}"

  def provision_id(_ref), do: nil

  @doc "The Schedules `refs` name that `doc` holds empty or not at all, and the provisions they name held repealed, each once."
  @spec wanted(Doc.t(), [tuple()]) :: [String.t()]
  def wanted(doc, refs) do
    schedules = refs |> Enum.map(&schedule_id/1) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    empty = Enum.filter(schedules, &empty?(doc, &1))

    # a paragraph of a Schedule fetched whole comes with it
    provisions =
      for ref <- refs,
          id = provision_id(ref),
          id != nil,
          not Enum.any?(empty, &String.starts_with?(id, &1 <> "-")),
          repealed?(doc, id),
          uniq: true,
          do: id

    Enum.sort(empty ++ provisions)
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

  @doc "The element a stored enacted file is (`…/enacted/schedule/18/data.xml.gz` → \"schedule-18\", `…/enacted/section/4/…` → \"section-4\")."
  @spec id(String.t()) :: String.t() | nil
  def id(file) do
    case Regex.run(
           ~r{/enacted/((?:schedule|section|regulation|article|rule)(?:/[^/]+)*)/data\.xml\.gz$},
           file
         ) do
      [_, path] -> String.replace(path, "/", "-")
      nil -> nil
    end
  end

  defp segment(id), do: String.replace(id, "-", "/")
end
