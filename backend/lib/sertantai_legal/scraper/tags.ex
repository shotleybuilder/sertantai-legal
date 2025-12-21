defmodule SertantaiLegal.Scraper.Tags do
  @moduledoc """
  Extracts meaningful keywords (tags) from legal document titles.

  Processes titles by:
  1. Normalizing text (lowercase, remove punctuation)
  2. Removing common stop words (the, and, of, etc.)
  3. Capitalizing remaining meaningful words

  Ported from Legl.Countries.Uk.LeglRegister.Tags
  """

  @doc """
  Set the Tags field based on the Title_EN.

  ## Parameters
  - record: Map with :Title_EN key

  ## Returns
  Map with :Tags field set to list of keywords

  ## Examples

      iex> Tags.set_tags(%{Title_EN: "Health and Safety at Work etc. Act 1974"})
      %{Title_EN: "...", Tags: ["Health", "Safety", "Work", "Etc", "Act"]}

      iex> Tags.set_tags(%{Title_EN: "The Control of Substances Hazardous to Health Regulations 2002"})
      %{Title_EN: "...", Tags: ["Control", "Substances", "Hazardous", "Health", "Regulations"]}
  """
  @spec set_tags(map()) :: map()
  def set_tags(%{Tags: tags} = record) when is_list(tags) and length(tags) > 1 do
    # Already has tags, keep them
    record
  end

  def set_tags(%{Title_EN: title} = record) when is_binary(title) and title != "" do
    Map.put(record, :Tags, extract_tags(title))
  end

  def set_tags(record), do: record

  @doc """
  Extract tags from a title string.

  ## Parameters
  - title: The legal document title

  ## Returns
  List of capitalized keywords
  """
  @spec extract_tags(String.t()) :: [String.t()]
  def extract_tags(title) when is_binary(title) do
    title
    |> String.trim()
    # Lowercase for consistent processing
    |> String.downcase()
    # Remove numbers and non-alphabetic characters (keep spaces and colons for splitting)
    |> String.replace(~r/[^a-zA-Z\s:]+/, "")
    # Normalize multiple spaces to single space
    |> String.replace(~r/\s{2,}/, " ")
    # Remove common stop words
    |> remove_stop_words()
    # Normalize spaces again
    |> String.replace(~r/\s{2,}/, " ")
    # Remove leading comma/space
    |> String.replace(~r/^,\s*/, "")
    |> String.trim()
    # Split into words and capitalize
    |> String.split(" ")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.capitalize/1)
    |> Enum.reject(&(&1 == ""))
  end

  @stop_words ~w[
    the a an and at are as
    to this that these those
    for or of off on
    if in is it its
    no not
    be by
    who with
    has have
  ]

  # Remove common English stop words that don't add meaning
  defp remove_stop_words(text) do
    words = String.split(text, " ")

    words
    |> Enum.reject(fn word -> word in @stop_words end)
    |> Enum.join(" ")
  end
end
