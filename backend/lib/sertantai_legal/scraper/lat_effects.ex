defmodule SertantaiLegal.Scraper.LatEffects do
  @moduledoc """
  legislation.gov.uk effects not yet applied to a law's text (sertantai-legal
  #167, L8.4: the manifest's `effects_unapplied`). Pure: reads the stored
  `🔻_affected_by_stats_per_law` (per amending law: `details` of
  `affect` / `target` / `applied`) and the law's section_ids.

  - **Unapplied** = `applied` starts "Not yet" for the English text. The
    Welsh-language-only variants ("Not yet made to Welsh language version …
    English language version") are not gaps in the English text.
  - **Target → section_id** (best effort): "s. 104(2)" → `s.104(2)`,
    "reg 5" → `reg.5`, "Pt. 1" → `pt.1`, "Sch. 1 para. 22" → `sch.1.s.22`
    (Acts) / `sch.1.reg.22` (instruments) / `art.` (EU); "Sch. 4" → `sch.4`;
    "s. 28 heading" → `s.28`; domestic "art." and "rule" → `reg.` (art. is EU only).
    Anything else ("Regulations title") → nil.
  - **Resolve** against the rows legal holds: the exact row, else its deepest
    existing ancestor (an unapplied insertion has no row yet), with `exact`.
  """

  @act_types ~w(ukpga asp anaw asc nia mwa apni ukla)
  @eu_types ~w(eur eudr eudn)

  @schedule_para ~r/^Sch\.? ?(\d+[A-Z]*) ?(?:Pt\.? ?\w+ )?para\.? ?(\d+[A-Z]*(?:\([^)\s]*\))*)/i
  @schedule ~r/^Sch\.? ?(\d+[A-Z]*)\b/i
  @qualifier ~r/\b(heading|cross-heading|table|class|entry|title|definition)\b/i
  @provision ~r/^(s|reg|art|rule)\.? ?(\d+[A-Z]*(?:\([^)\s]*\))*)/i

  @type effect :: %{
          by: String.t(),
          affect: String.t(),
          target: String.t(),
          section_id: String.t() | nil,
          exact: boolean()
        }

  @doc "True when the English text does not yet reflect the effect."
  @spec unapplied?(String.t() | nil) :: boolean()
  def unapplied?("Not yet" <> _ = applied),
    do: not String.contains?(applied, "English language version")

  def unapplied?(_), do: false

  @doc "The law's unapplied effects, by amending law, mapped to its rows where possible."
  @spec unapplied(map() | nil, String.t(), MapSet.t(String.t())) :: [effect()]
  def unapplied(nil, _law_name, _ids), do: []

  def unapplied(stats, law_name, ids) when is_map(stats) do
    for {by, entry} <- Enum.sort(stats),
        d <- Map.get(entry, "details") || [],
        unapplied?(d["applied"]) do
      target = d["target"] || ""
      {section_id, exact} = target |> target_section_id(law_name) |> resolve(ids)

      %{
        by: by,
        affect: d["affect"] || "",
        target: target,
        section_id: section_id,
        # "s. 7 cross-heading" names part of s.7's surroundings, not s.7 itself
        exact: exact and not Regex.match?(@qualifier, target)
      }
    end
  end

  @doc "The section_id an effect's target text names (not checked against the LAT); nil if unrecognised."
  @spec target_section_id(String.t(), String.t()) :: String.t() | nil
  def target_section_id(target, law_name) do
    t = target |> String.replace(~r/\s+/u, " ") |> String.trim()

    cond do
      m = Regex.run(@schedule_para, t) ->
        [_, sch, para] = m
        "#{law_name}:sch.#{sch}.#{provision_prefix(law_name)}.#{para}"

      m = Regex.run(@schedule, t) ->
        "#{law_name}:sch.#{Enum.at(m, 1)}"

      m = Regex.run(@provision, t) ->
        [_, prefix, number] = m
        "#{law_name}:#{prefix(String.downcase(prefix), law_name)}.#{number}"

      m = Regex.run(~r/^Pt\.? ?(\w+)/i, t) ->
        "#{law_name}:pt.#{Enum.at(m, 1)}"

      true ->
        nil
    end
  end

  # "art." is only EU retained law's prefix; domestic instruments use reg.
  defp prefix("art", law_name),
    do: if(provision_prefix(law_name) == "art", do: "art", else: "reg")

  # Rule-numbered domestic instruments are held under reg. too.
  defp prefix("rule", _law_name), do: "reg"
  defp prefix(prefix, _law_name), do: prefix

  @doc "`{section_id, exact?}`: the row itself, else its deepest existing ancestor, else `{nil, false}`."
  @spec resolve(String.t() | nil, MapSet.t(String.t())) :: {String.t() | nil, boolean()}
  def resolve(nil, _ids), do: {nil, false}

  def resolve(section_id, ids) do
    if MapSet.member?(ids, section_id) do
      {section_id, true}
    else
      found =
        section_id
        |> Stream.unfold(fn id ->
          case Regex.run(~r/\A(.+)\([^()]*\)\z/, id) do
            [_, parent] -> {parent, parent}
            nil -> nil
          end
        end)
        |> Enum.find(&MapSet.member?(ids, &1))

      {found || schedule_row(section_id, ids), false}
    end
  end

  # A schedule paragraph with no row of its own: the schedule's row, if held.
  defp schedule_row(section_id, ids) do
    case Regex.run(~r/\A(.+:sch\.[^.]+)\./, section_id) do
      [_, sch] -> if MapSet.member?(ids, sch), do: sch
      nil -> nil
    end
  end

  defp provision_prefix(law_name) do
    type = law_name |> String.split("_") |> Enum.at(1)

    cond do
      type in @act_types -> "s"
      type in @eu_types -> "art"
      true -> "reg"
    end
  end
end
