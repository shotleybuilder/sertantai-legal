defmodule SertantaiLegal.Sync.JobStatus do
  @moduledoc """
  Status of a sync job execution.
  """

  use Ash.Type.Enum,
    values: [
      :queued,
      :running,
      :completed,
      :failed,
      :cancelled
    ]
end
