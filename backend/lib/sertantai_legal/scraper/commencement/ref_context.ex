defmodule SertantaiLegal.Scraper.Commencement.RefContext do
  @moduledoc """
  The evaluator's context for an amending law's refs: a Schedule paragraph
  sits in its Schedule (and its Parts). Pure. Its own module so the build,
  the readers and the extent code can use it without naming the order
  reader (`Commencement.Order`), which would bring the whole order reader
  into their version stamps (the Commencement reader staleness session).
  """

  @doc "The context: `ancestors` gives a ref's Schedule Parts, then its Schedule."
  @spec context() :: map()
  def context do
    %{
      ancestors: fn ref ->
        # (its Parts, then its Schedule: "sch.4.pt.2.para.3" → sch.4.pt.2,
        # sch.4; "sch.para.3": an unnumbered Schedule's, in `sch`)
        case Regex.run(~r/^(sch(?:\.(?!pt\.|para\.)[^.]+)?)((?:\.pt\.[^.]+)*)\.para\./, ref) do
          [_, sch, pts] ->
            parts = for [p] <- Regex.scan(~r/\.pt\.[^.]+/, pts), do: p
            chain = Enum.scan(parts, sch, &(&2 <> &1))
            Enum.reverse(chain) ++ [sch]

          nil ->
            []
        end
      end
    }
  end
end
