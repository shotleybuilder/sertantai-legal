defmodule SertantaiLegal.Scraper.Amendment.ReadLaw do
  @moduledoc """
  Reading one amending law into amendment rules, from the text held now
  (amendment-rules AR-03): the read pass's reading (`mix lat.amending
  --read`, which stores the rules and the index), and the vocabulary's
  where an amending law's stored rules are stale (run time, 2026-10-25:
  build and golden used stale rules silently).

  - `notes/2`: the amendment notes on our rows pointing to the amending
    law (the collector's pointer: Citation, else the law the text names);
  - `law_ref/1`: a LAT law as the reader matches it (title, rows' prefix);
  - `rules/3`: the rules the amending law's provisions at `refs` state for
    `laws`.

  The reader decides each law offered on its own, so the rules for one law
  are the same whether it is read alone or among others.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Locator, Pointer}
  alias SertantaiLegal.Scraper.Amendment.{ProvisionRead, Reader, Rule}

  @type note :: %{
          law_name: String.t(),
          code: String.t() | nil,
          text: String.t() | nil,
          citation_law: String.t() | nil,
          affected_sections: [String.t()]
        }

  @doc "The amending law's document from the CLML store, or nil when not held (`Amendment.LawDoc.doc/1`)."
  @spec doc(String.t()) :: Doc.t() | nil
  defdelegate doc(amending), to: SertantaiLegal.Scraper.Amendment.LawDoc

  @doc """
  The amendment notes on our LAT rows pointing to `amending` — all of
  them, or only those on `law`'s rows.
  """
  @spec notes(String.t(), String.t() | nil) :: [note()]
  def notes(amending, law \\ nil) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT law_name, code, text, coalesce(citation_law, changed_by), affected_sections
        FROM amendment_annotations
        WHERE code_type = 'amendment' AND coalesce(citation_law, changed_by) = $1
          AND law_name IN (SELECT DISTINCT law_name FROM legal_articles)
          AND ($2::text IS NULL OR law_name = $2)
        """,
        [amending, law]
      )

    for [l, code, text, cl, sids] <- rows,
        do: %{
          law_name: l,
          code: code,
          text: text,
          citation_law: cl,
          affected_sections: sids || []
        }
  end

  @doc "The provisions of `amending` the notes point to."
  @spec note_refs(String.t(), [note()]) :: [Pointer.ref()]
  def note_refs(amending, notes) do
    for n <- notes,
        p = Pointer.parse(n),
        p.affecting_law == amending,
        ref <- p.provisions,
        do: ref
  end

  @doc "A LAT law's ref as the reader matches it: its title (no year) and its rows' prefix."
  @spec law_ref(String.t()) :: Reader.law_ref()
  def law_ref(law) do
    title =
      case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law]) do
        %{rows: [[t]]} when is_binary(t) ->
          own_title(t, law)

        _ ->
          nil
      end

    # the rows' prefix, and whether legislation.gov.uk numbers them as
    # articles (an Order under reg.: `Reader.law_ref/4`)
    {prefix, articles?} =
      case Repo.query!(
             "SELECT substring(section_id from ':(s|reg|art|rule)\\.'), source_xml_id LIKE 'article-%' FROM legal_articles WHERE law_name = $1 AND section_id ~ ':(s|reg|art|rule)\\.' LIMIT 1",
             [law]
           ) do
        %{rows: [[p, a]]} when is_binary(p) -> {p, a == true}
        _ -> {"s", false}
      end

    Reader.law_ref(law, title, prefix, articles: articles?)
  end

  @doc """
  A law's title as amending texts name it: the register's title less the
  law's own year at its end. A year inside the title stays ("Deregulation
  Act 2015 (Health and Safety at Work) … Order 2015", SI 2015/1637, had
  been cut to "Deregulation Act" and read as the Act; Waste, Water and
  Climate 2026-11-26).
  """
  @spec own_title(String.t(), String.t()) :: String.t()
  def own_title(title, law) do
    year = law |> String.split("_") |> Enum.at(2)
    # (a register note or a stray full stop after the year goes first:
    # "… Act 1972 (repealed 27.5.1997)", "… Regulations 2018.")
    title
    |> String.trim()
    |> String.replace(~r/\s*\((?:repealed|revoked)\b[^)]*\)$/i, "")
    |> String.trim_trailing(".")
    |> String.replace_suffix(" " <> to_string(year), "")
    |> String.trim()
  end

  @doc """
  The rules `doc`'s provisions at `refs` state for `laws`, with the
  provision ids read.
  """
  @spec rules(Doc.t(), [Reader.law_ref()], [Pointer.ref()]) :: {[Rule.t()], [String.t()]}
  def rules(doc, laws, refs) do
    ids = for ref <- Enum.uniq(refs), id <- Locator.ids(doc, ref), uniq: true, do: id
    {Enum.flat_map(ids, &ProvisionRead.read(doc, &1, laws)), ids}
  end
end
