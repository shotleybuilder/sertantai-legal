defmodule SertantaiLegal.Scraper.ExtentResolver do
  @moduledoc """
  Resolves a law's territorial **extent** (`geo_extent`, `geo_region`) from the
  sources legislation.gov.uk and the LAT provide, and records which source won
  (#162).

  Extent is the legal system(s) a law forms part of. It is **not** application
  (where the law operates), which fractalaw publishes separately (#163).

  Pure: no DB or HTTP access.

  ## Source priority (first source with a verdict wins)

  | Rank | Source           | Evidence                                                        |
  |------|------------------|-----------------------------------------------------------------|
  | 1    | `law_level`      | `Legislation/@RestrictExtent`, unless the document is unrevised |
  | 2    | `lat_provisions` | union of LAT `extent_code`                                      |
  | 3    | `contents_items` | union of `ContentsItem/@RestrictExtent`, revised documents only |
  | 4    | `text_clause`    | whole-instrument extent clauses ("These Regulations extend to…")|
  | 5    | `type_code`      | floor from the type code (ssi → S, nisr → NI, wsi → E+W …)      |

  With no verdict the extent is unknown (nil). It never defaults to `UK`:
  unrevised documents carry a placeholder `E+W+S+N.I.` on every ContentsItem,
  which is why devolved laws were mislabelled `UK`. An unknown resolution never
  clears a stored value; `geo_extent_source = nil` marks it legacy/unverified.

  `overwrite?/2` decides whether a new resolution may replace a stored one.
  """

  @order ["England", "Wales", "Scotland", "Northern Ireland"]
  @code %{"England" => "E", "Wales" => "W", "Scotland" => "S", "Northern Ireland" => "NI"}
  @token %{"E" => "England", "W" => "Wales", "S" => "Scotland", "NI" => "Northern Ireland"}

  @rank %{
    "law_level" => 1,
    "lat_provisions" => 2,
    "contents_items" => 3,
    "text_clause" => 4,
    "type_code" => 5
  }

  @type_floor %{
    "ssi" => ["Scotland"],
    "asp" => ["Scotland"],
    "ssa" => ["Scotland"],
    "nisr" => ["Northern Ireland"],
    "nia" => ["Northern Ireland"],
    "apni" => ["Northern Ireland"],
    "nisi" => ["Northern Ireland"],
    "nisro" => ["Northern Ireland"],
    "wsi" => ["England", "Wales"],
    "anaw" => ["England", "Wales"],
    "asc" => ["England", "Wales"],
    "mwa" => ["England", "Wales"]
  }

  @type input :: %{
          restrict_extent: String.t() | nil,
          document_status: String.t() | nil,
          lat_extent_codes: [String.t() | nil],
          contents_item_extents: [String.t() | nil],
          extent_clauses: [[String.t()]],
          type_code: String.t() | nil
        }

  @type result :: %{
          geo_extent: String.t() | nil,
          geo_region: [String.t()],
          source: String.t() | nil
        }

  @doc "Resolve extent from all available sources. See the moduledoc for priority."
  @spec resolve(input()) :: result()
  def resolve(input) do
    [
      {"law_level", law_level(input)},
      {"lat_provisions", union(input.lat_extent_codes)},
      {"contents_items", contents_items(input)},
      {"text_clause", input.extent_clauses |> List.flatten() |> ordered()},
      {"type_code", Map.get(@type_floor, input.type_code, [])}
    ]
    |> Enum.find(fn {_source, regions} -> regions != [] end)
    |> case do
      {source, regions} -> %{geo_extent: pan_region(regions), geo_region: regions, source: source}
      nil -> %{geo_extent: nil, geo_region: [], source: nil}
    end
  end

  @doc """
  May a new resolution (`new_source`, nil = unknown) replace the stored one?

  Unknown never replaces anything: a stored value with no source is legacy
  and unverified (it may be the unrevised placeholder, or correct), and is
  kept rather than cleared (Jason, 2026-09-25). A sourced resolution replaces
  a legacy value, or a sourced one of equal or worse rank.
  """
  @spec overwrite?(String.t() | nil, String.t() | nil) :: boolean()
  def overwrite?(_stored_source, nil), do: false

  def overwrite?(stored_source, new_source) do
    case Map.get(@rank, stored_source) do
      nil -> true
      stored_rank -> Map.fetch!(@rank, new_source) <= stored_rank
    end
  end

  @extent_fields [:geo_extent, :geo_region, :geo_extent_source]

  @doc """
  The extent fields a write may change, given the stored `geo_extent_source`.

  Extent is written as a group: all three fields when the incoming source may
  overwrite the stored one (`overwrite?/2`), otherwise none. An unsourced
  incoming extent is never written.
  """
  @spec extent_attrs(map(), String.t() | nil) :: map()
  def extent_attrs(attrs, stored_source) do
    new_source = attrs[:geo_extent_source]

    if new_source && overwrite?(stored_source, new_source),
      do: Map.take(attrs, @extent_fields),
      else: %{}
  end

  @doc """
  Parse an extent string in any source format into ordered region names.

  Handles `E+W+S+N.I.`, `E+W+S+NI`, `E.W.`, `N.I.` and named forms such as
  `Scotland,Northern Ireland`. Unknown tokens are ignored.
  """
  @spec parse_regions(String.t() | nil) :: [String.t()]
  def parse_regions(nil), do: []

  def parse_regions(extent) when is_binary(extent) do
    upper = String.upcase(extent)

    if String.match?(upper, ~r/ENGLAND|WALES|SCOTLAND|IRELAND/) do
      named_regions(upper)
    else
      upper
      |> String.replace(~r/N\.?I\.?/, "NI")
      |> String.split(~r/[+.,\s]+/, trim: true)
      |> Enum.map(&Map.get(@token, &1))
      |> Enum.reject(&is_nil/1)
      |> ordered()
    end
  end

  @doc "Region names → the stored pan-region code (UK, GB, E+W, …); none → nil."
  @spec pan_region([String.t()]) :: String.t() | nil
  def pan_region(regions) do
    case ordered(regions) do
      [] -> nil
      ["England", "Wales", "Scotland", "Northern Ireland"] -> "UK"
      ["England", "Wales", "Scotland"] -> "GB"
      other -> Enum.map_join(other, "+", &Map.fetch!(@code, &1))
    end
  end

  @doc """
  Extent from a whole-instrument extent clause in provision text, or nil.

  Only "These Regulations / This Order / This Act … extend(s) to X" counts.
  Anything partial ("Part 2 of this Act"), negative ("does not extend"),
  qualified ("except", "save", "for the purposes of") or continued as a list
  ("—") gives nil. An application statement after the extent ("and apply in
  England only") is not extent and is cut off.
  """
  @spec extent_clause(String.t() | nil) :: [String.t()] | nil
  def extent_clause(nil), do: nil

  def extent_clause(text) when is_binary(text) do
    regex =
      ~r/(?<prefix>\S+\s+)?(?:these|this)\s+(?:regulations|order|act|rules|scheme|measure|byelaws)\s+extends?\s+to\s+(?<target>[^.;—]*)(?<stop>[.;—]|$)/iu

    with %{"prefix" => prefix, "target" => target, "stop" => stop} <-
           Regex.named_captures(regex, text),
         false <- String.downcase(String.trim(prefix)) == "of",
         false <- stop == "—",
         target = cut_application(target),
         false <- String.match?(target, ~r/\b(except|save|other than|purposes|subject to|not)\b/i),
         [_ | _] = regions <- clause_regions(target) do
      regions
    else
      _ -> nil
    end
  end

  # ── Helpers ──

  defp law_level(%{document_status: "final"}), do: []
  defp law_level(%{restrict_extent: extent}), do: parse_regions(extent)

  defp contents_items(%{document_status: "revised", contents_item_extents: extents}),
    do: union(extents)

  defp contents_items(_input), do: []

  defp union(extents), do: extents |> Enum.flat_map(&parse_regions/1) |> ordered()

  defp ordered(regions), do: Enum.filter(@order, &(&1 in regions))

  defp named_regions(upper) do
    ordered(
      [
        {"ENGLAND", "England"},
        {"WALES", "Wales"},
        {"SCOTLAND", "Scotland"},
        {"NORTHERN IRELAND", "Northern Ireland"}
      ]
      |> Enum.filter(fn {needle, _} -> String.contains?(upper, needle) end)
      |> Enum.map(&elem(&1, 1))
    )
  end

  defp cut_application(target) do
    target
    |> String.split(~r/,?\s+(and|but)\s+appl(y|ies)\b/i, parts: 2)
    |> hd()
    |> String.replace(~r/\bonly\s*$/i, "")
  end

  defp clause_regions(target) do
    upper = String.upcase(target)

    cond do
      String.contains?(upper, "UNITED KINGDOM") -> @order
      String.contains?(upper, "GREAT BRITAIN") -> ["England", "Wales", "Scotland"]
      true -> named_regions(upper)
    end
  end
end
