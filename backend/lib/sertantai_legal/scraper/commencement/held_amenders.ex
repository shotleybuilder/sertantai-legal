defmodule SertantaiLegal.Scraper.Commencement.HeldAmenders do
  @moduledoc """
  The amending laws whose own commencement clause is read for a set of laws
  (`mix lat.commencement --read-amending --family F`): every law that made
  a stored change on them (the feed's, the markup note's, the amending
  law's own text), held in the CLML store — never a law with LAT rows
  (`--read` reads it), nor a commencement order (read as an order, never as
  an amending law's own clause: Environmental Protection's hand-built list
  took in 21). `select/2` is pure; `for_laws/1` reads the DB and the store,
  and writes nothing.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @type counted :: [{String.t(), non_neg_integer()}]
  @type t :: %{read: counted(), orders: counted(), lat: counted(), not_held: counted()}

  @order_title ~r/\((?:Commencement|Appointed Day)/i

  @doc """
  The amending laws of `laws`' stored changes, each with its changes:
  `read` (held, to be read), and those left out: `orders` (commencement
  orders), `lat` (laws with LAT rows), `not_held`.
  """
  @spec for_laws([String.t()]) :: t()
  def for_laws(laws) do
    amenders = amenders(laws)
    names = Map.keys(amenders)

    select(amenders, %{
      lat: MapSet.new(lat(names)),
      orders: names |> Enum.filter(&order?/1) |> MapSet.new(),
      held: names |> Enum.filter(&text_held?/1) |> MapSet.new()
    })
  end

  @doc "`amenders` (`%{law => changes}`) sorted into what is read and what is left out, and why."
  @spec select(%{String.t() => non_neg_integer()}, %{
          lat: MapSet.t(),
          orders: MapSet.t(),
          held: MapSet.t()
        }) :: t()
  def select(amenders, %{lat: lat, orders: orders, held: held}) do
    groups =
      amenders
      |> Enum.filter(fn {law, _} -> String.starts_with?(law, "UK_") end)
      |> Enum.sort()
      |> Enum.group_by(fn {law, _} ->
        cond do
          MapSet.member?(lat, law) -> :lat
          MapSet.member?(orders, law) -> :orders
          MapSet.member?(held, law) -> :read
          true -> :not_held
        end
      end)

    Map.merge(%{read: [], orders: [], lat: [], not_held: []}, groups)
  end

  @doc """
  Whether `law` is a commencement order: its register title says so, or
  rules read from it as an order are stored (SI 1997/1082 "The provisions
  specified in the Schedule shall come into force …").
  """
  @spec order?(String.t()) :: boolean()
  def order?(law) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT (SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1),
               EXISTS (SELECT 1 FROM commencement_rules WHERE source_law = $1
                       AND treatment IN ('order_date', 'order_schedule'))
        """,
        [law]
      )

    case rows do
      [[title, stored?]] -> stored? or order_title?(title)
      _ -> false
    end
  end

  @doc "Whether a register title is a commencement or appointed-day order's."
  @spec order_title?(String.t() | nil) :: boolean()
  def order_title?(title), do: is_binary(title) and title =~ @order_title

  @doc """
  Whether any of `law`'s text is held in the CLML store (its body, whole
  or in fragments, or its Schedules): what an amending law's clause is read
  from (`AmendingRead`, `--read-amending`).
  """
  @spec text_held?(String.t()) :: boolean()
  def text_held?(law) do
    case String.split(law, "_", parts: 4) do
      [_, _, _, _] -> ClmlStore.law_files(law) != []
      _ -> false
    end
  end

  @doc """
  Whether `law`'s whole body is held in the CLML store: the commencement
  catalogue's amending laws (`mix lat.commencement_patterns`). Not
  `text_held?/1`: a law held only as section fragments (1959 c.24) has text
  held but no body.
  """
  @spec body_held?(String.t()) :: boolean()
  def body_held?(law) do
    case String.split(law, "_", parts: 4) do
      [_, t, y, n] -> File.exists?("data/cache/clml/#{t}/#{y}/#{n}/body/data.xml.gz")
      _ -> false
    end
  end

  @doc """
  Every law a note on our rows cites as the law amending them, with no LAT
  rows of its own (one hop): the amending laws `--read-amending` reads and
  the commencement catalogue's CLML laws, in name order.
  """
  @spec cited_without_lat() :: [String.t()]
  def cited_without_lat do
    Repo.query!("""
    SELECT DISTINCT coalesce(a.citation_law, a.changed_by) FROM amendment_annotations a
    WHERE a.code_type = 'amendment' AND coalesce(a.citation_law, a.changed_by) ~ '^UK_'
      AND NOT EXISTS (SELECT 1 FROM legal_articles l WHERE l.law_name = coalesce(a.citation_law, a.changed_by))
    ORDER BY 1
    """).rows
    |> List.flatten()
  end

  # every law a stored change on `laws` names as its maker, with its changes
  defp amenders(laws) do
    Repo.query!(
      """
      SELECT c.value ->> 'v', count(DISTINCT pc.id)
      FROM provision_changes pc JOIN provision_change_claims c ON c.change_id = pc.id
      WHERE pc.law_name = ANY($1)
        AND ((c.source = 'feed' AND c.attribute = 'by')
          OR (c.source = 'markup' AND c.attribute = 'cited')
          OR (c.source = 'law_text' AND c.attribute = 'by'))
        AND c.value ->> 'v' IS NOT NULL
        AND NOT (c.value ->> 'v' = ANY($1))
      GROUP BY 1
      """,
      [laws]
    ).rows
    |> Map.new(fn [law, n] -> {law, n} end)
  end

  defp lat(names) do
    Repo.query!("SELECT DISTINCT law_name FROM legal_articles WHERE law_name = ANY($1)", [names]).rows
    |> List.flatten()
  end
end
