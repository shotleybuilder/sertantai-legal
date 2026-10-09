defmodule SertantaiLegal.Scraper.Territory do
  @moduledoc """
  UK territories in LAT extent codes ("E+W+S+NI", as `extent_code`) — for
  retained repeals (LAT parser coverage II): text repealed in some
  territories but kept for the others.

  Pure: `from_note/1` reads the territory a commentary note's change applies
  to ("Regulations revoked (S.) (1.11.2025) by …" → "S"); `covers?/2`,
  `subtract/2` and `union/1` work on codes. A nil row extent is the UK.
  """

  @order ~w(E W S NI)

  # "(S.)", "(E.W.)", "(E. and W.)", "(N.I.)", "(in relation to W.)"
  # "(1.4.2015 for S. for the repeal of …)", "(… in relation to E.W.)"
  @inline_territory ~r/\((?:[^()]*?\s)?(?:for|in relation to) ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)(?=[\s,)])/
  @note_territory ~r/\((?:in relation to )?((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)\)/

  @doc "The territory of a note's change, from the first territory parenthesis before \" by \"."
  @spec from_note(String.t() | nil) :: String.t() | nil
  def from_note(nil), do: nil

  def from_note(text), do: text |> note_territories() |> union_present()

  @doc """
  The territory of each of a note's changes (one per " by " clause), those
  naming one; [] when the first is "except in relation to …" ("(1.10.2023
  except in relation to W., 6.4.2024 for W.)": every territory, on
  different dates).
  """
  @spec note_territories(String.t() | nil) :: [String.t()]
  def note_territories(nil), do: []

  def note_territories(text) do
    [head | _] = all = clauses(text)

    if String.contains?(head, "except in relation to"),
      do: [],
      else: all |> Enum.map(&clause_territory/1) |> Enum.reject(&is_nil/1)
  end

  # The text before each " by ": the first whole, later ones from their last
  # "; " / " and " (so a citation's trailing "(S.)" never counts).
  defp clauses(text) do
    case String.split(text, " by ") do
      [_only] ->
        [text]

      parts ->
        [first | rest] = Enum.drop(parts, -1)
        [first | Enum.map(rest, &(&1 |> String.split(~r/; | and /) |> List.last()))]
    end
  end

  # A clause's territory: "(S.)" / "(… for E.W.)" letters, else a named
  # territory after a change verb ("disapplied in relation to Wales").
  defp clause_territory(clause),
    do: clause |> territory_letters() |> letters_to_code() || named_territory(clause)

  @names %{"England" => "E", "Wales" => "W", "Scotland" => "S", "Northern Ireland" => "NI"}
  @name ~S"(?:England|Wales|Scotland|Northern Ireland)"
  # only straight after the change: "Functions in relation to Wales" or a
  # title's "(… in relation to Wales) Order" are not territories
  @named_territory ~r/\b(?:disapplied|repealed|revoked|omitted|substituted|inserted|amended) in relation to (#{@name}(?:(?:, | and )#{@name})*)/

  defp named_territory(clause) do
    case Regex.run(@named_territory, clause) do
      [_, names] ->
        ~r/England|Wales|Scotland|Northern Ireland/
        |> Regex.scan(names)
        |> List.flatten()
        |> Enum.map(&Map.fetch!(@names, &1))
        |> union()

      nil ->
        nil
    end
  end

  defp union_present(codes) do
    case Enum.reject(codes, &is_nil/1) do
      [] -> nil
      present -> union(present)
    end
  end

  # every "(X.)" before the " by " ("inserted (E.) (11.7.2001) and (W.)
  # (1.4.2002) by …"), else the "for X." in the dates bracket
  defp territory_letters(head) do
    case Regex.scan(@note_territory, head, capture: :all_but_first) do
      [] -> inline_letters(head)
      found -> found |> List.flatten() |> Enum.join(" ")
    end
  end

  @inline_each ~r/(?:\bfor|in relation to) ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)(?=[\s,);]|$)/

  # Every "for X." in the first parenthesis naming one: a change in force on
  # different dates per territory, "(1.10.2017 for E., 1.4.2019 for W.)".
  defp inline_letters(head) do
    case Regex.run(@inline_territory, head, return: :index) do
      nil ->
        nil

      [{start, _} | _] ->
        group = head |> binary_part(start, byte_size(head) - start) |> bracket_group()

        # a dated part naming no territory ("6.8.2004 for specified purposes",
        # "1.10.2008 otherwise") is everywhere: the note restricts nothing
        if Enum.any?(dated_parts(group), &(not Regex.match?(@inline_each, &1))),
          do: nil,
          else:
            @inline_each
            |> Regex.scan(group, capture: :all_but_first)
            |> List.flatten()
            |> Enum.join(" ")
    end
  end

  # "(… s. 51B(6) …)" → the text up to the bracket's own closing ")"
  defp bracket_group("(" <> rest), do: bracket_group(rest, 0, [])

  defp bracket_group("", _depth, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()
  defp bracket_group(")" <> _rest, 0, acc), do: bracket_group("", 0, acc)
  defp bracket_group(")" <> rest, depth, acc), do: bracket_group(rest, depth - 1, [")" | acc])
  defp bracket_group("(" <> rest, depth, acc), do: bracket_group(rest, depth + 1, ["(" | acc])

  defp bracket_group(<<c::utf8, rest::binary>>, depth, acc),
    do: bracket_group(rest, depth, [<<c::utf8>> | acc])

  @date ~r/\b\d{1,2}\.\d{1,2}\.\d{4}\b/

  # "(1.10.2017 for E., 1.4.2019 for W.)" → each part from one date to the next
  defp dated_parts(group) do
    offsets = @date |> Regex.scan(group, return: :index) |> Enum.map(fn [{pos, _}] -> pos end)

    offsets
    |> Enum.zip(Enum.drop(offsets, 1) ++ [byte_size(group)])
    |> Enum.map(fn {from, to} -> binary_part(group, from, to - from) end)
  end

  defp letters_to_code(nil), do: nil

  defp letters_to_code(letters) do
    ~r/N\.I|[EWS]/
    |> Regex.scan(letters)
    |> List.flatten()
    |> Enum.map(&String.replace(&1, "N.I", "NI"))
    |> union()
  end

  @doc """
  An extent attribute as a code: "E+W", "E.W.", "E.W.S.", "N.I." → "E+W",
  "E+W", "E+W+S", "NI"; nil for blank.
  """
  @spec normalize(String.t() | nil) :: String.t() | nil
  def normalize(nil), do: nil

  def normalize(code),
    do:
      code
      |> String.replace("N.I", "NI")
      |> then(&Regex.scan(~r/NI|[EWS]/, &1))
      |> List.flatten()
      |> union()

  @doc "True when `repealed` includes every territory of `row_extent` (nil = UK)."
  @spec covers?(String.t(), String.t() | nil) :: boolean()
  def covers?(repealed, row_extent),
    do: MapSet.subset?(set(row_extent), set(repealed))

  @doc "The territories of `row_extent` (nil = UK) outside `repealed`; nil when none."
  @spec subtract(String.t() | nil, String.t()) :: String.t() | nil
  def subtract(row_extent, repealed),
    do: row_extent |> set() |> MapSet.difference(set(repealed)) |> format()

  @doc "True when the two codes share no territory."
  @spec disjoint?(String.t(), String.t()) :: boolean()
  def disjoint?(a, b), do: MapSet.disjoint?(set(a), set(b))

  @doc "Union of extent codes in canonical order; nil for none."
  @spec union([String.t()]) :: String.t() | nil
  def union(codes),
    do: codes |> Enum.flat_map(&MapSet.to_list(set(&1))) |> MapSet.new() |> format()

  defp set(nil), do: MapSet.new(@order)

  defp set(code) do
    code |> String.replace("N.I.", "NI") |> String.split("+", trim: true) |> MapSet.new()
  end

  defp format(set) do
    case Enum.filter(@order, &MapSet.member?(set, &1)) do
      [] -> nil
      parts -> Enum.join(parts, "+")
    end
  end
end
