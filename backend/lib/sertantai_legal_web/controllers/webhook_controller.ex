defmodule SertantaiLegalWeb.WebhookController do
  @moduledoc """
  Handles webhooks from sertantai-hub, including entitlement changes.
  """

  use SertantaiLegalWeb, :controller

  require Logger

  @doc """
  POST /api/webhooks/entitlement-change

  Upserts org entitlement and validates existing sync profiles.
  """
  def entitlement_change(conn, params) do
    with {:ok, attrs} <- validate_entitlement_params(params),
         {:ok, entitlement} <- upsert_entitlement(attrs) do
      # Validate existing profiles against new entitlement
      deactivated = validate_profiles(entitlement)

      conn
      |> put_status(200)
      |> json(%{
        ok: true,
        entitlement_id: entitlement.id,
        profiles_deactivated: length(deactivated)
      })
    else
      {:error, :invalid_params, details} ->
        conn |> put_status(422) |> json(%{error: "Invalid parameters", details: details})

      {:error, reason} ->
        Logger.error("Entitlement webhook failed: #{inspect(reason)}")
        conn |> put_status(500) |> json(%{error: "Internal error"})
    end
  end

  defp validate_entitlement_params(params) do
    required = ["organization_id", "families", "data_tier", "field_tier"]
    missing = Enum.filter(required, &is_nil(params[&1]))

    if missing == [] do
      {:ok,
       %{
         organization_id: params["organization_id"],
         families: params["families"],
         data_tier: params["data_tier"],
         field_tier: params["field_tier"],
         source: params["source"] || "tier_sync",
         granted_at: parse_datetime(params["granted_at"]) || DateTime.utc_now(),
         expires_at: parse_datetime(params["expires_at"])
       }}
    else
      {:error, :invalid_params, "Missing required fields: #{Enum.join(missing, ", ")}"}
    end
  end

  defp upsert_entitlement(attrs) do
    Ash.create(SertantaiLegal.Sync.OrgEntitlement, attrs, action: :upsert)
  end

  defp validate_profiles(entitlement) do
    entitled_families = MapSet.new(entitlement.families)

    case Ash.read(SertantaiLegal.Sync.SyncProfile,
           action: :active_by_organization,
           arguments: %{organization_id: entitlement.organization_id}
         ) do
      {:ok, profiles} ->
        Enum.filter(profiles, fn profile ->
          profile_families = MapSet.new(profile.families)
          remaining = MapSet.intersection(profile_families, entitled_families)

          if MapSet.size(remaining) == 0 do
            # No entitled families left — deactivate
            Ash.update(profile, %{
              is_active: false,
              deactivation_reason: "All families removed from entitlement"
            })

            true
          else
            # Trim to only entitled families
            if MapSet.size(remaining) < MapSet.size(profile_families) do
              Ash.update(profile, %{families: MapSet.to_list(remaining)})
            end

            false
          end
        end)

      _ ->
        []
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
