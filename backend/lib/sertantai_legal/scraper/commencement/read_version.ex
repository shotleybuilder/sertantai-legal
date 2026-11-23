defmodule SertantaiLegal.Scraper.Commencement.ReadVersion do
  @moduledoc """
  Which reader code a stored commencement rule was read by (#193): each
  rule is stamped (`commencement_rules.reader_version`) with the version of
  its own read path, by its treatment: the orders' (`ReadVersion.Orders`),
  the feed's (`ReadVersion.Effects`) or the clauses' (`ReadVersion.Clause`,
  every other treatment). So a fix to one read path stales only its own
  rules, and the builds that read them (`ChangeStaleness`,
  `:commencement_reader`; the Commencement reader staleness session).
  Pure.
  """

  alias __MODULE__.{Clause, Effects, Orders}

  @type group :: :clause | :orders | :effects

  @orders ~w(order_date order_schedule)
  @effects ~w(feed_commencement)

  @doc "The read path a treatment's rules come from."
  @spec group(atom() | String.t()) :: group()
  def group(treatment) when is_atom(treatment), do: group(Atom.to_string(treatment))
  def group(t) when t in @orders, do: :orders
  def group(t) when t in @effects, do: :effects
  def group(_treatment), do: :clause

  @doc "The treatments read by the orders' and the feed's paths (the clauses' are all others)."
  @spec treatments(:orders | :effects) :: [String.t()]
  def treatments(:orders), do: @orders
  def treatments(:effects), do: @effects

  @doc """
  Where a read path ends, for the coverage tests: the store and the
  stamps themselves, which shape no reading.
  """
  @spec boundaries() :: [String.t()]
  def boundaries,
    do: ~w(
      lib/sertantai_legal/scraper/commencement/store.ex
      lib/sertantai_legal/scraper/commencement/read_version.ex
      lib/sertantai_legal/scraper/commencement/read_version/clause.ex
      lib/sertantai_legal/scraper/commencement/read_version/orders.ex
      lib/sertantai_legal/scraper/commencement/read_version/effects.ex
    )

  @doc "A read path's version now."
  @spec current(group()) :: String.t()
  def current(:clause), do: Clause.current()
  def current(:orders), do: Orders.current()
  def current(:effects), do: Effects.current()

  @doc "The version a rule of `treatment` is stamped with now."
  @spec for_treatment(atom() | String.t()) :: String.t()
  def for_treatment(treatment), do: treatment |> group() |> current()
end
