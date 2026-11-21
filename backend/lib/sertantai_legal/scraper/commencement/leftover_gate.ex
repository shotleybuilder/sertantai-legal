defmodule SertantaiLegal.Scraper.Commencement.LeftoverGate do
  @moduledoc """
  The family gate over the commencement leftovers (Decision 1 (c), Jason
  2026-11-05): each leftover's reviewed status (`leftovers.json`), the
  items reaching a family, and whether every one is named as a known
  limit. The review's side of the leftovers; what a statement leaves over
  is `Leftovers`'. Pure.
  """

  @typedoc "A finding of a statement (a leftover or a misread): its words, with any other facts."
  @type finding :: %{required(:words) => String.t(), optional(atom()) => term()}

  @doc """
  A leftover's reviewed status (`leftovers.json`), nil when it has none: a
  statement named apart from its group (`"<shape> @ <row>"`: a laid-relative
  day, limit C, beside the group's real misses) first, else its group's.
  """
  @spec status(String.t(), map(), String.t() | nil) :: String.t() | nil
  def status(shape, reviewed, row \\ nil),
    do: Map.get(reviewed, "#{shape} @ #{row}") || Map.get(reviewed, shape)

  @doc "True for a status that names the leftover as a known limit (the family gate passes it)."
  @spec named?(String.t() | nil) :: boolean()
  def named?("known: " <> _), do: true
  def named?(_status), do: false

  # ── the family gate ─────────────────────────────────────────────────

  @type item :: %{
          source: :own | :order | :amending,
          law: String.t(),
          ref: String.t(),
          shape: String.t(),
          words: [String.t()],
          reach: integer(),
          status: String.t() | nil
        }

  @doc "A leftover reaching a family: where it is, its group's shape, its words, reach and status."
  @spec item(
          atom(),
          String.t(),
          String.t(),
          String.t(),
          [finding()],
          integer(),
          String.t() | nil
        ) ::
          item()
  def item(source, law, ref, shape, leftovers, reach, status),
    do: %{
      source: source,
      law: law,
      ref: ref,
      shape: shape,
      words: Enum.map(leftovers, & &1.words),
      reach: reach,
      status: status
    }

  @doc """
  The family gate over its leftovers: `pass?` when every one is named
  (`known:`); the failing ones (`fix:`, `check:`, no status) widest reach
  first; counts by status.
  """
  @spec gate([item()]) :: %{pass?: boolean(), failing: [item()], counts: map()}
  def gate(items) do
    failing =
      items |> Enum.reject(&named?(&1.status)) |> Enum.sort_by(&{-&1.reach, &1.law, &1.ref})

    %{
      pass?: failing == [],
      failing: failing,
      counts: Enum.frequencies_by(items, &status_kind(&1.status))
    }
  end

  defp status_kind("known: " <> _), do: :known
  defp status_kind("fix: " <> _), do: :fix
  defp status_kind("check: " <> _), do: :check
  defp status_kind(_none), do: :unreviewed
end
