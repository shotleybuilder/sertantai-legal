defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Default do
  @moduledoc """
  An extent clause's default — the law's own extent — and what one sentence
  of it states (CV-S05; decomposed from `AmendingLaw.Extent`, run time
  2026-10-25): "This Act extends to England and Wales only" → "E+W"; "This
  Act does not extend to Northern Ireland" → the rest of the UK; the
  exceptions after a default ("…, except for Part 1, which extends to
  England and Wales only"), read plainly or `:unread`. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Forms, Lists, Named, Parts, Places, Units}
  alias SertantaiLegal.Scraper.Territory

  @place_list Places.place_list()

  @doc """
  What one sentence of an extent clause states, in the reader's terms
  (CV-S05, the catalogue's outcome): `{:default, code}` (the law's own
  extent: "This Act extends to …", "… does not extend to …", "This Act,
  except— …, does not extend to …"), `{:list, kind, code}` (a list heading:
  "The following extend also to Scotland—"; `code` nil for "the same extent
  as the enactments"), `{:part_not, code}` ("Part III … does not extend to
  Scotland"), or nil (no statement the reader reads).
  """
  @spec statement(String.t(), String.t() | nil) ::
          {:default, String.t()}
          | {:list, Extent.list_kind(), String.t() | nil}
          | {:part_not, String.t()}
          | nil
  def statement(sentence, type \\ nil)

  # (an Act of the UK Parliament's "This Act extends to Northern Ireland"
  # is the UK, as `read/1` reads it: `type` the law's type code)
  def statement(sentence, type) do
    case statement_alone(sentence) do
      {:default, d} -> {:default, westminster(d, sentence, type)}
      other -> other
    end
  end

  defp statement_alone(sentence) do
    cond do
      Regex.match?(Forms.extends_and(), sentence) ->
        {:default, default(sentence)}

      Regex.match?(Forms.except_list(), sentence) or Regex.match?(Forms.extends(), sentence) or
        Regex.match?(Forms.not_extends(), sentence) or Regex.match?(Forms.cited_list(), sentence) ->
        {:default, default(sentence)}

      Regex.match?(Forms.amendments_same(), sentence) or
        Regex.match?(Forms.extent_of_same(), sentence) or
          Regex.match?(Forms.amendments_where(), sentence) ->
        {:list, :same, nil}

      m = Regex.named_captures(Forms.extends_except(), sentence) ->
        {:default, Territory.union(["E+W+S", Places.places(m["places"])])}

      (m = Regex.named_captures(Forms.extends_exc(), sentence)) &&
          exceptions(m, nil, nil) != :unread ->
        {:default, Places.places(m["places"])}

      m = Regex.named_captures(Forms.only_following(), sentence) ->
        {:default, Territory.subtract("E+W+S+NI", Places.places(m["places"]))}

      match = Regex.run(Forms.heading(), sentence) ->
        {:list, Lists.kind(match), Lists.place(match)}

      m = Regex.run(Forms.part_not(), sentence) ->
        {:part_not, Places.places(List.last(m))}

      (m = Regex.named_captures(Forms.named(), sentence)) && Named.plain_named?(m, sentence) ->
        {:list, Named.named_kind(m), Places.places(m["places"])}

      true ->
        nil
    end
  end

  # an Act of the UK Parliament that "extends to Northern Ireland" (no
  # "only") extends there as well as to Great Britain (Ministers of the
  # Crown Act 1975 s.9(2): CV-S05 round 3 A)
  @doc "A default of \"NI\" in an Act of the UK Parliament is the UK, unless it says \"only\"."
  @spec westminster(String.t() | nil, String.t(), String.t() | nil) :: String.t() | nil
  def westminster("NI", clause, "ukpga") do
    if clause =~ ~r/\bNorthern\s+Ireland\s+only\b|\bonly\s+to\s+Northern\s+Ireland\b/iu,
      do: "NI",
      else: "E+W+S+NI"
  end

  def westminster(default, _clause, _type), do: default

  # "These Regulations extend to England and Wales and Scotland" → E+W+S;
  # "This Act does not extend to Northern Ireland" → the rest of the UK
  @doc "The law's own extent from its clause's words; nil when none is read."
  @spec default(String.t()) :: String.t() | nil
  def default(clause) do
    cond do
      m = Regex.named_captures(Forms.extends_and(), clause) ->
        Territory.union([Places.places(m["a"]), Places.places(m["b"])])

      m = Regex.named_captures(Forms.except_list(), clause) ->
        Territory.subtract("E+W+S+NI", Places.places(m["places"]))

      m = Regex.run(Forms.extends(), clause) ->
        Places.places(Enum.at(m, 1))

      (m = Regex.named_captures(Forms.extends_exc(), clause)) &&
          exceptions(m, nil, nil) != :unread ->
        Places.places(m["places"])

      m = Regex.run(Forms.not_extends(), clause) ->
        Territory.subtract("E+W+S+NI", Places.places(List.last(m)))

      m = Regex.named_captures(Forms.extends_except(), clause) ->
        Territory.union(["E+W+S", Places.places(m["places"])])

      m = Regex.named_captures(Forms.only_following(), Units.no_dots(clause)) ->
        Territory.subtract("E+W+S+NI", Places.places(m["places"]))

      m = Regex.run(Forms.cited_list(), clause) ->
        [_, not_, list] = m

        if not_ == "",
          do: Places.places(list),
          else: Territory.subtract("E+W+S+NI", Places.places(list))

      true ->
        nil
    end
  end

  @doc "The lists a default's plain exceptions state (\"This Act extends to … except …\")."
  @spec exception_lists(String.t(), String.t() | nil, Doc.t()) :: [
          {atom(), String.t() | nil, [String.t()]}
        ]
  def exception_lists(clause, clause_ref, doc) do
    with nil <- Regex.run(Forms.extends(), clause),
         m when m != nil <- Regex.named_captures(Forms.extends_exc(), clause),
         lists when is_list(lists) <- exceptions(m, clause_ref, doc) do
      lists
    else
      _ -> []
    end
  end

  # the exceptions after a default: [] (stated elsewhere), lists, or :unread
  defp exceptions(%{"exc" => exc, "places" => default_places}, clause_ref, doc) do
    exc = String.trim(exc)

    cond do
      # stated elsewhere: the named provisions' own statements are read
      exc =~
          ~r/^(?:except|save)\s+(?:as|where|in\s+so\s+far\s+as)\s+(?:otherwise\s+)?(?:expressly\s+)?(?:provided|stated|specified|mentioned)\b/iu ->
        []

      # "except for Part 1, which extends to England and Wales only"
      m =
          Regex.run(
            ~r/^(?:except|save)\s+(?:for\s+)?(.+?),?\s+which\s+(?:shall\s+)?extends?\s+(?:only\s+)?to\s+((?>#{@place_list}))(?:\s+only)?\s*$/iu,
            exc
          ) ->
        [_, subj, list] = m

        # never another law's provisions ("paragraph 23 of Schedule 12A to
        # the Data Protection Act 2018")
        if subj =~
             ~r/\b(?:of|to)\s+the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations)(?:\s+\d{4})?/u,
           do: :unread,
           else: with_refs(subj, clause_ref, doc, &[{:only, Places.places(list), &1}])

      # "except that section 12 (…) extends to England and Wales and Scotland only"
      m = Regex.run(~r/^except\s+that\s+(.+)$/iu, exc) ->
        rest = Enum.at(m, 1)

        with n when n != nil <-
               Regex.named_captures(
                 Forms.named(),
                 String.capitalize(String.first(rest)) <> String.slice(rest, 1..-1//1)
               ),
             true <- Named.plain_named?(n, rest),
             refs =
               if(doc,
                 do:
                   Enum.uniq(
                     RefList.parse(n["subj"], clause_ref) ++
                       Parts.parts(n["subj"], doc, clause_ref)
                   ),
                 else: [:any]
               ),
             [_ | _] <- refs do
          [{Named.named_kind(n), Places.places(n["places"]), refs}]
        else
          _ -> :unread
        end

      # "except regulation 15": those don't extend there
      m =
          Regex.run(
            ~r/^(?:except|save|apart\s+from|other\s+than|excluding)\s+(?:for\s+)?(.+?)\s*$/iu,
            exc
          ) ->
        subj = Enum.at(m, 1)

        if subj =~ ~r/\b(?:so\s+far|which|where|that|of\s+the\s+[A-Z]|to\s+the\s+[A-Z])/u,
          do: :unread,
          else: with_refs(subj, clause_ref, doc, &[{:not, Places.places(default_places), &1}])

      true ->
        :unread
    end
  end

  # the provisions named, plainly; :unread where none are read (no doc: a
  # sentence alone, `default/1` — read when they name any provision)
  defp with_refs(subj, _clause_ref, nil, _fun),
    do:
      if(
        subj =~ ~r/\b(?:sections?|regulations?|articles?|rules?|Parts?|Schedules?|paragraphs?)\b/i,
        do: [],
        else: :unread
      )

  defp with_refs(subj, clause_ref, doc, fun) do
    case Enum.uniq(RefList.parse(subj, clause_ref) ++ Parts.parts(subj, doc, clause_ref)) do
      [] -> :unread
      refs -> fun.(refs)
    end
  end
end
