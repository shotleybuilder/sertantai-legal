defmodule SertantaiLegal.Scraper.Sources.Held do
  @moduledoc """
  The facts `Sources` judges, read from what is held: the local store
  (feeds, documents, enabling caches), the stored changes and extent rules,
  and the register. Never fetches. `mix lat.sources` passes them to the
  pure rules (`Sources.needs/2`, `Sources.report/3`).
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{EffectKind, LatScope, Sources}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store
  alias SertantaiLegal.Scraper.EnactedBy.EnablingCache
  alias SertantaiLegal.Scraper.LegislationGovUk.{ChangesFeed, ClmlStore}

  @text_ops ~w(inserted substituted repealed repealed_in_part renumbered)a

  @doc """
  One law in scope: its documents, its feed's effects (store only), its
  amending laws and the gaps the feed leaves (from the stored changes:
  `mix lat.vocabulary --build`), and the register's change statistics.
  """
  @spec law(String.t()) :: map()
  def law(law) do
    slash = slash(law)
    %{amenders: amenders, gaps: gaps} = law |> text_changes() |> Sources.change_facts()

    %{
      law: law,
      scope: Sources.own_paths(slash, LatScope.get(law)),
      effects: effects(law),
      amenders: amenders,
      gaps: gaps,
      register: register(law)
    }
  end

  @doc """
  One amending law: whether it states its extent (`clauses`, its extent
  rules), an SI's enabling-power parents (the cache, never fetched), and an
  Act's commencing orders with the provisions each commences (its own feed,
  store only).
  """
  @spec amending(String.t(), %{String.t() => map()}) :: map()
  def amending(law, clauses) do
    %{
      clause: Sources.clause?(clauses, law),
      enabling: enabling(law),
      commencing: law |> feed() |> ok_or([]) |> Sources.commencing_orders(law)
    }
  end

  @doc "Each law's register validity date and when its record last updated."
  @spec valid_dates([String.t()]) :: %{
          String.t() => {Date.t() | nil, NaiveDateTime.t() | nil}
        }
  def valid_dates(laws) do
    Repo.query!("SELECT name, md_dct_valid_date, updated_at FROM uk_lrt WHERE name = ANY($1)", [
      Enum.uniq(laws)
    ]).rows
    |> Map.new(fn [n, d, u] -> {n, {d, u}} end)
  end

  @doc "The register's change statistics for `law` (`Sources.register_stats/1`)."
  @spec register(String.t()) :: %{effects: integer(), laws: integer()} | nil
  def register(law) do
    Repo.query!(
      ~s(SELECT "🔻_stats_affected_by_count", "🔻_stats_affected_by_laws_count" FROM uk_lrt WHERE name = $1),
      [law]
    ).rows
    |> Sources.register_stats()
  end

  @doc "A needed document's status, against the register's `valid_dates/1`."
  @spec status(Sources.need(), map()) :: Sources.status()
  def status(%{part: :introduction, law: law}, _valid),
    do: Sources.introduction_status(EnablingCache.cached(law), stored_introduction(law))

  def status(%{part: :feed, law: law}, _valid) do
    [_, type, year, number] = String.split(law, "_", parts: 4)
    page = ClmlStore.get(ChangesFeed.page_path(type, year, number, 1))
    Sources.feed_status(feed(law), page, DateTime.utc_now())
  end

  def status(%{part: part, law: law}, valid) do
    law
    |> Sources.doc_path(part)
    |> ClmlStore.get()
    |> Sources.document_status(Map.get(valid, law, {nil, nil}), DateTime.utc_now())
  end

  defp effects(law) do
    law
    |> feed()
    |> ok_or([])
    |> Enum.map(&%{affecting: &1.affecting, kind: EffectKind.kind(&1.type, nil), type: &1.type})
    |> Enum.reject(&is_nil(&1.affecting))
  end

  defp text_changes(law),
    do: law |> Store.for_law() |> Enum.filter(&(&1.resolved.operation in @text_ops))

  defp enabling(law) do
    case EnablingCache.cached(law) do
      {:ok, ps} -> ps |> Enum.map(& &1["law"]) |> Enum.uniq()
      :none -> []
    end
  end

  defp feed(law) do
    [_, type, year, number] = String.split(law, "_", parts: 4)
    ChangesFeed.fetch(type, year, number, store: :only)
  end

  defp ok_or({:ok, v}, _default), do: v
  defp ok_or(_other, default), do: default

  defp stored_introduction(law) do
    case EnablingCache.from_store(law) do
      {:ok, _} = held -> held
      :not_held -> if EnablingCache.absent_upstream?(law), do: :absent, else: :not_held
    end
  end

  defp slash(law) do
    [_, type, year, number] = String.split(law, "_", parts: 4)
    "#{type}/#{year}/#{number}"
  end
end
