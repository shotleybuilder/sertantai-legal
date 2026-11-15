defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.AmendedExcepted do
  @moduledoc """
  A same-extent subject's exception naming the provisions amended (Fire and
  OH&S: Extent reader, Decision 1, Jason 2026-11-14): "An amendment (other
  than an amendment of Part 1A of the Petroleum Act 1998) or repeal made by
  this Act has the same extent as the provision to which it relates"
  (Energy Act 2016 s.85(2)). Every amendment the law makes follows its
  enactment; a change whose own target is one excepted takes the law's
  default instead — a target statement (`Extent.Targeted`'s shape: `:only`
  the default, scope `"*"`, the law named, its provisions; a Part as
  `pt.1A`), applied to a change by `Extent.ChangeTarget`.

  Read only where the law states a default, the subject is every amendment
  the law makes and the exception is the amendment (repeal, revocation) of
  provisions of a law named by its title and year; any other naming of
  another Act's provisions is left unread (round 12). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Forms, ItemExceptions, Targeted}
  alias SertantaiLegal.Scraper.AmendingLaw.RefList

  @change "(?:amendments?|repeals?|revocations?)"

  # "an amendment of Part 1A of the Petroleum Act 1998"; "the repeal of
  # sections 4 and 6 of the Promissory Oaths Act 1868 (c. 72),"
  @exception Regex.compile!(
               "^\\s*(?:an?|the|any)\\s+#{@change}(?:\\s+(?:or|and)\\s+#{@change})*\\s+of\\s+(?<provisions>[^()]+?)\\s+(?:of|to)\\s+the\\s+(?<title>[A-Z][\\w,'’&\\-\\s]*?\\s(?:Act|Regulations|Order|Rules)(?:\\s+\\(Northern\\s+Ireland\\))?\\s+\\d{4})(?:\\s*\\([^()]*\\))?\\s*,?\\s*$",
               "u"
             )

  @provision_word ~r/\b(?:sections?|regulations?|articles?|rules?|Parts?|Schedules?|paragraphs?)\s+[\dIVXL]/iu
  @parts ~r/^Parts?\s+((?:[\dIVXL]+[A-Z]*(?:\s*(?:,|and)\s*)?)+)$/u

  @doc """
  A same-extent subject read with its exception: `{subject without it,
  the target statements it makes}`; nil when it has none of this form, or
  the law states no `default`.
  """
  @spec read(String.t(), String.t() | nil) :: {String.t(), [Targeted.t()]} | nil
  def read(subject, default) when is_binary(default) do
    with {main, exception, _, _} when is_binary(exception) <- ItemExceptions.split(subject),
         false <- Regex.match?(@provision_word, main),
         %{"title" => title, "provisions" => provisions} <-
           Regex.named_captures(@exception, exception),
         [_ | _] = refs <- refs(provisions) do
      {main, [%{kind: :only, place: default, scope: "*", law: title, refs: refs}]}
    else
      _ -> nil
    end
  end

  def read(_subject, _default), do: nil

  @doc "The target statements of the unit sentences' same-extent subjects."
  @spec targets([{String.t(), String.t()}], String.t() | nil) :: [Targeted.t()]
  def targets(unit_sentences, default) do
    for {_ref, s} <- unit_sentences,
        form <- [Forms.amendments_same(), Forms.extent_of_same()],
        m = Regex.named_captures(form, s),
        m != nil,
        {_main, targets} <- List.wrap(read(m["subj"], default)),
        target <- targets,
        uniq: true,
        do: target
  end

  # the amended law's provisions, in its ref grammar; a Part as "pt.1A"
  defp refs(provisions) do
    case Regex.run(@parts, String.trim(provisions)) do
      [_, numbers] -> for [n] <- Regex.scan(~r/[\dIVXL]+[A-Z]*/u, numbers), do: "pt.#{n}"
      nil -> RefList.parse(provisions)
    end
  end
end
