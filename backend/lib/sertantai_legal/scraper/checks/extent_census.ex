defmodule SertantaiLegal.Scraper.Checks.ExtentCensus do
  @moduledoc """
  The whole-reader census (CV-S05d, #192): every catalogue and sweep
  sentence of every held law checked against the law's stored extent
  reading by an independent mention-finder (`ExtentCensus.LawCheck`),
  written as `census.py` wrote it: `sentences.tsv` (each sentence's worst
  verdict and flags), `scope.tsv` (apply statements of scope, not
  place), `unnamed.tsv` (stored refs no statement names) and
  `stats.json`.

  Per statement segment, each own provision it names is:
  ok, withheld (in an unread row), broader (only an ancestor stored),
  place (stored for other places), missing, q_read (qualified yet read),
  q_missing (qualified and in no row) or exc_held (excepted yet held);
  a whole-law statement is checked against the stored default or
  application (whole_missing, whole_mismatch).
  """

  alias SertantaiLegal.Scraper.Checks.ExtentCensus.{LawCheck, ScopeKind, Structure}
  alias SertantaiLegal.Scraper.Checks.{ExtentCensus.Re, PyCompat}

  @severe ~w(broader exc_held missing q_missing place whole_missing whole_mismatch q_read withheld scope ok)

  @type out :: %{sentences: iodata(), scope: iodata(), unnamed: iodata(), stats: String.t()}

  @doc """
  The census of `laws` (dump lines, decoded, in order), each law's
  structure read from the CLML store (`:store`) or taken from a map of
  frozen structures (a law not in it has none).
  """
  @spec run([map()], :store | %{String.t() => Structure.t()}) :: out()
  def run(laws, structures) do
    checked =
      laws
      |> Stream.map(&{&1, frozen(structures, &1["law"])})
      |> Task.async_stream(
        fn {d, st} -> {d["law"], LawCheck.check(d, st || Structure.read(d["law"]))} end,
        max_concurrency: System.schedulers_online(),
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, r} -> r end)

    rows =
      Enum.flat_map(checked, fn {_, {found, _}} ->
        Enum.map(found, &Map.put(&1, :worst, worst(&1.verdicts)))
      end)

    over = for {law, {_, unnamed}} <- checked, {k, p, r} <- unnamed, do: {law, k, p, r}

    %{
      sentences: [
        "law\tref\tclass\tworst\tcounted\tflags\tsentence\n" | Enum.map(rows, &sentence_line/1)
      ],
      scope: [
        "law\tref\tclass\tkind\tpolarity\tplace\tcarve_out\tsentence\n"
        | Enum.flat_map(rows, &scope_lines/1)
      ],
      unnamed: ["law\tkind\tplace\tref\n" | Enum.map(over, &unnamed_line/1)],
      stats: stats(rows, over)
    }
  end

  @doc "A law's structure: from the map (taken in the caller, so no task copies the map), else nil (read from the store)."
  @spec frozen(:store | %{String.t() => Structure.t()}, String.t()) :: Structure.t() | nil
  def frozen(:store, _law), do: nil
  def frozen(structures, law), do: Map.get_lazy(structures, law, &Structure.empty/0)

  @doc "A sentence's worst verdict, by `SEVERE`; \"none\" when it has none."
  @spec worst([LawCheck.verdict()]) :: String.t()
  def worst(verdicts) do
    keys = MapSet.new(verdicts, &elem(&1, 0))
    Enum.find(@severe, "none", &MapSet.member?(keys, &1))
  end

  @doc "Whether a sentence's class is counted by the reader (an unread or counted sweep sentence)."
  @spec counted?(String.t()) :: boolean()
  def counted?(cls),
    do: String.starts_with?(cls, "unread") or String.starts_with?(cls, "sweep:count")

  defp counted(cls), do: if(counted?(cls), do: "counted", else: "silent")

  defp sentence_line(f) do
    flags = for {v, r, _, _} <- f.verdicts, v not in ["ok", "withheld"], do: "#{v}:#{r}"
    tsv([f.law, f.ref, f.class, f.worst, counted(f.class), Enum.join(flags, "; "), f.s])
  end

  defp scope_lines(f) do
    for {sk, seg} <- f.scope, sk != "territorial" do
      c = Re.search(ScopeKind.thing_carve(), seg.text) || Re.search(ScopeKind.carve(), seg.text)
      carve = if c, do: seg.text |> Re.from(Re.start(c)) |> PyCompat.slice(160), else: ""
      polarity = if seg.neg, do: "does not apply", else: "applies"

      tsv([
        f.law,
        f.ref,
        f.class,
        sk,
        polarity,
        seg.places || "",
        carve,
        PyCompat.slice(f.s, 800)
      ])
    end
  end

  # `str(x)`: a place of none is "None"
  defp unnamed_line({law, k, p, r}), do: tsv([law, k, p || "None", r])

  defp tsv(fields), do: [Enum.intersperse(fields, "\t"), "\n"]

  defp stats(rows, over) do
    by_worst =
      rows
      |> Enum.frequencies_by(&{&1.worst, counted(&1.class)})
      |> Enum.sort()
      |> Enum.map(fn {{a, b}, n} -> {"#{a}/#{b}", n} end)

    PyCompat.json(
      [
        {"sentences", length(rows)},
        {"by_worst", by_worst},
        {"unnamed_refs", length(over)},
        {"unnamed_laws", over |> Enum.uniq_by(&elem(&1, 0)) |> length()}
      ],
      1
    )
  end
end
