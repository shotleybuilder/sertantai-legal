defmodule SertantaiLegal.Scraper.OrderCatalogue.LawRead do
  @moduledoc """
  One commencement order's reading for the order catalogue (`mix
  lat.order_patterns`), kept between runs (`CatalogueCache`, keyed on the
  order's CLML files, the Acts it is listed for and `OrderCatalogue.Version`):
  the Act it commences, each statement (`OrderMisreads.order_units/3`) with
  its pattern, leftovers and misreads, and the example of each statement
  the order alone would be asked for (as `CommencementCatalogue.LawScan.scan/3`
  does for a law: the run asks an order for no example it would not ask of
  it alone). The order's document is parsed once. Reads the CLML store; an
  order that raises is never cached.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.CatalogueCache
  alias SertantaiLegal.Scraper.Commencement.{Order, OrderMisreads, OrderPatterns}
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore
  alias SertantaiLegal.Scraper.OrderCatalogue.Version

  @whole_max 20_000
  @max 30_000

  @typedoc "An Act an order is listed for: as `Order.rules/2` takes it, with its reach and row ids."
  @type act :: %{act: Order.act(), reach: non_neg_integer(), ids: MapSet.t() | nil}

  @typedoc "An example as the order alone gives it."
  @type example :: {:held, map()} | :too_large | :mismatch

  @type t :: %{
          act: Order.act(),
          reach: non_neg_integer(),
          units: [map()],
          examples: %{String.t() => example()}
        }

  @doc "The order's reading and whether it came from the cache. `opts`: `CatalogueCache`'s."
  @spec order(String.t(), [act()], keyword()) :: {t(), :hit | :read}
  def order(order, acts, opts \\ []) do
    files = ClmlStore.law_files(order)

    CatalogueCache.fetch(
      "order_patterns",
      order,
      Version.current(),
      {order, Enum.map(files, &{&1, CatalogueCache.file_digest(&1)}), acts},
      fn -> read(order, ClmlStore.law_docs(order), acts) end,
      opts
    )
  end

  @doc """
  The reading from the order's CLML documents (`xmls`) and the Acts it is
  listed for: the Act it commences (the first it names, `Order.commences?/2`,
  else the first listed), its statements and their examples. Pure.
  """
  @spec read(String.t(), [String.t()], [act()]) :: t()
  def read(order, xmls, acts) do
    doc = Doc.new(order, xmls)
    %{act: act, reach: reach, ids: ids} = commenced(doc, acts)
    rules = Order.rules(doc, act)

    units =
      for %{unit: unit, outcome: o, pattern: key, leftovers: left, misreads: wrong} <-
            OrderMisreads.order_units(doc, rules, %{own: act, ids: ids}) do
        %{id: id(order, unit), unit: unit, outcome: o, key: key, leftovers: left, misreads: wrong}
      end

    %{act: act, reach: reach, units: units, examples: alone(order, act, doc, units)}
  end

  @doc "An example's id: the order and a short hash of its statement."
  @spec id(String.t(), map()) :: String.t()
  def id(order, unit),
    do:
      order <>
        "/" <>
        (:crypto.hash(:sha256, unit.id <> unit.text)
         |> Base.encode16(case: :lower)
         |> binary_part(0, 10))

  defp commenced(_doc, [one]), do: one
  defp commenced(doc, acts), do: Enum.find(acts, hd(acts), &Order.commences?(doc, &1.act))

  # the examples the order alone is asked for: a pattern takes one example
  # from an order (the run's rule: never two from one order), so each
  # pattern's statements in turn until one holds (a statement whose example
  # does not hold frees the order's place for the next of its pattern)
  defp alone(order, act, doc, units) do
    {_, examples} =
      Enum.reduce(units, {MapSet.new(), %{}}, &ask(&1, &2, {order, act, doc}))

    examples
  end

  defp ask(u, {held, examples}, {order, act, doc}) do
    if MapSet.member?(held, u.key) do
      {held, examples}
    else
      ex = example(order, act, doc, u.unit, u.outcome)
      held = if match?({:held, _}, ex), do: MapSet.put(held, u.key), else: held
      {held, Map.put(examples, u.id, ex)}
    end
  end

  # the order whole when small, else cut; held when it reads alone as the
  # whole order does
  defp example(order, act, doc, unit, outcome) do
    whole = OrderPatterns.example(doc, unit, :whole)

    xml =
      if byte_size(whole) <= @whole_max, do: whole, else: OrderPatterns.example(doc, unit, :cut)

    cond do
      byte_size(xml) > @max ->
        :too_large

      OrderPatterns.read(order, act, xml, unit) == outcome ->
        {:held,
         %{
           json: %{
             "order" => order,
             "act" => %{"law" => act.law, "title" => act.title, "year" => act.year},
             "unit" => %{"kind" => unit.kind, "id" => unit.id, "text" => unit.text},
             "xml" => xml
           },
           outcome: %{"class" => outcome.class, "rules" => outcome.rules}
         }}

      true ->
        :mismatch
    end
  end
end
