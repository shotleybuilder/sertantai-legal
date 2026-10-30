defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.Verdicts do
  @moduledoc """
  Agent verdicts from the acceptance checks, pooled into the pass bound
  (change vocabulary CV-S10). Before this, every pooled count and bound
  was worked out by hand from the agents' tables.

  One verdict file per agent batch (JSON), written by the check's agent:

      {"step": "label", "family": "OH&S: Occupational", "stratum": "R",
       "seed": 153, "round": 11,
       "items": [{"id": "<row or change>", "group": "<law or pair>",
                  "verdict": "ok", "fault": null, "pattern": null, "note": ""}]}

  - `verdict`: `ok`, `wrong`, `doubtful` (not decided: listed, not
    counted) or `gap` (a value no source gives: never wrong).
  - `fault`, for a wrong item: `own` (the step's own fault: counts against
    the bound), `upstream` (an earlier step's) or `known` (a logged class
    the step's pass rule excuses). Every wrong item counts end to end.
  - `group`: the unit of the second bound (the law, or the pair); a group
    is wrong when any of its items counts.

  Pooling takes the files since the step's last fix. An item checked in
  more than one file counts once: the latest round's verdict stands.

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Bound

  @verdicts %{"ok" => :ok, "wrong" => :wrong, "doubtful" => :doubtful, "gap" => :gap}
  @faults %{"own" => :own, "upstream" => :upstream, "known" => :known}

  @type item :: %{
          id: String.t(),
          group: String.t(),
          verdict: :ok | :wrong | :doubtful | :gap,
          fault: :own | :upstream | :known | nil,
          pattern: String.t() | nil
        }
  @type file :: %{
          step: String.t(),
          family: String.t() | nil,
          stratum: String.t() | nil,
          seed: integer(),
          round: integer(),
          items: [item()]
        }
  @type pool :: %{steps: [String.t()], seeds: [integer()], rounds: [integer()], items: [item()]}
  @type count :: %{n: non_neg_integer(), wrong: non_neg_integer()}

  @doc "A decoded verdict file, checked."
  @spec read(map()) :: {:ok, file()} | {:error, String.t()}
  def read(%{"step" => step, "seed" => seed, "round" => round, "items" => items} = raw)
      when is_binary(step) and is_integer(seed) and is_integer(round) and is_list(items) do
    with {:ok, items} <- items(items) do
      {:ok,
       %{
         step: step,
         family: raw["family"],
         stratum: raw["stratum"],
         seed: seed,
         round: round,
         items: items
       }}
    end
  end

  def read(_raw), do: {:error, "a verdict file needs step, seed, round and items"}

  @doc "The files' items pooled, each item once (the latest round's verdict)."
  @spec pool([file()]) :: pool()
  def pool(files) do
    sorted = Enum.sort_by(files, & &1.round)

    items =
      sorted
      |> Enum.flat_map(& &1.items)
      |> Enum.reverse()
      |> Enum.uniq_by(& &1.id)
      |> Enum.reverse()

    %{
      steps: sorted |> Enum.map(& &1.step) |> Enum.uniq(),
      seeds: sorted |> Enum.map(& &1.seed) |> Enum.uniq() |> Enum.sort(),
      rounds: sorted |> Enum.map(& &1.round) |> Enum.uniq(),
      items: items
    }
  end

  @doc """
  The pooled counts: items and groups against the bound (own faults),
  end to end (every wrong item), and the gap and doubtful ids.
  """
  @spec tally(pool()) :: %{
          items: count(),
          groups: count(),
          end_to_end: count(),
          gaps: [String.t()],
          doubtful: [String.t()]
        }
  def tally(%{items: items}) do
    counts? = &(&1.verdict == :wrong and &1.fault == :own)
    groups = Enum.group_by(items, & &1.group)

    %{
      items: %{n: length(items), wrong: Enum.count(items, counts?)},
      groups: %{
        n: map_size(groups),
        wrong: Enum.count(groups, fn {_, is} -> Enum.any?(is, counts?) end)
      },
      end_to_end: %{n: length(items), wrong: Enum.count(items, &(&1.verdict == :wrong))},
      gaps: for(%{verdict: :gap, id: id} <- items, do: id),
      doubtful: for(%{verdict: :doubtful, id: id} <- items, do: id)
    }
  end

  @doc "The 95% upper bounds of a tally and whether both are under their limits."
  @spec verdict(%{items: count(), groups: count()}, float(), float()) :: %{
          items_upper: float() | nil,
          groups_upper: float() | nil,
          pass: boolean()
        }
  def verdict(%{items: i, groups: g}, item_limit, group_limit) do
    %{
      items_upper: Bound.upper(i.wrong, i.n),
      groups_upper: Bound.upper(g.wrong, g.n),
      pass: Bound.passes?(i.wrong, i.n, item_limit) and Bound.passes?(g.wrong, g.n, group_limit)
    }
  end

  defp items(raw) do
    Enum.reduce_while(raw, {:ok, []}, fn r, {:ok, acc} ->
      case item(r) do
        {:ok, i} -> {:cont, {:ok, [i | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  defp item(%{"id" => id, "group" => group, "verdict" => v} = r)
       when is_binary(id) and is_binary(group) do
    verdict = @verdicts[v]
    fault = @faults[r["fault"]]

    cond do
      verdict == nil ->
        {:error, "#{id}: unknown verdict #{inspect(v)}"}

      r["fault"] != nil and fault == nil ->
        {:error, "#{id}: unknown fault #{inspect(r["fault"])}"}

      verdict == :wrong and fault == nil ->
        {:error, "#{id}: a wrong item needs its fault"}

      true ->
        {:ok, %{id: id, group: group, verdict: verdict, fault: fault, pattern: r["pattern"]}}
    end
  end

  defp item(r), do: {:error, "an item needs id, group and verdict: #{inspect(r)}"}
end
