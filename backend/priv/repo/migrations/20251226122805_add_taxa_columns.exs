defmodule SertantaiLegal.Repo.Migrations.AddTaxaColumns do
  use Ecto.Migration

  def change do
    alter table(:uk_lrt) do
      # duty_type and related columns
      add_if_not_exists :duty_type, :text
      add_if_not_exists :duty_type_article, :text
      add_if_not_exists :article_duty_type, :text

      # popimar article columns (popimar and popimar_article_clause already exist)
      add_if_not_exists :popimar_article, :text
      add_if_not_exists :article_popimar, :text
    end
  end
end
