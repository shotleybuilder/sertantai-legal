defmodule SertantaiLegal.Scraper.LatStatus do
  @moduledoc """
  Structural helpers for a law's LAT rows and notes (sertantai-legal #167;
  slimmed in lat-refactor LR-25): the status values, repealed text, and
  which rows a note and a provision's ancestors reach. Status as a label is
  the timeline's (`lat_label_timeline`); its note-text reading (`resolve/2`)
  was deleted in LR-25 — notes are pointers, never facts.

  A note's targets are its `affected_sections`: the rows that cite it at their
  own level (LH-01). A target covers itself, its sub-provisions (`s.6(1)(a)`,
  `s.6(1)[S]` under `s.6[S]`) and, untagged, its extent versions (`s.6[S]`).

  Pure.
  """

  @statuses ~w(in_force in_force_partial repealed repealed_saved prospective)

  @dots ~r/\A[\s.]+\z/
  @markers ["[Repealed]", "[Revoked]"]

  @type status :: String.t()

  @doc "The agreed status values."
  @spec statuses() :: [status()]
  def statuses, do: @statuses

  @doc "True when a row's text shows the provision has been repealed or revoked."
  @spec repealed_text?(String.t() | nil) :: boolean()
  def repealed_text?(text) when is_binary(text) do
    trimmed = String.trim(text)

    trimmed in @markers or
      (Regex.match?(@dots, trimmed) and String.contains?(trimmed, ". ."))
  end

  def repealed_text?(_), do: false

  @doc "The section_ids a note applies to: every row it is placed on."
  @spec note_targets(map()) :: [String.t()]
  def note_targets(%{affected_sections: [_ | _] = sections}), do: Enum.uniq(sections)
  def note_targets(_), do: []

  @doc "True when a note targeting `target` applies to `section_id`."
  @spec covers?(String.t(), String.t()) :: boolean()
  def covers?(target, section_id) do
    target == section_id or String.starts_with?(section_id, target <> "(") or
      String.starts_with?(section_id, target <> "[")
  end

  @doc """
  The section_id itself, then without an extent tag, then each enclosing
  "(…)" level: `"L:s.6(1)(a)[S]"` → `[.., "L:s.6(1)(a)", "L:s.6(1)", "L:s.6"]`.
  A note whose target is any of these applies to the row.
  """
  @spec ancestors(String.t()) :: [String.t()]
  def ancestors(section_id) do
    case Regex.run(~r/\A(.+?)(\[[^\]]*\])\z/, section_id) do
      # an extent version: its own tagged levels, then the untagged ones
      [_, untagged, tag] ->
        levels = strip_levels(untagged)
        Enum.uniq([section_id | Enum.map(levels, &(&1 <> tag))] ++ levels)

      nil ->
        Enum.uniq([section_id | strip_levels(section_id)])
    end
  end

  defp strip_levels(id) do
    case Regex.run(~r/\A(.+)\([^()]*\)\z/, id) do
      [_, parent] -> [id | strip_levels(parent)]
      nil -> [id]
    end
  end
end
