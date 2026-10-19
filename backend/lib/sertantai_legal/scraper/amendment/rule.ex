defmodule SertantaiLegal.Scraper.Amendment.Rule do
  @moduledoc """
  One amending provision as a rule (amendment-rules AR-01): what it
  changes — the law, its targets, the operation and its level — and the
  provision it came from. Readers translate an amending law's instructions
  and repeals tables into rules once; one evaluator says which rows of the
  amended law a rule reaches. The date is the commencement ruleset's (the
  source provision's commencement); the note only points at which
  provisions to read.

  We label which rows changed, never rebuild text (Jason 2026-10-19): no
  new text, no position.

  - `amends`: the law changed.
  - `targets`: refs in LAT's section_id grammar, expanded at read time —
    named provisions, ranges ("s.41..s.43"), the quote's own provisions (a
    block "For Part 13, Sub-Part C substitute—" → the regulations it quotes).
  - `operation`: `:inserted` · `:substituted` · `:repealed` · `:renumbered`.
  - `level`: `:provision` (reaches the rows inside each target) · `:words`
    (the named provision only — never a container's descendants).
  - `source`: `%{law, ref, text}` — the amending provision read, verbatim.
  - `treatment`: `:instruction` · `:repeal_table` (provenance only).

  `to_text/1` is the readable form (`mix lat.amending`); `to_row/1` /
  `from_row/1` the table's (`amendment_rules`). Pure.
  """

  @enforce_keys [:amends, :targets, :operation, :level, :source, :treatment]
  defstruct [:amends, :targets, :operation, :level, :source, :treatment]

  @type operation :: :inserted | :substituted | :repealed | :renumbered
  @type level :: :provision | :words
  @type treatment :: :instruction | :repeal_table
  @type source :: %{law: String.t(), ref: String.t() | nil, text: String.t() | nil}
  @type t :: %__MODULE__{
          amends: String.t(),
          targets: [String.t()],
          operation: operation(),
          level: level(),
          source: source(),
          treatment: treatment()
        }

  @operations [:inserted, :substituted, :repealed, :renumbered]
  @levels [:provision, :words]
  @treatments [:instruction, :repeal_table]

  @doc "A rule from its fields; raises `ArgumentError` on a value outside the schema."
  @spec new(keyword() | map()) :: t()
  def new(fields) do
    rule = struct!(__MODULE__, fields)

    unless is_binary(rule.amends), do: raise(ArgumentError, "amends: #{inspect(rule.amends)}")

    unless match?([_ | _], rule.targets) and Enum.all?(rule.targets, &is_binary/1),
      do: raise(ArgumentError, "targets: #{inspect(rule.targets)}")

    for {field, allowed} <- [operation: @operations, level: @levels, treatment: @treatments],
        Map.fetch!(rule, field) not in allowed do
      raise ArgumentError, "#{field}: #{inspect(Map.fetch!(rule, field))}"
    end

    rule
  end

  @doc "The rule as one readable line: law targets — (words) operation — treatment — source."
  @spec to_text(t()) :: String.t()
  def to_text(%__MODULE__{} = r) do
    Enum.join(
      [
        "#{r.amends} #{Enum.join(r.targets, ", ")}",
        if(r.level == :words, do: "words #{r.operation}", else: to_string(r.operation)),
        to_string(r.treatment),
        source_text(r.source)
      ],
      " — "
    )
  end

  @doc "The rule as an `amendment_rules` row (plain column values)."
  @spec to_row(t()) :: map()
  def to_row(%__MODULE__{} = r) do
    %{
      amends: r.amends,
      targets: r.targets,
      operation: Atom.to_string(r.operation),
      level: Atom.to_string(r.level),
      source_law: r.source.law,
      source_ref: r.source.ref,
      source_text: r.source.text,
      treatment: Atom.to_string(r.treatment)
    }
  end

  @doc "A rule from an `amendment_rules` row (`to_row/1`'s keys)."
  @spec from_row(map()) :: t()
  def from_row(row) do
    new(
      amends: row.amends,
      targets: row.targets,
      operation: String.to_existing_atom(row.operation),
      level: String.to_existing_atom(row.level),
      source: %{law: row.source_law, ref: row.source_ref, text: row.source_text},
      treatment: String.to_existing_atom(row.treatment)
    )
  end

  defp source_text(%{law: law, ref: ref, text: text}) do
    [law, ref]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> then(&if(text, do: "#{&1}: “#{text}”", else: &1))
  end
end
