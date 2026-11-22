defmodule SertantaiLegal.Scraper.Commencement.Orders do
  @moduledoc """
  An Act's commencement orders (commencement-rules CR-04, Jason 2026-10-18:
  "read all orders"): every order made to bring it into force, not only
  those a note cites — a staged commencement's last order ("so far as not
  already in force") is often cited by none.

  The orders are legislation.gov.uk's secondary legislation titled "<Act
  title> <year> (Commencement …" (its title search, every page), with the
  register's `uk_lrt.enacting` instruments titled "Commencement" or
  "Appointed Day". The list is kept per Act under
  `data/cache/commencement-orders/` (fetched once; `refresh: true` again).
  A list says where to look; the order's own text says what it commences.
  IO: legislation.gov.uk, the DB, the cache (`act_title/2` and
  `candidates/2` are pure).
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.Commencement.Authority
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  @dir "data/cache/commencement-orders"

  @doc """
  The Act a law's orders commence, as `Order.rules/2` takes it: the law, the
  title its orders name it by (`act_title/2`, from the register; nil when
  the register holds none), its year, and the commencing authority its
  own rows give each place (`Authority.read/1`, Decision 10).
  """
  @spec act(String.t()) :: %{
          law: String.t(),
          title: String.t() | nil,
          year: String.t(),
          authorities: Authority.t()
        }
  def act(law) do
    year = law |> String.split("_") |> Enum.at(2)

    title =
      case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law]) do
        %{rows: [[t]]} when is_binary(t) -> act_title(t, year)
        _ -> nil
      end

    %{law: law, title: title, year: year, authorities: authorities(law)}
  end

  # (only rows naming a place's authority, and the subsection lists they
  # point to, bear on it: the Act's rows read whole, in document order)
  defp authorities(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, text FROM legal_articles WHERE law_name = $1 ORDER BY sort_key",
        [law]
      )

    rows |> Enum.map(&List.to_tuple/1) |> Authority.read()
  end

  @doc """
  The title a law's orders name it by, without its year: the register's
  title, less the law's own year where it ends with it. A year inside the
  title stays: "Deregulation Act 2015 (Health and Safety at Work) …
  (Consequential Amendments) Order" (SI 2015/1637) is not the Deregulation
  Act 2015, whose orders were read as commencing it. Pure.
  """
  @spec act_title(String.t() | nil, String.t()) :: String.t() | nil
  def act_title(nil, _year), do: nil

  def act_title(title, year),
    do: title |> String.trim() |> String.replace_suffix(" " <> year, "") |> String.trim()

  @doc "The order list kept for `act`; nil where it was never searched for. No search."
  @spec cached(String.t()) :: [String.t()] | nil
  def cached(act) do
    case File.read(Path.join(@dir, "#{act}.json")) do
      {:ok, json} -> Jason.decode!(json)
      _ -> nil
    end
  end

  @doc """
  The orders a re-read takes for a law: its list (`cached`, nil for none)
  with the orders whose rules for it are stored (`Store.order_sources/1`).
  The list only says where to look, and a later search can drop an order
  from it: the order's rules are then read again from its own text, which
  says whether it commences the law (`Order.rules/2`), never left on the
  reading that wrote them (SI 2002/2024 for 2000 c.38). Pure.
  """
  @spec candidates([String.t()] | nil, [String.t()]) :: [String.t()]
  def candidates(cached, stored), do: ((cached || []) ++ stored) |> Enum.uniq() |> Enum.sort()

  @doc "The commencement orders of `act` (law name, title without the year, year), as law names."
  @spec for_act(String.t(), String.t() | nil, String.t(), keyword()) :: [String.t()]
  def for_act(act, title, year, opts \\ []) do
    path = Path.join(@dir, "#{act}.json")

    case {Keyword.get(opts, :refresh, false), cached(act)} do
      {false, orders} when is_list(orders) ->
        orders

      _ ->
        orders = Enum.uniq(searched(title, year) ++ enacting(act)) |> Enum.sort()
        File.mkdir_p!(@dir)
        File.write!(path, Jason.encode!(orders))
        orders
    end
  end

  # the register's instruments made under the Act, titled as commencing it
  defp enacting(act) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT e FROM uk_lrt r, unnest(r.enacting) e
        JOIN uk_lrt o ON o.name = e
        WHERE r.name = $1 AND o.title_en ~* '(commencement|appointed day)'
        """,
        [act]
      )

    List.flatten(rows)
  end

  defp searched(nil, _year), do: []

  defp searched(title, year) do
    query = URI.encode_www_form("#{title} #{year} (Commencement")
    page("/secondary/data.feed?title=#{query}", 1, [])
  end

  defp page(path, n, acc) do
    case Client.fetch_xml(path <> if(n > 1, do: "&page=#{n}", else: "")) do
      {:ok, xml} when is_binary(xml) ->
        ids =
          for [_, type, year, number] <-
                Regex.scan(
                  ~r"<id>http://www\.legislation\.gov\.uk/id/([a-z]+)/([0-9]{4})/([0-9]+)</id>",
                  xml
                ),
              do: "UK_#{type}_#{year}_#{number}"

        acc = acc ++ ids

        if xml =~ ~r/<link rel="next"/ and n < 20, do: page(path, n + 1, acc), else: acc

      _ ->
        acc
    end
  end
end
