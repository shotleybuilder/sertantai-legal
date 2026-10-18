defmodule SertantaiLegal.Scraper.Commencement.Rule do
  @moduledoc """
  One commencement statement as a rule (commencement-rules CR-01): what it
  brings into force, when, where and how far, and the words it came from.
  Readers translate a law's own commencement clause, its commencement
  orders and an amending law's clause into rules; one evaluator dates any
  provision from the rules alone. Bringing into force only (Jason
  2026-10-18: "The abstraction should simplify not complicate"): no expiry,
  no retrospective flag — "deemed to have come into force on 1 April" is
  that date.

  - `commences`: the law whose provisions come into force.
  - `scope`: `:all` · `:rest` ("otherwise", "the remaining provisions") ·
    a list of refs in LAT's section_id grammar ("s.12(3)", "pt.6.ch.1",
    "sch.13.para.70(a)"; a range is "s.1..s.5"); `except`: refs left out.
  - `when`: `{:date, date}` · `{:after, :made | :passed, {n, :day | :month}}`
    · `{:named_day, :exit_day | :ip_completion_day}` · `{:appointed, how}`
    (a day fixed later: by order, notice or event — undated until a rule
    dates it) · `{:with, "law:ref"}` (another provision's commencement) ·
    `:unread`.
  - `territory`: nil (wherever the provision extends) or "E", "E+W", ….
  - `purposes`: nil (fully) · `:for_making_secondary_legislation` ·
    `:in_relation_to` · `:for_specified_purposes`; the words are in
    `source.text`. A rule with a territory or purposes is partial.
  - `source`: `%{law, ref, text}` — the clause or article read, verbatim.
  - `treatment`: its catalogue name.

  `to_text/1` is the readable form (`mix lat.commencement`); `to_row/1` /
  `from_row/1` the table's (`commencement_rules`). Pure.
  """

  @enforce_keys [:commences, :scope, :when, :source, :treatment]
  defstruct [:commences, :scope, :when, :territory, :purposes, :source, :treatment, except: []]

  @type ref :: String.t()
  @type scope :: :all | :rest | [ref()]
  @type unit :: :day | :month
  @type when_ ::
          {:date, Date.t()}
          | {:after, :made | :passed, {pos_integer(), unit()}}
          | {:named_day, :exit_day | :ip_completion_day}
          | {:appointed, String.t()}
          | {:with, String.t()}
          | :unread
  @type purposes ::
          nil | :for_making_secondary_legislation | :in_relation_to | :for_specified_purposes
  @type source :: %{law: String.t(), ref: String.t() | nil, text: String.t() | nil}
  @type t :: %__MODULE__{
          commences: String.t(),
          scope: scope(),
          except: [ref()],
          when: when_(),
          territory: String.t() | nil,
          purposes: purposes(),
          source: source(),
          treatment: atom()
        }

  @purposes [nil, :for_making_secondary_legislation, :in_relation_to, :for_specified_purposes]
  @named_days [:exit_day, :ip_completion_day]

  @doc "A rule from its fields; raises `ArgumentError` on a value outside the schema."
  @spec new(keyword() | map()) :: t()
  def new(fields) do
    rule = struct!(__MODULE__, fields)

    unless scope?(rule.scope), do: raise(ArgumentError, "scope: #{inspect(rule.scope)}")
    unless when?(rule.when), do: raise(ArgumentError, "when: #{inspect(rule.when)}")

    unless rule.purposes in @purposes,
      do: raise(ArgumentError, "purposes: #{inspect(rule.purposes)}")

    rule
  end

  @doc "In force fully where it applies: no territory, no purposes."
  @spec full?(t()) :: boolean()
  def full?(%__MODULE__{territory: t, purposes: p}), do: t == nil and p == nil

  @doc """
  A partial entry's qualification in the changes feed's words, as the
  register's in-force entries carry it (`EffectFacts.partial?/3` reads
  them): "for E.", "for specified purposes", "for W. for specified
  purposes"; nil when full.
  """
  @spec qualification(String.t() | nil, purposes()) :: String.t() | nil
  def qualification(nil, nil), do: nil

  def qualification(territory, purposes) do
    place =
      territory &&
        "for " <>
          Enum.map_join(
            String.split(territory, "+"),
            "",
            &(String.replace(&1, "NI", "N.I") <> ".")
          )

    how =
      case purposes do
        nil -> nil
        :for_specified_purposes -> "for specified purposes"
        :for_making_secondary_legislation -> "for the purposes of making secondary legislation"
        :in_relation_to -> "for certain purposes"
      end

    [place, how] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end

  @doc "The rule as one readable line: scope — when — where, how far — treatment — source."
  @spec to_text(t()) :: String.t()
  def to_text(%__MODULE__{} = r) do
    Enum.join(
      [
        scope_text(r.scope, r.except),
        when_text(r.when),
        extent_text(r.territory, r.purposes),
        to_string(r.treatment),
        source_text(r.source)
      ],
      " — "
    )
  end

  @doc "The rule as a `commencement_rules` row (plain column values)."
  @spec to_row(t()) :: map()
  def to_row(%__MODULE__{} = r) do
    {kind, date, basis, offset, detail} = when_columns(r.when)

    %{
      commences: r.commences,
      scope_kind: if(is_list(r.scope), do: "refs", else: Atom.to_string(r.scope)),
      scope: if(is_list(r.scope), do: r.scope, else: []),
      scope_except: r.except,
      when_kind: kind,
      when_date: date,
      when_basis: basis,
      when_offset: offset,
      when_detail: detail,
      territory: r.territory,
      purposes: r.purposes && Atom.to_string(r.purposes),
      source_law: r.source.law,
      source_ref: r.source.ref,
      source_text: r.source.text,
      treatment: Atom.to_string(r.treatment)
    }
  end

  @doc "A rule from a `commencement_rules` row (`to_row/1`'s keys)."
  @spec from_row(map()) :: t()
  def from_row(row) do
    new(
      commences: row.commences,
      scope:
        case row.scope_kind do
          "refs" -> row.scope
          kind -> String.to_existing_atom(kind)
        end,
      except: row.scope_except || [],
      when: when_from(row),
      territory: row.territory,
      purposes: row.purposes && String.to_existing_atom(row.purposes),
      source: %{law: row.source_law, ref: row.source_ref, text: row.source_text},
      treatment: String.to_atom(row.treatment)
    )
  end

  defp scope?(scope) when scope in [:all, :rest], do: true
  defp scope?([_ | _] = refs), do: Enum.all?(refs, &is_binary/1)
  defp scope?(_), do: false

  defp when?({:date, %Date{}}), do: true

  defp when?({:after, basis, {n, unit}})
       when basis in [:made, :passed] and is_integer(n) and n >= 0 and unit in [:day, :month],
       do: true

  defp when?({:named_day, day}) when day in @named_days, do: true
  defp when?({:appointed, how}) when is_binary(how), do: true
  defp when?({:with, ref}) when is_binary(ref), do: true
  defp when?(:unread), do: true
  defp when?(_), do: false

  defp scope_text(:all, except), do: with_except("all", except)
  defp scope_text(:rest, except), do: with_except("rest", except)
  defp scope_text(refs, except), do: with_except(Enum.join(refs, ", "), except)

  defp with_except(text, []), do: text
  defp with_except(text, except), do: "#{text} except #{Enum.join(except, ", ")}"

  defp when_text({:date, d}), do: Date.to_iso8601(d)
  defp when_text({:after, basis, {n, unit}}), do: "#{basis} + #{offset(n, unit)}"
  defp when_text({:named_day, day}), do: day |> Atom.to_string() |> String.replace("_", " ")
  defp when_text({:appointed, how}), do: "appointed (#{how})"
  defp when_text({:with, ref}), do: "with #{ref}"
  defp when_text(:unread), do: "unread"

  defp extent_text(territory, purposes) do
    where = territory || "everywhere"
    how = if purposes, do: purposes |> Atom.to_string() |> String.replace("_", " "), else: "fully"
    "#{where}, #{how}"
  end

  defp source_text(%{law: law, ref: ref, text: text}) do
    [law, ref]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> then(&if(text, do: "#{&1}: “#{text}”", else: &1))
  end

  defp offset(1, unit), do: "1 #{unit}"
  defp offset(n, unit), do: "#{n} #{unit}s"

  # {kind, date, basis, offset, detail}
  defp when_columns({:date, d}), do: {"date", d, nil, nil, nil}

  defp when_columns({:after, basis, {n, unit}}),
    do: {"after", nil, Atom.to_string(basis), offset(n, unit), nil}

  defp when_columns({:named_day, day}), do: {"named_day", nil, nil, nil, Atom.to_string(day)}
  defp when_columns({:appointed, how}), do: {"appointed", nil, nil, nil, how}
  defp when_columns({:with, ref}), do: {"with", nil, nil, nil, ref}
  defp when_columns(:unread), do: {"unread", nil, nil, nil, nil}

  defp when_from(%{when_kind: "date", when_date: d}), do: {:date, d}

  defp when_from(%{when_kind: "after", when_basis: b, when_offset: o}) do
    [n, unit] = String.split(o, " ")
    {:after, String.to_existing_atom(b), {String.to_integer(n), unit_atom(unit)}}
  end

  defp when_from(%{when_kind: "named_day", when_detail: d}),
    do: {:named_day, String.to_existing_atom(d)}

  defp when_from(%{when_kind: "appointed", when_detail: d}), do: {:appointed, d}
  defp when_from(%{when_kind: "with", when_detail: d}), do: {:with, d}
  defp when_from(%{when_kind: "unread"}), do: :unread

  defp unit_atom(u) when u in ["day", "days"], do: :day
  defp unit_atom(u) when u in ["month", "months"], do: :month
end
