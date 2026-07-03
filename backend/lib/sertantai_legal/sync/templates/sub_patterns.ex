defmodule SertantaiLegal.Sync.Templates.SubPatterns do
  @moduledoc """
  Sub-pattern configuration for compliance templates.

  Each dimension is independent — customers mix and match to build their
  workspace. Templates read these to adapt their field specs, views,
  and seed logic.
  """

  @type t :: %__MODULE__{
          storage_mode: :embedded | :reference,
          risk_scoring: :simple | :matrix,
          people: :flat | :linked | :collaborator | :hybrid,
          org_structure: :flat | :department | :site | :division_site,
          assessment_grain: :law | :provision,
          review_cycle: :manual | :scheduled,
          reporting: :standard | :dashboard,
          data_collection: :grid_only | :forms,
          improvement: :none | :pdca
        }

  defstruct storage_mode: :embedded,
            risk_scoring: :simple,
            people: :linked,
            org_structure: :flat,
            assessment_grain: :law,
            review_cycle: :scheduled,
            reporting: :standard,
            data_collection: :grid_only,
            improvement: :none

  @doc "Build a SubPatterns struct from a keyword list or map, using defaults for missing keys."
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @doc "Validate that all sub-pattern values are recognised."
  def validate(%__MODULE__{} = sp) do
    errors =
      []
      |> check(:storage_mode, sp.storage_mode, [:embedded, :reference])
      |> check(:risk_scoring, sp.risk_scoring, [:simple, :matrix])
      |> check(:people, sp.people, [:flat, :linked, :collaborator, :hybrid])
      |> check(:org_structure, sp.org_structure, [:flat, :department, :site, :division_site])
      |> check(:assessment_grain, sp.assessment_grain, [:law, :provision])
      |> check(:review_cycle, sp.review_cycle, [:manual, :scheduled])
      |> check(:reporting, sp.reporting, [:standard, :dashboard])
      |> check(:data_collection, sp.data_collection, [:grid_only, :forms])
      |> check(:improvement, sp.improvement, [:none, :pdca])

    case errors do
      [] -> :ok
      errs -> {:error, errs}
    end
  end

  defp check(errors, field, value, allowed) do
    if value in allowed do
      errors
    else
      [{field, "must be one of #{inspect(allowed)}, got #{inspect(value)}"} | errors]
    end
  end
end
