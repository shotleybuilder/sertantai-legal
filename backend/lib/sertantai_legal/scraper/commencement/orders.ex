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
  IO: legislation.gov.uk, the DB, the cache.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  @dir "data/cache/commencement-orders"

  @doc "The commencement orders of `act` (law name, title without the year, year), as law names."
  @spec for_act(String.t(), String.t() | nil, String.t(), keyword()) :: [String.t()]
  def for_act(act, title, year, opts \\ []) do
    path = Path.join(@dir, "#{act}.json")

    case {Keyword.get(opts, :refresh, false), File.read(path)} do
      {false, {:ok, json}} ->
        Jason.decode!(json)

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
