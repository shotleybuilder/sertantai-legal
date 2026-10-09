defmodule SertantaiLegal.Scraper.InForceQualifier do
  @moduledoc """
  Reads a changes-feed effect's in-force qualification (`ukm:InForce
  Qualification`) for territory (LR-03; extracted from `EffectTerritory`
  in LR-04): which territory it names, and for which provisions.

  - "for E.", "for E.W. in so far as not already in force" → `{"E.", :all}`
  - "for S. for the repeal of ss. 1-19, 22-28" → `{"S.", {:only, {"section", items}}}`
  - "for E. except in relation to ss. 13-15, 76" → `{"E.", {:except, …}}`
  - "except in relation to W." → `except/1` = "W."
  - anything more ("for E. in relation to the pilot areas", purposes,
    Schs. / Pts. lists) → unusable (nil)

  Territories are returned as written ("E.W."); `EffectTerritory` turns them
  into extent codes. Pure.
  """

  # "for E.", "for E.W.", "for S. so far as …"; not "for specified purposes"
  @for_territory ~r/\bfor ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)/

  @except_territory ~r/except in relation to ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)/

  @only_except ~r/^except in relation to ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)\s*((in force )?(in )?so far as not already in force)?$/

  # "for E." alone, give or take a date note before it and "in so far as not
  # already in force" (or a timing) after it; anything more limits it to
  # part of the territory or the change ("for E. in relation to the pilot
  # areas": 2000/37; "for W. for the insertion of s. 53B") — unusable
  @before_territory ~r/^(\(being the da(te|y) on which .*came into force\)|at [\d.]+ [ap]\.m\.)?$/
  @after_territory ~r/^((in force )?(in )?so far as not already in force|to the extent, if any, that it is not already in force|immediately after the coming into force of .*)?$/

  @only_provisions ~r/^for the (?:repeal|revocation|omission|insertion|substitution) of (.+)$/
  @except_provisions ~r/^except in relation to (.+)$/

  # "ss. 1-19, 22-28" / "s. 26(5)" / "regs. 3 and 4" → {mode, {kind, items}};
  # nil when any item can't be read
  @list ~r/^(ss?|regs?)\.\s+(.+?)\.?$/
  @item ~r/^(\d+[A-Z]*)(?:-(\d+[A-Z]*))?((?:\([0-9A-Za-z]+\))*)$/

  @type items :: [[String.t()]]
  @type scope :: :all | {:only | :except, {String.t(), items()}}

  @doc "The qualification limits the change to purposes."
  @spec purposes?(String.t()) :: boolean()
  def purposes?(q), do: String.contains?(q, "purpose")

  @doc ~s[Some territory is named ("for E.", "except in relation to W.").]
  @spec territorial?(String.t()) :: boolean()
  def territorial?(q), do: Regex.match?(@for_territory, q) or Regex.match?(@except_territory, q)

  @doc "The territory after \"except in relation to\", anywhere in the qualification; nil when none."
  @spec except(String.t()) :: String.t() | nil
  def except(q) do
    case Regex.run(@except_territory, q, capture: :all_but_first) do
      [territory] -> territory
      nil -> nil
    end
  end

  @doc """
  The territory an "except in relation to W." qualification excludes when
  that is all it says (give or take "in so far as not already in force");
  nil otherwise.
  """
  @spec only_except(String.t()) :: String.t() | nil
  def only_except(q) do
    case Regex.run(@only_except, String.trim(q), capture: :all_but_first) do
      [territory | _] -> territory
      nil -> nil
    end
  end

  @doc """
  `{territory, :all | {:only | :except, {kind, items}}}` for a "for E. …"
  qualification; nil when unusable.
  """
  @spec scope(String.t()) :: {String.t(), scope()} | nil
  def scope(q) do
    with [{at, len}, {t_at, t_len}] <- Regex.run(@for_territory, q, return: :index),
         before = q |> binary_part(0, at) |> String.trim(),
         true <- before =~ @before_territory,
         rest = q |> binary_part(at + len, byte_size(q) - at - len) |> String.trim(),
         scope when scope != nil <- rest_scope(rest) do
      {binary_part(q, t_at, t_len), scope}
    else
      _ -> nil
    end
  end

  @doc "The row's provision (\"section-14A-1\") is of the scope's kind, so the list can be read for it."
  @spec scope_kind?(scope(), String.t() | nil) :: boolean()
  def scope_kind?(_scope, nil), do: false

  def scope_kind?({_mode, {kind, _items}}, provision),
    do: String.starts_with?(provision, kind <> "-")

  @doc "The row's provision (\"section-14A-1\") is listed (:only) or not listed (:except)."
  @spec in_scope?(scope(), String.t() | nil) :: boolean()
  def in_scope?(_scope, nil), do: false

  def in_scope?({mode, {kind, items}}, provision) do
    case Regex.run(~r/^(section|regulation)-(\d+[A-Z]*)((?:-[0-9A-Za-z]+)*)$/, provision,
           capture: :all_but_first
         ) do
      [^kind, number, path] ->
        listed = Enum.any?(items, &listed?(&1, number, path))
        if mode == :only, do: listed, else: not listed

      _ ->
        false
    end
  end

  defp rest_scope(rest) do
    cond do
      rest =~ @after_territory -> :all
      m = Regex.run(@only_provisions, rest, capture: :all_but_first) -> provisions(:only, m)
      m = Regex.run(@except_provisions, rest, capture: :all_but_first) -> provisions(:except, m)
      true -> nil
    end
  end

  defp provisions(mode, [list]) do
    with [kind, items] <- Regex.run(@list, String.trim(list), capture: :all_but_first),
         items = String.split(items, ~r/,\s*|\s+and\s+/),
         parsed = Enum.map(items, &Regex.run(@item, String.trim(&1), capture: :all_but_first)),
         false <- Enum.any?(parsed, &is_nil/1) do
      {mode, {if(String.starts_with?(kind, "s"), do: "section", else: "regulation"), parsed}}
    else
      _ -> nil
    end
  end

  defp listed?([from, to | _], number, _path) when to != "",
    do: number_key(from) <= number_key(number) and number_key(number) <= number_key(to)

  defp listed?([single | rest], number, path) do
    subs = rest |> List.last() |> to_string() |> then(&Regex.scan(~r/\(([0-9A-Za-z]+)\)/, &1))
    prefix = Enum.map_join(subs, fn [_, sub] -> "-" <> sub end)
    single == number and String.starts_with?(path, prefix)
  end

  defp number_key(number) do
    [digits, suffix] = Regex.run(~r/^(\d+)([A-Z]*)$/, number, capture: :all_but_first)
    {String.to_integer(digits), suffix}
  end
end
