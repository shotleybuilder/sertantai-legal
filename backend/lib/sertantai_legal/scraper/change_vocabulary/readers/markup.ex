defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup do
  @moduledoc """
  The CLML change markup as claims (change vocabulary, CV-02 slice): each
  change id (an `Addition`, `Substitution` or `Repeal` element, however many
  times it occurs) is one change, on the lowest provision holding all its
  occurrences, keyed by the effect id its ChangeId carries
  (`EffectIndex.effect_id/1`), else the ChangeId itself.

  Claims (source `:markup`): `operation` (Repeal → repealed, a Repeal paired
  with a substitution → substituted, Substitution → substituted, Addition →
  inserted), `level` (`:provision` when the change wraps the provision's
  number, else `:words`), `retained` (RetainText), `territory` (the Extent
  attribute), and `cited` — the law the change's note cites. `cited` is a
  pointer for identity only (`ChangeVocabulary.Merge`), never a fact.

  A heading's change (`P1group/Title`) is on the provision the group holds.
  Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.ChangeVocabulary.Claim
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.EffectIndex

  @changes ~w(Addition Substitution Repeal)a

  @doc """
  Provision facts the markup states (CV-03): each provision within an
  element marked `Status="Prospective"` (not yet in force in the revised
  text), by ref.
  """
  @spec provisions(String.t()) :: %{String.t() => %{prospective: boolean()}}
  def provisions(xml) do
    doc = SweetXml.parse(xml, quiet: true, namespace_conformant: false)

    # the status sits on the provision or an element around it (a P1group
    # has no id: Building Safety Act 2022 s.138)
    for el <- xpath(doc, ~x"//*[@Status='Prospective']/descendant-or-self::*[@id]"l),
        ref = el |> xpath(~x"./@id"s) |> Order.ref(),
        ref != nil,
        into: %{},
        do: {ref, %{prospective: true}}
  end

  @doc "Claim sets `{key, target, claims}`, one per change id."
  @spec read(String.t()) :: [{String.t(), String.t(), [Claim.t()]}]
  def read(xml) do
    doc = SweetXml.parse(xml, quiet: true, namespace_conformant: false)
    cited = cited(doc)

    doc
    |> occurrences([], [])
    |> Enum.group_by(& &1.change_id)
    |> Enum.flat_map(fn {change_id, occ} ->
      key = EffectIndex.effect_id(change_id) || change_id

      for {ref, xml_id, group} <- placements(change_id, occ),
          do: {key, ref, claims(change_id, group, xml_id, cited)}
    end)
  end

  # where a change id's occurrences land: the lowest provision holding them
  # all; with none (they span the law) — a legacy id is a change to the
  # whole law ("*", a whole-Act repeal for a territory: Forestry Act 1967),
  # an effect id is a change to each top provision it touches
  defp placements(change_id, occ) do
    case occ |> Enum.map(& &1.path) |> lowest() do
      nil ->
        if EffectIndex.effect_id(change_id) do
          # outside any provision (an empty path) it lands nowhere
          occ
          |> Enum.reject(&(&1.path == []))
          |> Enum.group_by(&List.first(&1.path))
          |> Enum.flat_map(fn {_top, group} -> placements(change_id, group) end)
        else
          [{"*", "*", occ}]
        end

      id ->
        case Order.ref(id) do
          nil -> []
          ref -> [{ref, id, occ}]
        end
    end
  end

  # every change element with the path of provision ids above it, and
  # whether it sits in the provision's number; a group's title belongs to
  # the provision the group holds
  defp occurrences({:xmlElement, name, _, _, _, _, _, attrs, children, _, _, _} = el, path, flags) do
    path = if id = attr(attrs, :id), do: path ++ [id], else: path
    flags = if name == :Pnumber, do: [:number | flags], else: flags
    title_path = if name == :P1group, do: path ++ List.wrap(group_provision(el)), else: path

    own =
      if name in @changes and attr(attrs, :ChangeId) do
        [
          %{
            change_id: attr(attrs, :ChangeId),
            kind: name,
            path: path,
            number?: :number in flags,
            retain: attr(attrs, :RetainText) == "true",
            paired: attr(attrs, :SubstitutionRef) != nil,
            extent: attr(attrs, :Extent),
            note: attr(attrs, :CommentaryRef)
          }
        ]
      else
        []
      end

    own ++
      Enum.flat_map(children, fn
        {:xmlElement, :Title, _, _, _, _, _, _, _, _, _, _} = title ->
          occurrences(title, title_path, flags)

        child ->
          occurrences(child, path, flags)
      end)
  end

  defp occurrences(_other, _path, _flags), do: []

  defp group_provision(group) do
    case xpath(group, ~x"./*[@id][1]/@id"s) do
      "" -> nil
      id -> id
    end
  end

  # the deepest id every occurrence's path shares
  defp lowest(paths) do
    paths
    |> Enum.reduce(fn p, acc ->
      acc |> Enum.zip(p) |> Enum.take_while(fn {a, b} -> a == b end) |> Enum.map(&elem(&1, 0))
    end)
    |> List.last()
  end

  defp claims(change_id, occ, target, cited) do
    first = hd(occ)
    whole? = Enum.any?(occ, &(&1.number? and (target == "*" or List.last(&1.path) == target)))

    operation =
      cond do
        first.kind == :Repeal and first.paired -> :substituted
        first.kind == :Repeal -> :repealed
        first.kind == :Substitution -> :substituted
        true -> :inserted
      end

    Enum.concat([
      Claim.new(:markup, :operation, operation, change_id),
      Claim.new(:markup, :level, if(whole?, do: :provision, else: :words), change_id),
      Claim.new(:markup, :retained, if(first.kind == :Repeal, do: first.retain), change_id),
      Claim.new(:markup, :territory, Enum.find_value(occ, & &1.extent) |> code(), change_id),
      Claim.new(:markup, :cited, Map.get(cited, first.note), change_id)
    ])
  end

  # each commentary's first cited law, as a law name ("UK_uksi_2023_911")
  defp cited(doc) do
    for c <- xpath(doc, ~x"//Commentary"l),
        id = xpath(c, ~x"./@id"s),
        uri = xpath(c, ~x"(.//Citation/@URI)[1]"s),
        [_, type, year, num] <- [Regex.run(~r"/id/([a-z]+)/(\d{4})/(\d+)", uri)],
        into: %{},
        do: {id, "UK_#{type}_#{year}_#{num}"}
  end

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn
      {:xmlAttribute, ^name, _, _, _, _, _, _, value, _} -> to_string(value)
      _ -> nil
    end)
  end

  defp code(nil), do: nil
  defp code(value), do: SertantaiLegal.Scraper.Territory.normalize(value)
end
