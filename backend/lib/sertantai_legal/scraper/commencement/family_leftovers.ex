defmodule SertantaiLegal.Scraper.Commencement.FamilyLeftovers do
  @moduledoc """
  The commencement leftovers that reach a family (Decision 1 (c), Jason
  2026-11-05: the family gate): every commencement statement of its laws'
  own clauses, of the commencement orders held for them, and of the held
  amending laws its undated changes point to — read as the catalogues read
  them (`Leftovers.sentences/2`, `OrderLeftovers.order_units/2`) — each leftover
  with its group's reviewed status (`leftovers.json`). The gate itself is
  `Leftovers.gate/1`. IO: the DB, the CLML store, the cached order lists
  (never a search).
  """

  alias SertantaiLegal.Repo

  alias SertantaiLegal.Scraper.Commencement.{
    AmendingRead,
    HeldAmenders,
    Leftovers,
    Order,
    OrderLeftovers,
    OrderRead,
    Orders,
    OwnRead
  }

  alias SertantaiLegal.Scraper.LawStart.Input

  @sentences "test/fixtures/commencement_patterns/leftovers.json"
  @orders "test/fixtures/order_patterns/leftovers.json"

  @typedoc """
  A law's readings, read once and shared by the check (`mix
  lat.commencement_check --fresh`) and this gate: its own reading
  (`OwnRead.reading/2`), the Act its orders commence, the orders already
  read for it (`OrderRead.read/3`, by name) and its LAT rows' count.
  """
  @type law_reading :: %{
          own: OwnRead.reading(),
          act: Order.act(),
          orders: %{String.t() => OrderRead.t()},
          reach: non_neg_integer()
        }

  @typedoc "The reviewed groups: the sentences' (`leftovers.json`) and the orders'."
  @type reviewed :: %{sentences: map(), orders: map()}

  @typedoc "A law's leftover items: its own clause's, and its orders'."
  @type law_items :: {[Leftovers.item()], [Leftovers.item()]}

  @doc """
  The leftovers reaching `laws` (the family's LAT laws) and `amenders`
  (`%{amending law => its undated changes on the family}`), as
  `Leftovers.item()`s, every law and amending law read here.
  """
  @spec for_family([String.t()], %{String.t() => integer()}) :: [Leftovers.item()]
  def for_family(laws, amenders) do
    reviewed = reviewed()
    pairs = Enum.map(laws, &law_items(law_reading(&1), reviewed))
    gather(pairs, amending_items(amenders, %{}, reviewed))
  end

  @doc "The reviewed groups (`t:reviewed/0`), read once a run."
  @spec reviewed() :: reviewed()
  def reviewed, do: %{sentences: read_reviewed(@sentences), orders: read_reviewed(@orders)}

  @doc """
  One law's leftover items from its readings: taken as the law is read
  (the check's `--fresh`), so no reading is held past its law.
  """
  @spec law_items(law_reading(), reviewed()) :: law_items()
  def law_items(reading, reviewed),
    do: {own(reading, reviewed.sentences), orders(reading, reviewed.orders)}

  @doc """
  The amending laws' leftover items: each from its leftover sentences
  read already (`sentences/1`, by law), else read here.
  """
  @spec amending_items(%{String.t() => integer()}, %{String.t() => [map()]}, reviewed()) ::
          [Leftovers.item()]
  def amending_items(amenders, read, reviewed) do
    amenders
    # (a commencement order is read as an order, its Schedule's table,
    # never as an amending law's own clause: SI 1997/1082)
    |> Enum.reject(fn {law, _} -> HeldAmenders.order?(law) end)
    |> Enum.flat_map(fn {law, n} ->
      sentences = Map.get_lazy(read, law, fn -> law |> AmendingRead.reading() |> sentences() end)
      items(:amending, law, sentences, n, reviewed.sentences)
    end)
  end

  @doc "An amending law's sentences with leftovers (`Leftovers.sentences/2`); [] when not held."
  @spec sentences(AmendingRead.reading() | nil) :: [map()]
  def sentences(nil), do: []

  def sentences(%{rows: rows, read: read}),
    do: for(%{leftovers: [_ | _]} = s <- Leftovers.sentences(rows, read), do: s)

  @doc "The family's items in the gate's order: every law's own, then every law's orders', then the amending laws'."
  @spec gather([law_items()], [Leftovers.item()]) :: [Leftovers.item()]
  def gather(pairs, amending),
    do: Enum.flat_map(pairs, &elem(&1, 0)) ++ Enum.flat_map(pairs, &elem(&1, 1)) ++ amending

  @doc "A law's readings (`t:law_reading/0`) from its LAT rows (`Input.rows/1`) and the orders read for it."
  @spec law_reading(String.t(), [map()] | nil, %{String.t() => OrderRead.t()}) :: law_reading()
  def law_reading(law, lat_rows \\ nil, orders \\ %{}) do
    rows = lat_rows || Input.rows(law)
    %{own: OwnRead.reading(law, rows), act: Orders.act(law), orders: orders, reach: length(rows)}
  end

  defp own(%{own: own, act: %{law: law}, reach: reach}, reviewed),
    do: statements(:own, law, own.rows, own.read, reach, reviewed)

  defp statements(source, law, rows, read, reach, reviewed),
    do: items(source, law, Leftovers.sentences(rows, read), reach, reviewed)

  defp items(source, law, sentences, reach, reviewed) do
    for %{row: row, pattern: pattern, leftovers: [_ | _] = left} <- sentences do
      shape = Leftovers.shape(pattern, left)

      Leftovers.item(source, law, row, shape, left, reach, Leftovers.status(shape, reviewed, row))
    end
  end

  # the orders held for a law: its cached list and those its rules came from
  # (an order legislation.gov.uk lists for the law but which commences
  # another Act is read for that one: SI 1995/965, the 1970 Act's, listed
  # for the 1995 Act), each read as `--read-orders` writes it (`OrderRead`:
  # an order never commences itself, NISR 2012/286, nor an Act it doesn't
  # name) — those the check read already taken from its reading
  defp orders(%{act: act, own: own, orders: read, reach: reach}, reviewed) do
    for order <- order_names(act.law),
        %{doc: doc, commences?: true, rules: rules} <- [
          Map.get_lazy(read, order, fn -> OrderRead.read(order, act, own.rules) end)
        ],
        %{unit: unit, pattern: pattern, leftovers: [_ | _] = left} <-
          OrderLeftovers.order_units(doc, rules) do
      shape = Leftovers.shape(pattern, left)

      Leftovers.item(
        :order,
        order,
        unit.id,
        shape,
        left,
        reach,
        Leftovers.status(shape, reviewed, "#{order}:#{unit.id}")
      )
    end
  end

  defp order_names(law) do
    listed =
      case File.read("data/cache/commencement-orders/#{law}.json") do
        {:ok, json} -> Jason.decode!(json)
        _ -> []
      end

    stored =
      Repo.query!(
        """
        SELECT DISTINCT source_law FROM commencement_rules
        WHERE commences = $1 AND source_law <> $1 AND treatment IN ('order_date', 'order_schedule')
        """,
        [law]
      ).rows
      |> List.flatten()

    Enum.uniq(listed ++ stored)
  end

  defp read_reviewed(path) do
    case File.read(path) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end
end
