defmodule SertantaiLegal.Scraper.InForceQualifierTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.InForceQualifier, as: Q

  # Real InForce Qualification strings from the local changes-feed store
  # (89 territorial ones, 2026-10-09; counts in the corpus), with what is read.
  # {qualification, except/1, scope/1, purposes?/1}
  @gallery [
    # 2,635 / 2,495: the territory alone
    {"for W.", nil, {"W.", :all}, false},
    {"for E.", nil, {"E.", :all}, false},
    {"for E.W.S.", nil, {"E.W.S.", :all}, false},
    {"for W. and N.I.", nil, {"W. and N.I.", :all}, false},
    # give or take "in so far as not already in force", a timing, a date note
    {"for E.W. in so far as not already in force", nil, {"E.W. ", :all}, false},
    {"for E. so far as not already in force", nil, {"E. ", :all}, false},
    {"for E. in force in so far as not already in force", nil, {"E. ", :all}, false},
    {"for S. to the extent, if any, that it is not already in force", nil, {"S. ", :all}, false},
    {"for E. immediately after the coming into force of 2000 c. 37, ss. 47-50", nil,
     {"E. ", :all}, false},
    {"(being the date on which S.I. 2007/739 came into force) for W.", nil, {"W.", :all}, false},
    {"at 9.00 a.m. for W.", nil, {"W.", :all}, false},
    # 580: everywhere but
    {"except in relation to W.", "W.", nil, false},
    {"otherwise except in relation to W.", "W.", nil, false},
    {"in so far as not already in force except in relation to N.I.", "N.I.", nil, false},
    # purposes: unusable for territory
    {"for W. for specified purposes", nil, nil, true},
    {"for specified purposes except in relation to W.", "W.", nil, true},
    {"for W. for the purpose of and in relation to financial years beginning on or after 1.4.2004",
     nil, nil, true},
    # scoped to provisions
    {"for W. for the repeal of s. 26(5)", nil, {"W. ", {:only, {"section", [["26", "", "(5)"]]}}},
     false},
    {"for S. for the repeal of ss. 1-19, 22-28", nil,
     {"S. ", {:only, {"section", [["1", "19", ""], ["22", "28", ""]]}}}, false},
    {"for E. for the insertion of s. 53B", nil, {"E. ", {:only, {"section", [["53B", "", ""]]}}},
     false},
    {"for E. except in relation to ss. 13-15, 76", nil,
     {"E. ", {:except, {"section", [["13", "15", ""], ["76", "", ""]]}}}, false},
    # more than a territory: unusable
    {"for E. in relation to the pilot areas", nil, nil, false},
    {"for E. so far as it relates to the omission of Sch. 1 para. 5", nil, nil, false},
    {"for E. except in relation to the insertion of s. 81B", nil, nil, false},
    {"except in relation to local authorities in W.", nil, nil, false},
    {"for S. in so far as not already repealed by Statute Law Repeals Act 2004 (c. 14)", nil, nil,
     false},
    # read since LR-05: "insofar", "except for", the phrase before the
    # territory, a territory without its full stop (not "Wales")
    {"for E. insofar as not already in force", nil, {"E. ", :all}, false},
    {"except for W.", "W.", nil, false},
    {"in so far as not already in force for N.I.", nil, {"N.I.", :all}, false},
    {"for specified purposes except in relation to W", "W", nil, true},
    {"except in relation to local authorities in Wales", nil, nil, false},
    {"except for the repeal of Sch. 28 para. 11", nil, nil, false}
  ]

  for {q, except, scope, purposes} <- @gallery do
    test "reads #{inspect(q)}" do
      assert Q.except(unquote(q)) == unquote(except)
      assert Q.scope(unquote(q)) == unquote(Macro.escape(scope))
      assert Q.purposes?(unquote(q)) == unquote(purposes)
    end
  end

  test "only_except/1: an except-territory that is all the qualification says" do
    assert Q.only_except("except in relation to W.") == "W."
    assert Q.only_except("except in relation to W. in so far as not already in force") == "W. "
    assert Q.only_except("otherwise except in relation to W.") == nil
    assert Q.only_except("except for W.") == "W."
  end

  test "territorial?/1" do
    assert Q.territorial?("for E.")
    assert Q.territorial?("for specified purposes except in relation to W.")
    refute Q.territorial?("for specified purposes")
    refute Q.territorial?("wholly in force")
  end

  test "in_scope?/2 and scope_kind?/2 on the row's provision" do
    {_, only} = Q.scope("for S. for the repeal of ss. 1-19, 22-28")
    assert Q.in_scope?(only, "section-14A-1")
    refute Q.in_scope?(only, "section-20")
    assert Q.scope_kind?(only, "section-20")
    refute Q.scope_kind?(only, "regulation-20")
    refute Q.in_scope?(only, nil)

    {_, except} = Q.scope("for E. except in relation to ss. 13-15, 76")
    refute Q.in_scope?(except, "section-13")
    assert Q.in_scope?(except, "section-12")

    {_, sub} = Q.scope("for W. for the repeal of s. 26(5)")
    assert Q.in_scope?(sub, "section-26-5")
    refute Q.in_scope?(sub, "section-26-4")
  end
end
