defmodule SertantaiLegal.Scraper.ChangeVocabulary.EvidenceSample do
  @moduledoc """
  The evidence check's sample items (change vocabulary CV-S08): a merged
  change with what judging its chosen values needs — each attribute's
  value and the source it came from, every source's claims (each with the
  effect id, ChangeId or amending provision it came from), the stratum's
  reason (the value conflicts, the markup–feed disagreements, or the
  attributes several sources claim), and the amending provision's own
  words where the law's text states it (`Amendment.CheckSample`). An agent
  judges each value against the sources' own records (`evidence-check`
  skill). Reads the CLML store and `amendment_rules`; writes nothing.

  `pattern/1` names a D item's disagreement, so a draw can take each
  pattern (the table applies one rule to all its items).
  """

  alias SertantaiLegal.Scraper.Amendment.CheckSample
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Evidence, EvidenceStrata, MergeStrata}

  # the claims beside the table's own that judging a value needs
  @context ~w(date_first cited affecting extent effect_extent via placed savings note)a

  @doc "One sampled change (`{law, change, stratum}`) as an item."
  @spec item({String.t(), Change.t(), atom()}, pos_integer()) :: map()
  def item({law, %Change{} = c, stratum}, i) do
    %{
      "n" => i,
      "stratum" => to_string(stratum),
      "law" => law,
      "target" => c.target,
      "key" => short(c.key),
      "aliases" => Enum.map(c.aliases, &short/1),
      "sources" => Enum.map(MergeStrata.sources(c), &to_string/1),
      "chosen" => chosen(c),
      "why" => why(c, stratum),
      "claims" => claims(c),
      "amending_provisions" =>
        if(Change.values(c, :law_text, :operation) != [],
          do: CheckSample.item({law, c}, i)["amending_provisions"],
          else: []
        )
    }
  end

  @doc """
  A D item's pattern: the attributes in disagreement with each side's
  values, and the chosen operation (`"level words/provision commenced"`).
  """
  @spec pattern(Change.t()) :: String.t()
  def pattern(%Change{} = c) do
    op = c.resolved && c.resolved.operation

    c
    |> EvidenceStrata.disagreements()
    |> Enum.map_join("; ", fn
      {:by, _, _} -> "by cited/affecting"
      {a, m, f} -> "#{a} #{join(m)}/#{join(f)}"
    end)
    |> Kernel.<>(" #{op}")
  end

  defp join(vs), do: vs |> Enum.uniq() |> Enum.map_join("+", &str/1)

  defp chosen(%Change{resolved: nil}), do: nil

  defp chosen(%Change{resolved: r}) do
    for {attribute, source} <- r.sources,
        into: %{},
        do:
          {to_string(attribute), %{"value" => str(Map.get(r, attribute)), "from" => str(source)}}
  end

  defp why(c, :V) do
    for {attribute, {ps, pv}, {ds, dv}} <- c.resolved.conflicts,
        do: %{
          "attribute" => to_string(attribute),
          "primary" => %{"source" => str(ps), "value" => str(pv)},
          "derived" => %{"source" => str(ds), "value" => str(dv)}
        }
  end

  defp why(c, :D) do
    for {attribute, m, f} <- EvidenceStrata.disagreements(c),
        do: %{
          "attribute" => to_string(attribute),
          "markup" => str(m),
          "feed" => str(f),
          "pattern" => pattern(c)
        }
  end

  defp why(c, :A), do: %{"contested" => Enum.map(EvidenceStrata.contested(c), &to_string/1)}

  defp claims(c) do
    attributes =
      Keyword.keys(Evidence.table()) ++ @context

    c.claims
    |> Enum.filter(&(&1.attribute in attributes))
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

  # an effect id's last six characters (never written whole)
  defp short("key-" <> rest), do: "key-…" <> String.slice(rest, -6, 6)
  defp short(key), do: key

  defp str(nil), do: nil
  defp str("key-" <> _ = key), do: short(key)
  defp str(v) when is_atom(v), do: Atom.to_string(v)
  defp str(v) when is_binary(v), do: v
  defp str(%Date{} = d), do: Date.to_iso8601(d)
  defp str(v) when is_list(v), do: Enum.map(v, &str/1)
  defp str(v), do: inspect(v)
end
