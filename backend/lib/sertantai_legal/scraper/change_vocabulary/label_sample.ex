defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelSample do
  @moduledoc """
  The label check's sample items (change vocabulary CV-S09): a row with
  what judging its periods needs — the provision (extent, the law's
  start), the folded periods with each field's tier, today's stored label,
  the stratum and why the row is in it (its shapes, its difference), and
  every change reaching it with its chosen values, their sources and every
  source's claims (`EvidenceSample`). An agent judges each period against
  the law's sources (`label-check` skill). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.EvidenceSample

  @doc "One sampled row (`{law, row}`, `LabelSource.rows/1`) as a JSON-ready item."
  @spec item({String.t(), map()}, atom(), [atom()], String.t() | nil, pos_integer()) :: map()
  def item({law, row}, stratum, shapes, difference, i) do
    %{
      "n" => i,
      "stratum" => to_string(stratum),
      "law" => law,
      "row" => row.id,
      "extent" => row.extent,
      "law_start" => str(row.start),
      "shapes" => Enum.map(shapes, &to_string/1),
      "difference_from_today" => difference,
      "periods" => Enum.map(row.periods, &period/1),
      "today" => Enum.map(row.today, &period/1),
      "changes_reaching" =>
        row.reaching
        |> Enum.sort_by(&{&1.resolved.date && Date.to_iso8601(&1.resolved.date), &1.key})
        |> Enum.map(fn c ->
          %{
            "key" => EvidenceSample.short(c.key),
            "target" => c.target,
            "chosen" => EvidenceSample.chosen(c),
            "claims" => EvidenceSample.claims(c)
          }
        end)
    }
  end

  defp period(p) do
    %{
      "from" => str(p.valid_from),
      "to" => str(p.valid_to),
      "status" => str(p.status),
      "in_force_from" => str(p.in_force_from),
      "changed_by" => p.changed_by,
      "territory" => p.territory,
      "tiers" => p |> Map.get(:tiers, %{}) |> Map.new(fn {k, v} -> {to_string(k), str(v)} end)
    }
  end

  defp str(nil), do: nil
  defp str(%Date{} = d), do: Date.to_iso8601(d)
  defp str(v) when is_atom(v), do: Atom.to_string(v)
  defp str(v), do: v
end
