defmodule SertantaiLegal.Legal.Taxa.DutyActor do
  @moduledoc """
  Extracts duty actors from legal text.

  Duty actors are the entities (people, organizations, government bodies) that have
  duties, rights, responsibilities, or powers under a piece of legislation.

  Two categories of actors are identified:
  - **Governed actors** ("Duty Actor"): Non-government entities like employers, companies, individuals
  - **Government actors** ("Duty Actor Gvt"): Government bodies like ministers, authorities, agencies

  ## Usage

      # Extract from a single text
      iex> DutyActor.get_actors_in_text("The employer shall ensure safety")
      %{actors: ["Org: Employer"], actors_gvt: []}

      # Process a law record
      iex> DutyActor.process_record(%{text: "The Minister may prescribe..."})
      %{text: "...", role: ["Gvt: Minister"], role_gvt: ["Gvt: Minister"]}
  """

  alias SertantaiLegal.Legal.Taxa.ActorDefinitions

  @government ActorDefinitions.government()
  @governed ActorDefinitions.governed()

  @type actor :: String.t()
  @type text :: String.t()

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Extracts both governed and government actors from text.

  Returns a map with `:actors` (governed) and `:actors_gvt` (government).
  """
  @spec get_actors_in_text(text()) :: %{actors: list(actor()), actors_gvt: list(actor())}
  def get_actors_in_text(text) when is_binary(text) do
    cleaned_text = apply_blacklist(text)

    %{
      actors: extract_actors(cleaned_text, :governed),
      actors_gvt: extract_actors(cleaned_text, :government)
    }
  end

  def get_actors_in_text(_), do: %{actors: [], actors_gvt: []}

  @doc """
  Extracts governed actors ("Duty Actor") from text.

  These are non-government entities: employers, companies, workers, etc.
  """
  @spec get_governed_actors(text()) :: list(actor())
  def get_governed_actors(text) when is_binary(text) do
    text
    |> apply_blacklist()
    |> extract_actors(:governed)
  end

  def get_governed_actors(_), do: []

  @doc """
  Extracts government actors ("Duty Actor Gvt") from text.

  These are government bodies: ministers, authorities, agencies, etc.
  """
  @spec get_government_actors(text()) :: list(actor())
  def get_government_actors(text) when is_binary(text) do
    text
    |> apply_blacklist()
    |> extract_actors(:government)
  end

  def get_government_actors(_), do: []

  @doc """
  Processes a single law record, extracting actors into role/role_gvt fields.

  Expects a map with a `:text` or `"text"` key containing the legal text.
  Returns the map with `:role` and `:role_gvt` added.
  """
  @spec process_record(map()) :: map()
  def process_record(%{text: text} = record) when is_binary(text) and text != "" do
    %{actors: actors, actors_gvt: actors_gvt} = get_actors_in_text(text)

    record
    |> Map.put(:role, actors)
    |> Map.put(:role_gvt, actors_gvt)
  end

  def process_record(%{"text" => text} = record) when is_binary(text) and text != "" do
    %{actors: actors, actors_gvt: actors_gvt} = get_actors_in_text(text)

    record
    |> Map.put("role", actors)
    |> Map.put("role_gvt", actors_gvt)
  end

  def process_record(record), do: record

  @doc """
  Processes a list of law records, extracting actors for each.
  """
  @spec process_records(list(map())) :: list(map())
  def process_records(records) when is_list(records) do
    Enum.map(records, &process_record/1)
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  # Extracts actors using the specified library
  defp extract_actors(text, :governed) do
    run_actor_regex(text, @governed)
  end

  defp extract_actors(text, :government) do
    run_actor_regex(text, @government)
  end

  # Runs regex patterns against text and collects matching actors
  defp run_actor_regex(text, library) do
    {_remaining_text, actors} =
      Enum.reduce(library, {text, []}, fn {actor, regex}, {txt, acc} ->
        case Regex.compile(regex, "m") do
          {:ok, regex_compiled} ->
            case Regex.run(regex_compiled, txt) do
              [_match | _] ->
                actor_str = to_string(actor)
                # Remove matched text to prevent duplicate matches
                new_text = Regex.replace(regex_compiled, txt, "", global: false)
                {new_text, [actor_str | acc]}

              nil ->
                {txt, acc}
            end

          {:error, {error, _pos}} ->
            IO.puts("ERROR: DutyActor regex doesn't compile: #{error}")
            {txt, acc}
        end
      end)

    actors
    |> Enum.reverse()
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Removes blacklisted terms from text before processing
  defp apply_blacklist(text) do
    Enum.reduce(ActorDefinitions.blacklist(), text, fn pattern, acc ->
      case Regex.compile(pattern, "m") do
        {:ok, regex} -> Regex.replace(regex, acc, "")
        {:error, _} -> acc
      end
    end)
  end
end
