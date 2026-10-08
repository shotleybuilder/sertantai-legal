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

  A note's targets are its `affected_sections`: the rows that cite it at their
  own level (LH-01). A target covers itself, its sub-provisions (`s.6(1)(a)`,
  `s.6(1)[S]` under `s.6[S]`) and, untagged, its extent versions (`s.6[S]`).

  Status is not part of `lat_hash`/`struct_hash` (a shared contract with
  fractalaw); the manifest's `status_hash` carries it.
  """

  @statuses ~w(in_force in_force_partial repealed repealed_saved prospective)

  @dots ~r/\A[\s.]+\z/
  @markers ["[Repealed]", "[Revoked]"]

  alias SertantaiLegal.Scraper.Territory

  @partial ~r/for (specified|certain) purposes/i
  # "... for specified purposes and otherwise 1.4.1996" / "... and 1.4.2007
  # otherwise": the remainder commenced too.
  # "so far as it is / they are not already in force", "… in operation", typos
  # ("alrady"), "for (all) remaining purposes" (RTA 1988 s.184 et al.).
  @full ~r/wholly in force|fully in force|so far as (?:it is |they are )?not (?:al\w*dy )?in (?:forc|operation)|for all other purposes|remaining purposes|\botherwise\b/i
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
  Status per row. `rows`: maps with `:section_id`, `:text` and `:status` (the
  parser's value; only `"prospective"` is kept from it). `notes`: maps with
  `:affected_sections`, `:text` and optionally `:code_type`.
  """
  @spec resolve([map()], [map()]) :: %{String.t() => status()}
  def resolve(rows, notes) do
    by_target =
      notes
      |> Enum.flat_map(fn n ->
        Enum.map(note_targets(n), &{&1, {Map.get(n, :code_type), n.text}})
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

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

      # text retained but repealed in every territory the row extends to
      # (savings / specified purposes); repealed in some → still in force
      Map.get(row, :excluded_extent) &&
          Territory.covers?(row.excluded_extent, Map.get(row, :extent_code)) ->
        "repealed_saved"

      Enum.any?(commencement, &partial_note?(&1, row.section_id)) and
          not Enum.any?(commencement, &Regex.match?(@full, &1)) ->
        "in_force_partial"

      true ->
        "in_force"
    end
  end

  # A note puts its row partly in force only when "for specified purposes"
  # is about the note's own change: before " by " (not in the citation), not
  # in an "except …" clause, and — when the note opens with a section /
  # regulation / article number or range — about the row's provision
  # (legislation.gov.uk copies notes onto other provisions: NPA 2017 s.44
  # carries "S. 2 in force for specified purposes").
  defp partial_note?(text, section_id) do
    # each ";"-separated commencement step, up to its " by "
    partial = text |> String.split(";") |> Enum.any?(&partial_step?/1)
    partial and subject_covers?(text, section_id)
  end

  defp partial_step?(segment) do
    head = segment |> String.split(" by ", parts: 2) |> hd()

    # a repeal's "(except for … for specified purposes …)" lists what is
    # kept; an insertion's "(date except for certain purposes)" is partial
    head =
      if Regex.match?(@repeal, head),
        do: head |> String.split(~r/\bexcept\b/, parts: 2) |> hd(),
        else: head

    Regex.match?(@partial, head)
  end

  @subject ~r/\A(?:Ss?|Regs?|Arts?|Rules?)\.\s*(\d+)[A-Z]*(?:\(\w+\))*(?:\s*[-–]\s*(\d+)[A-Z]*)?/

  defp subject_covers?(text, section_id) do
    with [_ | bounds] <- Regex.run(@subject, text),
         [_, own] <- Regex.run(~r/:(?:s|reg|art|rule)\.(\d+)/, section_id) do
      [from | rest] = Enum.map(bounds, &String.to_integer/1)
      to = List.first(rest, from)
      String.to_integer(own) in from..to//1
    else
      # no numbered subject (Pt., Ch., words in …) or a row with no number
      _ -> true
    end
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
