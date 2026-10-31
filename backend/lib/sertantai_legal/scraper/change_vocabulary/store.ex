defmodule SertantaiLegal.Scraper.ChangeVocabulary.Store do
  @moduledoc """
  The change register's tables, `provision_changes` and
  `provision_change_claims` (CV-04): a law's merged changes are written
  together (delete + insert by `law_name`, one transaction), so they always
  match its latest build, and read back as `Change` structs — what the
  label fold reads. Tiers and conflicts are not stored; they are derived on
  read (`Evidence.derive/1`). Each build is a `changes_built` lat_event
  holding the code version and its inputs' fingerprints.

  DB only; claim values go through `Store.Codec`. Names read back
  (sources, attributes, operations) become atoms with `String.to_atom/1`:
  they are this table's own, written from atoms, and a reader's atoms may
  not be loaded yet in a fresh VM.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence, Store, Version}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store.Codec

  defdelegate encode(value), to: Codec
  defdelegate decode(map), to: Codec

  @doc """
  Replace `law`'s changes with `changes` (resolved), and record the build
  (`inputs`: what it was built from, for staleness). Returns `{:ok,
  %{changes: n, claims: m}}`.
  """
  @spec write(String.t(), [Change.t()], map()) ::
          {:ok, %{changes: non_neg_integer(), claims: non_neg_integer()}}
  def write(law, changes, inputs \\ %{}) do
    version = Version.current()
    now = DateTime.utc_now()

    rows =
      for c <- changes do
        id = Ecto.UUID.generate()
        r = c.resolved

        change = %{
          id: Ecto.UUID.dump!(id),
          law_name: law,
          key: c.key,
          target: c.target,
          aliases: c.aliases,
          operation: r.operation && to_string(r.operation),
          level: r.level && to_string(r.level),
          territory: r.territory,
          date: r.date,
          by: r.by,
          commenced_by: r.commenced_by,
          retained: r.retained,
          partial: r.partial,
          saved: r.saved,
          sources: Map.new(r.sources, fn {a, s} -> {to_string(a), s && to_string(s)} end),
          code_version: version,
          built_at: now
        }

        claims =
          c.claims
          |> Enum.with_index()
          |> Enum.map(fn {cl, i} ->
            %{
              id: Ecto.UUID.bingenerate(),
              change_id: change.id,
              position: i,
              source: to_string(cl.source),
              attribute: to_string(cl.attribute),
              value: Codec.encode(cl.value),
              ref: cl.ref
            }
          end)

        {change, claims}
      end

    changes_rows = Enum.map(rows, &elem(&1, 0))
    claim_rows = Enum.flat_map(rows, &elem(&1, 1))

    Repo.transaction(
      fn ->
        Repo.query!("DELETE FROM provision_changes WHERE law_name = $1", [law])

        for chunk <- Enum.chunk_every(changes_rows, 2_000),
            do: Repo.insert_all("provision_changes", chunk)

        for chunk <- Enum.chunk_every(claim_rows, 5_000),
            do: Repo.insert_all("provision_change_claims", chunk)

        record(law, version, inputs, length(changes_rows), length(claim_rows))
        %{changes: length(changes_rows), claims: length(claim_rows)}
      end,
      timeout: :infinity
    )
  end

  # the build, as a lat_event (as `LabelRefresh.record_success/2`)
  defp record(law, version, inputs, changes, claims) do
    Repo.query!(
      """
      INSERT INTO lat_events (law_id, country, law_name, event, at, source, provenance)
      SELECT id, country, name, 'changes_built', now() AT TIME ZONE 'utc', 'change_vocabulary', $2
      FROM legal_register WHERE name = $1
      """,
      [law, %{code_version: version, inputs: inputs, changes: changes, claims: claims}]
    )
  end

  @doc """
  Each built law's latest build (its `changes_built` event): the code
  version and the inputs recorded (`Store.Inputs`), as atoms.
  """
  @spec builds() :: %{String.t() => %{code_version: String.t() | nil, inputs: map()}}
  def builds do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT DISTINCT ON (law_name) law_name, provenance
        FROM lat_events WHERE event = 'changes_built'
        ORDER BY law_name, at DESC, id DESC
        """,
        [],
        timeout: :infinity
      )

    known = Map.new(Store.Inputs.keys(), &{to_string(&1), &1})

    Map.new(rows, fn [law, p] ->
      inputs = for {k, v} <- p["inputs"] || %{}, a = known[k], into: %{}, do: {a, v}

      {law,
       %{
         code_version: p["code_version"],
         inputs: inputs,
         affecting: get_in(p, ["inputs", "affecting"]),
         commencement_sources: get_in(p, ["inputs", "commencement_sources"])
       }}
    end)
  end

  @doc "`law`'s stored changes, resolved, with tiers and conflicts derived."
  @spec for_law(String.t()) :: [Change.t()]
  def for_law(law) do
    %{rows: changes} =
      Repo.query!(
        """
        SELECT id, key, target, aliases, operation, level, territory, date, by, commenced_by,
               retained, partial, saved, sources
        FROM provision_changes WHERE law_name = $1 ORDER BY key, target
        """,
        [law]
      )

    %{rows: claims} =
      Repo.query!(
        """
        SELECT cl.change_id, cl.source, cl.attribute, cl.value, cl.ref
        FROM provision_change_claims cl JOIN provision_changes c ON c.id = cl.change_id
        WHERE c.law_name = $1 ORDER BY cl.change_id, cl.position
        """,
        [law]
      )

    claims =
      Enum.group_by(
        claims,
        &hd/1,
        fn [_, source, attribute, value, ref] ->
          %Claim{
            source: String.to_atom(source),
            attribute: String.to_atom(attribute),
            value: Codec.decode(value),
            ref: ref
          }
        end
      )

    for [
          id,
          key,
          target,
          aliases,
          op,
          level,
          territory,
          date,
          by,
          commenced_by,
          retained,
          partial,
          saved,
          sources
        ] <- changes do
      resolved =
        %Evidence.Resolved{
          operation: op && String.to_atom(op),
          level: level && String.to_atom(level),
          territory: territory,
          date: date,
          by: by,
          commenced_by: commenced_by,
          retained: retained,
          partial: partial,
          saved: saved,
          sources:
            Map.new(sources, fn {a, s} ->
              {String.to_atom(a), s && String.to_atom(s)}
            end)
        }

      Evidence.derive(%Change{
        key: key,
        target: target,
        aliases: aliases,
        claims: Map.get(claims, id, []),
        resolved: resolved
      })
    end
  end
end
