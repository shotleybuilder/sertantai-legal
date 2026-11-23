defmodule SertantaiLegal.Scraper.Commencement.AmendingPicks do
  @moduledoc """
  Picks the amending Acts, and the orders their notes cite, for `mix
  lat.commencement`'s round-wide modes: `--effects`, `--orders` and
  `--read-orders` with no `--law` or `--family`.

  The picks come from the change register: the built laws' stored changes
  (`HeldAmenders`) and the text-change notes on their rows. They never come
  from the old label path's register (Commencement reader decouple,
  2026-11-23; `OldPathFenceTest`).

  `acts/1` and `cited/2` are pure; `acts/0` and `cited_orders/1` read the
  DB and write nothing.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Pointer
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store
  alias SertantaiLegal.Scraper.Commencement.HeldAmenders

  @act ~r/^UK_(ukpga|asp|anaw|asc|nia|apni|mwa)_/

  @doc "Every amending Act of the built laws' stored changes, sorted."
  @spec acts() :: [String.t()]
  def acts, do: built_laws() |> HeldAmenders.for_laws() |> acts()

  @doc "The Acts among `picked` (`HeldAmenders.for_laws/1`), however each was sorted, in order."
  @spec acts(HeldAmenders.t()) :: [String.t()]
  def acts(picked) do
    for({_kind, counted} <- picked, {law, _} <- counted, law =~ @act, uniq: true, do: law)
    |> Enum.sort()
  end

  @doc "For each of `acts`, the orders cited by the text-change notes on the built laws' rows."
  @spec cited_orders([String.t()]) :: %{String.t() => [String.t()]}
  def cited_orders(acts) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT code, text, citation_law, affected_sections FROM amendment_annotations
        WHERE law_name = ANY($1) AND code LIKE 'F:%' AND citation_law = ANY($2)
        """,
        [built_laws(), acts],
        timeout: :infinity
      )

    rows
    |> Enum.map(fn [code, text, law, sids] ->
      %{code: code, text: text, citation_law: law, affected_sections: sids || []}
    end)
    |> cited(acts)
  end

  @doc """
  For each of `acts`, the orders that `notes` (text-change notes, `F:`)
  cite after its amending provision ("…, s. 103(3); S.I. 2014/253, art. 3"),
  sorted.
  """
  @spec cited([map()], [String.t()]) :: %{String.t() => [String.t()]}
  def cited(notes, acts) do
    acts = MapSet.new(acts)

    for note <- notes,
        text_change?(note),
        %Pointer{affecting_law: law, commencing: commencing} = Pointer.parse(note),
        law in acts,
        {order, _refs} <- commencing,
        reduce: %{} do
      acc -> Map.update(acc, law, [order], &[order | &1])
    end
    |> Map.new(fn {law, orders} -> {law, orders |> Enum.uniq() |> Enum.sort()} end)
  end

  defp text_change?(%{code: "F:" <> _}), do: true
  defp text_change?(_), do: false

  defp built_laws, do: Store.builds() |> Map.keys()
end
