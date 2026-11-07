defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.ReadingDiff do
  @moduledoc """
  Per law, how the stored extent reading changed between two dumps:
  default, application, rows gone and added, sentence class counts
  (CV-S05d `rdiff.py`, #192). The text is the script's run file: its
  count line first (as `reading_diff_vs_run06.txt` holds it), then a
  block per changed law.
  """

  @doc "The diff of dump lines `old` and `new` (maps of law to line), and the count of laws changed."
  @spec run(%{String.t() => map()}, %{String.t() => map()}) :: {String.t(), non_neg_integer()}
  def run(old, new) do
    blocks =
      (Map.keys(old) ++ Map.keys(new))
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.flat_map(&law(&1, old[&1], new[&1]))

    n = length(blocks)
    {"\n#{n} laws changed of #{map_size(new)}\n" <> Enum.join(blocks), n}
  end

  defp law(law, nil, _b), do: ["## #{law}: added\n"]
  defp law(law, _a, nil), do: ["## #{law}: gone\n"]

  defp law(law, a, b) do
    out =
      [
        if(a["default"] != b["default"],
          do: "  default #{py(a["default"])} -> #{py(b["default"])}"
        ),
        if(a["application"] != b["application"],
          do: "  application #{py(a["application"])} -> #{py(b["application"])}"
        )
      ] ++ rows_changed(rows(a), rows(b)) ++ [classes_changed(classes(a), classes(b))]

    case Enum.reject(out, &is_nil/1) do
      [] -> []
      lines -> ["## #{law}\n" <> Enum.map_join(lines, &(&1 <> "\n"))]
    end
  end

  defp rows(d),
    do:
      MapSet.new(
        for r <- d["lists"] ++ d["applies"], x <- r["refs"], do: {r["kind"], r["place"], x}
      )

  defp rows_changed(ra, rb) do
    gone = ra |> MapSet.difference(rb) |> Enum.sort()
    added = rb |> MapSet.difference(ra) |> Enum.sort()
    [if(gone != [], do: "  - " <> fmt(gone)), if(added != [], do: "  + " <> fmt(added))]
  end

  defp fmt(xs) do
    xs
    |> Enum.reduce({[], %{}}, fn {k, p, r}, {keys, g} ->
      {if(Map.has_key?(g, {k, p}), do: keys, else: [{k, p} | keys]),
       Map.update(g, {k, p}, [r], &(&1 ++ [r]))}
    end)
    |> then(fn {keys, g} ->
      keys
      |> Enum.reverse()
      |> Enum.map_join("; ", fn {k, p} = key -> "#{k} #{py(p)}: #{refs(g[key])}" end)
    end)
  end

  defp refs(v) when length(v) > 12, do: Enum.join(Enum.take(v, 12), ",") <> "…+#{length(v) - 12}"
  defp refs(v), do: Enum.join(v, ",")

  defp classes(d), do: Enum.frequencies_by(d["sentences"], & &1["class"])

  defp classes_changed(ca, cb) when ca == cb, do: nil

  defp classes_changed(ca, cb) do
    diffs =
      for k <- Enum.sort(Enum.uniq(Map.keys(ca) ++ Map.keys(cb))),
          d = Map.get(cb, k, 0) - Map.get(ca, k, 0),
          d != 0,
          do: k <> if(d > 0, do: "+#{d}", else: "#{d}")

    "  classes " <> Enum.join(diffs, ", ")
  end

  # `str(x)`: none is "None"
  defp py(nil), do: "None"
  defp py(x), do: x
end
