defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelReachTest do
  @moduledoc """
  `Label.reaches?/2` answers as it did before its prefix test (#191,
  2026-11-07): the reach test, written as it was, against it over rows and
  targets with tags, disambiguators, the whole law and nesting.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence, Label}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Facts
  alias SertantaiLegal.Scraper.LatRef

  # the reach test before 2026-11-07, verbatim
  defp before?(%Change{target: target, resolved: r} = c, id) do
    target == id or
      (((r.level == :provision and level_stated?(r)) or
          (Facts.earlier_amendment?(c) and r.level != :words)) and
         (target == "*" or target in above(id)))
  end

  defp above(id) do
    case Regex.run(~r/^(.*[)0-9A-Za-z])n\d+$/, id) do
      [_, same] -> id |> LatRef.ancestors() |> tl() |> List.delete(same)
      nil -> tl(LatRef.ancestors(id))
    end
  end

  defp level_stated?(%{sources: sources}) when is_map(sources),
    do: Map.fetch(sources, :level) != {:ok, nil}

  defp level_stated?(_r), do: true

  @ids ~w|s.33 s.33(2) s.33(2)(a) s.33(2)(a)n1 s.33(2)n2 s.3 s.333(1) s.33[E+W] s.33(2)[E+W]
          s.33(2)(a)[S] s.33(2)(a)n1[E+W] reg.4(1) sch.2.para.3(1)(b)
          s.50(4)n1 s.50(4) s.1[E][S]| ++ ["art.Article 127P(4B)(a)"]

  @targets @ids ++ ~w|* s.50 s.33(1) sch.2.para.3 sch.2 s.1[E] s.1| ++ ["art.Article 127P", nil]

  defp change(target, level, opts) do
    %Change{
      key: "k",
      target: target,
      claims:
        for(
          {s, a, v} <- Keyword.get(opts, :claims, []),
          do: %Claim{source: s, attribute: a, value: v, ref: "k"}
        ),
      resolved: %Evidence.Resolved{
        operation: :substituted,
        level: level,
        territory: nil,
        date: ~D[2020-01-01],
        by: "UK_x",
        commenced_by: nil,
        retained: false,
        partial: false,
        saved: false,
        sources: Keyword.get(opts, :sources, %{operation: :law_text})
      }
    }
  end

  test "the same answer as before for every row and target" do
    kinds = [
      fn t -> change(t, :provision, []) end,
      fn t -> change(t, :provision, sources: %{level: nil}) end,
      fn t -> change(t, :words, []) end,
      fn t -> change(t, :words, claims: [{:feed, :earlier_amendment, true}]) end,
      fn t -> change(t, :heading, claims: [{:feed, :earlier_amendment, true}]) end
    ]

    for id <- @ids, t <- @targets, kind <- kinds do
      c = kind.(t)
      assert Label.reaches?(c, id) == before?(c, id), "#{inspect(t)} #{c.resolved.level} on #{id}"
    end
  end

  test "a change on a provision holding it, a sibling and a longer number" do
    whole = change("s.33", :provision, [])
    assert Label.reaches?(whole, "s.33(2)(a)")
    refute Label.reaches?(%{whole | target: "s.33(1)"}, "s.33(2)(a)")
    refute Label.reaches?(%{whole | target: "s.3"}, "s.33(2)")
  end
end
