defmodule SertantaiLegal.Scraper.LegislationGovUk.Parser do
  @moduledoc """
  HTML parser for legislation.gov.uk using Floki.

  Parses the "new laws" page to extract law records.

  Ported from Legl.Services.LegislationGovUk.Parsers.Html
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.Helpers

  @doc """
  Parse the "new laws" HTML page from legislation.gov.uk.

  Returns a list of maps with:
  - `:Title_EN` - Full title of the legislation
  - `:type_code` - Type code (e.g., "uksi", "ukpga")
  - `:Year` - Year as integer
  - `:Number` - Legislation number as string
  - `:md_description` - Description text (if available)

  ## Examples

      iex> Parser.parse_new_laws(html_content)
      {:ok, [%{Title_EN: "Example Regulations 2024", type_code: "uksi", Year: 2024, Number: "123"}]}
  """
  @spec parse_new_laws(String.t()) :: {:ok, list(map())} | {:error, String.t()}
  def parse_new_laws(html) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        content = Floki.find(document, ".p_content")

        records =
          content
          |> List.first()
          |> get_children()
          |> traverse()

        {:ok, records}

      {:error, reason} ->
        {:error, "Failed to parse HTML: #{inspect(reason)}"}
    end
  end

  defp get_children(nil), do: []

  defp get_children(element) do
    element
    |> Floki.children()
    |> List.first()
    |> case do
      nil -> []
      child -> Floki.children(child)
    end
  end

  defp traverse(content) when is_list(content) do
    content
    |> Enum.reduce([], fn element, acc ->
      process_element(element, acc)
    end)
  end

  defp traverse(_), do: []

  # Link element with title - h6 with anchor
  defp process_element({"h6", _, [{"a", [{"href", path}], title}, _, _]}, acc) do
    make_map(path, title, acc)
  end

  defp process_element({"h6", _, [{"a", [{"href", path}], title}]}, acc) do
    make_map(path, title, acc)
  end

  # Description paragraph
  defp process_element({"p", _, description}, acc) do
    description_text =
      case description do
        [] ->
          ""

        _ ->
          description
          |> Enum.join(" ")
          |> String.trim()
          |> String.replace("\t", "")
          |> String.replace("\n", " ")
      end

    case List.pop_at(acc, 0) do
      {nil, acc} ->
        acc

      {record, rest} ->
        [Map.put(record, :md_description, description_text) | rest]
    end
  end

  # Ignore section headers
  defp process_element({"h4", _, _}, acc), do: acc
  defp process_element({"h5", _, _}, acc), do: acc

  # Log unmatched elements
  defp process_element(element, acc) do
    IO.puts("Warning: Unmatched element in HTML: #{inspect(element)}")
    acc
  end

  defp make_map(path, title, acc) do
    case Helpers.split_path(path) do
      {:ok, type_code, year, number} ->
        cleaned_title =
          title
          |> Enum.join(" ")
          |> Helpers.split_title()
          |> Helpers.title_clean()

        record = %{
          Title_EN: cleaned_title,
          type_code: type_code,
          Year: String.to_integer(year),
          Number: number
        }

        [record | acc]

      {:error, _} ->
        IO.puts("Warning: Could not parse path: #{path}")
        acc
    end
  end

  @doc """
  Parse amendment table HTML.

  Used for parsing the "affects" and "affected by" tables on legislation pages.
  """
  @spec parse_amendment_table(String.t()) :: {:ok, list()} | :no_records | {:error, String.t()}
  def parse_amendment_table(html) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        case Floki.find(document, "tbody") do
          [] -> :no_records
          body -> {:ok, body}
        end

      {:error, reason} ->
        {:error, "Failed to parse HTML: #{inspect(reason)}"}
    end
  end
end
