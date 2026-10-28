defmodule SertantaiLegal.Scraper.ChangeVocabulary.MergeSample do
  @moduledoc """
  The merge check's sample items (change vocabulary CV-S07): a merged
  change with what judging its merge needs — its claims by source (each
  with the effect id or amending provision it came from), the merged
  values, the changes beside it by the same law (above, at or below its
  provision: the unjoined item's twins, the candidate's partner, a joined
  change's neighbours), and the amending provision's own words where the
  law's text states it (`Amendment.CheckSample`). An agent judges whether
  the change is one real event and every event it holds is one change
  (`merge-check` skill). Reads the CLML store and `amendment_rules`;
  writes nothing.
  """

  alias SertantaiLegal.Scraper.Amendment.CheckSample
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, MergeStrata}
  alias SertantaiLegal.Scraper.LatRef

  # the claims an agent judges a merge on
  @attributes ~w(operation level by cited date affecting placed partial retained ranged)a

  @doc "One sampled change (`{law, change, stratum}`), with the law's other changes, as an item."
  @spec item({String.t(), Change.t(), atom()}, [Change.t()], pos_integer()) :: map()
  def item({law, %Change{} = c, stratum}, changes, i) do
    by = c.resolved && c.resolved.by

    %{
      "n" => i,
      "stratum" => to_string(stratum),
      "law" => law,
      "target" => c.target,
      "key" => short(c.key),
      "aliases" => Enum.map(c.aliases, &short/1),
      "sources" => Enum.map(MergeStrata.sources(c), &to_string/1),
      "merged" => resolved(c),
      "claims" => claims(c),
      "beside" =>
        for(
          d <- changes,
          d != c,
          d.resolved && d.resolved.by == by,
          near?(c.target, d.target),
          MergeStrata.sources(d) != [],
          do: %{
            "target" => d.target,
            "key" => short(d.key),
            "sources" => Enum.map(MergeStrata.sources(d), &to_string/1),
            "merged" => resolved(d),
            "claims" => claims(d)
          }
        ),
      "amending_provisions" =>
        if(Change.values(c, :law_text, :operation) != [],
          do: CheckSample.item({law, c}, i)["amending_provisions"],
          else: []
        )
    }
  end

  defp resolved(%Change{resolved: nil}), do: nil

  defp resolved(%Change{resolved: r}),
    do: %{
      "operation" => str(r.operation),
      "level" => str(r.level),
      "by" => r.by,
      "date" => str(r.date),
      "territory" => str(r.territory)
    }

  defp claims(c) do
    c.claims
    |> Enum.filter(&(&1.attribute in @attributes and &1.source in [:feed, :markup, :law_text]))
    |> Enum.group_by(& &1.source)
    |> Map.new(fn {s, cs} ->
      {to_string(s),
       for(
         cl <- cs,
         do: %{
           "attribute" => to_string(cl.attribute),
           "value" => str(cl.value),
           "ref" => short(cl.ref)
         }
       )}
    end)
  end

  defp near?(a, b), do: a == b or a in LatRef.ancestors(b) or b in LatRef.ancestors(a)

  # an effect id's last six characters (never written whole)
  defp short("key-" <> rest), do: "key-…" <> String.slice(rest, -6, 6)
  defp short(key), do: key

  defp str(nil), do: nil
  defp str(v) when is_atom(v), do: Atom.to_string(v)
  defp str(v) when is_binary(v), do: v
  defp str(%Date{} = d), do: Date.to_iso8601(d)
  defp str(v) when is_list(v), do: Enum.map(v, &str/1)
  defp str(v), do: inspect(v)
end
