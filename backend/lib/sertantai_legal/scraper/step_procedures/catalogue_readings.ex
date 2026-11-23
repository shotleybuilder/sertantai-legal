defmodule SertantaiLegal.Scraper.StepProcedures.CatalogueReadings do
  @moduledoc """
  A commencement catalogue example's reading now, as `expected.json` holds
  it (`%{"class" => …, "rules" => …}`): an own clause's sentence by
  `OwnClause` (each law read once, several at a time), an order's unit by
  `OrderPatterns.read/4`. For `StepProcedures.HeldMoves`.
  """

  alias SertantaiLegal.Scraper.Commencement.{OrderPatterns, OwnClause, SentencePatterns}

  @doc "The own clauses' reader over `laws` (`laws.json`): every law read once, then each example's sentence."
  @spec own(map()) :: (map() -> map())
  def own(laws) do
    reads =
      laws
      |> Task.async_stream(
        fn {law, input} -> {law, OwnClause.read(law, SentencePatterns.input(law, input))} end,
        timeout: :infinity,
        ordered: false
      )
      |> Map.new(fn {:ok, r} -> r end)

    fn %{"law" => law, "sentence" => s} ->
      g = SentencePatterns.outcome(s, reads[law])
      %{"class" => g.class, "rules" => g.rules}
    end
  end

  @doc "The orders' reader: each example's unit read in its order."
  @spec orders(term()) :: (map() -> map())
  def orders(_laws) do
    fn %{"order" => o, "act" => a, "unit" => u, "xml" => xml} ->
      act = %{law: a["law"], title: a["title"], year: a["year"]}
      g = OrderPatterns.read(o, act, xml, %{kind: u["kind"], id: u["id"], text: u["text"]})
      %{"class" => g.class, "rules" => g.rules}
    end
  end
end
