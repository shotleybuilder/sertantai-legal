defmodule SertantaiLegal.Scraper.LatCause do
  @moduledoc """
  Why a law's LAT changed in one parse operation (sertantai-legal #167, L8.3;
  fractalaw DRRP-TEMPORAL-PROPOSAL L2/L3). Pure: `decide/1` takes the facts
  gathered around a parse; `LatCause.Apply` gathers them and records the
  result on the operation's `parsed` lat_event.

  | cause          | when                                                              |
  |----------------|-------------------------------------------------------------------|
  | `initial`      | the law had no LAT before: first observed (not necessarily made)  |
  | `correction`   | the caller says so (an admin/fix task)                            |
  | `scope`        | the caller says so, or the fetched paths differ from last parse   |
  | `parser`       | the source CLML is byte-identical to the last parse (exact), or   |
  |                | nothing legal is visible: no new note, no status change, and the  |
  |                | content (lat_hash) is unchanged                                   |
  | `legislative`  | the source changed **and** there is evidence: a note whose        |
  |                | change_id is new, or a row whose status changed                   |
  | `unattributed` | the source and content changed with no evidence. Fractalaw never  |
  |                | versions these (L3); they are overwritten and flagged             |

  Never "unknown". The first L8.3 parse of a law already held has no previous
  `source_hash`, so it relies on the evidence and content rules.
  """

  @causes ~w(initial legislative parser scope correction unattributed)

  @type facts :: %{
          first?: boolean(),
          explicit: String.t() | nil,
          scope_changed?: boolean(),
          same_source?: boolean(),
          new_change_ids?: boolean(),
          status_changed?: boolean(),
          content_changed?: boolean()
        }

  @doc "The agreed cause values."
  @spec causes() :: [String.t()]
  def causes, do: @causes

  @doc "The cause of one parse operation, from the facts around it (see moduledoc)."
  @spec decide(facts()) :: String.t()
  def decide(%{first?: true}), do: "initial"
  def decide(%{explicit: explicit}) when explicit in ["correction", "scope"], do: explicit
  def decide(%{scope_changed?: true}), do: "scope"
  def decide(%{same_source?: true}), do: "parser"

  def decide(%{new_change_ids?: new, status_changed?: status}) when new or status,
    do: "legislative"

  def decide(%{content_changed?: false}), do: "parser"
  def decide(_facts), do: "unattributed"

  @doc "SHA-256 hex of the fetched CLML documents, in fetch order; nil with none."
  @spec source_hash([String.t()]) :: String.t() | nil
  def source_hash([]), do: nil

  def source_hash(xmls) when is_list(xmls) do
    xmls
    |> Enum.intersperse(<<0>>)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @doc "legislation.gov.uk's `<dct:valid>` (the date the revised text is valid to): the latest across documents."
  @spec valid_date([String.t()]) :: Date.t() | nil
  def valid_date(xmls) do
    xmls
    |> Enum.flat_map(
      &Regex.scan(~r/<dct:valid>(\d{4}-\d{2}-\d{2})<\/dct:valid>/, &1, capture: :all_but_first)
    )
    |> Enum.flat_map(fn [d] ->
      case Date.from_iso8601(d) do
        {:ok, date} -> [date]
        _ -> []
      end
    end)
    |> Enum.max(Date, fn -> nil end)
  end
end
