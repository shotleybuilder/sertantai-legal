defmodule SertantaiLegal.Scraper.Commencement.OrderRead do
  @moduledoc """
  A commencement order's rules for the Act it commences, read now from the
  CLML held: what `mix lat.commencement --read-orders` writes, what the
  check's `--fresh` previews and what the leftovers gate reads — one
  reading, so the three never differ (the preview skipped "the day
  appointed for the purpose of section N", SI 1996/218; the gate read an
  order held as another instrument). An order held as another instrument
  commences nothing under the name it is held by (`Order.HeldAs`). Reads
  the CLML store once per order; writes nothing.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Order, Rule}
  alias SertantaiLegal.Scraper.Commencement.Order.HeldAs
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @type t :: %{doc: Doc.t() | nil, commences?: boolean(), rules: [Rule.t()]}

  @doc """
  `order` read for `act` from the CLML held: its document (nil when none is
  held); whether it commences the Act (held as itself, never the Act
  itself — NISR 2012/286 — and naming it: `Order.commences?/2`); and its
  rules, each "day appointed for the purpose of" rule given what the Act's
  own rule leaves to it (`act_rules`: the Act's rules).
  """
  @spec read(String.t(), Order.act(), [Rule.t()]) :: t()
  def read(order, act, act_rules) do
    case ClmlStore.law_docs(order) do
      [] -> %{doc: nil, commences?: false, rules: []}
      xmls -> from_docs(order, xmls, act, act_rules)
    end
  end

  @doc "As `read/3`, from the order's CLML documents in hand. Pure."
  @spec from_docs(String.t(), [String.t()], Order.act(), [Rule.t()]) :: t()
  def from_docs(order, xmls, act, act_rules) do
    doc = Doc.new(order, xmls)

    commences? =
      order != act.law and Enum.all?(xmls, &HeldAs.itself?(order, &1)) and
        Order.commences?(doc, act)

    rules =
      if commences?,
        do: doc |> Order.rules(act) |> Order.resolve_appointed_for(act_rules),
        else: []

    %{doc: doc, commences?: commences?, rules: rules}
  end
end
