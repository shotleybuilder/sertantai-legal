defmodule SertantaiLegal.Sync.Templates.Customers do
  @moduledoc """
  Customers template — demo customer directory.

  One row per demo customer. Legal Register links to this table via a
  many-to-many link_row, defining which laws apply to each customer.
  All other tables filter through the Legal Register relationship chain.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @impl true
  def id, do: :customers

  @impl true
  def name, do: "Customers — Demo Customer Directory"

  @impl true
  def requires, do: []

  @impl true
  def tables, do: [:customers]

  @impl true
  def field_specs(_sub_patterns) do
    %{
      customers: [
        %{
          name: "Name",
          type: :text,
          primary: true,
          description: "Customer name (e.g. QQ London)"
        },
        %{name: "Industry", type: :text, description: "Industry sector"},
        %{name: "Notes", type: :long_text, description: "Internal notes"}
      ]
    }
  end

  @impl true
  def view_specs(_sub_patterns) do
    %{
      customers: [
        %{name: "All Customers", type: :grid}
      ]
    }
  end
end
