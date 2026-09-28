defmodule SertantaiLegal.Scraper.LiveStatus.Revokers do
  @moduledoc """
  DB lookup of revoking laws' recorded extent and made date, for
  `LiveStatus.decide/2`'s `revokers` context. Laws not in the register are
  absent from the result (LiveStatus then falls back to the revoker's type).
  """

  alias SertantaiLegal.Repo

  @doc "`%{name => %{extent, date}}` for the given UK law names found in legal_register."
  @spec load([String.t()]) :: %{String.t() => SertantaiLegal.Scraper.LiveStatus.revoker()}
  def load([]), do: %{}

  def load(names) do
    %{rows: rows} =
      Repo.query!(
        "SELECT name, geo_extent, md_date FROM legal_register WHERE country = 'uk' AND name = ANY($1)",
        [Enum.uniq(names)]
      )

    Map.new(rows, fn [name, extent, date] -> {name, %{extent: extent, date: date}} end)
  end
end
