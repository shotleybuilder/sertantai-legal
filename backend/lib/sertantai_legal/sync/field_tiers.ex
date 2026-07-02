defmodule SertantaiLegal.Sync.FieldTiers do
  @moduledoc """
  Maps field tiers to the LRT columns that should be synced.
  Each higher tier includes all columns from lower tiers.
  """

  @essential_columns [
    :id,
    :name,
    :title_en,
    :family,
    :year,
    :number,
    :type_desc,
    :live,
    :geo_extent,
    :source_url,
    :significance_rating,
    :significance_score,
    :significance_high_count,
    :significance_medium_count,
    :significance_low_count,
    :significance_total_obligations
  ]

  @standard_columns @essential_columns ++
                      [
                        :function,
                        :duty_holder,
                        :power_holder,
                        :rights_holder,
                        :purpose,
                        :duty_type,
                        :domain,
                        :geo_region,
                        :making_classification,
                        :making_review,
                        :is_making,
                        :fitness_person,
                        :fitness_process,
                        :fitness_place,
                        :fitness_plant,
                        :fitness_sector
                      ]

  @full_columns @standard_columns ++
                  [
                    :popimar,
                    :si_code,
                    :md_description,
                    :role,
                    :amending,
                    :amended_by,
                    :rescinding,
                    :rescinded_by,
                    :md_date,
                    :md_made_date,
                    :md_enactment_date,
                    :md_coming_into_force_date,
                    :latest_amend_date
                  ]

  @doc "Returns the list of LRT column atoms for the given field tier."
  def columns(:essential), do: @essential_columns
  def columns(:standard), do: @standard_columns
  def columns(:full), do: @full_columns
  def columns(tier) when is_binary(tier), do: columns(String.to_existing_atom(tier))
end
