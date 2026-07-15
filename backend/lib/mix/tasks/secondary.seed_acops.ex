defmodule Mix.Tasks.Secondary.SeedAcops do
  @shortdoc "Seed current HSE Approved Codes of Practice with parent law links"

  @moduledoc """
  Registers the ~25 current HSE ACoPs as secondary sources and links
  each to its parent legislation in the legal register.

  ## Usage

      mix secondary.seed_acops
      mix secondary.seed_acops --dry-run

  Idempotent — skips sources that already exist (matched by source_id).
  """

  use Mix.Task

  require Ash.Query

  alias SertantaiLegal.Legal.SecondarySource
  alias SertantaiLegal.Legal.SourceLink

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: [dry_run: :boolean])
    dry_run? = Keyword.get(opts, :dry_run, false)

    IO.puts("=== Seed HSE Approved Codes of Practice ===")
    IO.puts("Mode: #{if dry_run?, do: "DRY RUN", else: "APPLY"}\n")

    acops = acop_catalog()
    IO.puts("Catalog: #{length(acops)} ACoPs\n")

    {created, skipped, errors} =
      Enum.reduce(acops, {0, 0, 0}, fn acop, {c, s, e} ->
        case register_acop(acop, dry_run?) do
          :created -> {c + 1, s, e}
          :skipped -> {c, s + 1, e}
          :error -> {c, s, e + 1}
        end
      end)

    IO.puts("\n=== Summary ===")
    IO.puts("Created: #{created}")
    IO.puts("Skipped: #{skipped} (already exist)")
    if errors > 0, do: IO.puts("Errors:  #{errors}")
  end

  defp register_acop(acop, dry_run?) do
    %{source_id: source_id, title: title, links: links} = acop

    # Check if already exists
    existing =
      SecondarySource
      |> Ash.Query.filter(source_id == ^source_id)
      |> Ash.read!()

    case existing do
      [_ | _] ->
        IO.puts("  SKIP  #{source_id} (exists)")
        :skipped

      [] ->
        if dry_run? do
          IO.puts("  WOULD #{source_id} — #{title}")

          Enum.each(links, fn {law_name, link_type} ->
            IO.puts("         → #{law_name} (#{link_type})")
          end)

          :created
        else
          do_register(acop)
        end
    end
  end

  defp do_register(acop) do
    %{source_id: source_id, title: title, links: links} = acop

    attrs = %{
      source_id: source_id,
      source_type: :acop,
      title: title,
      issuer: "HSE",
      legal_weight: :reverse_burden,
      status: Map.get(acop, :status, :current),
      edition: Map.get(acop, :edition),
      effective_date: Map.get(acop, :effective_date),
      structure_type: Map.get(acop, :structure_type, :sections)
    }

    case Ash.create(SecondarySource, attrs, action: :create) do
      {:ok, source} ->
        IO.puts("  OK    #{source_id} — #{title}")
        create_links(source, links)
        :created

      {:error, error} ->
        IO.puts("  ERROR #{source_id}: #{inspect(error)}")
        :error
    end
  end

  defp create_links(source, links) do
    Enum.each(links, fn {law_name, link_type} ->
      attrs = %{
        secondary_source_id: source.id,
        law_name: law_name,
        link_type: link_type
      }

      case Ash.create(SourceLink, attrs, action: :create) do
        {:ok, _} ->
          IO.puts("         → #{law_name} (#{link_type})")

        {:error, error} ->
          IO.puts("         ✗ #{law_name}: #{inspect(error)}")
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # ACoP Catalog
  #
  # Current HSE Approved Codes of Practice (L-series publications containing
  # ACoPs approved under HSWA s.16). Excludes withdrawn ACoPs.
  #
  # Parent law links use the legal_register.name convention.
  # ---------------------------------------------------------------------------

  defp acop_catalog do
    [
      # --- HSWA 1974 general duties ---
      %{
        source_id: "L1",
        title: "Management of Health and Safety at Work — ACoP",
        edition: "3rd edition, 2000",
        links: [{"UK_uksi_1999_3242", :approved_under}]
      },
      %{
        source_id: "L5",
        title: "Control of Substances Hazardous to Health — ACoP",
        edition: "6th edition, 2013",
        links: [{"UK_uksi_2002_2677", :approved_under}]
      },
      %{
        source_id: "L8",
        title: "Legionella — ACoP and Guidance",
        edition: "4th edition, 2013",
        links: [
          {"UK_ukpga_1974_37", :approved_under},
          {"UK_uksi_2002_2677", :approved_under}
        ]
      },
      %{
        source_id: "L21",
        title: "Management of Health and Safety at Work — ACoP (Young Persons)",
        edition: "2nd edition, 2000",
        links: [{"UK_uksi_1999_3242", :approved_under}]
      },
      %{
        source_id: "L22",
        title: "Safe Use of Work Equipment — ACoP and Guidance",
        edition: "4th edition, 2014",
        links: [{"UK_uksi_1998_2306", :approved_under}]
      },
      %{
        source_id: "L23",
        title: "Manual Handling Operations — ACoP and Guidance",
        edition: "4th edition, 2016",
        links: [{"UK_uksi_1992_2793", :approved_under}]
      },
      %{
        source_id: "L24",
        title: "Workplace Health, Safety and Welfare — ACoP and Guidance",
        edition: "2nd edition, 2013",
        links: [{"UK_uksi_1992_3004", :approved_under}]
      },
      %{
        source_id: "L25",
        title: "Personal Protective Equipment at Work — ACoP and Guidance",
        edition: "3rd edition, 2015",
        links: [{"UK_uksi_2002_2174", :approved_under}]
      },
      %{
        source_id: "L26",
        title: "Display Screen Equipment — ACoP and Guidance",
        edition: "2nd edition, 2013",
        links: [{"UK_uksi_1992_2792", :approved_under}]
      },

      # --- Construction ---
      %{
        source_id: "L153",
        title: "Managing Health and Safety in Construction — ACoP",
        edition: "2015",
        links: [{"UK_uksi_2015_51", :approved_under}]
      },

      # --- Dangerous substances and explosives ---
      %{
        source_id: "L134",
        title: "Design and Construction of Vents and Vent Systems — ACoP",
        edition: "2003",
        links: [{"UK_uksi_2002_2776", :approved_under}]
      },
      %{
        source_id: "L135",
        title: "Storage of Dangerous Substances — ACoP",
        edition: "2003",
        links: [{"UK_uksi_2002_2776", :approved_under}]
      },
      %{
        source_id: "L136",
        title: "Control and Mitigation Measures in DSEAR — ACoP",
        edition: "2003",
        links: [{"UK_uksi_2002_2776", :approved_under}]
      },
      %{
        source_id: "L137",
        title: "Storage of Flammable Liquids in Containers — ACoP and Guidance",
        edition: "2nd edition, 2015",
        links: [{"UK_uksi_2002_2776", :approved_under}]
      },
      %{
        source_id: "L138",
        title: "Dangerous Substances and Explosive Atmospheres — ACoP",
        edition: "2nd edition, 2013",
        links: [{"UK_uksi_2002_2776", :approved_under}]
      },

      # --- First aid ---
      %{
        source_id: "L74",
        title: "First Aid at Work — ACoP and Guidance",
        edition: "3rd edition, 2013",
        links: [{"UK_uksi_1981_917", :approved_under}]
      },

      # --- Noise and vibration ---
      %{
        source_id: "L108",
        title: "Controlling Noise at Work — ACoP and Guidance",
        edition: "2nd edition, 2005",
        links: [{"UK_uksi_2005_1643", :approved_under}]
      },
      %{
        source_id: "L140",
        title: "Hand-Arm Vibration — ACoP and Guidance",
        edition: "2005",
        links: [{"UK_uksi_2005_1093", :approved_under}]
      },
      %{
        source_id: "L141",
        title: "Whole-Body Vibration — ACoP and Guidance",
        edition: "2005",
        links: [{"UK_uksi_2005_1093", :approved_under}]
      },

      # --- Pressure systems ---
      %{
        source_id: "L122",
        title: "Safety of Pressure Systems — ACoP and Guidance",
        edition: "2nd edition, 2014",
        links: [{"UK_uksi_2000_128", :approved_under}]
      },

      # --- Lifting and work at height ---
      %{
        source_id: "L113",
        title: "Safe Use of Lifting Equipment — ACoP and Guidance",
        edition: "2nd edition, 2014",
        links: [{"UK_uksi_1998_2307", :approved_under}]
      },

      # --- Asbestos ---
      %{
        source_id: "L127",
        title: "Management of Asbestos in Non-domestic Premises — ACoP and Guidance",
        edition: "2nd edition, 2012",
        links: [{"UK_uksi_2012_632", :approved_under}]
      },
      %{
        source_id: "L143",
        title: "Work with Materials Containing Asbestos — ACoP",
        edition: "2nd edition, 2013",
        links: [{"UK_uksi_2012_632", :approved_under}]
      },

      # --- Control of Major Accident Hazards ---
      %{
        source_id: "L111",
        title: "COMAH — ACoP and Guidance",
        edition: "3rd edition, 2015",
        links: [{"UK_uksi_2015_483", :approved_under}]
      },

      # --- Confined spaces ---
      %{
        source_id: "L101",
        title: "Safe Work in Confined Spaces — ACoP and Guidance",
        edition: "2nd edition, 2014",
        links: [{"UK_uksi_1997_1713", :approved_under}]
      },

      # --- Electricity ---
      %{
        source_id: "L44",
        title: "Safety in Electrical Testing at Work — Guidance (with ACoP extracts)",
        edition: "1995",
        links: [{"UK_uksi_1989_635", :approved_under}]
      },

      # --- Lead ---
      %{
        source_id: "L132",
        title: "Control of Lead at Work — ACoP",
        edition: "3rd edition, 2002",
        links: [{"UK_uksi_2002_2676", :approved_under}]
      },

      # --- Genetically modified organisms ---
      %{
        source_id: "L29",
        title: "Genetically Modified Organisms (Contained Use) — ACoP",
        edition: "4th edition, 2014",
        links: [{"UK_uksi_2014_1663", :approved_under}]
      },

      # --- Ionising radiation ---
      %{
        source_id: "L121",
        title: "Ionising Radiation — ACoP and Guidance",
        edition: "2nd edition, 2018",
        links: [{"UK_uksi_2017_1075", :approved_under}]
      }
    ]
  end
end
