defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ChangeTarget do
  @moduledoc """
  A change's bound by its own target (CV-S05f): the amending provisions'
  bound (`Extent.Lookup.of_change/2`) with the target statements
  (`Extent.Targeted`) whose scope holds one of those provisions and whose
  targets hold the change's — SOCPA 2005 Sch.7 para 27(2) repeals RTA 1988
  s.4(6) to (8) in England and Wales; "The repeal of section 4(8) extends
  also to Scotland" makes s.4(8)'s E+W+S.

  They apply in the lists' order (only sets, named sets or widens a stated
  default, also widens, not narrows). A statement naming a law applies
  where the change's law has that title; with no title known, any such
  statement in scope makes the bound unknown — never one it may narrow.

  A statement naming a Part of the amended law ("an amendment of Part 1A of
  the Petroleum Act 1998", `Extent.AmendedExcepted`) speaks of a change
  whose target is that Part, or is within it: the change's `within` (the
  Parts holding its target, as the change's reader knows them). With no
  `within` given, such a change's bound is unknown. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Extent, RefList}
  alias SertantaiLegal.Scraper.Territory

  @order %{only: 1, named: 2, also: 3, not: 4}

  @doc """
  A change as the lookup takes it: its amended `law`, that law's `title`
  and its `target`, with the Parts holding the target (`within`) where
  `parts` (the amended law's rows: ref → its Parts, `["pt.1A"]`) knows the
  target or the provision holding it; a Schedule's provision is in none.
  """
  @spec change(
          String.t() | nil,
          String.t() | nil,
          String.t(),
          %{String.t() => [String.t()]} | nil
        ) ::
          map()
  def change(law, title, target, parts) do
    change = %{law: law, title: title, target: target}

    case parts && within(parts, target) do
      within when is_list(within) -> Map.put(change, :within, within)
      _ -> change
    end
  end

  # (a Schedule's provision is in no Part of the body, held as a row or not)
  defp within(_parts, "sch." <> _), do: []
  defp within(parts, target), do: parts[target] || parts[String.replace(target, ~r/\(.*$/, "")]

  @doc "The bound `base` with the target statements that speak of `change` (`law`, `title`, `target`)."
  @spec bound(Extent.t(), [String.t()], map() | nil, String.t() | :same | nil) ::
          String.t() | :same | nil
  def bound(%Extent{targets: []}, _refs, _change, base), do: base
  def bound(%Extent{}, _refs, nil, base), do: base

  def bound(%Extent{targets: targets} = e, refs, change, base) do
    speaking =
      for t <- targets, in_scope?(t.scope, refs), s = speaks(t, change), s != false do
        if s == :unknown, do: :unknown, else: t
      end

    cond do
      :unknown in speaking ->
        nil

      speaking == [] ->
        base

      true ->
        speaking
        |> Enum.sort_by(&Map.fetch!(@order, &1.kind))
        |> Enum.reduce(base, &step(&1, &2, e))
    end
  end

  # whether the statement speaks of the change: its targets hold the
  # change's, and its law is the change's; `:unknown` where either can't be
  # told (no title; a Part named and the Part of the change's target not
  # given)
  defp speaks(t, change) do
    case {covers(t.refs, change), law?(t.law, change)} do
      {false, _} -> false
      {_, false} -> false
      {true, true} -> true
      _ -> :unknown
    end
  end

  # a Part (or Chapter) of the amended law holds a target that is it, or
  # that the change says is within it (`within`: the target's own Parts)
  defp covers(refs, %{target: target} = change) do
    cond do
      covers?(refs, target) -> true
      not Enum.any?(refs, &container?/1) or container?(target) -> false
      is_list(change[:within]) -> Enum.any?(change.within, &covers?(refs, &1))
      true -> :unknown
    end
  end

  defp container?(ref) when is_binary(ref), do: ref =~ ~r/^(?:pt|ch)\.[^.]+$/
  defp container?(_ref), do: false

  defp step(%{kind: :only, place: place}, _acc, _e), do: place

  defp step(%{kind: :named, place: place}, acc, e) when is_binary(acc) and is_binary(e.default),
    do: Territory.union([acc, place])

  defp step(%{kind: :named, place: place}, _acc, _e), do: place

  defp step(%{kind: :also, place: place}, acc, _e) when is_binary(acc),
    do: Territory.union([acc, place])

  defp step(%{kind: :not, place: place}, acc, _e) when is_binary(acc),
    do: Territory.subtract(acc, place)

  # (unknown, or the enactment's own: widening or narrowing it stays unknown)
  defp step(_t, _acc, _e), do: nil

  defp in_scope?("*", _refs), do: true

  defp in_scope?(scope, refs),
    do:
      Enum.any?(
        refs,
        &(&1 == scope or RefList.covers?(scope, &1) or String.starts_with?(&1, scope <> "("))
      )

  defp covers?(["*"], _target), do: true

  defp covers?(refs, target) when is_binary(target),
    do:
      Enum.any?(
        refs,
        &(&1 == target or String.starts_with?(target, &1 <> "(") or RefList.covers?(&1, target))
      )

  defp covers?(_refs, _target), do: false

  # none named: the scope's own law; else its name and year (the
  # register's titles carry no year: "Road Traffic Act", the year is the
  # law's own, UK_ukpga_1988_52)
  defp law?(nil, _change), do: true
  defp law?(_law, %{title: nil}), do: :unknown

  defp law?(law, %{title: title, law: name}) do
    {named, year} = name_year(law)
    {held, held_year} = name_year(title)
    named == held and year == (held_year || law_year(name))
  end

  defp name_year(title) do
    case Regex.run(~r/^(.*?)\s+(\d{4})$/u, normal(title)) do
      [_, name, year] -> {name, year}
      nil -> {normal(title), nil}
    end
  end

  defp law_year(law) do
    case String.split(law || "", "_") do
      [_, _type, year | _] -> year
      _ -> nil
    end
  end

  @doc "A law's title as compared: no \"the\", no chapter aside, lower case."
  @spec normal(String.t()) :: String.t()
  def normal(title) do
    title
    |> String.downcase()
    |> String.replace(~r/^\s*the\s+/u, "")
    |> String.replace(~r/\s*\((?:c\.|s\.i\.)[^()]*\)\s*$/u, "")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end
end
