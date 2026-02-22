defmodule SertantaiLegal.Legal.Taxa.TaxaFormatter do
  @moduledoc """
  Serializes TaxaParser results into various output formats.

  This module decouples parsing logic from output format concerns, allowing
  TaxaParser to produce both legacy text format and new JSONB format without
  modifying the complex DutyTypeLib parsing logic.

  ## Phase 2a Strategy

  Parse the existing text output (with emojis and newlines) into structured
  JSONB format. This approach:
  - Zero changes to DutyTypeLib (complex, optimized)
  - Easy to validate against Phase 1 migrated data
  - Full rollback capability if issues arise

  ## JSONB Schema

  ```json
  {
    "entries": [
      {"holder": "Ind: Person", "article": "regulation/4", "duty_type": "DUTY", "clause": "..."}
    ],
    "holders": ["Ind: Person"],
    "articles": ["regulation/4"]
  }
  ```
  """

  @doc """
  Convert legacy text format to JSONB structure.

  Parses the emoji-formatted text output from DutyTypeLib into structured JSONB.

  ## Parameters
  - `text` - The legacy text format (e.g., duty_holder_article_clause)
  - `default_type` - Default duty type if not specified in text (e.g., "DUTY")

  ## Returns
  Map with `entries`, `holders`, and `articles` keys, or nil if text is empty.
  """
  @spec text_to_jsonb(String.t() | nil, String.t()) :: map() | nil
  def text_to_jsonb(nil, _default_type), do: nil
  def text_to_jsonb("", _default_type), do: nil
  def text_to_jsonb("{}", _default_type), do: nil

  def text_to_jsonb(text, default_type) when is_binary(text) do
    text = String.trim(text)
    if text == "", do: nil, else: parse_text_to_jsonb(text, default_type)
  end

  @doc """
  Convert duties text to JSONB (convenience wrapper).
  """
  @spec duties_to_jsonb(String.t() | nil) :: map() | nil
  def duties_to_jsonb(text), do: text_to_jsonb(text, "DUTY")

  @doc """
  Convert rights text to JSONB (convenience wrapper).
  """
  @spec rights_to_jsonb(String.t() | nil) :: map() | nil
  def rights_to_jsonb(text), do: text_to_jsonb(text, "RIGHT")

  @doc """
  Convert responsibilities text to JSONB (convenience wrapper).
  """
  @spec responsibilities_to_jsonb(String.t() | nil) :: map() | nil
  def responsibilities_to_jsonb(text), do: text_to_jsonb(text, "RESPONSIBILITY")

  @doc """
  Convert powers text to JSONB (convenience wrapper).
  """
  @spec powers_to_jsonb(String.t() | nil) :: map() | nil
  def powers_to_jsonb(text), do: text_to_jsonb(text, "POWER")

  # ============================================================================
  # Phase 2b: Direct structured match conversion (no text parsing)
  # ============================================================================

  @doc """
  Convert structured match data directly to JSONB format.

  This is the Phase 2b approach - DutyTypeLib now returns structured maps
  instead of emoji-formatted text, so we can convert directly without parsing.

  ## Parameters
  - `matches` - List of match maps with :holder, :duty_type, :clause keys
  - `opts` - Optional keyword list with :article key for article context

  ## Returns
  Map with `entries`, `holders`, and `articles` keys, or nil if empty.
  """
  @spec matches_to_jsonb(list(map()) | nil, keyword()) :: map() | nil
  def matches_to_jsonb(matches, opts \\ [])
  def matches_to_jsonb(nil, _opts), do: nil
  def matches_to_jsonb([], _opts), do: nil

  def matches_to_jsonb(matches, opts) when is_list(matches) do
    article = Keyword.get(opts, :article)

    entries =
      Enum.map(matches, fn match ->
        entry = %{
          "holder" => match[:holder] || match["holder"],
          "duty_type" => match[:duty_type] || match["duty_type"],
          "clause" => match[:clause] || match["clause"],
          "article" => article
        }

        confidence = match[:regex_clause_confidence] || match["regex_clause_confidence"]

        # Add article bonus to confidence if article context is available
        confidence =
          if confidence && article do
            Float.round(min(confidence + 0.15, 1.0), 2)
          else
            confidence
          end

        entry
        |> then(fn e ->
          if confidence, do: Map.put(e, "regex_clause_confidence", confidence), else: e
        end)
      end)

    if entries == [] do
      nil
    else
      holders = entries |> Enum.map(& &1["holder"]) |> Enum.uniq() |> Enum.sort()
      articles = if article, do: [article], else: []

      %{
        "entries" => entries,
        "holders" => holders,
        "articles" => articles
      }
    end
  end

  @doc """
  Convert duty matches to JSONB (Phase 2b convenience wrapper).
  """
  @spec duties_from_matches(list(map()) | nil, keyword()) :: map() | nil
  def duties_from_matches(matches, opts \\ []), do: matches_to_jsonb(matches, opts)

  @doc """
  Convert rights matches to JSONB (Phase 2b convenience wrapper).
  """
  @spec rights_from_matches(list(map()) | nil, keyword()) :: map() | nil
  def rights_from_matches(matches, opts \\ []), do: matches_to_jsonb(matches, opts)

  @doc """
  Convert responsibility matches to JSONB (Phase 2b convenience wrapper).
  """
  @spec responsibilities_from_matches(list(map()) | nil, keyword()) :: map() | nil
  def responsibilities_from_matches(matches, opts \\ []), do: matches_to_jsonb(matches, opts)

  @doc """
  Convert power matches to JSONB (Phase 2b convenience wrapper).
  """
  @spec powers_from_matches(list(map()) | nil, keyword()) :: map() | nil
  def powers_from_matches(matches, opts \\ []), do: matches_to_jsonb(matches, opts)

  # ============================================================================
  # Phase 2 Issue #15: POPIMAR JSONB conversion
  # ============================================================================

  @doc """
  Convert POPIMAR matches to JSONB format.

  Takes the list of POPIMAR categories and article context, producing
  a structured JSONB with entries, categories, and articles.

  ## Parameters
  - `categories` - List of POPIMAR category strings (e.g., ["Records", "Risk Control"])
  - `opts` - Optional keyword list with :article key for article context

  ## Returns
  Map with `entries`, `categories`, and `articles` keys, or nil if empty.

  ## Example

      iex> popimar_to_jsonb(["Records", "Risk Control"], article: "regulation/4")
      %{
        "entries" => [
          %{"category" => "Records", "article" => "regulation/4"},
          %{"category" => "Risk Control", "article" => "regulation/4"}
        ],
        "categories" => ["Records", "Risk Control"],
        "articles" => ["regulation/4"]
      }
  """
  @spec popimar_to_jsonb(list(String.t()) | nil, keyword()) :: map() | nil
  def popimar_to_jsonb(nil, _opts), do: nil
  def popimar_to_jsonb([], _opts), do: nil

  def popimar_to_jsonb(categories, opts) when is_list(categories) do
    article = Keyword.get(opts, :article)

    entries =
      Enum.map(categories, fn category ->
        %{
          "category" => category,
          "article" => article
        }
      end)

    if entries == [] do
      nil
    else
      unique_categories = categories |> Enum.uniq() |> Enum.sort()
      articles = if article, do: [article], else: []

      %{
        "entries" => entries,
        "categories" => unique_categories,
        "articles" => articles
      }
    end
  end

  @doc """
  Merge multiple POPIMAR JSONB results into one.

  Used when combining results from chunked processing where each section
  may have different POPIMAR categories.

  ## Parameters
  - `results` - List of POPIMAR JSONB maps to merge

  ## Returns
  Merged map with deduplicated entries, categories, and articles.
  """
  @spec merge_popimar_jsonb(list(map() | nil)) :: map() | nil
  def merge_popimar_jsonb(results) do
    results = Enum.reject(results, &is_nil/1)

    if results == [] do
      nil
    else
      all_entries = Enum.flat_map(results, & &1["entries"])
      # Deduplicate by category+article combination
      unique_entries = Enum.uniq_by(all_entries, fn e -> {e["category"], e["article"]} end)

      categories = unique_entries |> Enum.map(& &1["category"]) |> Enum.uniq() |> Enum.sort()

      articles =
        unique_entries
        |> Enum.map(& &1["article"])
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.sort()

      %{
        "entries" => unique_entries,
        "categories" => categories,
        "articles" => articles
      }
    end
  end

  # ============================================================================
  # Phase 2 Issue #16: Role JSONB conversion
  # ============================================================================

  @doc """
  Convert role list to JSONB format with article context.

  Takes a list of role strings and optional article context, producing
  a structured JSONB with entries, roles, and articles.

  ## Parameters
  - `roles` - List of role strings (e.g., ["Ind: Person", "Org: Employer"])
  - `opts` - Optional keyword list with :article key for article context

  ## Returns
  Map with `entries`, `roles`, and `articles` keys, or nil if empty.

  ## Example

      iex> roles_to_jsonb(["Ind: Person", "Org: Employer"], article: "regulation/4")
      %{
        "entries" => [
          %{"role" => "Ind: Person", "article" => "regulation/4"},
          %{"role" => "Org: Employer", "article" => "regulation/4"}
        ],
        "roles" => ["Ind: Person", "Org: Employer"],
        "articles" => ["regulation/4"]
      }
  """
  @spec roles_to_jsonb(list(String.t()) | nil, keyword()) :: map() | nil
  def roles_to_jsonb(nil, _opts), do: nil
  def roles_to_jsonb([], _opts), do: nil

  def roles_to_jsonb(roles, opts) when is_list(roles) do
    article = Keyword.get(opts, :article)

    entries =
      Enum.map(roles, fn role ->
        %{
          "role" => role,
          "article" => article
        }
      end)

    if entries == [] do
      nil
    else
      unique_roles = roles |> Enum.uniq() |> Enum.sort()
      articles = if article, do: [article], else: []

      %{
        "entries" => entries,
        "roles" => unique_roles,
        "articles" => articles
      }
    end
  end

  @doc """
  Merge multiple role JSONB results into one.

  Used when combining results from chunked processing where each section
  may have different roles.

  ## Parameters
  - `results` - List of role JSONB maps to merge

  ## Returns
  Merged map with deduplicated entries, roles, and articles.
  """
  @spec merge_roles_jsonb(list(map() | nil)) :: map() | nil
  def merge_roles_jsonb(results) do
    results = Enum.reject(results, &is_nil/1)

    if results == [] do
      nil
    else
      all_entries = Enum.flat_map(results, & &1["entries"])
      # Deduplicate by role+article combination
      unique_entries = Enum.uniq_by(all_entries, fn e -> {e["role"], e["article"]} end)

      roles = unique_entries |> Enum.map(& &1["role"]) |> Enum.uniq() |> Enum.sort()

      articles =
        unique_entries
        |> Enum.map(& &1["article"])
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.sort()

      %{
        "entries" => unique_entries,
        "roles" => roles,
        "articles" => articles
      }
    end
  end

  # ============================================================================
  # Private Functions (Phase 2a legacy text parsing)
  # ============================================================================

  defp parse_text_to_jsonb(text, default_type) do
    # Split into holder blocks (separated by [Holder Name] headers)
    blocks = split_into_holder_blocks(text)

    entries =
      blocks
      |> Enum.flat_map(fn {holder, block_text} ->
        parse_holder_block(holder, block_text, default_type)
      end)

    if entries == [] do
      nil
    else
      holders = entries |> Enum.map(& &1["holder"]) |> Enum.uniq() |> Enum.sort()
      articles = entries |> Enum.map(& &1["article"]) |> Enum.uniq() |> Enum.sort()

      %{
        "entries" => entries,
        "holders" => holders,
        "articles" => articles
      }
    end
  end

  # Split text into blocks by [Holder Name] headers
  defp split_into_holder_blocks(text) do
    # Match [Category: Name] or [Name] at start of line
    regex = ~r/^\[([^\]]+)\]\s*$/m

    parts = Regex.split(regex, text, include_captures: true, trim: true)

    # Pair headers with their content
    parts
    |> Enum.chunk_every(2)
    |> Enum.filter(fn chunk -> length(chunk) == 2 end)
    |> Enum.map(fn [header, content] ->
      # Extract holder name from [Name] format
      holder = header |> String.trim() |> String.replace(~r/^\[|\]$/, "")
      {holder, content}
    end)
  end

  # Parse a single holder's block into entries
  defp parse_holder_block(holder, block_text, default_type) do
    lines = String.split(block_text, "\n") |> Enum.map(&String.trim/1)

    # State machine to parse entries
    parse_lines(lines, holder, default_type, nil, nil, [])
  end

  # Recursive line parser
  # State: current_article, current_duty_type, accumulated entries
  defp parse_lines([], _holder, _default_type, _article, _duty_type, entries) do
    Enum.reverse(entries)
  end

  defp parse_lines([line | rest], holder, default_type, article, duty_type, entries) do
    cond do
      # URL line - extract article path
      String.starts_with?(line, "https://legislation.gov.uk/") ->
        new_article = extract_article_path(line)
        parse_lines(rest, holder, default_type, new_article, duty_type, entries)

      # Duty type line (DUTY, RIGHT, POWER, RESPONSIBILITY)
      line in ["DUTY", "RIGHT", "POWER", "RESPONSIBILITY"] ->
        parse_lines(rest, holder, default_type, article, line, entries)

      # Holder line with emoji - confirms holder (skip, we already have it)
      String.starts_with?(line, "👤") ->
        parse_lines(rest, holder, default_type, article, duty_type, entries)

      # Clause line with emoji - create entry
      String.starts_with?(line, "📌") ->
        clause_text = String.replace_prefix(line, "📌", "") |> String.trim()

        entry = %{
          "holder" => holder,
          "article" => article,
          "duty_type" => duty_type || default_type,
          "clause" => if(clause_text == "", do: nil, else: clause_text)
        }

        # Only add entry if we have an article
        new_entries = if article, do: [entry | entries], else: entries
        parse_lines(rest, holder, default_type, article, nil, new_entries)

      # Empty line or other - skip
      true ->
        parse_lines(rest, holder, default_type, article, duty_type, entries)
    end
  end

  # Extract article path from full URL
  # Input: https://legislation.gov.uk/uksi/2005/621/regulation/4
  # Output: regulation/4
  defp extract_article_path(url) do
    case Regex.run(~r{legislation\.gov\.uk/[^/]+/\d+/\d+/(.+)$}, url) do
      [_, path] -> path
      _ -> url |> String.replace(~r{^https?://[^/]+/[^/]+/\d+/\d+/?}, "")
    end
  end
end
