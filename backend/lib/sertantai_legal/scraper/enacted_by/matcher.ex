defmodule SertantaiLegal.Scraper.EnactedBy.Matcher do
  @moduledoc """
  Behaviour for enacted_by pattern matchers.

  Each pattern type has a corresponding matcher module that implements
  this behaviour. Matchers are responsible for:
  - Checking if a pattern matches the input text
  - Extracting law IDs when a match is found

  ## Implementing a Matcher

  ```elixir
  defmodule MyMatcher do
    @behaviour SertantaiLegal.Scraper.EnactedBy.Matcher

    @impl true
    def match(pattern, text, context) do
      # Return {:match, [law_ids]} or :no_match
    end
  end
  ```

  ## Context

  The context map contains additional data needed for matching:
  - `:urls` - Map of footnote ID to URL list (for footnote-based matchers)
  - `:years` - List of years mentioned in text (for filtering)
  """

  @type pattern :: map()
  @type context :: %{
          optional(:urls) => %{String.t() => [String.t()]},
          optional(:years) => [String.t()]
        }
  @type match_result :: {:match, [String.t()], map()} | :no_match

  @doc """
  Attempt to match a pattern against the input text.

  ## Parameters
  - `pattern` - Pattern definition from PatternRegistry
  - `text` - The text to match against
  - `context` - Additional context (urls, years, etc.)

  ## Returns
  - `{:match, law_ids, metadata}` - Pattern matched, returns list of law IDs and metadata
  - `:no_match` - Pattern did not match
  """
  @callback match(pattern(), String.t(), context()) :: match_result()

  @doc """
  Returns the pattern type this matcher handles.
  """
  @callback pattern_type() :: atom()

  @doc """
  Run all patterns of a given type against the text.

  Returns all matched law IDs with metadata about which patterns matched.
  """
  @spec run_patterns(module(), [pattern()], String.t(), context()) ::
          {[String.t()], [map()]}
  def run_patterns(matcher_module, patterns, text, context) do
    results =
      Enum.reduce(patterns, {[], []}, fn pattern, {laws_acc, meta_acc} ->
        case matcher_module.match(pattern, text, context) do
          {:match, law_ids, metadata} ->
            meta = Map.merge(metadata, %{pattern_id: pattern.id, pattern_name: pattern.name})
            {laws_acc ++ law_ids, [meta | meta_acc]}

          :no_match ->
            {laws_acc, meta_acc}
        end
      end)

    {elem(results, 0) |> Enum.uniq(), elem(results, 1)}
  end
end
