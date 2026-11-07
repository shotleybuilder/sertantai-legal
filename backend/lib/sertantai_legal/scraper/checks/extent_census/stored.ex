defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.Stored do
  @moduledoc """
  A law's stored extent reading as the census checks it: each row's kind,
  place and refs (ranges "s.3..s.5" expanded by the law's structure),
  the default and the application (`census.py`'s `Stored`, `expand`,
  `ancestors`; #192).
  """

  alias SertantaiLegal.Scraper.Checks.ExtentCensus.Structure

  @enforce_keys [:rows, :default, :application]
  defstruct [:rows, :default, :application]

  @type row :: {String.t(), String.t() | nil, MapSet.t(String.t())}
  @type t :: %__MODULE__{rows: [row()], default: String.t() | nil, application: String.t() | nil}

  @doc "The stored reading of a dump line (`lists`, `applies`, `default`, `application`)."
  @spec new(map(), Structure.t()) :: t()
  def new(d, st) do
    rows =
      for r <- d["lists"] ++ d["applies"] do
        {r["kind"], r["place"], r["refs"] |> Enum.flat_map(&expand(&1, st)) |> MapSet.new()}
      end

    %__MODULE__{rows: rows, default: d["default"], application: d["application"]}
  end

  @doc ~s|A stored ref, a range "s.3..s.5" spanned by document order (with "s.5A", "s.5B" after its end).|
  @spec expand(String.t(), Structure.t()) :: [String.t()]
  def expand(ref, st) do
    with [_, a, b] <- Regex.run(~r/\A(.+)\.\.(.+)\z/u, ref),
         [_ | _] = span <- Structure.between(st, a, b) do
      span ++ trailing(st, Structure.position(st, List.last(span)) + 1, b)
    else
      _ -> [ref]
    end
  end

  defp trailing(st, i, b) do
    re = Regex.compile!("\\A" <> Regex.escape(b) <> "\\d+[A-Z]*\\z", "u")

    st.order
    |> Enum.drop(i)
    |> Enum.take_while(&Regex.match?(re, &1))
  end

  @doc ~s|The rows whose refs hold `ref` (a "same" row of "*" holds all), and those holding an ancestor of it, as {kind, place}.|
  @spec where(t(), String.t()) ::
          {[{String.t(), String.t() | nil}], [{String.t(), String.t() | nil}]}
  def where(%__MODULE__{rows: rows}, ref) do
    ancs = ancestors(ref)

    exact =
      for {k, p, refs} <- rows,
          MapSet.member?(refs, ref) or (MapSet.member?(refs, "*") and k == "same"),
          do: {k, p}

    cover = for {k, p, refs} <- rows, a <- ancs, MapSet.member?(refs, a), do: {k, p}
    {exact, cover}
  end

  @doc ~s|A ref's ancestors, nearest first: "s.3(1)(a)" → s.3(1), s.3; each Schedule and Part holding a paragraph: "sch.9.pt.2.para.3" → sch.9.pt.2, sch.9.|
  @spec ancestors(String.t()) :: [String.t()]
  def ancestors(ref), do: brackets(ref, [])

  defp brackets(r, out) do
    case :binary.matches(r, "(") do
      [] -> Enum.reverse(out) ++ schedule_holders(r)
      ms -> r |> binary_part(0, ms |> List.last() |> elem(0)) |> then(&brackets(&1, [&1 | out]))
    end
  end

  defp schedule_holders(r) do
    case String.split(r, ".") do
      ["sch" | _] = bits ->
        for k <- (length(bits) - 1)..1//-1,
            Enum.at(bits, k) in ["para", "pt"],
            do: bits |> Enum.take(k) |> Enum.join(".")

      _ ->
        []
    end
  end
end
