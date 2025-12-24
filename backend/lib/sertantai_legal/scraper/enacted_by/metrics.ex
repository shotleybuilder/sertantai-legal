defmodule SertantaiLegal.Scraper.EnactedBy.Metrics do
  @moduledoc """
  Metrics and logging for enacted_by pattern matching.

  Provides visibility into:
  - Which patterns matched for a given law
  - Which patterns are never matching (potential gaps)
  - Match rates for each pattern type

  ## Usage

  Use `find_enacting_laws_with_metrics/2` instead of `find_enacting_laws/2`
  to get detailed match information:

  ```elixir
  {law_ids, metrics} = Metrics.find_enacting_laws_with_metrics(text, urls)

  # metrics contains:
  # - matched_patterns: list of patterns that matched
  # - unmatched_pattern_types: list of pattern types that didn't match
  # - strategy_used: :specific_act, :powers_clause, or :fallback
  # - law_count: number of laws found
  ```

  ## Logging

  Enable debug logging to see pattern matches in real-time:

  ```elixir
  Logger.configure(level: :debug)
  ```
  """

  require Logger

  alias SertantaiLegal.Scraper.EnactedBy.PatternRegistry
  alias SertantaiLegal.Scraper.EnactedBy.Matcher
  alias SertantaiLegal.Scraper.EnactedBy.Matchers.{SpecificAct, PowersClause, FootnoteFallback}

  @type match_metrics :: %{
          matched_patterns: [map()],
          unmatched_pattern_types: [atom()],
          strategy_used: atom() | nil,
          law_ids: [String.t()],
          law_count: non_neg_integer(),
          text_length: non_neg_integer(),
          has_footnotes: boolean()
        }

  @type pattern_summary_result :: %{
          total_patterns: non_neg_integer(),
          by_type: %{
            specific_act: non_neg_integer(),
            powers_clause: non_neg_integer(),
            footnote_fallback: non_neg_integer()
          },
          patterns: [map()]
        }

  @doc """
  Find enacting laws with detailed metrics about pattern matching.

  Returns `{law_ids, metrics}` where metrics contains information about
  which patterns matched and which didn't.
  """
  @spec find_enacting_laws_with_metrics(String.t(), map()) :: {[String.t()], match_metrics()}
  def find_enacting_laws_with_metrics("", _urls) do
    {[], empty_metrics("")}
  end

  def find_enacting_laws_with_metrics(text, urls) do
    context = %{urls: urls}
    has_footnotes = map_size(urls) > 0

    # Run all pattern types and collect metrics
    {specific_laws, specific_meta} =
      run_with_logging(:specific_act, SpecificAct, text, context)

    {powers_laws, powers_meta} =
      run_with_logging(:powers_clause, PowersClause, text, context)

    # Only run fallback if nothing else matched
    {fallback_laws, fallback_meta, used_fallback} =
      if specific_laws == [] and powers_laws == [] do
        {laws, meta} = run_with_logging(:footnote_fallback, FootnoteFallback, text, context)
        {laws, meta, true}
      else
        {[], [], false}
      end

    # Combine results
    all_laws = (specific_laws ++ powers_laws ++ fallback_laws) |> Enum.uniq()
    all_meta = specific_meta ++ powers_meta ++ fallback_meta

    # Determine which strategy produced results
    strategy_used =
      cond do
        specific_laws != [] -> :specific_act
        powers_laws != [] -> :powers_clause
        fallback_laws != [] -> :footnote_fallback
        true -> nil
      end

    # Build metrics
    metrics = %{
      matched_patterns: all_meta,
      unmatched_pattern_types: get_unmatched_types(specific_meta, powers_meta, fallback_meta, used_fallback),
      strategy_used: strategy_used,
      law_ids: all_laws,
      law_count: length(all_laws),
      text_length: String.length(text),
      has_footnotes: has_footnotes
    }

    # Log summary
    log_match_summary(metrics)

    {all_laws, metrics}
  end

  @doc """
  Get a summary report of pattern coverage.

  Call this after processing multiple laws to see which patterns
  are matching and which might need attention.
  """
  @spec pattern_summary() :: pattern_summary_result()
  def pattern_summary do
    patterns = PatternRegistry.all()

    %{
      total_patterns: length(patterns),
      by_type: %{
        specific_act: length(PatternRegistry.by_type(:specific_act)),
        powers_clause: length(PatternRegistry.by_type(:powers_clause)),
        footnote_fallback: length(PatternRegistry.by_type(:footnote_fallback))
      },
      patterns:
        Enum.map(patterns, fn p ->
          %{
            id: p.id,
            name: p.name,
            type: p.type,
            priority: p.priority,
            enabled: p.enabled
          }
        end)
    }
  end

  @doc """
  Log a detailed breakdown of a match result.
  Useful for debugging why a particular law didn't match expected patterns.
  """
  @spec debug_match(String.t(), map()) :: :ok
  def debug_match(text, urls) do
    {laws, metrics} = find_enacting_laws_with_metrics(text, urls)

    IO.puts("\n=== EnactedBy Match Debug ===")
    IO.puts("Text length: #{metrics.text_length}")
    IO.puts("Has footnotes: #{metrics.has_footnotes}")
    IO.puts("Strategy used: #{metrics.strategy_used || "none"}")
    IO.puts("Laws found: #{inspect(laws)}")

    if metrics.matched_patterns != [] do
      IO.puts("\nMatched patterns:")

      Enum.each(metrics.matched_patterns, fn meta ->
        IO.puts("  - #{meta.pattern_name} (#{meta.pattern_id})")
      end)
    else
      IO.puts("\nNo patterns matched")
    end

    if metrics.unmatched_pattern_types != [] do
      IO.puts("\nUnmatched pattern types: #{inspect(metrics.unmatched_pattern_types)}")
    end

    # Show text preview
    preview = String.slice(text, 0, 200)
    IO.puts("\nText preview: #{preview}...")

    :ok
  end

  # Private functions

  defp run_with_logging(type, matcher_module, text, context) do
    patterns = PatternRegistry.by_type(type)
    {laws, meta} = Matcher.run_patterns(matcher_module, patterns, text, context)

    if laws != [] do
      Logger.debug(
        "[EnactedBy] #{type} matched: #{length(laws)} laws via #{length(meta)} patterns"
      )
    end

    {laws, meta}
  end

  defp get_unmatched_types(specific_meta, powers_meta, fallback_meta, used_fallback) do
    unmatched = []

    unmatched =
      if specific_meta == [] do
        [:specific_act | unmatched]
      else
        unmatched
      end

    unmatched =
      if powers_meta == [] do
        [:powers_clause | unmatched]
      else
        unmatched
      end

    unmatched =
      if used_fallback and fallback_meta == [] do
        [:footnote_fallback | unmatched]
      else
        unmatched
      end

    unmatched
  end

  defp empty_metrics(text) do
    %{
      matched_patterns: [],
      unmatched_pattern_types: [],
      strategy_used: nil,
      law_ids: [],
      law_count: 0,
      text_length: String.length(text),
      has_footnotes: false
    }
  end

  defp log_match_summary(metrics) do
    if metrics.law_count > 0 do
      Logger.debug(
        "[EnactedBy] Found #{metrics.law_count} laws via #{metrics.strategy_used} strategy"
      )
    else
      Logger.debug("[EnactedBy] No enacted_by laws found (text_length: #{metrics.text_length})")
    end
  end
end
