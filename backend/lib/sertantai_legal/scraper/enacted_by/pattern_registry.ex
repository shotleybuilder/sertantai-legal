defmodule SertantaiLegal.Scraper.EnactedBy.PatternRegistry do
  @moduledoc """
  Registry of patterns for identifying enacted_by relationships.

  Patterns are defined as data, making them easy to:
  - Add new patterns without changing matcher logic
  - Test individually
  - Track match rates
  - Document coverage

  ## Pattern Types

  - `:specific_act` - Matches specific Act name → returns fixed law ID
  - `:powers_clause` - Matches "powers conferred by" etc. with footnote capture
  - `:footnote_fallback` - Extracts all footnotes as last resort

  ## Pattern Structure

  Each pattern is a map with:
  - `id` - Unique identifier (atom)
  - `name` - Human-readable name
  - `type` - Pattern type (see above)
  - `priority` - Higher = matched first (100 = high, 50 = medium, 10 = low)
  - `pattern` - Regex or other matcher input
  - `output` - For specific_act: the law ID to return
  - `enabled` - Whether pattern is active (default true)
  """

  alias SertantaiLegal.Scraper.IdField

  @doc """
  Returns all enabled patterns, sorted by priority (highest first).
  """
  @spec all() :: [map()]
  def all do
    patterns()
    |> Enum.filter(& &1.enabled)
    |> Enum.sort_by(& &1.priority, :desc)
  end

  @doc """
  Returns patterns of a specific type.
  """
  @spec by_type(atom()) :: [map()]
  def by_type(type) do
    all()
    |> Enum.filter(&(&1.type == type))
  end

  @doc """
  Returns a specific pattern by ID.
  """
  @spec get(atom()) :: map() | nil
  def get(id) do
    Enum.find(patterns(), &(&1.id == id))
  end

  @doc """
  List all pattern IDs.
  """
  @spec list_ids() :: [atom()]
  def list_ids do
    Enum.map(patterns(), & &1.id)
  end

  # ===========================================================================
  # Pattern Definitions
  # ===========================================================================

  defp patterns do
    specific_act_patterns() ++ powers_clause_patterns() ++ fallback_patterns()
  end

  # ---------------------------------------------------------------------------
  # Specific Act Patterns (Type: :specific_act)
  # These match known Act names and return a fixed law ID
  # Priority: 100 (matched first)
  # ---------------------------------------------------------------------------

  defp specific_act_patterns do
    [
      %{
        id: :hswa_1974,
        name: "Health and Safety at Work etc. Act 1974",
        type: :specific_act,
        priority: 100,
        pattern: ~r/Health and Safety at Work etc\.? Act 1974/i,
        output: IdField.build_name("ukpga", "1974", "37"),
        enabled: true,
        notes: "Primary H&S enabling Act - very common"
      },
      %{
        id: :planning_act_2008,
        name: "Planning Act 2008",
        type: :specific_act,
        priority: 100,
        pattern: ~r/Planning Act 2008/i,
        output: IdField.build_name("ukpga", "2008", "29"),
        enabled: true,
        notes: "Enables DCO orders"
      },
      %{
        id: :planning_act_2008_sections,
        name: "Planning Act 2008 (section refs)",
        type: :specific_act,
        priority: 100,
        pattern: ~r/section 114.*?and 120.*?of the 2008 Act/i,
        output: IdField.build_name("ukpga", "2008", "29"),
        enabled: true,
        notes: "Alternative reference pattern for Planning Act"
      },
      %{
        id: :eu_withdrawal_2018,
        name: "European Union (Withdrawal) Act 2018",
        type: :specific_act,
        priority: 100,
        pattern: ~r/powers.*?European Union \(Withdrawal\) Act 2018/i,
        output: IdField.build_name("ukpga", "2018", "16"),
        enabled: true,
        notes: "Brexit-related SIs"
      },
      %{
        id: :transport_works_1992,
        name: "Transport and Works Act 1992",
        type: :specific_act,
        priority: 100,
        pattern: ~r/under sections?.*? of the Transport and Works Act 1992/i,
        output: IdField.build_name("ukpga", "1992", "42"),
        enabled: true,
        notes: "TWA orders for railways, tramways etc."
      },
      %{
        id: :building_act_1984,
        name: "Building Act 1984",
        type: :specific_act,
        priority: 100,
        pattern: ~r/(?:of|under) the Building Act 1984/i,
        output: IdField.build_name("ukpga", "1984", "55"),
        enabled: true,
        notes: "Building regulations, safety levy etc."
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # Powers Clause Patterns (Type: :powers_clause)
  # These match "powers conferred by" style text and capture footnote refs
  # Priority: 50 (matched after specific acts)
  # ---------------------------------------------------------------------------

  defp powers_clause_patterns do
    [
      %{
        id: :powers_conferred_by,
        name: "Powers conferred by (with footnote)",
        type: :powers_clause,
        priority: 50,
        pattern: ~r/powers? conferred.*?by.*?(f\d{5})/,
        enabled: true,
        notes: "Most common phrasing"
      },
      %{
        id: :powers_under,
        name: "Powers under (with footnote)",
        type: :powers_clause,
        priority: 50,
        pattern: ~r/powers under.*?(f\d{5})/,
        enabled: true,
        notes: "Alternative phrasing"
      },
      %{
        id: :in_exercise_of_powers,
        name: "In exercise of the powers (with footnote)",
        type: :powers_clause,
        priority: 50,
        pattern: ~r/in exercise of the powers.*?(f\d{5})/,
        enabled: true,
        notes: "Formal phrasing"
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # Fallback Patterns (Type: :footnote_fallback)
  # Last resort - extract all footnotes and filter by year mentions
  # Priority: 10 (matched last)
  # ---------------------------------------------------------------------------

  defp fallback_patterns do
    [
      %{
        id: :all_footnotes,
        name: "All footnotes with year filter",
        type: :footnote_fallback,
        priority: 10,
        pattern: ~r/f\d{5}/,
        enabled: true,
        notes: "Fallback: extract all footnote refs, filter by years in text"
      }
    ]
  end
end
