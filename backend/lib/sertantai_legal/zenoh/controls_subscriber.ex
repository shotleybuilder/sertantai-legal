defmodule SertantaiLegal.Zenoh.ControlsSubscriber do
  @moduledoc """
  Subscribes to fractalaw AI-generated controls over Zenoh.

  Fractalaw publishes controls as Arrow IPC payloads, batched per law.
  This subscriber decodes them with Explorer and upserts into the controls
  table, then rebuilds control_mappings from linked_provisions.

  Key expressions:
  - `fractalaw/@{tenant}/controls/{law_name}` — N control rows per law
  - `fractalaw/@{tenant}/controls/predicate/{law_name}` — 1 policy predicate per law
  """

  use GenServer
  require Logger
  require Ash.Query

  alias SertantaiLegal.Legal.{Control, ControlMapping}
  alias SertantaiLegal.Zenoh.ActivityLog

  # Arrow column name → Ash attribute atom.
  # Avoids String.to_existing_atom and any atom table exhaustion risk.
  @field_atoms %{
    "law_name" => :law_name,
    "control_id" => :control_id,
    "title" => :title,
    "description" => :description,
    "what_it_checks" => :what_it_checks,
    "control_type" => :control_type,
    "nature" => :nature,
    "domain" => :domain,
    "frequency" => :frequency,
    "info_distance" => :info_distance,
    "blast_radius" => :blast_radius,
    "expected_touch_frequency" => :expected_touch_frequency,
    "mapping_strength" => :mapping_strength,
    "load_bearing_judgement" => :load_bearing_judgement,
    "evidence_type_a" => :evidence_type_a,
    "evidence_type_b" => :evidence_type_b,
    "honest_limit" => :honest_limit,
    "status" => :status,
    "tier" => :tier,
    "generation_model" => :generation_model,
    "base_hash" => :base_hash
  }

  # Predicate uses predicate_id instead of control_id
  @predicate_id_key "predicate_id"

  @poll_interval :timer.seconds(2)
  @max_poll_attempts 30

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  catch
    :exit, _ -> %{state: :stopped, key_expr: nil}
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    ActivityLog.set_status(:controls_subscriber, :connecting)
    send(self(), :setup)
    {:ok, %{subscriber_id: nil, poll_count: 0, key_expr: nil}}
  end

  @impl true
  def handle_info(:setup, state) do
    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        tenant = Application.get_env(:sertantai_legal, :zenoh)[:tenant] || "dev"
        key_expr = "fractalaw/@#{tenant}/controls/**"

        {:ok, subscriber_id} =
          Zenohex.Session.declare_subscriber(session_id, key_expr, self())

        Logger.info("[Zenoh.ControlsSubscriber] Subscribed to #{key_expr}")
        ActivityLog.set_status(:controls_subscriber, :ready)
        ActivityLog.record(:controls_subscriber, :connected, %{key_expr: key_expr})
        {:noreply, %{state | subscriber_id: subscriber_id, key_expr: key_expr}}

      {:error, :not_ready} ->
        if state.poll_count < @max_poll_attempts do
          Process.send_after(self(), :setup, @poll_interval)
          {:noreply, %{state | poll_count: state.poll_count + 1}}
        else
          Logger.error(
            "[Zenoh.ControlsSubscriber] Session not ready after #{@max_poll_attempts} attempts"
          )

          {:stop, :session_not_ready, state}
        end
    end
  end

  def handle_info(%Zenohex.Sample{} = sample, state) do
    {is_predicate, law_name} = parse_key_expr(sample.key_expr)
    ActivityLog.increment(:controls_subscriber, :received)

    case decode_and_upsert(law_name, is_predicate, sample.payload) do
      {:ok, count} ->
        ActivityLog.increment(:controls_subscriber, :updated)

        ActivityLog.record(:controls_subscriber, :updated, %{
          law_name: law_name,
          controls: count,
          is_predicate: is_predicate
        })

      {:error, reason} ->
        ActivityLog.increment(:controls_subscriber, :failed)

        ActivityLog.record(:controls_subscriber, :error, %{
          law_name: law_name,
          reason: inspect(reason)
        })

        Logger.error(
          "[Zenoh.ControlsSubscriber] Failed to process #{law_name}: #{inspect(reason)}"
        )
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("[Zenoh.ControlsSubscriber] Unexpected message: #{inspect(msg)}")
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

  # Parse key expression to determine message type and extract law_name.
  #
  # Controls:  fractalaw/@dev/controls/UK_uksi_1997_1713
  # Predicate: fractalaw/@dev/controls/predicate/UK_uksi_1997_1713
  defp parse_key_expr(key_expr) do
    segments = String.split(key_expr, "/")

    case segments do
      [_, _, "controls", "predicate", law_name] -> {true, law_name}
      [_, _, "controls", law_name] -> {false, law_name}
      _ -> {false, List.last(segments)}
    end
  end

  defp decode_and_upsert(law_name, is_predicate, ipc_bytes) do
    case decode_arrow_ipc(ipc_bytes) do
      {:ok, rows} ->
        results = Enum.map(rows, &upsert_control(&1, law_name, is_predicate))
        ok_count = Enum.count(results, &match?({:ok, _}, &1))

        real_errors =
          Enum.count(results, fn
            {:error, _} -> true
            _ -> false
          end)

        type = if is_predicate, do: "predicate", else: "controls"

        if real_errors > 0 do
          Logger.warning(
            "[Zenoh.ControlsSubscriber] #{law_name} #{type}: #{ok_count} ok, #{real_errors} failed"
          )
        else
          Logger.info("[Zenoh.ControlsSubscriber] Upserted #{ok_count} #{type} for #{law_name}")
        end

        {:ok, ok_count}

      {:error, :empty_payload} ->
        Logger.debug("[Zenoh.ControlsSubscriber] Empty payload for #{law_name}")
        {:ok, 0}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_arrow_ipc(ipc_bytes) do
    df = Explorer.DataFrame.load_ipc_stream!(ipc_bytes)
    rows = Explorer.DataFrame.to_rows(df, atom_keys: false)

    case rows do
      [] -> {:error, :empty_payload}
      rows -> {:ok, rows}
    end
  rescue
    e -> {:error, {:decode_failed, Exception.message(e)}}
  end

  defp upsert_control(row, law_name, is_predicate) do
    attrs = normalize_control(row, law_name, is_predicate)

    case Ash.create(Control, attrs, action: :upsert_from_fractalaw) do
      {:ok, control} ->
        rebuild_mappings(control)
        {:ok, control}

      {:error, reason} ->
        control_id = attrs[:control_id] || "unknown"

        Logger.error(
          "[Zenoh.ControlsSubscriber] Upsert failed for #{law_name}:#{control_id}: #{inspect(reason)}"
        )

        {:error, {:upsert_failed, control_id, reason}}
    end
  end

  @doc false
  def normalize_control(row, law_name, is_predicate) do
    # Map scalar fields via @field_atoms whitelist
    attrs =
      Enum.reduce(@field_atoms, %{}, fn {str_key, atom_key}, acc ->
        case Map.get(row, str_key) do
          nil -> acc
          value -> Map.put(acc, atom_key, value)
        end
      end)

    # Handle linked_provisions — List<Utf8> in Arrow, arrives as list of strings
    attrs =
      case Map.get(row, "linked_provisions") do
        nil -> attrs
        provisions when is_list(provisions) -> Map.put(attrs, :linked_provisions, provisions)
        _ -> attrs
      end

    # Ensure law_name is set (may not be in Arrow payload if implicit from key expression)
    attrs = Map.put_new(attrs, :law_name, law_name)

    # For predicates: map predicate_id → control_id, set is_predicate flag
    attrs =
      if is_predicate do
        predicate_id = Map.get(row, @predicate_id_key) || attrs[:control_id]

        attrs
        |> Map.put(:control_id, predicate_id)
        |> Map.put(:is_predicate, true)
      else
        Map.put_new(attrs, :is_predicate, false)
      end

    attrs
  end

  # Rebuild control_mappings from the control's linked_provisions.
  # Deletes existing mappings for this control, then creates new ones.
  defp rebuild_mappings(%Control{} = control) do
    provisions = control.linked_provisions || []
    if provisions == [], do: :ok, else: do_rebuild_mappings(control, provisions)
  end

  defp do_rebuild_mappings(control, provisions) do
    # Delete existing mappings for this control
    case ControlMapping
         |> Ash.Query.filter(control_id == ^control.id)
         |> Ash.read() do
      {:ok, existing} ->
        Enum.each(existing, fn mapping ->
          Ash.destroy!(mapping)
        end)

      {:error, reason} ->
        Logger.warning(
          "[Zenoh.ControlsSubscriber] Failed to read existing mappings for #{control.law_name}: #{inspect(reason)}"
        )
    end

    # Create new mappings from linked_provisions.
    # fractalaw may send full section_ids (UK_uksi_1997_1713:reg.3(1))
    # or short refs (reg.3(1)). Detect by checking for the law_name prefix.
    results =
      Enum.map(provisions, fn ref ->
        {section_id, short_ref} =
          if String.starts_with?(ref, control.law_name <> ":") do
            short = String.replace_prefix(ref, control.law_name <> ":", "")
            {ref, short}
          else
            {"#{control.law_name}:#{ref}", ref}
          end

        # Normalize art. → reg. for non-EU domestic instruments.
        # art. is reserved for EU retained law (eudr/eur). All domestic
        # instruments (uksi, ssi, ukpga, etc.) use reg.
        {section_id, short_ref} =
          normalize_domestic_prefix(control.law_name, section_id, short_ref)

        case Ash.create(
               ControlMapping,
               %{
                 control_id: control.id,
                 law_name: control.law_name,
                 section_id: section_id,
                 short_ref: short_ref,
                 mapping_strength: control.mapping_strength
               },
               action: :upsert
             ) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, {:mapping_failed, section_id, reason}}
        end
      end)

    ok_count = Enum.count(results, &(&1 == :ok))
    failed = Enum.count(results, &match?({:error, _}, &1))

    if failed > 0 do
      Logger.warning(
        "[Zenoh.ControlsSubscriber] Mappings for #{control.law_name}: #{ok_count} ok, #{failed} failed"
      )
    end

    :ok
  end

  # EU retained law type_codes — these use art. prefix legitimately.
  @eu_type_codes ["eudr", "eur"]

  # Normalize art. → reg. for domestic instruments.
  # Extracts the type_code from law_name (e.g. UK_uksi_1997_1713 → uksi)
  # and replaces art. with reg. unless it's EU retained law.
  defp normalize_domestic_prefix(law_name, section_id, short_ref) do
    type_code = extract_type_code(law_name)

    if type_code not in @eu_type_codes and String.contains?(short_ref, "art.") do
      new_short = String.replace(short_ref, "art.", "reg.")
      new_section = "#{law_name}:#{new_short}"
      {new_section, new_short}
    else
      {section_id, short_ref}
    end
  end

  # UK_uksi_1997_1713 → uksi, UK_ssi_2006_456 → ssi, UK_eudr_2010_35 → eudr
  defp extract_type_code(law_name) do
    case String.split(law_name, "_", parts: 4) do
      [_, type_code, _, _] -> type_code
      _ -> ""
    end
  end
end
