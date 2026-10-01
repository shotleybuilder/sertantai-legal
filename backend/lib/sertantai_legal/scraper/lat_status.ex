defmodule SertantaiLegal.Scraper.LatStatus do
  @moduledoc """
  Per-row legal status of a law's LAT (sertantai-legal #167, L8.1 of fractalaw's
  DRRP-TEMPORAL-PROPOSAL; D1–D4 approved 2026-10-01).

  Pure: takes rows and amendment notes, returns `%{section_id => status}`.
  No DB access (`LatStatus.Apply` loads and writes).

  | status             | evidence                                                        |
  |--------------------|-----------------------------------------------------------------|
  | `prospective`      | CLML `Status="Prospective"`, set by the parser and kept here    |
  | `repealed`         | text is only dots, or the parser's `[Repealed]`/`[Revoked]`     |
  | `repealed_saved`   | repealed, and a repeal note on it mentions savings (D2: only    |
  |                    | with a note, never inferred)                                    |
  | `in_force_partial` | a commencement/amendment note on it (or an ancestor) says "for  |
  |                    | specified/certain purposes", and none says wholly/fully in      |
  |                    | force, "not already in force" or "otherwise" (modification      |
  |                    | notes are about application, not commencement: ignored)        |
  | `in_force`         | everything else                                                 |

  A note's target is the last (deepest) entry of its `affected_sections`; the
  others are ancestors for context. A target covers itself, its
  sub-provisions (`s.6(1)(a)`) and its extent versions (`s.6[S]`).

  Status is not part of `lat_hash`/`struct_hash` (a shared contract with
  fractalaw); the manifest's `status_hash` carries it.
  """

  @statuses ~w(in_force in_force_partial repealed repealed_saved prospective)

  @dots ~r/\A[\s.]+\z/
  @markers ["[Repealed]", "[Revoked]"]

  @partial ~r/for (specified|certain) purposes/i
  # "... for specified purposes and otherwise 1.4.1996" / "... and 1.4.2007
  # otherwise": the remainder commenced too.
  @full ~r/wholly in force|fully in force|so far as not already in force|for all other purposes|\botherwise\b/i
  @repeal ~r/\b(repealed|revoked|omitted)\b/i
  # Case-sensitive: "Saving Provisions" / "Energy Savings" in instrument titles
  # are capitalised; a savings note on the repeal reads "... and savings in ...".
  @savings ~r/\bsavings\b/

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

  @doc "The section_id a note applies to: the last of its `affected_sections`."
  @spec note_target(map()) :: String.t() | nil
  def note_target(%{affected_sections: [_ | _] = sections}), do: List.last(sections)
  def note_target(_), do: nil

  @doc "True when a note targeting `target` applies to `section_id`."
  @spec covers?(String.t(), String.t()) :: boolean()
  def covers?(target, section_id) do
    target == section_id or String.starts_with?(section_id, target <> "(") or
      String.starts_with?(section_id, target <> "[")
  end

  @doc """
  Status per row. `rows`: maps with `:section_id`, `:text` and `:status` (the
  parser's value; only `"prospective"` is kept from it). `notes`: maps with
  `:affected_sections`, `:text` and optionally `:code_type`.
  """
  @spec resolve([map()], [map()]) :: %{String.t() => status()}
  def resolve(rows, notes) do
    by_target = Enum.group_by(notes, &note_target/1, &{Map.get(&1, :code_type), &1.text})

    Map.new(rows, fn row ->
      notes = Enum.flat_map(ancestors(row.section_id), &Map.get(by_target, &1, []))
      {row.section_id, status(row, notes)}
    end)
  end

  defp status(%{status: "prospective"}, _notes), do: "prospective"

  defp status(row, notes) do
    texts = Enum.map(notes, &elem(&1, 1))
    # Modification notes are about how a provision applies, not when it
    # commenced, so they are no evidence of partial commencement.
    commencement = for {type, text} <- notes, type != "modification", do: text

    cond do
      repealed_text?(row.text) ->
        if Enum.any?(texts, &(Regex.match?(@repeal, &1) and Regex.match?(@savings, &1))),
          do: "repealed_saved",
          else: "repealed"

      Enum.any?(commencement, &Regex.match?(@partial, &1)) and
          not Enum.any?(commencement, &Regex.match?(@full, &1)) ->
        "in_force_partial"

      true ->
        "in_force"
    end
  end

  @doc """
  The section_id itself, then without an extent tag, then each enclosing
  "(…)" level: `"L:s.6(1)(a)[S]"` → `[.., "L:s.6(1)(a)", "L:s.6(1)", "L:s.6"]`.
  A note whose target is any of these applies to the row.
  """
  @spec ancestors(String.t()) :: [String.t()]
  def ancestors(section_id) do
    untagged = String.replace(section_id, ~r/\[[^\]]*\]\z/, "")
    Enum.uniq([section_id | strip_levels(untagged)])
  end

  defp strip_levels(id) do
    case Regex.run(~r/\A(.+)\([^()]*\)\z/, id) do
      [_, parent] -> [id | strip_levels(parent)]
      nil -> [id]
    end
  end
end
