defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.AmendingYardstick do
  @moduledoc """
  The Amending-law reader's standard figures against legislation.gov.uk:
  each text change of a family (an operation from some source, not a
  commencement) by how the amending law's text and legislation.gov.uk (the
  feed, else the markup) state its operation (`agree`, `differ`,
  `law_only`, `gov_only`) and, where both state it, its level (`agree`,
  `differ`); with the check's strata (`Amendment.CheckStrata`: A, D, L).
  Under RULES `amending-legislation-gov-uk-first-where-it-speaks` a D change
  is a known limit and L is the gate's. Plain equality, as the readiness
  review's yardstick (`data/reports/amending-reader/readiness/feed-vs-law.sql`).
  Recorded by `mix lat.amending_check --family F --strata`, published by
  `mix lat.measures --family F`, as `ExtentYardstick` is for the Extent
  reader. Pure but for the record file.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change

  @dir "data/reports/amending-reader/yardstick"
  @operation ~w(agree differ law_only gov_only)
  @level ~w(agree differ)
  @strata ~w(A D L)

  @type t :: %{
          family: String.t(),
          at: DateTime.t(),
          text_changes: non_neg_integer(),
          operation: %{String.t() => non_neg_integer()},
          level: %{String.t() => non_neg_integer()},
          strata: %{String.t() => non_neg_integer()}
        }

  @doc """
  A change's `{operation class, level class or nil}`; nil when it is no
  text change (no operation, or a commencement).
  """
  @spec classify(Change.t()) :: {String.t(), String.t() | nil} | nil
  def classify(c) do
    {law, gov} = {Change.value(c, :law_text, :operation), gov(c, :operation)}

    case law || gov do
      nil -> nil
      :commenced -> nil
      _ -> {operation(law, gov), level(Change.value(c, :law_text, :level), gov(c, :level))}
    end
  end

  defp gov(c, attribute),
    do: Change.value(c, :feed, attribute) || Change.value(c, :markup, attribute)

  defp operation(law, nil) when law != nil, do: "law_only"
  defp operation(nil, _gov), do: "gov_only"
  defp operation(same, same), do: "agree"
  defp operation(_law, _gov), do: "differ"

  defp level(nil, _gov), do: nil
  defp level(_law, nil), do: nil
  defp level(same, same), do: "agree"
  defp level(_law, _gov), do: "differ"

  @doc "The record of one check: `changes` (the family's merged changes) and its strata counts."
  @spec record(String.t(), DateTime.t(), [Change.t()], %{atom() => non_neg_integer()}) :: t()
  def record(family, at, changes, strata) do
    classes = changes |> Enum.map(&classify/1) |> Enum.reject(&is_nil/1)

    %{
      family: family,
      at: at,
      text_changes: length(classes),
      operation: tally(@operation, Enum.map(classes, &elem(&1, 0))),
      level: tally(@level, classes |> Enum.map(&elem(&1, 1)) |> Enum.reject(&is_nil/1)),
      strata: Map.new(@strata, &{&1, Map.get(strata, String.to_atom(&1), 0)})
    }
  end

  defp tally(keys, values), do: Map.merge(Map.new(keys, &{&1, 0}), Enum.frequencies(values))

  @doc "The record file for `family`."
  @spec path(String.t()) :: String.t()
  def path(family) do
    slug = family |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
    Path.join(@dir, slug <> ".json")
  end

  @doc "Writes the record."
  @spec write(t(), String.t()) :: :ok
  def write(r, path) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(%{r | at: DateTime.to_iso8601(r.at)}, pretty: true))
  end

  @doc "Reads a record back, nil when there is none."
  @spec read(String.t()) :: t() | nil
  def read(path) do
    with {:ok, body} <- File.read(path),
         m = Jason.decode!(body),
         {:ok, at, _} <- DateTime.from_iso8601(m["at"]) do
      %{
        family: m["family"],
        at: at,
        text_changes: m["text_changes"],
        operation: m["operation"],
        level: m["level"],
        strata: m["strata"]
      }
    else
      _ -> nil
    end
  end

  @doc "The table `mix lat.measures` prints; `built_at` the family's last build."
  @spec lines(t() | nil, DateTime.t() | nil) :: [String.t()]
  def lines(nil, _built_at),
    do: [
      "Amending against legislation.gov.uk: no record; run `mix lat.amending_check --family F --strata`"
    ]

  def lines(r, built_at) do
    order = if built_at && DateTime.compare(r.at, built_at) == :lt, do: "BEFORE", else: "after"
    {op, lv} = {r.operation, r.level}

    [
      "Amending against legislation.gov.uk (the check of #{DateTime.to_string(r.at)}, #{order} the last build; #{r.text_changes} text changes):"
    ] ++
      Enum.map(@operation, &count_line("operation #{&1}", n(op, &1), r.text_changes)) ++
      Enum.map(@level, &count_line("level #{&1}", n(lv, &1), n(lv, "agree") + n(lv, "differ"))) ++
      [
        "  operation agreement where both state it: #{pct(n(op, "agree"), n(op, "agree") + n(op, "differ"))}",
        "  the gate: D #{n(r.strata, "D")} (legislation.gov.uk speaks: known), L #{n(r.strata, "L")} (the law's text only: reviewed)"
      ]
  end

  defp n(counts, k), do: Map.get(counts, k) || 0

  defp count_line(k, n, total),
    do: "  #{String.pad_leading(to_string(n), 7)}  #{pct(n, total)}  #{k}"

  defp pct(_n, 0), do: "   n/a"

  defp pct(n, total),
    do: String.pad_leading(:erlang.float_to_binary(100 * n / total, decimals: 1) <> "%", 6)
end
