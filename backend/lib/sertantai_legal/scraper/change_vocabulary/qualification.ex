defmodule SertantaiLegal.Scraper.ChangeVocabulary.Qualification do
  @moduledoc """
  What an in-force qualification says, as the feed reader carries it
  (CV-S02b; Jason 2026-10-23, catalogue review A and E). Pure.

  - `complete?/1`: it completes the provision's commencement — none,
    "wholly in force", "(in) so far as not already in force".
  - `in_force_for/1`: the territory it names ("for E.W.S." → "E+W+S"; "in
    relation to Wales" → "W"), never one it excepts.
  - `in_force_except/1`: the territory it excepts ("except in relation to
    W." → "W").
  - `classes/1`: what else it says — purposes, territory, except, time of
    day, in accordance with, retrospective, dated scope, provisions — or
    "other".
  - `partial?/1`: it limits the commencement's scope — purposes, a
    territory named or excepted, a dated scope, certain provisions. A time
    of day, "with effect in accordance with", "retrospective" limit nothing:
    not partial, carried as their class.
  """

  @complete ~r/^\s*$|wholly in force|so far as not already in force/i

  @places_re "(?:N\\.\\s?I\\.?|[EWS]\\.|England|Wales|Scotland|Northern Ireland)"
  @places %{"England" => "E", "Wales" => "W", "Scotland" => "S", "Northern Ireland" => "NI"}

  @for Regex.compile!(
         "\\b(?:for|in relation to)\\s+((?:#{@places_re}(?:\\s*(?:,|and|\\+)?\\s*))+)",
         "u"
       )
  @except Regex.compile!(
            "\\bexcept\\s+(?:in relation to|for|as regards|so far as (?:it )?relat\\w* to)\\s+((?:#{@places_re}(?:\\s*(?:,|and|\\+)?\\s*))+)",
            "u"
          )
  # an exception runs to the end of its clause
  @except_clause ~r/\bexcept\b[^;]*/u

  # each class a qualification can name, by its words
  @classes [
    {"purposes", ~r/\bpurposes?\b/i},
    {"except", ~r/\bexcept\b/i},
    {"time of day",
     ~r/\bat \d|a\.m\.|p\.m\.|\bimmediately (?:before|after)\b|\b(?:beginning|end) of the day\b/i},
    {"in accordance with",
     ~r/in accordance with|specifying with effect|as specified|as notified|london gazette/i},
    {"retrospective", ~r/\bretrospective/i},
    {"dated scope",
     ~r/on or after|\btax years?\b|financial years?|accounting periods?|in respect of|in relation to (?!(?:E|W|S|N\.?\s?I)\.|England|Wales|Scotland|Northern Ireland)/i},
    {"provisions",
     ~r/\bfor the (?:insertion|substitution|repeal|omission)\b|specified provisions|so far as (?:not )?relat|to the extent|\buntil\b|for a period/i}
  ]

  # the classes that limit what comes into force
  @limiting ["purposes", "territory", "except", "dated scope", "provisions"]

  @doc "Whether the qualification completes the provision's commencement."
  @spec complete?(String.t() | nil) :: boolean()
  def complete?(q), do: String.match?(q || "", @complete)

  @doc "The territory the qualification names for its commencement, or nil."
  @spec in_force_for(String.t() | nil) :: String.t() | nil
  def in_force_for(nil), do: nil

  def in_force_for(q) do
    q = String.replace(q, @except_clause, "")

    case Regex.run(@for, q) do
      [_, places] -> code(places)
      nil -> nil
    end
  end

  @doc "The territory the qualification excepts, or nil."
  @spec in_force_except(String.t() | nil) :: String.t() | nil
  def in_force_except(nil), do: nil

  def in_force_except(q) do
    case Regex.run(@except, q) do
      [_, places] -> code(places)
      nil -> nil
    end
  end

  @doc """
  What the qualification says, as classes ("territory + purposes"); "none"
  for no qualification, "complete" for one that only completes, else
  "other".
  """
  @spec classes(String.t() | nil) :: [String.t()]
  def classes(q) do
    q = q || ""

    found =
      Enum.reject(
        [
          if(String.trim(q) != "" and complete?(q), do: "complete"),
          if(in_force_for(q) || in_force_except(q), do: "territory")
          | for({name, re} <- @classes, do: if(q =~ re, do: name))
        ],
        &is_nil/1
      )

    cond do
      String.trim(q) == "" -> ["none"]
      found == [] -> ["other"]
      true -> found
    end
  end

  @doc "Whether the qualification limits the commencement's scope (a partial stage)."
  @spec partial?(String.t() | nil) :: boolean()
  def partial?(q) do
    classes = classes(q)
    "complete" not in classes and Enum.any?(classes, &(&1 in @limiting))
  end

  defp code(places) do
    places
    |> then(
      &Regex.replace(~r/England|Wales|Scotland|Northern Ireland/, &1, fn p ->
        @places[p] <> "."
      end)
    )
    |> SertantaiLegal.Scraper.Territory.normalize()
  end
end
