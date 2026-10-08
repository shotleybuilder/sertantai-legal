defmodule SertantaiLegal.Scraper.NotePlacement do
  @moduledoc """
  Places amendment notes on their provisions without a re-parse (LAT parser
  coverage II): notes cited only by a `CommentaryRef` attribute
  (Addition/Substitution/Repeal) or from a P1group Title were stored with no
  `affected_sections`. `mix lat.place_notes` re-parses each law from the CLML
  store and sets the sections of the stored notes.

  Pure: `plan/2` matches stored notes to parsed ones on `{code_type, code,
  text}` (exact — a note that drifted from the source is left for a
  re-parse) and returns `{id, sections}` updates. A parse that finds no
  sections never clears stored ones.
  """

  @type note :: %{
          required(:code_type) => String.t(),
          required(:code) => String.t(),
          required(:text) => String.t(),
          required(:affected_sections) => [String.t()] | nil,
          optional(:id) => String.t()
        }

  @doc "Section updates for the stored notes, and how many could not be matched."
  @spec plan([note()], [note()]) :: %{
          updates: [{String.t(), [String.t()]}],
          unmatched: non_neg_integer()
        }
  def plan(stored, parsed) do
    sections =
      parsed
      |> Enum.group_by(
        &{to_string(&1.code_type), &1.code, &1.text},
        &(&1.affected_sections || [])
      )
      |> Map.new(fn {key, lists} -> {key, lists |> List.flatten() |> Enum.uniq()} end)

    Enum.reduce(stored, %{updates: [], unmatched: 0}, fn n, acc ->
      case Map.fetch(sections, {n.code_type, n.code, n.text}) do
        :error -> %{acc | unmatched: acc.unmatched + 1}
        {:ok, []} -> acc
        {:ok, same} when same == n.affected_sections -> acc
        {:ok, new} -> %{acc | updates: [{n.id, new} | acc.updates]}
      end
    end)
    |> Map.update!(:updates, &Enum.reverse/1)
  end
end
