defmodule SertantaiLegal.Scraper.ChangeVocabulary.Checked do
  @moduledoc """
  The switch-over's checked rows (CV-06; Jason 2026-11-01: "a pass that
  doesn't rely on agents"): the rows agents judged, each with its status —
  `accepted` (its periods are the expected label), `to_fix` (judged wrong;
  expected periods written from its note when fixed), `known` (a named
  known limit), `to_decide` (for Jason), `upstream` (the source's error) —
  in `test/fixtures/change_vocabulary/switch_checked.json`. Code compares
  the current labels with every accepted one; the pass needs every one to
  match and none left to fix.

  Compared as compliance reads a period: its dates, status,
  `in_force_from`, `changed_by` and territory (`Territory.normalize/1`).

  Pure.
  """

  alias SertantaiLegal.Scraper.Territory

  @fields ~w(valid_from valid_to status in_force_from changed_by territory)

  @doc "A row's periods as compared: dates as ISO strings, territory normalised."
  @spec norm([map()]) :: [map()]
  def norm(periods) do
    for p <- periods do
      Map.new(@fields, fn f ->
        v = Map.get(p, f) || Map.get(p, String.to_atom(f))
        {f, value(f, v)}
      end)
    end
  end

  defp value(_f, %Date{} = d), do: Date.to_iso8601(d)
  defp value("territory", t) when t in [nil, "", "nowhere"], do: nil
  defp value("territory", t), do: Territory.normalize(t)
  defp value("status", s) when is_atom(s) and s != nil, do: Atom.to_string(s)
  defp value(_f, ""), do: nil
  defp value(_f, v), do: v

  @doc """
  Each checked row against its current periods (`current`: `"law|sid"` →
  timeline rows): `{:match | :changed | :missing | status, row}` — an
  accepted row matching or changed; a row of any other status as its
  status.
  """
  @spec compare([map()], %{String.t() => [map()]}) :: [{atom(), map()}]
  def compare(rows, current) do
    for r <- rows do
      id = "#{r["law"]}|#{r["section_id"]}"

      case {r["status"], Map.fetch(current, id)} do
        {"accepted", :error} ->
          {:missing, r}

        {"accepted", {:ok, now}} ->
          {if(norm(now) == norm(r["periods"]), do: :match, else: :changed), r}

        {status, _} ->
          {String.to_atom(status), r}
      end
    end
  end
end
