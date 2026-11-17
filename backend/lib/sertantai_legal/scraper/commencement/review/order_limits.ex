defmodule SertantaiLegal.Scraper.Commencement.Review.OrderLimits do
  @moduledoc """
  A review of the stored order rules that limit a list: each dated order
  rule for some purposes over three or more provisions, and whether its
  words put the limit after a final ", and <item>" — the SI 1991/96 reg.2
  misreading, where the last item's limit was read on every item. It reads
  rules, never shapes them: outside every version file's patterns
  (`Commencement.ReadVersion`, `ChangeVocabulary.Version`). Pure.
  """

  alias SertantaiLegal.Scraper.Commencement.Order.LastItemLimit
  alias SertantaiLegal.Scraper.Commencement.Rule

  @order_treatments [:order_date, :order_schedule]
  @min_refs 3

  @doc "Whether `rule` is an order's."
  @spec order_rule?(Rule.t()) :: boolean()
  def order_rule?(%Rule{treatment: t}), do: t in @order_treatments

  @doc "The dated order rules for some purposes over three or more provisions."
  @spec limited_lists([Rule.t()]) :: [Rule.t()]
  def limited_lists(rules), do: Enum.filter(rules, &limited_list?/1)

  @doc "Whether the rule's words put a limit after a final \", and <item>\"."
  @spec last_item_form?(Rule.t()) :: boolean()
  def last_item_form?(rule), do: rule |> words() |> LastItemLimit.form?()

  @doc "Whether the reader now gives that limit to the last item only."
  @spec splits?(Rule.t()) :: boolean()
  def splits?(rule), do: rule |> words() |> LastItemLimit.split() != nil

  @doc """
  What a fresh reading of one order moves: `{gone, new}`, the stored rules
  it no longer gives and the rules it gives that are not stored (compared
  by what a rule says, never when it was read).
  """
  @spec moved([Rule.t()], [Rule.t()]) :: {[String.t()], [String.t()]}
  def moved(stored, fresh) do
    was = stored |> Enum.filter(&order_rule?/1) |> Enum.map(&Rule.to_text/1)
    now = Enum.map(fresh, &Rule.to_text/1)
    {was -- now, now -- was}
  end

  @doc "One line per rule: the order, the Act, its provisions, the flag and its words."
  @spec line(Rule.t()) :: String.t()
  def line(rule) do
    flag =
      cond do
        splits?(rule) -> "LAST-ITEM split"
        last_item_form?(rule) -> "LAST-ITEM kept (the list's)"
        true -> "-"
      end

    "#{rule.source.law} | #{rule.commences} | #{length(rule.scope)} refs | #{rule.purposes} | #{flag} | #{words(rule)}"
  end

  defp limited_list?(%Rule{when: {:date, _}, purposes: p, scope: scope} = rule)
       when not is_nil(p) and is_list(scope),
       do: order_rule?(rule) and length(scope) >= @min_refs

  defp limited_list?(_rule), do: false

  # the item's own line: a rule's source text is "<head> … <line>"
  defp words(%Rule{source: %{text: text}}) when is_binary(text),
    do: text |> String.split(" … ") |> List.last()

  defp words(_rule), do: ""
end
