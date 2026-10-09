defmodule SertantaiLegal.Scraper.NoteTerritory do
  @moduledoc """
  The territory in a legislation.gov.uk F note, read as legislation.gov.uk
  documents it (`docs/LEGISLATION-GOV-UK-NOTE-TYPOLOGY.md`). A note is
  machine-drafted from an effect record; territory appears in two forms
  that mean different things:

  - `applies/1` — a bare "(X.)" after the verb ("S. 10A(1)(a) repealed
    (E.W.) (1.4.2010) by …"; spelled out: "disapplied in relation to
    Scotland"): **where the change applies** — the effect's territorial
    application, the same fact as the change element's `Extent` attribute
    (they agree 97.8% of the time where both exist).
  - `in_force/1` — "date for X." in the dates bracket ("inserted (6.4.2012
    for E.)", "(1.10.2017 for E., 1.4.2019 for W.)"): **where the change is
    in force** — the effect's InForce qualifications. "for specified
    purposes" qualifies purposes, not territory; "otherwise", "in so far as
    not already in force", "for remaining purposes" and "wholly" mean
    everywhere; "except in relation to X." everywhere but X.

  Only the text before each " by " counts (citations and titles after it
  never do). Pure.

  **Interim.** Notes are hints, not facts (`docs/LEGISLATION-GOV-UK-NOTE-TYPOLOGY.md`
  §3): the effects layer is the source of a change's territory and is to
  replace this reading where an effect exists (lat-refactor LR-03).
  """

  alias SertantaiLegal.Scraper.Territory

  @uk "E+W+S+NI"

  # territory letters: "E.", "W.", "S.", "N.I." (or "N.I" closing a group)
  @letters ~S"(?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+"
  @bare ~r/\((?:in relation to )?(#{@letters})\)/
  @names %{"England" => "E", "Wales" => "W", "Scotland" => "S", "Northern Ireland" => "NI"}
  @name ~S"(?:England|Wales|Scotland|Northern Ireland)"
  # straight after the change only: "Functions in relation to Wales" or a
  # title's "(… in relation to Wales) Order" are not territories
  @named ~r/\b(?:disapplied|repealed|revoked|omitted|substituted|inserted|amended) in relation to (#{@name}(?:(?:, | and )#{@name})*)/
  @for_territory ~r/\b(?:for|in relation to) (#{@letters})(?=[\s,;)]|$)/
  @except_territory ~r/except in relation to (#{@letters})(?=[\s,;)]|$)/
  @date ~r/\b\d{1,2}\.\d{1,2}\.\d{4}\b/
  @catch_all ~r/\botherwise\b(?!\s*prosp)|not already in force|remaining purposes|\bwholly\b/

  @doc "Where the note's changes apply: one code per bare territory, in order; [] when none."
  @spec applies(String.t() | nil) :: [String.t()]
  def applies(nil), do: []

  def applies(text) do
    text
    |> clauses()
    |> Enum.flat_map(fn clause ->
      # a "(X.)" inside the dates bracket ("(24.8.2005 (E.) …)") qualifies
      # the commencement: not where the change applies
      outside_dates = Enum.reduce(date_groups(clause), clause, &String.replace(&2, &1, ""))

      bare =
        @bare
        |> Regex.scan(outside_dates, capture: :all_but_first)
        |> Enum.map(&letters_code(hd(&1)))

      if bare == [], do: List.wrap(named(outside_dates)), else: bare
    end)
  end

  @doc """
  Where the note's change is in force, from its dated qualifiers; nil when
  they name no territory.
  """
  @spec in_force(String.t() | nil) :: String.t() | nil
  def in_force(nil), do: nil

  def in_force(text) do
    parts = text |> clauses() |> Enum.flat_map(&date_groups/1) |> Enum.flat_map(&dated_parts/1)
    qualified = Enum.map(parts, &qualify/1)

    if Enum.any?(qualified, &match?({kind, _} when kind in [:for, :except], &1)) do
      qualified
      |> Enum.flat_map(fn
        {:for, code} -> [code]
        {:except, code} -> [Territory.subtract(@uk, code)]
        :everywhere -> [@uk]
        :none -> []
      end)
      |> Enum.reject(&is_nil/1)
      |> Territory.union()
    end
  end

  # one dated part's meaning
  defp qualify(part) do
    cond do
      # before "for/in relation to": "except in relation to W." contains it
      match = Regex.run(@except_territory, part, capture: :all_but_first) ->
        {:except, letters_code(hd(match))}

      match = Regex.run(@for_territory, part, capture: :all_but_first) ->
        {:for, letters_code(hd(match))}

      # "24.8.2005 (E.) in so far as …"
      match = Regex.run(@bare, part, capture: :all_but_first) ->
        {:for, letters_code(hd(match))}

      Regex.match?(@catch_all, part) ->
        :everywhere

      Regex.match?(~r/purposes?|prosp|except/, part) ->
        :none

      # a bare date beside territorial ones: in force everywhere from then
      unqualified?(part) ->
        :everywhere

      true ->
        :none
    end
  end

  defp unqualified?(part),
    do: part |> String.replace(@date, "") |> String.replace(~r/[\s,;.]|\band\b/u, "") == ""

  # The text before each " by ": the first whole, later ones from their last
  # "; " / " and " (a citation's trailing "(S.)" never counts).
  defp clauses(text) do
    case String.split(text, " by ") do
      [_only] ->
        [text]

      parts ->
        [first | rest] = Enum.drop(parts, -1)
        [first | Enum.map(rest, &(&1 |> String.split(~r/; | and /) |> List.last()))]
    end
  end

  # Each bracket in the clause holding a date, whole (nested brackets kept:
  # "(… s. 51B(6) …, 1.4.2019 for W.)").
  defp date_groups(clause) do
    clause
    |> top_level_groups()
    |> Enum.filter(&Regex.match?(@date, &1))
  end

  defp top_level_groups(text), do: groups(text, 0, [], [])

  defp groups("", _depth, _current, found), do: Enum.reverse(found)

  defp groups("(" <> rest, 0, _current, found), do: groups(rest, 1, [], found)

  defp groups("(" <> rest, depth, current, found),
    do: groups(rest, depth + 1, ["(" | current], found)

  defp groups(")" <> rest, 1, current, found),
    do: groups(rest, 0, [], [current |> Enum.reverse() |> IO.iodata_to_binary() | found])

  defp groups(")" <> rest, depth, current, found) when depth > 1,
    do: groups(rest, depth - 1, [")" | current], found)

  defp groups(<<c::utf8, rest::binary>>, depth, current, found) when depth > 0,
    do: groups(rest, depth, [<<c::utf8>> | current], found)

  defp groups(<<_c::utf8, rest::binary>>, depth, current, found),
    do: groups(rest, depth, current, found)

  # "1.10.2017 for E., 1.4.2019 for W." → each part from one date to the next
  defp dated_parts(group) do
    offsets = @date |> Regex.scan(group, return: :index) |> Enum.map(fn [{pos, _}] -> pos end)

    offsets
    |> Enum.zip(Enum.drop(offsets, 1) ++ [byte_size(group)])
    |> Enum.map(fn {from, to} -> binary_part(group, from, to - from) end)
  end

  defp named(clause) do
    case Regex.run(@named, clause, capture: :all_but_first) do
      [names] ->
        ~r/England|Wales|Scotland|Northern Ireland/
        |> Regex.scan(names)
        |> List.flatten()
        |> Enum.map(&Map.fetch!(@names, &1))
        |> Territory.union()

      nil ->
        nil
    end
  end

  defp letters_code(letters) do
    ~r/N\.I|[EWS]/
    |> Regex.scan(letters)
    |> List.flatten()
    |> Enum.map(&String.replace(&1, "N.I", "NI"))
    |> Territory.union()
  end
end
