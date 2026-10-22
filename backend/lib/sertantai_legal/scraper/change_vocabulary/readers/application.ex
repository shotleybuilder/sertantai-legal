defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Application do
  @moduledoc """
  A law's own application clauses as changes — primary (change vocabulary
  C6, Jason 2026-10-21: a provision's own application clause sets territory
  over the instrument's extent). Application is not extent: a law extending
  to the UK can apply in Northern Ireland only.

  - A whole-instrument clause ("From 1st January 2021 these Regulations
    apply in Northern Ireland only, …": SI 2012/3038 reg.1A) applies to
    every provision (target `"*"`), from its stated date, else from the
    start of the provision holding it (`clause`).
  - A provision's own clause ("This regulation applies in relation to
    England only") applies to that provision and those under it.

  Claims (source `:law_text`): `operation` `:applied`, `level`
  `:provision`, `territory`, `date` (stated), `clause` (the provision
  holding it), `by` (the law). The clauses are read by `ApplicationClause`
  (`parse_dated/1`, `parse_provision/1`). Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.ApplicationClause
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, Ref}
  alias SertantaiLegal.Scraper.Territory

  @doc "Claim sets `{key, target, claims}` for the law's application clauses."
  @spec read(String.t(), String.t()) :: [{String.t(), String.t(), [Claim.t()]}]
  def read(xml, law_name) do
    doc = SweetXml.parse(xml, quiet: true, namespace_conformant: false)

    for el <- xpath(doc, ~x"//*[@id]"l),
        ref = el |> xpath(~x"./@id"s) |> Ref.from_clml(law_name),
        ref != nil,
        text = el |> own() |> Doc.text(),
        text != "",
        {target, {:apply, regions}, date} <- clauses(text, ref),
        uniq: true do
      key = "#{law_name}:application:#{ref}"

      {key, target,
       Enum.concat([
         Claim.new(:law_text, :operation, :applied, key),
         Claim.new(:law_text, :level, :provision, key),
         Claim.new(:law_text, :territory, Territory.union(regions), key),
         Claim.new(:law_text, :date, date, key),
         Claim.new(:law_text, :clause, ref, key),
         Claim.new(:law_text, :by, law_name, key)
       ])}
    end
  end

  defp clauses(text, ref) do
    whole =
      case ApplicationClause.parse_dated(text) do
        {clause, date} -> [{"*", clause, date}]
        nil -> []
      end

    own =
      case ApplicationClause.parse_provision(text) do
        nil -> []
        clause -> [{ref, clause, nil}]
      end

    whole ++ own
  end

  # the provision's own words: not its number, title or sub-provisions
  defp own({:xmlElement, _, _, _, _, _, _, _, children, _, _, _} = el) do
    kept =
      Enum.flat_map(children, fn
        {:xmlElement, name, _, _, _, _, _, attrs, _, _, _, _} = c ->
          id? = Enum.any?(attrs, &match?({:xmlAttribute, :id, _, _, _, _, _, _, _, _}, &1))
          if name in [:Pnumber, :Title] or id?, do: [], else: [own(c)]

        other ->
          [other]
      end)

    put_elem(el, 8, kept)
  end
end
