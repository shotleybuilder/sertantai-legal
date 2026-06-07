defmodule SertantaiLegal.Sync.Templates.TemplateBehaviour do
  @moduledoc """
  Behaviour for provider-agnostic compliance templates.

  Each template defines its schema (tables, fields, views) using universal
  types. The `TemplateApplicator` resolves dependencies, checks provider
  capabilities, and delegates creation to the provider adapter.

  Templates adapt their output based on sub-pattern configuration —
  e.g., risk scoring fields only appear when `risk_scoring: :matrix`.
  """

  alias SertantaiLegal.Sync.Templates.{FieldTypes, SubPatterns}

  @doc "Unique template identifier (e.g., :foundation, :compliance_assessment)."
  @callback id() :: atom()

  @doc "Human-readable template name."
  @callback name() :: String.t()

  @doc "Template IDs that must be applied before this one."
  @callback requires() :: [atom()]

  @doc "Table keys this template creates (e.g., [:assessments, :actions])."
  @callback tables() :: [atom()]

  @doc """
  Field specs for each table, adapted by sub-patterns.

  Returns `%{table_key => [field_spec]}`.
  """
  @callback field_specs(SubPatterns.t()) :: %{atom() => [FieldTypes.field_spec()]}

  @doc """
  View specs for each table, adapted by sub-patterns.

  Returns `%{table_key => [view_spec]}`.
  """
  @callback view_specs(SubPatterns.t()) :: %{atom() => [FieldTypes.view_spec()]}

  @doc """
  Rollup/lookup fields to add to OTHER templates' tables.

  Returns `%{table_key => [field_spec]}` where table_key belongs to a
  prerequisite template (e.g., adding a rollup to the LRT table).
  """
  @callback cross_table_fields(SubPatterns.t()) :: %{atom() => [FieldTypes.field_spec()]}

  @doc """
  Webhook specs — which tables and events to subscribe to.

  Returns a list of `%{table: atom(), events: [:created | :updated | :deleted]}`.
  """
  @callback webhook_specs() :: [%{table: atom(), events: [atom()]}]

  @doc """
  Seed initial data after tables and fields are created.

  Receives the applicator context (config, row mappings from prerequisite
  templates, sub-patterns). Returns `{:ok, count}` or `{:error, reason}`.
  """
  @callback seed(context :: map()) :: {:ok, non_neg_integer()} | {:error, term()}

  @optional_callbacks [cross_table_fields: 1, webhook_specs: 0, seed: 1]
end
