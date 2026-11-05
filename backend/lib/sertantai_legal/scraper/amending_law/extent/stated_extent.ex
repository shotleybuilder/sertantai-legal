defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.StatedExtent do
  @moduledoc """
  The extent legislation.gov.uk states on one provision of an Act, from its
  CLML (`RestrictExtent`): a section's on the `P1group` it opens (or its
  `P1`), a Schedule's on its `Schedule` element; territorial versions
  united; a provision stating none takes the extent stated on the whole Act
  (its root element). Used only for an Act that states no extent clause, so
  an SI made under it is placed as far as its enabling provision reaches
  (Decision 2, Jason 2026-11-05, Maritime Safety: Extent reader: the
  European Communities Act 1972 s.2, E+W+S+N.I.). Pure.
  """

  alias SertantaiLegal.Scraper.Territory

  @doc "The stated extent of `ref` (\"s.2\", \"sch.2\") in the law's documents, as a code; nil where none is stated."
  @spec of([String.t()], String.t()) :: String.t() | nil
  def of(xmls, ref) do
    with id when id != nil <- id(ref),
         [_ | _] = found <- Enum.flat_map(xmls, &stated(&1, id)) do
      found |> Enum.reject(&(&1 == :none)) |> own_or_root(xmls)
    else
      _ -> nil
    end
  end

  # a provision stating none of its own takes its Act's, stated on the
  # whole Act (Decision 3, Jason 2026-11-05: the Merchant Shipping
  # (Pollution) Act 2006 s.1)
  defp own_or_root([], xmls), do: root(xmls)
  defp own_or_root(codes, _xmls), do: Territory.union(codes)

  @doc """
  The whole Act's stated extent where every provision states the same or
  none (an amending Act stating no clause: Decision 3); nil where any
  states another, or the Act states none.
  """
  @spec uniform([String.t()]) :: String.t() | nil
  def uniform(xmls) do
    with code when code != nil <- root(xmls),
         true <- Enum.all?(xmls, &states_only?(&1, code)) do
      code
    else
      _ -> nil
    end
  end

  defp states_only?(xml, code) do
    ~r/\bRestrictExtent="([^"]*)"/u
    |> Regex.scan(xml, capture: :all_but_first)
    |> Enum.all?(fn [c] -> Territory.normalize(c) == code end)
  end

  @doc "The extent stated on the whole Act (its root element's `RestrictExtent`); nil where none is."
  @spec root([String.t()]) :: String.t() | nil
  def root(xmls) do
    Enum.find_value(xmls, fn xml ->
      case Regex.run(~r/<Legislation\b[^>]*>/u, xml) do
        [tag] -> restrict(tag)
        _ -> nil
      end
    end)
  end

  defp id("s." <> n), do: "section-" <> n
  defp id("sch." <> n), do: "schedule-" <> n
  defp id(_), do: nil

  defp stated(xml, "schedule-" <> _ = id) do
    for [attrs] <-
          Regex.scan(~r/<Schedule\b([^>]*\bid="#{id}"[^>]*)>/u, xml, capture: :all_but_first),
        do: restrict(attrs) || :none
  end

  defp stated(xml, id) do
    for [{at, _}] <- Regex.scan(~r/<P1\b[^>]*\bid="#{id}"[^>]*>/u, xml, return: :index),
        do: section_extent(xml, at) || :none
  end

  # on the P1 itself, else on the P1group just before it (its heading's)
  defp section_extent(xml, at) do
    tag =
      xml |> binary_part(at, byte_size(xml) - at) |> then(&hd(Regex.run(~r/^<P1\b[^>]*>/u, &1)))

    restrict(tag) || group_extent(binary_part(xml, 0, at))
  end

  defp group_extent(before) do
    case Regex.scan(~r/<P1group\b([^>]*)>/u, before, return: :index) do
      [] ->
        nil

      groups ->
        [{gat, _}, {aat, al}] = List.last(groups)
        # only the group that opens this P1 (none closed between)
        unless String.contains?(binary_part(before, gat, byte_size(before) - gat), "</P1group>"),
          do: restrict(binary_part(before, aat, al))
    end
  end

  defp restrict(attrs) do
    case Regex.run(~r/\bRestrictExtent="([^"]*)"/u, attrs) do
      [_, code] -> Territory.normalize(code)
      _ -> nil
    end
  end
end
