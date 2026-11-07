defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.Structure do
  @moduledoc """
  Which provisions each Part, Chapter and Schedule of a law holds, and
  its provisions in document order, read from the law's stored CLML
  (`finder.py`'s `Structure`, #192). Shares no code with the extent
  reader: element ids only, by a SAX walk of each `*/data.xml.gz`.
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @enforce_keys [:order, :index, :members, :containers]
  defstruct [:order, :index, :members, :containers]

  @type t :: %__MODULE__{
          order: [String.t()],
          index: %{String.t() => non_neg_integer()},
          members: %{String.t() => [String.t()]},
          containers: [String.t()]
        }

  @p1_id ~r/^(section|regulation|article|rule)-(\w+?)$/u
  @sch_id ~r/^schedule(?:-(\w+?))?((?:-part-\w+?)*)(?:-paragraph-(\w+?))?$/u
  @part_of ~r/-part-(\w+?)(?=-part-|$)/u
  @container ~r/^(part|schedule)-/u
  @part_chapter ~r/\Apart-\w+(?:-chapter-\w+)?\z/u

  @doc "A law's structure from the CLML store (`root:` names another store)."
  @spec read(String.t(), keyword()) :: t()
  def read(law, opts \\ []) do
    [_, t, y, n] = String.split(law, "_", parts: 4)

    [ClmlStore.root(opts), t, y, n, "*", "data.xml.gz"]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.sort_by(&(&1 |> Path.dirname() |> Path.basename()))
    |> Enum.reduce(walk_start(), &read_file/2)
    |> finish()
  end

  @doc "A structure from its JSON form: `order`, and `members` as `[container, refs]` pairs in order."
  @spec from_map(map()) :: t()
  def from_map(%{"order" => order, "members" => members}) do
    %__MODULE__{
      order: order,
      index: index(order),
      members: Map.new(members, fn [c, refs] -> {c, refs} end),
      containers: Enum.map(members, &hd/1)
    }
  end

  @doc "A law with no structure held."
  @spec empty() :: t()
  def empty, do: %__MODULE__{order: [], index: %{}, members: %{}, containers: []}

  @doc "Its JSON form (`from_map/1`'s input)."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = st),
    do: %{"order" => st.order, "members" => Enum.map(st.containers, &[&1, st.members[&1]])}

  @doc "The provisions a container holds, in document order."
  @spec held(t(), String.t() | nil) :: [String.t()]
  def held(%__MODULE__{members: m}, cid), do: Map.get(m, cid, [])

  @doc ~s[The id of the last Part ("part") or Chapter ("chapter") holding `ref`.]
  @spec container_of(t(), String.t(), String.t()) :: String.t() | nil
  def container_of(%__MODULE__{} = st, ref, kind) do
    st.containers
    |> Enum.filter(fn cid ->
      Regex.match?(@part_chapter, cid) and kind == "chapter" == String.contains?(cid, "-chapter-") and
        ref in st.members[cid]
    end)
    |> List.last()
  end

  @doc "The top-level provisions from `a` to `b` inclusive, by document order; nil unless both are held in order."
  @spec between(t(), String.t(), String.t()) :: [String.t()] | nil
  def between(%__MODULE__{index: ix, order: order}, a, b) do
    with i when i != nil <- ix[a], j when j != nil and i <= j <- ix[b] do
      Enum.slice(order, i..j)
    else
      _ -> nil
    end
  end

  @doc "The position of `ref` in document order, or nil."
  @spec position(t(), String.t()) :: non_neg_integer() | nil
  def position(%__MODULE__{index: ix}, ref), do: ix[ref]

  @doc ~s[An element id's provision ref: "section-3A" → "s.3A", "schedule-2-paragraph-4" → "sch.2.para.4"; a Part is none.]
  @spec top_ref(String.t()) :: String.t() | nil
  def top_ref(id) do
    case Regex.run(@p1_id, id) do
      [_, kind, n] -> if(kind == "section", do: "s.", else: "reg.") <> n
      nil -> schedule_ref(Regex.run(@sch_id, id))
    end
  end

  defp schedule_ref(nil), do: nil
  defp schedule_ref([_, "part" | _]), do: nil

  defp schedule_ref(caps) do
    [sch, parts, para] = caps |> tl() |> Enum.concat(["", ""]) |> Enum.take(3)

    if para != "" or parts == "" do
      "sch" <>
        if(sch == "", do: "", else: ".#{sch}") <>
        Enum.map_join(Regex.scan(@part_of, parts), &".pt.#{Enum.at(&1, 1)}") <>
        if para == "", do: "", else: ".para.#{para}"
    end
  end

  # the walk: the stack of open ids, provisions seen, containers' members
  # (reversed while read)
  defp walk_start, do: %{stack: [], order: [], seen: MapSet.new(), members: %{}, containers: []}

  defp read_file(path, acc) do
    xml = path |> File.read!() |> :zlib.gunzip()

    case :xmerl_sax_parser.stream(xml, event_fun: &event/3, event_state: %{acc | stack: []}) do
      {:ok, acc, _rest} -> acc
      # (a fault in the document: what was read before it stands, as iterparse gives it)
      {_error, _where, _reason, _rest, acc} -> acc
    end
  end

  defp event({:startElement, _uri, _local, _qname, attrs}, _loc, acc) do
    id =
      Enum.find_value(attrs, fn {_u, prefix, name, value} ->
        prefix == [] and name == ~c"id" and to_string(value)
      end)

    acc = %{acc | stack: [id | acc.stack]}
    ref = id && top_ref(id)
    if ref && not MapSet.member?(acc.seen, ref), do: add(acc, ref), else: acc
  end

  defp event({:endElement, _uri, _local, _qname}, _loc, acc), do: %{acc | stack: tl(acc.stack)}
  defp event(_event, _loc, acc), do: acc

  defp add(acc, ref) do
    holders =
      acc.stack |> tl() |> Enum.reverse() |> Enum.filter(&(&1 && Regex.match?(@container, &1)))

    Enum.reduce(holders, %{acc | order: [ref | acc.order], seen: MapSet.put(acc.seen, ref)}, fn c,
                                                                                                a ->
      case a.members do
        %{^c => refs} -> %{a | members: %{a.members | c => [ref | refs]}}
        m -> %{a | members: Map.put(m, c, [ref]), containers: [c | a.containers]}
      end
    end)
  end

  defp finish(acc) do
    order = Enum.reverse(acc.order)

    %__MODULE__{
      order: order,
      index: index(order),
      members: Map.new(acc.members, fn {c, refs} -> {c, Enum.reverse(refs)} end),
      containers: Enum.reverse(acc.containers)
    }
  end

  defp index(order), do: order |> Enum.with_index() |> Map.new()
end
