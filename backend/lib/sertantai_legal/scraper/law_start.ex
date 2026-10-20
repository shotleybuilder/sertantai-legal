defmodule SertantaiLegal.Scraper.LawStart do
  @moduledoc """
  When a law came into force, and how we know (lat-refactor LR-33): the
  timeline's `law_start` (J1). **The one place that says which treatment
  decides a law's start.**

  Every law gets exactly one treatment: `resolve/1` tries `catalogue/0` in
  order and the first that decides wins. A treatment either dates the law
  or is a known limit (no date; the law's provisions without another start
  stay unknown, never a guess). The treatment is written to the change
  register as the law's `commencement` record (`effect_type`), so

      SELECT effect_type, count(*) FROM lat_change_log
      WHERE collector = 'commencement' GROUP BY 1

  shows the treatments in force, and `mix lat.law_start --law X` explains one
  law. Add a treatment here, with its rule, its decision and a test; nowhere
  else.

  The law's own commencement clause is the law speaking about itself: a
  fact from the law (law → markup → effects), never from a note. Dated
  exceptions on particular provisions ("Articles 45(4)(d) and 48 come into
  force on …") are not read here (LR-34).

  Pure: the caller passes the register date, the CLML metadata, the made
  date and the law's rows.
  """

  alias SertantaiLegal.Scraper.LawStart.{Clause, Eu}

  @enforce_keys [:treatment]
  defstruct [:treatment, :date, :evidence, :text]

  @type treatment ::
          :lrt_metadata
          | :clml_coming_into_force
          | :act_enactment
          | :eu_directive
          | :eu_entry_into_force
          | :eu_publication_relative
          | :clause_date
          | :clause_made_relative
          | :clause_named_day
          | :clause_staged
          | :by_order
          | :tied_to_other_law
          | :clause_unread
          | :no_clause

  @type provision_treatment ::
          :provision_dated | :provision_by_order | :provision_qualified | :provision_unread

  @type t :: %__MODULE__{
          treatment: treatment(),
          date: Date.t() | nil,
          evidence: String.t() | nil,
          text: String.t() | nil
        }

  @typedoc """
  What a law's start is decided from: `lrt_date` (`uk_lrt.md_coming_into_force_date`),
  `clml_head` (the CLML metadata), `made` (the made date; an Act's passing),
  `rows` (`section_id`, `text`, in document order).
  """
  @type input :: %{
          required(:type_code) => String.t(),
          optional(:lrt_date) => Date.t() | nil,
          optional(:clml_head) => String.t() | nil,
          optional(:made) => Date.t() | nil,
          optional(:rows) => [map()]
        }

  # Royal Assent is an Act's start only where its own clause states no date
  @acts ~w(ukpga asp anaw asc mwa nia apni ukla)
  @eu ~w(eur eudr eudn)

  # {treatment, dates the law?, rule, decided}
  @catalogue [
    {:lrt_metadata, true, "the register's coming into force (uk_lrt.md_coming_into_force_date)",
     "LR-24"},
    {:clml_coming_into_force, true, "CLML ukm:ComingIntoForce, the earliest date (J3)", "LR-24"},
    {:eu_directive, false,
     "an EU directive binds Member States and was never in force in the UK itself",
     "Jason 2026-10-16 (LR-33 P3)"},
    {:eu_entry_into_force, true,
     "an EU regulation or decision: EUR-Lex entry into force where the metadata is the original act's (CELEX 3…), else a date its text states",
     "Jason 2026-10-16 (LR-33 P3)"},
    {:eu_publication_relative, false,
     "an EU text dated from Official Journal publication, with metadata of a consolidation (its date is the consolidation's)",
     "Jason 2026-10-16 (LR-33 P3)"},
    {:clause_date, true, "the law's commencement clause states a date",
     "Jason 2026-10-16 (LR-33 P1)"},
    {:clause_made_relative, true,
     "the clause counts from the made (or passed) date: the day after; N days after; the expiration of N days / weeks / months from (+1 day) or beginning with the day; the first day of the following month",
     "Jason 2026-10-16 (LR-33 P1)"},
    {:clause_named_day, true,
     "IP completion day = 2020-12-31 (and immediately before / after); exit day = 2020-01-31, read as IP completion day in an instrument made before exit day (EU(WA)A 2020 Sch. 5 para. 1(1); CR-09)",
     "Jason 2026-10-16 (LR-33 P1, P2)"},
    {:clause_staged, true,
     "the general clause defers to its paragraphs (\"in accordance with paragraphs (2) and (3)\"): the earliest date they state",
     "Jason 2026-10-16 (LR-33 P1)"},
    {:act_enactment, true,
     "an Act whose own clause states no date: Royal Assent (ukm:EnactmentDate; the Interpretation Act 1978 s.4 default, which applies only where no provision is made otherwise)",
     "LR-24 J3; after the clause, LR-33"},
    {:by_order, false, "\"on such day as … may by order appoint\"",
     "Jason 2026-10-16 (LR-33 P4)"},
    {:tied_to_other_law, false,
     "\"at the same time as section 83 of the 2022 Act comes into force\"",
     "Jason 2026-10-16 (LR-33 P4)"},
    {:clause_unread, false, "a commencement clause none of the above reads (listed for review)",
     "Jason 2026-10-16 (LR-33 P5)"},
    {:no_clause, false, "nothing above", "Jason 2026-10-16 (LR-33 P5)"}
  ]

  # {treatment, starts its rows?, rule, decided}: the commencement of
  # particular provisions (LR-34, `LawStart.Provisions`)
  @provision_catalogue [
    {:provision_dated, true,
     "named provisions of this law commence on a date the clause states: their start, in place of the law's",
     "Jason 2026-10-16 (LR-33 P1, LR-34)"},
    {:provision_by_order, true,
     "named or remaining provisions left to commencement orders, or a law commenced wholly by order: no law start; their own dated commencement where held, else in force as at the revised text unless it marks them prospective, since unknown (gap commenced_by_order)",
     "Jason 2026-10-16 (LR-34 D1 b)"},
    {:provision_qualified, true,
     "commenced for some purposes or places only (\"so far as …\", \"in relation to Wales\"): partly in force from its date (in_force_partial), fully once a rule for the rest starts (the evaluator's partial rule)",
     "Jason 2026-10-16 (LR-34 D2); CR-03"},
    {:provision_unread, false,
     "a sentence whose provisions or date the reader can't resolve: listed for the law, no effect",
     "LR-34"}
  ]

  @doc "The provision-level treatments (LR-34): `{treatment, affects rows?, rule, decided}`."
  @spec provision_catalogue() :: [{provision_treatment(), boolean(), String.t(), String.t()}]
  def provision_catalogue, do: @provision_catalogue

  @doc "The treatments in the order they are tried: `{treatment, dates?, rule, decided}`."
  @spec catalogue() :: [{treatment(), boolean(), String.t(), String.t()}]
  def catalogue, do: @catalogue

  @doc "Whether a treatment dates the law (else it is a known limit)."
  @spec dates?(treatment()) :: boolean()
  def dates?(treatment),
    do: Enum.find_value(@catalogue, fn {t, d, _, _} -> t == treatment and d end) || false

  @doc """
  A law's start and the treatment that decided it: the first in
  `catalogue/0` order. A clause the reader can't date (by order, tied,
  unread) yields to Royal Assent for an Act, and is the law's treatment
  otherwise.
  """
  @spec resolve(input()) :: t()
  def resolve(%{type_code: type} = input) do
    head = Map.get(input, :clml_head) || ""
    clause = Clause.read(Map.get(input, :rows, []), Map.get(input, :made))

    lrt(input) || coming_into_force(head) || eu(input, head, type) ||
      dated(clause) || enactment(head, type) || clause ||
      %__MODULE__{treatment: :no_clause}
  end

  defp dated(%__MODULE__{date: %Date{}} = clause), do: clause
  defp dated(_clause), do: nil

  defp lrt(%{lrt_date: %Date{} = d}),
    do: %__MODULE__{
      treatment: :lrt_metadata,
      date: d,
      evidence: "uk_lrt.md_coming_into_force_date"
    }

  defp lrt(_input), do: nil

  defp coming_into_force(head) do
    with [_, inner] <- Regex.run(~r{<ukm:ComingIntoForce>(.*?)</ukm:ComingIntoForce>}s, head),
         [_ | _] = dates <-
           Regex.scan(~r/Date="(\d{4}-\d{2}-\d{2})"/, inner, capture: :all_but_first) do
      date = dates |> List.flatten() |> Enum.map(&Date.from_iso8601!/1) |> Enum.min(Date)
      %__MODULE__{treatment: :clml_coming_into_force, date: date, evidence: "ukm:ComingIntoForce"}
    else
      _ -> nil
    end
  end

  defp enactment(head, type) when type in @acts do
    case Regex.run(~r/<ukm:EnactmentDate Date="(\d{4}-\d{2}-\d{2})"/, head) do
      [_, d] ->
        %__MODULE__{
          treatment: :act_enactment,
          date: Date.from_iso8601!(d),
          evidence: "ukm:EnactmentDate"
        }

      nil ->
        nil
    end
  end

  defp enactment(_head, _type), do: nil

  defp eu(input, head, type) when type in @eu,
    do: Eu.read(type, head, Map.get(input, :rows, []))

  defp eu(_input, _head, _type), do: nil
end
