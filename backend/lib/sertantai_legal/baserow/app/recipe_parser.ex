defmodule SertantaiLegal.Baserow.App.RecipeParser do
  @moduledoc """
  Parses YAML recipe files into structured maps for the Builder.
  """

  @recipe_dir "priv/baserow/app/recipes"

  @doc """
  Load all recipes from the recipes directory.
  Returns a map of `recipe_key → parsed_recipe`.
  """
  def load_all do
    recipe_path = Application.app_dir(:sertantai_legal, @recipe_dir)

    recipe_path
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".yml"))
    |> Enum.map(fn filename ->
      key = filename |> String.replace_suffix(".yml", "") |> String.to_atom()
      {:ok, content} = File.read(Path.join(recipe_path, filename))
      {:ok, parsed} = YamlElixir.read_from_string(content)
      {key, parsed}
    end)
    |> Map.new()
  end

  @doc """
  Load a single recipe by key (e.g. :legal_register).
  """
  def load(key) when is_atom(key) do
    filename = "#{key}.yml"
    path = Application.app_dir(:sertantai_legal, Path.join(@recipe_dir, filename))

    case File.read(path) do
      {:ok, content} ->
        {:ok, parsed} = YamlElixir.read_from_string(content)
        {:ok, parsed}

      {:error, :enoent} ->
        {:error, {:recipe_not_found, key}}
    end
  end

  @doc """
  Extract the table key that a recipe's data sources reference.
  Returns a list of unique table keys used by the recipe.
  """
  def table_keys(recipe) do
    (recipe["data_sources"] || [])
    |> Enum.map(fn ds -> ds["table"] end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  Collect all manual steps from a recipe.
  Returns a list of human-readable instructions.
  """
  def manual_steps(recipe) do
    steps = []

    # Check form_container children (manual nesting)
    steps =
      steps ++
        collect_manual_nesting(recipe["elements"] || [])

    # Check data sources with manual_config
    steps =
      steps ++
        ((recipe["data_sources"] || [])
         |> Enum.filter(& &1["manual_config"])
         |> Enum.map(fn ds ->
           "Set '#{ds["name"]}' data source Row ID to: #{ds["row_id"]}"
         end))

    # Check workflow actions with manual_config
    steps =
      steps ++
        ((get_in(recipe, ["workflow", "on_submit"]) || [])
         |> Enum.filter(& &1["manual_config"])
         |> Enum.map(fn action ->
           "Configure '#{action["type"]}' action field mappings in UI"
         end))

    # Check button events with manual_config
    steps =
      steps ++
        collect_manual_button_events(recipe["elements"] || [])

    # Link text (always manual for link-type table columns)
    steps =
      steps ++
        collect_link_text_steps(recipe["elements"] || [])

    steps
  end

  defp collect_manual_nesting(elements) do
    elements
    |> Enum.filter(fn el ->
      el["type"] == "form_container" && el["manual_nesting"] == true
    end)
    |> Enum.map(fn el ->
      children = el["children"] || []
      names = Enum.map(children, fn c -> c["label"] || c["type"] end) |> Enum.join(", ")
      "Drag #{names} INTO the Form container"
    end)
  end

  defp collect_manual_button_events(elements) do
    elements
    |> Enum.filter(fn el -> el["type"] == "button" && el["events"] end)
    |> Enum.flat_map(fn el ->
      (el["events"]["on_click"] || [])
      |> Enum.filter(& &1["manual_config"])
      |> Enum.map(fn action ->
        "Configure button '#{el["value"]}' #{action["type"]} action in UI"
      end)
    end)
  end

  defp collect_link_text_steps(elements) do
    elements
    |> Enum.filter(fn el -> el["type"] == "table" end)
    |> Enum.flat_map(fn table ->
      (table["columns"] || [])
      |> Enum.filter(fn col -> col["type"] == "link" && col["link_text"] end)
      |> Enum.map(fn col ->
        "Set '#{col["name"]}' link text to '#{col["link_text"]}' in table config"
      end)
    end)
  end
end
