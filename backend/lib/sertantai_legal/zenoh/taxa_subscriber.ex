defmodule SertantaiLegal.Zenoh.TaxaSubscriber do
  @moduledoc """
  Subscribes to fractalaw taxa enrichment data over Zenoh.

  Fractalaw publishes DRRP (duties, rights, responsibilities, powers) data
  as Arrow IPC streaming payloads. This subscriber decodes them with Explorer
  and upserts the taxa fields into existing LegalRegister records.

  Key expression: fractalaw/@{tenant}/taxa/enrichment/{law_name}
  """

  use GenServer
  require Logger
  require Ash.Query
  # import Ecto.Query, only: [from: 2]  # Removed with pruner (#110)

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Zenoh.ActivityLog

  # Static map from Arrow column name (string) → Ash attribute (atom).
  # Avoids String.to_existing_atom and any atom table exhaustion risk.
  @field_atoms %{
    "duty_holder" => :duty_holder,
    "rights_holder" => :rights_holder,
    "responsibility_holder" => :responsibility_holder,
    "power_holder" => :power_holder,
    "duty_type" => :duty_type,
    "role" => :role,
    "role_gvt" => :role_gvt,
    "duties" => :duties,
    "rights" => :rights,
    "responsibilities" => :responsibilities,
    "powers" => :powers,
    # Fitness / Applicability columns (Issue #39)
    "fitness_person" => :fitness_person,
    "fitness_process" => :fitness_process,
    "fitness_place" => :fitness_place,
    "fitness_plant" => :fitness_plant,
    "fitness_property" => :fitness_property,
    "fitness_sector" => :fitness_sector,
    "fitness" => :fitness,
    # Fitness v0.3 — reconciled entities and scope dimensions
    "fitness_entities" => :fitness_entities,
    "fitness_scope_dimensions" => :fitness_scope_dimensions,
    "fitness_mention_count" => :fitness_mention_count,
    "fitness_applies_count" => :fitness_applies_count,
    "fitness_disapplies_count" => :fitness_disapplies_count,
    # Significance (law-level aggregate)
    "significance_rating" => :significance_rating,
    "significance_score" => :significance_score,
    "significance_high_count" => :significance_high_count,
    "significance_medium_count" => :significance_medium_count,
    "significance_low_count" => :significance_low_count,
    "significance_total_obligations" => :significance_total_obligations,
    "significance_parts" => :significance_parts
  }

  @poll_interval :timer.seconds(2)
  @max_poll_attempts 30

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns current status for the admin dashboard."
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  catch
    :exit, _ -> %{state: :stopped, key_expr: nil}
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    ActivityLog.set_status(:taxa_subscriber, :connecting)
    send(self(), :setup)
    {:ok, %{subscriber_id: nil, poll_count: 0, key_expr: nil}}
  end

  @impl true
  def handle_info(:setup, state) do
    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        tenant = Application.get_env(:sertantai_legal, :zenoh)[:tenant] || "dev"
        key_expr = "fractalaw/@#{tenant}/taxa/enrichment/*"

        {:ok, subscriber_id} =
          Zenohex.Session.declare_subscriber(session_id, key_expr, self())

        Logger.info("[Zenoh.TaxaSubscriber] Subscribed to #{key_expr}")
        ActivityLog.set_status(:taxa_subscriber, :ready)
        ActivityLog.record(:taxa_subscriber, :connected, %{key_expr: key_expr})
        {:noreply, %{state | subscriber_id: subscriber_id, key_expr: key_expr}}

      {:error, :not_ready} ->
        if state.poll_count < @max_poll_attempts do
          Process.send_after(self(), :setup, @poll_interval)
          {:noreply, %{state | poll_count: state.poll_count + 1}}
        else
          Logger.error(
            "[Zenoh.TaxaSubscriber] Session not ready after #{@max_poll_attempts} attempts"
          )

          {:stop, :session_not_ready, state}
        end
    end
  end

  def handle_info(%Zenohex.Sample{} = sample, state) do
    law_name = sample.key_expr |> String.split("/") |> List.last()
    ActivityLog.increment(:taxa_subscriber, :received)

    case decode_and_upsert(law_name, sample.payload) do
      :ok ->
        ActivityLog.increment(:taxa_subscriber, :updated)
        ActivityLog.record(:taxa_subscriber, :updated, %{law_name: law_name})

        # Notify change detection for any org that has this law in their register
        notify_enrichment_change(law_name)

      {:error, reason} ->
        ActivityLog.increment(:taxa_subscriber, :failed)

        ActivityLog.record(:taxa_subscriber, :error, %{
          law_name: law_name,
          reason: inspect(reason)
        })

        Logger.error("[Zenoh.TaxaSubscriber] Failed to process #{law_name}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("[Zenoh.TaxaSubscriber] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      state: if(state.subscriber_id, do: :ready, else: :connecting),
      key_expr: state.key_expr
    }

    {:reply, status, state}
  end

  # --- Internal ---

  defp decode_and_upsert(law_name, ipc_bytes) do
    case decode_arrow_ipc(ipc_bytes) do
      {:ok, taxa} ->
        with {:ok, record} <- find_record(law_name),
             {:ok, _updated} <- upsert_taxa(record, taxa) do
          Logger.info("[Zenoh.TaxaSubscriber] Updated taxa for #{law_name}")
          :ok
        end

      {:error, :empty_payload} ->
        # No taxa data at all — Housekeeping (procedural/administrative law)
        with {:ok, record} <- find_record(law_name),
             {:ok, _updated} <- apply_housekeeping(record) do
          Logger.info("[Zenoh.TaxaSubscriber] Housekeeping for #{law_name} (empty payload)")
          :ok
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_arrow_ipc(ipc_bytes) do
    df = Explorer.DataFrame.load_ipc_stream!(ipc_bytes)
    rows = Explorer.DataFrame.to_rows(df, atom_keys: false)

    case rows do
      [row | _] -> {:ok, normalize_taxa(row)}
      [] -> {:error, :empty_payload}
    end
  rescue
    e -> {:error, {:decode_failed, Exception.message(e)}}
  end

  defp find_record(law_name) do
    LegalRegister
    |> Ash.Query.filter(name == ^law_name)
    |> Ash.read()
    |> case do
      {:ok, [record | _]} -> {:ok, record}
      {:ok, []} -> {:error, {:not_found, law_name}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp upsert_taxa(record, taxa) do
    taxa = convert_duty_type(taxa, record)
    taxa = derive_enrichment_result(record, taxa)

    Logger.info(
      "[Zenoh.TaxaSubscriber] Upserting #{record.name}: " <>
        "taxa_keys=#{inspect(Map.keys(taxa))}, " <>
        "function=#{inspect(taxa[:function])}, " <>
        "is_making=#{inspect(taxa[:is_making])}"
    )

    case Ash.update(record, taxa, action: :update) do
      {:ok, _} = result ->
        result

      {:error, reason} = err ->
        Logger.error(
          "[Zenoh.TaxaSubscriber] Ash.update failed for #{record.name}: #{inspect(reason)}"
        )

        err
    end
  end

  # Handle empty Arrow payload — enrichment ran but no taxa data was sent.
  # Determine label from existing record state:
  # - If record already has duty_type (from prior enrichment) → Empowering
  # - If record has no duty_type → Housekeeping
  defp apply_housekeeping(record) do
    label =
      case record.duty_type do
        %{values: values} when is_list(values) and values != [] -> "Empowering"
        _ -> "Housekeeping"
      end

    function = merge_enrichment_function(record, label)

    params =
      %{function: function}
      |> maybe_set_is_making(label)
      |> maybe_prune_lat(record, label)

    Ash.update(record, params, action: :update)
  end

  defp maybe_set_is_making(params, "Empowering"), do: Map.put(params, :is_making, false)
  defp maybe_set_is_making(params, _label), do: params

  @doc false
  def normalize_taxa(row) do
    # List<Utf8> columns → map with values key (matches existing JSONB format)
    # List<Struct> columns → map with entries key
    %{}
    |> put_holder_map(row, "duty_holder")
    |> put_holder_map(row, "rights_holder")
    |> put_holder_map(row, "responsibility_holder")
    |> put_holder_map(row, "power_holder")
    |> put_holder_map(row, "duty_type")
    |> put_list_field(row, "role")
    |> put_holder_map(row, "role_gvt")
    |> put_entries_map(row, "duties")
    |> put_entries_map(row, "rights")
    |> put_entries_map(row, "responsibilities")
    |> put_entries_map(row, "powers")
    # Fitness tag columns — List<Utf8> → text[] (same as role)
    |> put_list_field(row, "fitness_person")
    |> put_list_field(row, "fitness_process")
    |> put_list_field(row, "fitness_place")
    |> put_list_field(row, "fitness_plant")
    |> put_list_field(row, "fitness_property")
    |> put_list_field(row, "fitness_sector")
    # Fitness detail — List<Struct> → {:array, :map} (passed through directly)
    |> put_list_of_maps(row, "fitness")
    # Fitness v0.3 — reconciled entities and scope dimensions
    |> put_list_field(row, "fitness_entities")
    |> put_list_field(row, "fitness_scope_dimensions")
    |> put_scalar(row, "fitness_mention_count")
    |> put_scalar(row, "fitness_applies_count")
    |> put_scalar(row, "fitness_disapplies_count")
    # Significance — simple scalars (string, float, int)
    |> put_scalar(row, "significance_rating")
    |> put_scalar(row, "significance_score")
    |> put_scalar(row, "significance_high_count")
    |> put_scalar(row, "significance_medium_count")
    |> put_scalar(row, "significance_low_count")
    |> put_scalar(row, "significance_total_obligations")
    # significance_parts — Utf8 (JSON string) → {:array, :map}
    |> put_json_field(row, "significance_parts")
  end

  # Derive proper DRRP duty_type from structured entry columns.
  # Fractalaw places entries in the correct columns (duties, rights, responsibilities,
  # powers) but sends raw Obligation/Liberty labels in duty_type. We derive the
  # canonical DRRP vocabulary from which columns have entries.
  # Checks the incoming taxa first, then falls back to the existing record's entries
  # (covers the case where law-level enrichment arrives before provision-level).
  # Falls back to fractalaw's raw duty_type if no structured entries anywhere.
  defp convert_duty_type(taxa, record) do
    derived =
      []
      |> maybe_add_drrp("Duty", taxa[:duties] || record.duties)
      |> maybe_add_drrp("Right", taxa[:rights] || record.rights)
      |> maybe_add_drrp("Responsibility", taxa[:responsibilities] || record.responsibilities)
      |> maybe_add_drrp("Power", taxa[:powers] || record.powers)

    if derived != [] do
      Map.put(taxa, :duty_type, %{values: Enum.reverse(derived)})
    else
      taxa
    end
  end

  defp maybe_add_drrp(list, label, %{entries: entries})
       when is_list(entries) and entries != [],
       do: [label | list]

  defp maybe_add_drrp(list, _label, _), do: list

  @doc """
  Classify enrichment result from taxa fields. Public for testing.

  Returns the taxa map with `:is_making` and `:function` set based on duty_type values.
  """
  @spec classify_enrichment(map(), map()) :: map()
  def classify_enrichment(record, taxa) do
    taxa
    |> convert_duty_type(record)
    |> then(&derive_enrichment_result(record, &1))
  end

  # DRRP types that indicate the law creates substantive obligations.
  # Supports both old vocabulary (Duty, Responsibility) and new (Obligation).
  @making_duty_types ["Duty", "Responsibility", "Obligation"]

  # Derive enrichment result from taxa fields and set function labels.
  #
  # Three enrichment outcomes:
  # 1. Making:      duty_type has Duty/Responsibility/Obligation → is_making=true, function gets "Making"
  # 2. Empowering:  duty_type present but no making types (powers/rights only) → is_making=false, function gets "Empowering"
  # 3. Housekeeping: no taxa fields at all → function gets "Housekeeping", LAT pruned
  #
  # Note: does NOT overwrite making_classification (immutable auto-detection result).
  defp derive_enrichment_result(record, %{duty_type: %{values: values}} = taxa)
       when is_list(values) do
    is_making = Enum.any?(values, &(&1 in @making_duty_types))

    enrichment_label = if is_making, do: "Making", else: "Empowering"
    function = merge_enrichment_function(record, enrichment_label)

    taxa
    |> Map.put(:is_making, is_making)
    |> Map.put(:function, function)
    |> maybe_prune_lat(record, enrichment_label)
  end

  defp derive_enrichment_result(record, taxa) when map_size(taxa) > 0 do
    # Taxa analysis ran (has enrichment fields) but no duty_type → Empowering
    # This covers cases where only role/role_gvt/fitness are present without duty_type
    function = merge_enrichment_function(record, "Empowering")

    taxa
    |> Map.put(:is_making, false)
    |> Map.put(:function, function)
    |> maybe_prune_lat(record, "Empowering")
  end

  defp derive_enrichment_result(record, taxa) do
    # Empty taxa — no DRRP signal at all → Housekeeping
    function = merge_enrichment_function(record, "Housekeeping")

    taxa
    |> Map.put(:function, function)
    |> maybe_prune_lat(record, "Housekeeping")
  end

  # Merge enrichment function label into existing function JSONB.
  # Enrichment labels (Making, Empowering, Housekeeping) are mutually exclusive —
  # remove any existing enrichment label before adding the new one.
  # Relationship labels (Amending, Revoking, etc.) are preserved.
  @enrichment_labels ["Making", "Empowering", "Housekeeping"]

  defp merge_enrichment_function(record, new_label) do
    existing = record.function || %{}

    existing
    |> Map.drop(@enrichment_labels)
    |> Map.put(new_label, true)
  end

  # DISABLED — see #110. Pruner incorrectly classified HSWA as non-making and
  # deleted 835 LAT rows. Destructive action needs UI visibility before re-enabling.
  defp maybe_prune_lat(taxa, _record, _label), do: taxa

  # --- Change detection hook ---

  # If this law is in any org's register (status = 'yes'), log a
  # match_score_changed event so the Change Review Dashboard picks it up.
  # Runs inline but is a single lightweight query + insert per affected org.
  defp notify_enrichment_change(law_name) do
    alias SertantaiLegal.Sync.ApplicabilityEvent

    query = """
    SELECT oa.organization_id, oa.source
    FROM org_applicabilities oa
    WHERE oa.law_name = $1
      AND oa.status = 'yes'
      AND NOT EXISTS (
        SELECT 1 FROM applicability_events ae
        WHERE ae.organization_id = oa.organization_id
          AND ae.law_name = $1
          AND ae.event = 'match_score_changed'
          AND ae.inserted_at > (now() - interval '1 hour')
      )
    """

    case SertantaiLegal.Repo.query(query, [law_name]) do
      {:ok, %{rows: rows}} when rows != [] ->
        Enum.each(rows, fn [org_id, source] ->
          # Screener-sourced = moderate (profile match may have changed)
          # Manually confirmed = minor (informational, won't auto-remove)
          materiality = if source == "screener", do: "moderate", else: "minor"

          review_due_days = %{"moderate" => 60, "minor" => 90}
          due = Date.add(Date.utc_today(), review_due_days[materiality] || 90)

          org_id_str =
            case Ecto.UUID.load(org_id) do
              {:ok, str} -> str
              _ -> org_id
            end

          ApplicabilityEvent.log(%{
            organization_id: org_id_str,
            law_name: law_name,
            event: "match_score_changed",
            actor: "sertantai",
            status_before: "yes",
            status_after: "yes",
            source: "enrichment",
            materiality: materiality,
            review_due_date: due,
            metadata: %{
              "change_type" => "enrichment_update",
              "source" => "taxa_subscriber"
            }
          })
        end)

        Logger.debug(
          "[Zenoh.TaxaSubscriber] Logged enrichment change for #{law_name} " <>
            "affecting #{length(rows)} org(s)"
        )

      _ ->
        :ok
    end
  rescue
    e ->
      Logger.warning(
        "[Zenoh.TaxaSubscriber] Failed to notify enrichment change for #{law_name}: #{Exception.message(e)}"
      )
  end

  # List<Utf8> → %{values: ["a", "b"]} to match existing JSONB map format.
  # Strips "(inferred)" suffix and trailing bare colons from actor labels —
  # these are extraction_method indicators, not distinct actors.
  defp put_holder_map(acc, row, str_key) do
    case Map.get(row, str_key) do
      nil ->
        acc

      values when is_list(values) ->
        cleaned =
          values
          |> Enum.map(&clean_actor_label/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.uniq()

        Map.put(acc, @field_atoms[str_key], %{values: cleaned})

      _ ->
        acc
    end
  end

  defp clean_actor_label(label) when is_binary(label) do
    label
    |> String.replace(~r/\s*\(inferred\)\s*$/, "")
    |> String.replace(~r/:+\s*$/, "")
    |> String.trim()
  end

  defp clean_actor_label(label), do: label

  # role is {:array, :string} not :map
  defp put_list_field(acc, row, str_key) do
    case Map.get(row, str_key) do
      nil -> acc
      values when is_list(values) -> Map.put(acc, @field_atoms[str_key], values)
      _ -> acc
    end
  end

  # List<Struct> → %{entries: [%{holder, duty_type, clause, article}]}
  defp put_entries_map(acc, row, str_key) do
    case Map.get(row, str_key) do
      nil ->
        acc

      entries when is_list(entries) ->
        Map.put(acc, @field_atoms[str_key], %{entries: entries})

      _ ->
        acc
    end
  end

  # List<Struct> → [{map}] — stored directly as {:array, :map} (no wrapper)
  defp put_list_of_maps(acc, row, str_key) do
    case Map.get(row, str_key) do
      nil -> acc
      entries when is_list(entries) -> Map.put(acc, @field_atoms[str_key], entries)
      _ -> acc
    end
  end

  defp put_scalar(acc, row, str_key) do
    case Map.get(row, str_key) do
      nil -> acc
      value -> Map.put(acc, @field_atoms[str_key], value)
    end
  end

  defp put_json_field(acc, row, str_key) do
    case Map.get(row, str_key) do
      nil ->
        acc

      value when is_list(value) ->
        Map.put(acc, @field_atoms[str_key], value)

      value when is_binary(value) ->
        case Jason.decode(value) do
          {:ok, parsed} when is_list(parsed) -> Map.put(acc, @field_atoms[str_key], parsed)
          _ -> acc
        end

      _ ->
        acc
    end
  end
end
