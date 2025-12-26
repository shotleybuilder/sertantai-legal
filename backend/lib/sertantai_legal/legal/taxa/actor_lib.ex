defmodule SertantaiLegal.Legal.Taxa.ActorLib do
  @moduledoc """
  Utilities for extracting duty actors from legal text using regex patterns.

  This module provides functions to:
  - Run actor patterns against text and collect matches
  - Build custom actor libraries from subsets
  - Create regex OR groups for combined matching

  ## Example

      iex> ActorLib.workflow("The employer shall ensure safety", :actor)
      ["Org: Employer"]

      iex> ActorLib.workflow("The Minister may prescribe regulations", :actor)
      ["Gvt: Minister"]
  """

  alias SertantaiLegal.Legal.Taxa.ActorDefinitions

  @dutyholder_library ActorDefinitions.dutyholder_library()
  @government ActorDefinitions.government()
  @governed ActorDefinitions.governed()

  @type actor :: atom() | String.t()
  @type regex :: String.t()
  @type library :: list({actor(), regex()})

  @doc """
  Prints all dutyholder categories to console (for debugging).
  """
  @spec print_dutyholders_to_console() :: :ok
  def print_dutyholders_to_console do
    @dutyholder_library
    |> Enum.map(fn {class, _} -> to_string(class) end)
    |> Enum.each(&IO.puts/1)
  end

  @doc """
  Extracts actors from text using the full dutyholder library.

  Returns a list of actor names found in the text.
  Matched text is removed progressively to prevent duplicate matches.
  """
  @spec workflow(String.t()) :: list()
  def workflow(""), do: []

  @spec workflow(String.t(), :actor) :: list(String.t())
  def workflow(text, :actor) do
    {text, []}
    |> blacklister()
    |> process(@dutyholder_library, true)
    |> elem(1)
    |> Enum.reverse()
  end

  @doc """
  Extracts actors from text using a custom library.

  Returns a sorted list of actor names found in the text.
  """
  @spec workflow(String.t(), library()) :: list(String.t())
  def workflow(text, library) when is_list(library) do
    {text, []}
    |> process(library, true)
    |> elem(1)
    |> Enum.sort()
  end

  @doc """
  Processes text against a library of actor patterns.

  ## Parameters
  - `collector` - Tuple of `{text, accumulated_actors}`
  - `library` - List of `{actor_name, regex_pattern}` tuples
  - `rm?` - Whether to remove matched text (prevents duplicate matches)

  ## Returns
  Tuple of `{remaining_text, list_of_actors}`
  """
  @spec process({String.t(), list()}, library(), boolean()) :: {String.t(), list(String.t())}
  def process(collector, library, rm?) do
    Enum.reduce(library, collector, fn {actor, regex}, {text, actors} = acc ->
      case Regex.compile(regex, "m") do
        {:ok, regex_compiled} ->
          case Regex.run(regex_compiled, text) do
            [_match] ->
              actor_str = to_string(actor)
              new_text = if rm?, do: Regex.replace(regex_compiled, text, ""), else: text
              {new_text, [actor_str | actors]}

            nil ->
              acc

            _multiple_matches ->
              # Multiple matches - take first occurrence
              actor_str = to_string(actor)
              new_text = if rm?, do: Regex.replace(regex_compiled, text, "", global: false), else: text
              {new_text, [actor_str | actors]}
          end

        {:error, {error, _pos}} ->
          IO.puts("ERROR: Actor regex doesn't compile: #{error}\nPattern: #{regex}")
          acc
      end
    end)
  end

  @doc """
  Builds a custom library using a list of actor names.

  ## Parameters
  - `actors` - List of actor name strings to include
  - `library_type` - One of `:government`, `:governed`, or `:all`

  ## Example

      iex> ActorLib.custom_actor_library(["Org: Employer", "Ind: Worker"], :governed)
      [{"Org: Employer", "..."}, {"Ind: Worker", "..."}]
  """
  @spec custom_actor_library(list(String.t()), atom()) :: library()
  def custom_actor_library(actors, library_type) when is_list(actors) do
    library =
      case library_type do
        :government -> @government
        :governed -> @governed
        _ -> @dutyholder_library
      end

    actors
    |> Enum.map(&String.to_atom/1)
    |> Enum.reduce([], fn actor, acc ->
      case Keyword.get(library, actor) do
        nil ->
          # Actor not found in library - skip silently
          acc

        pattern ->
          [{actor, pattern} | acc]
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Converts a library to a single regex OR group string.

  Useful for building combined patterns that match any actor in the library.

  ## Example

      iex> ActorLib.dutyholders_regex([{"Org: Employer", "[Ee]mployers?"}])
      [{"Org: Employer", {"[Ee]mployers?", "(?:[ \"][Ee]mployers?[ \\\\.,;:\"])"}}]
  """
  @spec dutyholders_regex(library()) :: list({actor(), {String.t(), String.t()}})
  def dutyholders_regex(library) do
    Enum.reduce(library, [], fn
      {k, v}, acc when is_binary(v) ->
        pattern = ~s/(?:[ "]#{v}[ \\.,:;"\\]])/
        [{k, {v, pattern}} | acc]

      {k, v}, acc when is_list(v) ->
        pattern =
          v
          |> Enum.map(&~s/[ "]#{&1}[ \\.,:;"\\]]/)
          |> Enum.join("|")
          |> then(&~s/(?:#{&1})/)

        [{k, {v, pattern}} | acc]
    end)
    |> Enum.reverse()
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  # Removes blacklisted terms from text before processing
  defp blacklister({text, collector}) do
    cleaned_text =
      Enum.reduce(ActorDefinitions.blacklist(), text, fn regex, acc ->
        Regex.replace(~r/#{regex}/m, acc, "")
      end)

    {cleaned_text, collector}
  end
end
