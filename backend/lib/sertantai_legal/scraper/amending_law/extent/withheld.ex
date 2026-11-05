defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Withheld do
  @moduledoc """
  The extent reader's family gate (Decision 1, Jason 2026-11-05, Maritime
  Safety: Extent reader): every text change of the family that gets no
  bound, grouped by its cause (`Check.change_row/2`'s `none:` outcome) and
  amending law. Each group's reach is the number of changes it leaves
  unbound, and its words are the law's unread statements or why it has no
  powers. Each group carries its reviewed status
  (`test/fixtures/extent_patterns/withheld.json`: `"<cause> @ <law>"`,
  else `"<cause>"`). The gate passes only when every one is named
  `known:`, with the commencement gate's status semantics
  (`Commencement.Leftovers.status/3`, `gate/1`). Pure.
  """

  alias SertantaiLegal.Scraper.Commencement.Leftovers

  @doc """
  The no-bound causes reaching the family: `change_rows` (with `outcome` and
  `by`), the amending laws' rows by law (with `withholding` and
  `powers_why`), and the reviewed statuses.
  """
  @spec items([map()], %{String.t() => map()}, map()) :: [Leftovers.item()]
  def items(change_rows, rows_by_law, reviewed) do
    change_rows
    |> Enum.filter(&String.starts_with?(&1.outcome, "none:"))
    |> Enum.group_by(&{&1.outcome, &1.by})
    |> Enum.map(fn {{cause, law}, changes} ->
      words = cause |> words(Map.get(rows_by_law, law, %{})) |> Enum.map(&%{words: &1})
      law = law || "-"

      Leftovers.item(
        :amending,
        law,
        "-",
        cause,
        words,
        length(changes),
        Leftovers.status(cause, reviewed, law)
      )
    end)
  end

  @doc "The gate over the items: as `Commencement.Leftovers.gate/1`."
  @spec gate([Leftovers.item()]) :: %{
          pass?: boolean(),
          failing: [Leftovers.item()],
          counts: map()
        }
  def gate(items), do: Leftovers.gate(items)

  # (the law's unread statements, wherever its changes' provisions are
  # left unnamed: what a reviewer reads first)
  defp words(cause, row)
       when cause in ~w(none:unread_statement none:same_or_not_named none:not_named none:provision_not_named),
       do: row[:withholding] || []

  defp words("none:law_no_powers", %{powers_why: why}) when is_binary(why), do: [why]
  defp words(_cause, _row), do: []
end
