defmodule SertantaiLegal.Scraper.StepProcedures.AmendingStale do
  @moduledoc """
  The amending laws behind the build's `:amending_reader` reason
  (`ChangeVocabulary.Store.Inputs.readers/3`): each built law's text
  amenders (`Amendment.TextAmenders`), their text held, whose index is not
  current for it (`Amendment.Index.current?/3`), by cause — never read (no
  index), read by other reader code or from other text (`old_code`), or
  read but not for that law (`not_for_law`). Store-wide or for a family's
  builds (`mix lat.amending --read --stale`, `lat.reread`, `lat.stale`).
  DB and file reads only.
  """

  alias SertantaiLegal.Scraper.Amendment.{Index, TextAmenders}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @type t :: %{not_read: [String.t()], old_code: [String.t()], not_for_law: [String.t()]}

  @doc "The stale amending laws of every build (`nil`) or of `family`'s builds."
  @spec laws(String.t() | nil) :: t()
  def laws(family \\ nil), do: family |> built() |> for_laws()

  @doc """
  The stale amending laws of `laws` (built laws), each by its cause (an
  amending law's index decides it, so a law has one); `effects` gives a
  law's feed effects (`TextAmenders.feed_effects/1`, a stub in tests).
  """
  @spec for_laws([String.t()], (String.t() -> [map()])) :: t()
  def for_laws(laws, effects \\ &TextAmenders.feed_effects/1) do
    pairs = for {law, as} <- TextAmenders.for_laws(laws, effects), a <- as, do: {law, a}
    amenders = pairs |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> Enum.filter(&held?/1)
    index = Map.new(amenders, &{&1, Index.get(&1)})

    causes =
      for {law, a} <- pairs,
          Map.has_key?(index, a),
          not Index.current?(a, index[a], law),
          do: {a, cause(a, index[a])}

    by = Enum.group_by(causes, &elem(&1, 1), &elem(&1, 0))

    %{
      not_read: sorted(by[:not_read]),
      old_code: sorted(by[:old_code]),
      not_for_law: sorted(by[:not_for_law])
    }
  end

  @doc "The causes' laws as one list, sorted."
  @spec all(t()) :: [String.t()]
  def all(%{not_read: n, old_code: o, not_for_law: f}), do: Enum.sort(n ++ o ++ f)

  defp built(family) do
    builds = Store.builds()

    case family do
      nil -> builds |> Map.keys() |> Enum.sort()
      f -> f |> Source.family_laws() |> Enum.filter(&Map.has_key?(builds, &1))
    end
  end

  defp cause(_a, nil), do: :not_read
  defp cause(a, index), do: if(Index.fresh?(a, index), do: :not_for_law, else: :old_code)

  defp held?(law), do: ClmlStore.law_files(law) != []

  defp sorted(nil), do: []
  defp sorted(laws), do: laws |> Enum.uniq() |> Enum.sort()
end
