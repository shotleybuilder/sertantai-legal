defmodule SertantaiLegal.Scraper.ChangeCollector.Record do
  @moduledoc """
  One change to one LAT row from one source (lat-refactor LR-22/LR-23): a
  `lat_change_log` row before it is written.

  - target: `law_name` (the law changed), `section_id` (nil: the change
    reached no row — a visible gap), `via` (how it reached the row,
    strongest first) and `pointer` (the note whose placement carried it)
  - source: `source` (`effect` | `markup` | `law`) and `evidence` (the
    effect id, ChangeId or provision read)
  - the change as the source states it: refs, operation, dates, extent
  """

  @enforce_keys [:law_name, :source, :evidence]
  defstruct [
    :law_name,
    :section_id,
    :pointer,
    :source,
    :evidence,
    :affected_ref,
    :affecting_law,
    :affecting_ref,
    :operation,
    :effect_type,
    :effective_from,
    :prospective,
    :applied,
    :affected_extent,
    :effect_extent,
    :territorial_application,
    :dated_by_law,
    :dated_by_ref,
    via: [],
    in_force: [],
    savings: []
  ]

  @type t :: %__MODULE__{
          law_name: String.t(),
          section_id: String.t() | nil,
          via: [String.t()],
          pointer: String.t() | nil,
          source: String.t(),
          evidence: String.t(),
          affected_ref: String.t() | nil,
          affecting_law: String.t() | nil,
          affecting_ref: String.t() | nil,
          operation: String.t() | nil,
          effect_type: String.t() | nil,
          effective_from: Date.t() | nil,
          in_force: [map()],
          prospective: boolean() | nil,
          applied: boolean() | nil,
          savings: [String.t()],
          affected_extent: String.t() | nil,
          effect_extent: String.t() | nil,
          territorial_application: String.t() | nil,
          dated_by_law: String.t() | nil,
          dated_by_ref: String.t() | nil
        }
end
