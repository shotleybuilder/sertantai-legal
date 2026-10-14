defmodule SertantaiLegal.Scraper.AmendingLaw.RowRef do
  @moduledoc """
  A LAT row as an amending law would name it (lat-refactor LR-08): its law
  (type, year, number, title) and provision (`kind`, number, the bracketed
  path), from its section_id ("UK_ukpga_1989_29:s.25(5A)" → section 25,
  ["5A"]; an extent tag "[S]" dropped). Parts, headings and the like are
  `:other` (no amending provision names a row by those here). Pure.
  """

  @enforce_keys [:section_id, :law_name, :kind]
  defstruct [:section_id, :law_name, :type, :year, :number, :title, :kind, :number_ref, subs: []]

  @type t :: %__MODULE__{
          section_id: String.t(),
          law_name: String.t(),
          type: String.t() | nil,
          year: String.t() | nil,
          number: String.t() | nil,
          title: String.t() | nil,
          kind: :section | :regulation | :article | :rule | :other,
          number_ref: String.t() | nil,
          subs: [String.t()]
        }

  @kinds %{"s" => :section, "reg" => :regulation, "art" => :article, "rule" => :rule}

  @doc "The row's ref; `title` is its law's title (\"Electricity Act\")."
  @spec new(String.t(), String.t() | nil) :: t()
  def new(section_id, title) do
    [law, provision] = String.split(section_id, ":", parts: 2)
    [_, type, year, number] = String.split(law, "_", parts: 4)
    provision = String.replace(provision, ~r/\[[^\]]*\]$/, "")

    base = %__MODULE__{
      section_id: section_id,
      law_name: law,
      type: type,
      year: year,
      number: number,
      title: title,
      kind: :other
    }

    case Regex.run(~r/^(s|reg|art|rule)\.(\d+[A-Z]*)((?:\([^)]*\))*)$/, provision) do
      [_, kind, n, subs] ->
        %{
          base
          | kind: @kinds[kind],
            number_ref: n,
            subs: ~r/\(([^)]*)\)/ |> Regex.scan(subs, capture: :all_but_first) |> List.flatten()
        }

      nil ->
        base
    end
  end
end
