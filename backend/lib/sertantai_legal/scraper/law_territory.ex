defmodule SertantaiLegal.Scraper.LawTerritory do
  @moduledoc """
  Where a law's changes reach (V1-04): one rule for the change register's
  records (`Amendment.Collect`, AR-09; `ChangeCollector`'s feed records,
  V1-03) and the parse's territory claims (`EffectTerritory`, through
  `ChangesFeed.Effect.affecting_territory`). A territorial law changes text
  only in its territory: an "(England)" SI's repeal of an E+W provision
  leaves it in force in Wales (SI 2010/404 reg.14 by SI 2023/911).

  - `territory/3`: a devolved law's from its type; a UK-level law's extent
    when narrower than the UK; nil when the amended law is devolved to the
    same territory
  - `extent/2`: a law's extent — the place in its own title, else its
    register extent
  - `title_place/1`: the place in a law's own title

  Pure: the register lookup (title, extent) stays in the callers.
  """

  alias SertantaiLegal.Scraper.Territory

  # a devolved law's territory from its type (as `LiveStatus`): Welsh law
  # extends to E+W but applies in Wales
  @devolved %{
    "ssi" => "S",
    "asp" => "S",
    "wsi" => "W",
    "anaw" => "W",
    "asc" => "W",
    "mwa" => "W",
    "nisr" => "NI",
    "nisro" => "NI",
    "nia" => "NI",
    "apni" => "NI",
    "nisi" => "NI"
  }

  @places %{
    "England and Wales" => "E+W",
    "England" => "E",
    "Wales" => "W",
    "Scotland" => "S",
    "Northern Ireland" => "NI"
  }

  @doc """
  The territory a law's change reaches (AR-09, Jason): a devolved law's
  from its type; a UK-level law's `extent` (`extent/2`) when narrower than
  the UK (an extent is the law's whole reach: too wide at worst, never the
  wrong territory); nil (the UK) otherwise — and nil when the `amended` law
  is devolved to that same territory (a Welsh law's rows extend to E+W: a
  Welsh repeal of them is whole).
  """
  @spec territory(String.t(), String.t() | nil, String.t() | nil) :: String.t() | nil
  def territory(law, extent, amended \\ nil) do
    t = reach(law, extent)
    if t != nil and t == devolved(amended), do: nil, else: t
  end

  @doc """
  A law's extent for `territory/3` (V1-03): the place in its own title
  first ("… (England) Regulations" extend to E+W yet apply in England),
  else its register extent.
  """
  @spec extent(String.t() | nil, String.t() | nil) :: String.t() | nil
  def extent(title, register_extent), do: title_place(title) || register_extent

  defp devolved(nil), do: nil
  defp devolved(law), do: @devolved[law |> String.split("_") |> Enum.at(1)]

  defp reach(law, extent) do
    devolved(law) ||
      case extent && String.trim(extent) do
        "GB" -> "E+W+S"
        "UK" -> nil
        e -> e |> Territory.normalize() |> narrower()
      end
  end

  defp narrower("E+W+S+NI"), do: nil
  defp narrower(code), do: code

  @doc """
  The place in a law's own title (V1-03): "Building Regulations etc.
  (Amendment) (England) Regulations" → "E"; a place belonging to a law the
  title cites isn't its own ("Forestry and Land Management (Scotland) Act
  2018 (Consequential Provisions and Modifications) Order" → nil).
  """
  @spec title_place(String.t() | nil) :: String.t() | nil
  def title_place(title) when is_binary(title) do
    # the title's own instrument word at its end (a year and a register note
    # "(repealed …)" allowed), then the last place before it — none when a
    # cited law ("… (Scotland) Act 1994 (Commencement) Order") sits between;
    # or a place after the word, as Northern Ireland's ("Mines Act (Northern
    # Ireland)")
    title = String.replace(title, ~r/\s*\((?:repealed|revoked)[^)]*\)\s*$/i, "")

    trailing =
      ~r/\b(?:Regulations|Order(?: in Council)?|Rules|Act|Measure|Scheme|Byelaws?)(?:\s+\d{4})?\s*\((England and Wales|England|Wales|Scotland|Northern Ireland)\)(?:\s+\d{4})?\s*$/

    with nil <- Regex.run(trailing, title),
         [_, head] <-
           Regex.run(
             ~r/^(.*)\b(?:Regulations|Order(?: in Council)?|Rules|Act|Measure|Scheme|Byelaws?)(?:\s+\d{4})?\s*$/,
             title
           ),
         [_ | _] = places <-
           Regex.scan(
             ~r/\((England and Wales|England|Wales|Scotland|Northern Ireland)\)(.*?)(?=\(|$)/,
             head
           ),
         [_, place, _] <- List.last(places),
         rest = head |> String.split("(#{place})") |> List.last(),
         false <- rest =~ ~r/\b(?:Act|Measure)\s+\d{4}\b/ do
      @places[place]
    else
      [_, place] -> @places[place]
      _ -> nil
    end
  end

  def title_place(_title), do: nil
end
