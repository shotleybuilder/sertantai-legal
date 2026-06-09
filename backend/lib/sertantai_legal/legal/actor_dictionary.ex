defmodule SertantaiLegal.Legal.ActorDictionary do
  @moduledoc """
  Actor Dictionary — single source of truth for canonical actor labels.

  Loaded from fractalaw via Zenoh queryable on startup. Falls back to a
  bundled YAML snapshot if Zenoh is unavailable.

  Provides:
  - `canonical_labels/0` — all canonical labels (for Baserow vocabulary validation)
  - `governed_labels/0` — labels for governed entities (Org, Ind, SC, Svc, Public, etc.)
  - `government_labels/0` — labels for government entities (Gvt, EU)
  - `category/1` — category for a label (e.g., "Org", "Gvt", "Ind")
  - `valid?/1` — is this label in the dictionary?
  - `categories/0` — all categories with their labels
  """

  use GenServer
  require Logger

  @table :actor_dictionary
  @snapshot_path "priv/data/actor-dictionary.yaml"

  # Categories that represent government actors
  @government_categories MapSet.new(["Gvt", "EU"])

  # ── Client API ──────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "All canonical actor labels."
  def canonical_labels do
    :ets.tab2list(@table)
    |> Enum.map(fn {label, _category, _triggers} -> label end)
    |> Enum.sort()
  end

  @doc "Governed entity labels (Org, Ind, SC, Svc, Public, Offshore, etc.)."
  def governed_labels do
    :ets.tab2list(@table)
    |> Enum.reject(fn {_label, category, _triggers} ->
      MapSet.member?(@government_categories, category)
    end)
    |> Enum.map(fn {label, _category, _triggers} -> label end)
    |> Enum.sort()
  end

  @doc "Government entity labels (Gvt, EU)."
  def government_labels do
    :ets.tab2list(@table)
    |> Enum.filter(fn {_label, category, _triggers} ->
      MapSet.member?(@government_categories, category)
    end)
    |> Enum.map(fn {label, _category, _triggers} -> label end)
    |> Enum.sort()
  end

  @doc "Get the category for a label. Returns nil if not in dictionary."
  def category(label) do
    case :ets.lookup(@table, label) do
      [{^label, category, _triggers}] -> category
      [] -> nil
    end
  end

  @doc "Is this label in the dictionary?"
  def valid?(label) do
    :ets.member(@table, label)
  end

  @doc "Is this a government actor label?"
  def government?(label) do
    case category(label) do
      nil -> false
      cat -> MapSet.member?(@government_categories, cat)
    end
  end

  @doc "All categories with their labels, as a map."
  def categories do
    :ets.tab2list(@table)
    |> Enum.group_by(
      fn {_label, category, _triggers} -> category end,
      fn {label, _category, _triggers} -> label end
    )
    |> Map.new(fn {cat, labels} -> {cat, Enum.sort(labels)} end)
  end

  @doc "Number of entries in the dictionary."
  def count do
    :ets.info(@table, :size)
  end

  @doc "Reload the dictionary from Zenoh or snapshot."
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  # ── Server Callbacks ────────────────────────────────────────

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set])
    load_dictionary()
    subscribe_to_updates()
    {:ok, %{}}
  end

  @impl true
  def handle_call(:reload, _from, state) do
    load_dictionary()
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(%Zenohex.Sample{} = sample, state) do
    case parse_yaml(sample.payload) do
      {:ok, entries} ->
        populate_ets(entries)
        Logger.info("[ActorDictionary] Reloaded #{length(entries)} actors from Zenoh publish")

      {:error, reason} ->
        Logger.warning("[ActorDictionary] Failed to parse dictionary update: #{reason}")
    end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ── Subscription ────────────────────────────────────────────

  defp subscribe_to_updates do
    if Application.get_env(:sertantai_legal, :test_mode, false) do
      :ok
    else
      do_subscribe()
    end
  end

  defp do_subscribe do
    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        tenant = Application.get_env(:sertantai_legal, :zenoh)[:tenant] || "dev"
        key_expr = "fractalaw/@#{tenant}/dictionary/actors"

        case Zenohex.Session.declare_subscriber(session_id, key_expr, self()) do
          {:ok, _subscriber_id} ->
            Logger.info("[ActorDictionary] Subscribed to #{key_expr}")

          {:error, reason} ->
            Logger.warning("[ActorDictionary] Failed to subscribe: #{inspect(reason)}")
        end

      {:error, _reason} ->
        Logger.debug("[ActorDictionary] Zenoh not ready, skipping subscription")
    end
  rescue
    e -> Logger.warning("[ActorDictionary] Subscribe failed: #{Exception.message(e)}")
  catch
    :exit, _reason -> Logger.debug("[ActorDictionary] Zenoh not running, skipping subscription")
  end

  # ── Loading ─────────────────────────────────────────────────

  defp load_dictionary do
    if Application.get_env(:sertantai_legal, :test_mode, false) do
      load_from_snapshot()
    else
      case load_from_zenoh() do
        {:ok, entries} ->
          populate_ets(entries)
          Logger.info("[ActorDictionary] Loaded #{length(entries)} actors from Zenoh")

        {:error, reason} ->
          Logger.warning("[ActorDictionary] Zenoh unavailable (#{reason}), loading snapshot")
          load_from_snapshot()
      end
    end
  end

  defp load_from_zenoh do
    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        tenant = Application.get_env(:sertantai_legal, :zenoh)[:tenant] || "dev"
        key_expr = "fractalaw/@#{tenant}/dictionary/actors"

        case Zenohex.Session.get(session_id, key_expr, timeout: 5000) do
          {:ok, [%{payload: payload} | _]} when is_binary(payload) ->
            parse_yaml(payload)

          {:ok, []} ->
            {:error, :no_response}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
  catch
    :exit, reason -> {:error, {:exit, inspect(reason)}}
  end

  defp load_from_snapshot do
    path = Application.app_dir(:sertantai_legal, @snapshot_path)

    case File.read(path) do
      {:ok, content} ->
        case parse_yaml(content) do
          {:ok, entries} ->
            populate_ets(entries)
            Logger.info("[ActorDictionary] Loaded #{length(entries)} actors from snapshot")

          {:error, reason} ->
            Logger.error("[ActorDictionary] Failed to parse snapshot: #{reason}")
        end

      {:error, reason} ->
        Logger.error("[ActorDictionary] Failed to read snapshot: #{reason}")
    end
  end

  defp parse_yaml(content) when is_binary(content) do
    case YamlElixir.read_from_string(content) do
      {:ok, entries} when is_list(entries) ->
        {:ok, entries}

      {:ok, _} ->
        {:error, :invalid_format}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp populate_ets(entries) do
    :ets.delete_all_objects(@table)

    Enum.each(entries, fn entry ->
      canonical = entry["canonical"]
      category = entry["category"] || "other"
      triggers = entry["triggers"] || []

      if canonical do
        :ets.insert(@table, {canonical, category, triggers})
      end
    end)
  end
end
