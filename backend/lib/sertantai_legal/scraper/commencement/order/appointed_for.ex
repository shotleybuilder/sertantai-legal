defmodule SertantaiLegal.Scraper.Commencement.Order.AppointedFor do
  @moduledoc """
  "The day appointed for the purpose of section N": rules left to the day an
  Act's own provision appoints.

  Pure; part of the order reader (`Commencement.Order`).
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  alias SertantaiLegal.Scraper.Commencement.Order.{
    Dates,
    Words
  }

  alias SertantaiLegal.Scraper.Commencement.{ClmlRef, Rule}

  # ── the day a section of the Act appoints ───────────────────────────

  @appointed_for ~r/\bthe\s+(?:day|date)\s+appointed\s+for\s+the\s+purposes?\s+of\s+(section|article|regulation)\s+(\d+[A-Z]*(?:\([0-9A-Za-z]+\))*)\s+of\s+(?:the\s+)?(.+?)\s+(?:shall\s+be|is)\s+(.+)$/iu

  # "The day appointed for the purpose of section 18(2) of the Gas Act 1995
  # shall be 1st March 1996" (SI 1996/218 art.2, CV-S04 round 3): the day
  # what that section leaves to "the appointed day" comes in — a rule whose
  # scope is that section's, `resolve_appointed_for/2` reading it from the
  # Act's own rules
  @doc "An order's \"the day appointed for the purpose of section N\" rules, each left for `resolve_appointed_for/2`."
  @spec appointed_for(Doc.t(), [String.t()]) :: [Rule.t()]
  def appointed_for(order, aliases) do
    for id <- order.ids,
        String.match?(id, ~r/^(?:article|regulation)-\d+[A-Z]*(?:-\d+[A-Z]*)?$/),
        line <- order |> Doc.element(id) |> Doc.lines() |> Enum.map(&Words.clean_line/1),
        [_, noun, n, law, tail] <- [Regex.run(@appointed_for, line)],
        Enum.any?(aliases, &String.contains?(Words.norm("the " <> law), &1)) or
          Words.norm(law) in ["act", "the act"],
        [d | _] <- [Dates.parse_dates(tail)],
        uniq: true do
      Rule.new(
        commences: :pending,
        scope: ["appointed_for:#{ClmlRef.prefix(String.downcase(noun))}.#{n}"],
        when: {:date, d},
        source: %{law: order.law_name, ref: Words.source_ref(id), text: Words.squash(line)},
        treatment: :order_date
      )
    end
  end

  @doc """
  An order's "the day appointed for the purpose of section 18(2)" rules
  given the scope (and except) of the Act's own rule from that section that
  leaves its provisions to the appointed day (`act_rules`: the Act's rules);
  dropped where the Act holds none.
  """
  @spec resolve_appointed_for([Rule.t()], [Rule.t()]) :: [Rule.t()]
  def resolve_appointed_for(rules, act_rules) do
    Enum.flat_map(rules, fn
      %Rule{scope: ["appointed_for:" <> ref]} = r ->
        case Enum.find(
               act_rules,
               &(match?({:appointed, _}, &1.when) and &1.source.law == r.commences and
                   (&1.source.ref == ref or String.starts_with?(&1.source.ref || "", ref <> "(")))
             ) do
          nil -> []
          own -> [%{r | scope: own.scope, except: own.except}]
        end

      r ->
        [r]
    end)
  end
end
