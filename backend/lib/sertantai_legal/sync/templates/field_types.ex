defmodule SertantaiLegal.Sync.Templates.FieldTypes do
  @moduledoc """
  Universal field type definitions for provider-agnostic templates.

  Templates define fields using these types. Provider adapters translate
  them to provider-specific API parameters (e.g., `:long_text` → Baserow
  `"long_text"`, Airtable `"multilineText"`).
  """

  @type field_type ::
          :text
          | :long_text
          | :number
          | :date
          | :boolean
          | :single_select
          | :multi_select
          | :link_row
          | :lookup
          | :rollup
          | :formula
          | :file
          | :url
          | :email

  @type field_spec :: %{
          required(:name) => String.t(),
          required(:type) => field_type(),
          optional(:options) => [String.t()],
          optional(:target) => atom(),
          optional(:target_field) => String.t(),
          optional(:rollup_function) => atom(),
          optional(:expression) => String.t() | %{atom() => String.t()},
          optional(:description) => String.t(),
          optional(:read_only) => boolean()
        }

  @type view_type :: :grid | :kanban | :calendar | :form | :gallery | :timeline

  @type view_spec :: %{
          required(:name) => String.t(),
          required(:type) => view_type(),
          optional(:filters) => [filter_spec()],
          optional(:sorts) => [sort_spec()],
          optional(:group_by) => String.t(),
          optional(:stack_by) => String.t(),
          optional(:date_field) => String.t()
        }

  @type filter_spec :: %{
          required(:field) => String.t(),
          required(:op) => atom(),
          required(:value) => term()
        }

  @type sort_spec :: %{
          required(:field) => String.t(),
          required(:direction) => :asc | :desc
        }

  @doc "All supported universal field types."
  def types do
    [
      :text,
      :long_text,
      :number,
      :date,
      :boolean,
      :single_select,
      :multi_select,
      :link_row,
      :lookup,
      :rollup,
      :formula,
      :file,
      :url,
      :email
    ]
  end

  @doc "All supported view types."
  def view_types do
    [:grid, :kanban, :calendar, :form, :gallery, :timeline]
  end
end
