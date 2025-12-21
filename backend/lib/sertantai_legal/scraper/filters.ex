defmodule SertantaiLegal.Scraper.Filters do
  @moduledoc """
  Filters for categorizing and filtering UK legislation.

  Provides:
  - Title exclusions (railways, drought orders, etc.)
  - Terms-based filtering (matching titles to EHS categories)
  - SI code-based filtering

  Ported from Legl.Countries.Uk.LeglRegister.New.Filters
  """

  alias SertantaiLegal.Scraper.Terms.Environment
  alias SertantaiLegal.Scraper.Terms.HealthSafety
  alias SertantaiLegal.Scraper.Terms.SICodes

  @exclusions [
    ~r/railways?.*station.*order/,
    ~r/railways?.*junction.*order/,
    ~r/(network rail|railways?).*(extensions?|improvements?|preparation|enhancement|reduction).*order/,
    ~r/rail freight.*order/,
    ~r/light railway order/,
    ~r/drought.*order/,
    ~r/restriction of flying/,
    ~r/correction slip/,
    ~r/trunk road/,
    ~r/harbour empowerment order/,
    ~r/harbour revision order/,
    ~r/parking places/,
    ~r/parking prohibition/,
    ~r/parking and waiting/,
    ~r/development consent order/,
    ~r/electrical system order/
  ]

  @doc """
  Filter records by title exclusions.

  Excludes laws that match certain patterns (railway orders, parking, etc.)
  that are typically not relevant for EHS compliance.

  ## Returns
  `{included_records, excluded_records}`
  """
  @spec title_filter(list(map())) :: {list(map()), list(map())}
  def title_filter(records) when is_list(records) do
    IO.puts("PRE-TITLE FILTER RECORD COUNT: #{Enum.count(records)}")

    {inc, exc} =
      Enum.reduce(records, {[], []}, fn record, {inc, exc} ->
        title = String.downcase(record[:Title_EN] || record["Title_EN"] || "")

        case exclude?(title) do
          false -> {[record | inc], exc}
          true -> {inc, [record | exc]}
        end
      end)

    IO.puts("POST-TITLE FILTER")
    IO.puts("# INCLUDED RECORDS: #{Enum.count(inc)}")
    IO.puts("# EXCLUDED RECORDS: #{Enum.count(exc)}")

    {Enum.reverse(inc), Enum.reverse(exc)}
  end

  defp exclude?(title) do
    Enum.reduce_while(@exclusions, false, fn pattern, _acc ->
      case Regex.match?(pattern, title) do
        true -> {:halt, true}
        false -> {:cont, false}
      end
    end)
  end

  @doc """
  Filter records by search terms in title.

  Matches law titles against EHS search terms and assigns a Family.

  ## Parameters
  - `{included, excluded}` - Tuple of included and excluded record lists

  ## Returns
  `{:ok, {included_with_family, excluded}}`
  """
  @spec terms_filter({list(map()), list(map())}) :: {:ok, {list(map()), list(map())}}
  def terms_filter({inc, exc}) do
    IO.puts("Terms inside Title Filter")
    IO.puts("# PRE_FILTERED RECORDS: inc:#{Enum.count(inc)} exc:#{Enum.count(exc)}")

    search_terms = HealthSafety.search_terms() ++ Environment.search_terms()

    {new_inc, new_exc} =
      Enum.reduce(inc, {[], exc}, fn law, {inc_acc, exc_acc} ->
        title = String.downcase(law[:Title_EN] || law["Title_EN"] || "")

        match_result =
          Enum.reduce_while(search_terms, false, fn {family, terms}, _acc ->
            case term_match?(title, terms) do
              true -> {:halt, {true, family}}
              false -> {:cont, false}
            end
          end)

        case match_result do
          {true, family} ->
            updated_law = Map.put(law, :Family, Atom.to_string(family))
            {[updated_law | inc_acc], exc_acc}

          false ->
            {inc_acc, [law | exc_acc]}
        end
      end)

    IO.puts("# INCLUDED RECORDS: #{Enum.count(new_inc)}")
    IO.puts("# EXCLUDED RECORDS: #{Enum.count(new_exc)}")

    {:ok, {Enum.reverse(new_inc), Enum.reverse(new_exc)}}
  end

  defp term_match?(title, terms) do
    Enum.any?(terms, fn term ->
      String.contains?(title, term)
    end)
  end

  @doc """
  Filter records by SI code.

  Checks if the law's SI code matches the EHS SI code set.

  ## Returns
  `{:ok, {with_matching_si_code, without_matching_si_code}}`
  """
  @spec si_code_filter(list(map())) :: {:ok, {list(map()), list(map())}}
  def si_code_filter(records) when is_list(records) do
    result =
      Enum.reduce(records, {[], []}, fn record, {inc, exc} ->
        si_code = record[:si_code] || record["si_code"]

        case si_code do
          nil ->
            {inc, [record | exc]}

          "" ->
            {inc, [record | exc]}

          [] ->
            {inc, [record | exc]}

          code when is_binary(code) ->
            si_codes = String.split(code, ",")

            case si_code_member?(si_codes) do
              true ->
                record = Map.put(record, :Family, si_code_family(si_codes))
                {[record | inc], exc}

              false ->
                {inc, [record | exc]}
            end

          codes when is_list(codes) ->
            case si_code_member?(codes) do
              true ->
                record = Map.put(record, :Family, si_code_family(codes))
                {[record | inc], exc}

              false ->
                {inc, [record | exc]}
            end
        end
      end)

    {:ok, result}
  end

  @spec si_code_filter({list(map()), list(map())}) :: {:ok, {list(map()), list(map())}}
  def si_code_filter({inc_w_si, inc_wo_si}) do
    result =
      Enum.reduce(inc_w_si, {[], inc_wo_si}, fn law, {inc, exc} ->
        si_codes =
          case law[:si_code] || law["si_code"] do
            code when is_binary(code) -> String.split(code, ",")
            codes when is_list(codes) -> codes
            _ -> []
          end

        case si_code_member?(si_codes) do
          true ->
            law = Map.put(law, :Family, si_code_family(si_codes))
            {[law | inc], exc}

          false ->
            {inc, [law | exc]}
        end
      end)

    {:ok, result}
  end

  defp si_code_member?(si_code) when is_binary(si_code) do
    SICodes.member?(si_code)
  end

  defp si_code_member?(si_codes) when is_list(si_codes) do
    Enum.reduce_while(si_codes, false, fn si_code, _acc ->
      case si_code_member?(si_code) do
        true -> {:halt, true}
        _ -> {:cont, false}
      end
    end)
  end

  defp si_code_family(si_codes) when is_list(si_codes) do
    si_codes
    |> Enum.map(&si_code_family/1)
    |> Enum.uniq()
    |> Enum.filter(&(&1 != nil))
    |> List.first()
  end

  defp si_code_family(si_code) when is_binary(si_code) do
    # Could be expanded to map SI codes to specific families
    # For now, return nil as the legl code doesn't populate this
    cond do
      MapSet.member?(SICodes.hs_si_codes(), si_code) -> "Health & Safety"
      MapSet.member?(SICodes.e_si_codes(), si_code) -> "Environment"
      true -> nil
    end
  end

  @doc """
  Get all search terms combined from Health & Safety and Environment.
  """
  @spec all_search_terms() :: keyword(list(String.t()))
  def all_search_terms do
    HealthSafety.search_terms() ++ Environment.search_terms()
  end
end
