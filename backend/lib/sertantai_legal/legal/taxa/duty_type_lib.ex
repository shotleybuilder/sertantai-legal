defmodule SertantaiLegal.Legal.Taxa.DutyTypeLib do
  @moduledoc """
  Utility functions for duty type classification.

  This module provides the core logic for:
  - Finding role holders (duty holders, rights holders, etc.) in legal text
  - Processing generic duty type patterns
  - Building custom regex libraries for specific actors

  ## Processing Flow

  1. Text is first cleaned with `blacklist/1` to remove false positive patterns
  2. `find_role_holders/4` searches for actor-specific duties/rights/responsibilities/powers
  3. `duty_types_generic/1` identifies structural duty types (amendment, definition, etc.)
  4. Results are combined and sorted

  ## Example

      iex> DutyTypeLib.duty_types_generic("This Act may be cited as...")
      ["Enactment, Citation, Commencement"]

      iex> DutyTypeLib.find_role_holders(:duty, ["Org: Employer"], "The employer shall ensure...")
      {["Org: Employer"], ["Duty"], "DUTY\\n👤Org: Employer\\n📌..."}
  """

  alias SertantaiLegal.Legal.Taxa.{
    ActorLib,
    DutyTypeDefn,
    DutyTypeDefnGoverned,
    DutyTypeDefnGovernment
  }

  @type duty_types :: list(String.t())
  @type actors :: list(String.t())
  @type text :: String.t()
  @type role :: :duty | :right | :responsibility | :power

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Finds role holders of a specific type in legal text.

  Returns a tuple of:
  - List of actor names found with that role
  - List containing the role type ("Duty", "Right", etc.) if found
  - Formatted string of matches for debugging/display
  - Accumulated regex patterns used

  ## Parameters

  - `role`: One of `:duty`, `:right`, `:responsibility`, `:power`
  - `actors`: List of actor names to search for
  - `text`: The legal text to search
  - `regexes`: Accumulated regex patterns (for debugging)
  """
  @spec find_role_holders(role(), actors(), text(), list()) ::
          {actors(), duty_types(), String.t(), list()}
  def find_role_holders(_role, [], _text, regexes), do: {[], [], "", regexes}

  def find_role_holders(role, actors, text, regexes) when is_list(actors) do
    # Build actor-specific regex library
    actors_regex =
      case role do
        r when r in [:duty, :right] -> ActorLib.custom_actor_library(actors, :governed)
        _ -> ActorLib.custom_actor_library(actors, :government)
      end

    # Build role-specific patterns for each actor
    regex_lib =
      case role do
        :duty -> build_lib(actors_regex, &DutyTypeDefnGoverned.duty/1)
        :right -> build_lib(actors_regex, &DutyTypeDefnGoverned.right/1)
        :responsibility -> build_lib(actors_regex, &DutyTypeDefnGovernment.responsibility/1)
        :power -> build_lib(actors_regex, &DutyTypeDefnGovernment.power_conferred/1)
      end

    # Clean text and run patterns
    cleaned_text = blacklist(text)
    label = role |> Atom.to_string() |> String.upcase()

    case run_role_regex({cleaned_text, [], [], regexes}, regex_lib, label) do
      {_, [], _, regexes} ->
        {[], [], "", regexes}

      {_, role_holders, matches, regexes} ->
        {
          Enum.uniq(role_holders),
          role |> Atom.to_string() |> String.capitalize() |> List.wrap(),
          matches |> Enum.uniq() |> Enum.map(&String.trim/1) |> Enum.join("\n"),
          regexes
        }
    end
  end

  @doc """
  Extracts generic duty types from text (not actor-specific).

  Checks for structural patterns like amendments, definitions, scope, etc.
  """
  @spec duty_types_generic(text()) :: duty_types()
  def duty_types_generic(text) do
    {text, []}
    |> process_duty_types()
    |> elem(1)
    |> Enum.uniq()
  end

  @doc """
  Processes text against a list of duty type patterns.

  Returns `{remaining_text, list_of_duty_types}`.
  """
  @spec process({text(), list()}, list({String.t(), String.t()})) :: {text(), duty_types()}
  def process(collector, regexes) do
    Enum.reduce(regexes, collector, fn {regex, duty_type}, {text, duty_types} = acc ->
      case Regex.match?(~r/#{regex}/, text) do
        true ->
          duty_type = if is_binary(duty_type), do: [duty_type], else: duty_type
          # Remove matched text to avoid duplicate matches
          {Regex.replace(~r/#{regex}/m, text, ""), duty_types ++ duty_type}

        false ->
          acc
      end
    end)
  end

  @doc """
  Removes blacklisted patterns from text before processing.

  This prevents false positive matches on common phrases.
  """
  @spec blacklist(text()) :: text()
  def blacklist(text) do
    blacklist_regex()
    |> Enum.reduce(text, fn regex, acc ->
      Regex.replace(~r/#{regex}/, acc, " ")
    end)
  end

  @doc """
  Builds a library of actor-specific role patterns.

  ## Parameters

  - `actors_regex`: List of `{actor_name, regex_pattern}` tuples
  - `pattern_fn`: Function that generates role patterns for a regex
  """
  @spec build_lib(list(), function()) :: list({atom(), list()})
  def build_lib(actors_regex, pattern_fn) do
    actors_regex
    |> Enum.map(fn {actor, regex} -> {actor, pattern_fn.(regex)} end)
    |> List.flatten()
    |> Enum.reverse()
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  # Processes text through all generic duty type patterns
  defp process_duty_types(collector) do
    collector
    |> process(DutyTypeDefn.enaction_citation_commencement())
    |> process(DutyTypeDefn.extent())
    |> process(DutyTypeDefn.interpretation_definition())
    |> process(DutyTypeDefn.application_scope())
    |> process(DutyTypeDefn.exemption())
    |> process(DutyTypeDefn.repeal_revocation())
    |> process(DutyTypeDefn.transitional_arrangement())
    |> process(DutyTypeDefn.charge_fee())
    |> process(DutyTypeDefn.offence())
    |> process(DutyTypeDefn.enforcement_prosecution())
    |> process(DutyTypeDefn.defence_appeal())
    |> process(DutyTypeDefn.power_conferred())
  end

  # Runs role-specific regex patterns against text
  defp run_role_regex(collector, library, label) do
    Enum.reduce(library, collector, fn {actor, regexes}, acc ->
      Enum.reduce(regexes, acc, fn regex, {text, role_holders, matches, reg_exs} = acc2 ->
        {regex, rm_matched_text?} =
          case regex do
            {regex, true} -> {regex, true}
            _ -> {regex, false}
          end

        case Regex.compile(regex, "m") do
          {:ok, regex_c} ->
            case Regex.run(regex_c, text) do
              [match | _] ->
                text =
                  if rm_matched_text?,
                    do: Regex.replace(regex_c, text, ""),
                    else: text

                match = ensure_valid_utf8(match)
                actor_str = to_string(actor)

                {
                  text,
                  [actor_str | role_holders],
                  [~s/#{label}\n👤#{actor_str}\n📌#{match}\n/ | matches],
                  [~s/#{label}: #{actor_str}\n#{regex}\n-> #{match}\n/ | reg_exs]
                }

              nil ->
                acc2
            end

          {:error, {error, _pos}} ->
            IO.puts("ERROR: DutyTypeLib regex doesn't compile: #{error}\nPattern: #{regex}")
            acc2
        end
      end)
    end)
  end

  # Blacklist patterns that cause false positives
  defp blacklist_regex do
    modals = ~s/(?:shall|must|may[ ]only|may[ ]not)/

    [
      "[ ]area of the authority",
      # Other subjects directly adjacent to the modal verb
      "[ ]said report (?:shall|must)|shall[ ]not[ ]apply",
      "[ ]may[ ]be[ ](?:approved|reduced|reasonably foreseeably|required)",
      "[ ]may[ ]reasonably[ ]require",
      "[ ]as[ ]the[ ]case[ ]may[ ]be",
      "[ ]as may reasonably foreseeably",
      "[ ]and[ ]#{modals}"
    ]
  end

  # Ensures string is valid UTF-8
  defp ensure_valid_utf8(str) do
    if String.valid?(str), do: str, else: to_utf8(str)
  end

  # Converts binary to UTF-8 string
  defp to_utf8(binary) do
    binary
    |> :unicode.characters_to_binary(:latin1)
    |> case do
      {:error, _, _} -> binary
      {:incomplete, _, _} -> binary
      result -> result
    end
  end
end
