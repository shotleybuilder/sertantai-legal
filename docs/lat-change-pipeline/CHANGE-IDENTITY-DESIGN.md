# Change Identity in the Merge (CV-S07)

Status: design, reviewed (zoom-out: reviewer subagent; design: Gemini, `backend/data/code-reviews/cv-s07-identity-design-*.md`), 2026-10-28. Session: `.claude/sessions/change-vocabulary/2026-10-22-cv-s07-merge.md`.

## Problem

The change vocabulary merges three sources' records of a change to a provision into one change per real event (`ChangeVocabulary.Merge`):

- **feed:** legislation.gov.uk's changes feed, one effect per event, id `key-…`;
- **markup:** legislation.gov.uk's CLML change markup in the law's text, with an effect id or a legacy ChangeId (`d29p11431`, `M_F_…`) and a commentary note;
- **law text:** the amending law's own words, keyed "law:element id".

Today a change's identity is its **effect id**. A record with none (law text, legacy markup) joins "the one change" by the same amending law, of the same operation family, on its provision or one above or below it. With none, or several, it stays apart.

The CV-S07 round 1 check (OH&S, 2026-10-28) found that identity too weak. All its faults are **splits**, one event left as two or more changes:

| Stratum | Checked | Wrong |
|---|---|---|
| J (joined: two or more sources state it), sample on seed 41 | 50 | 6 |
| U (unjoined: the law text beside legislation.gov.uk's likely same event), all | 45 | 44 |
| C (candidates: one source alone beside another source's change), all | 62 | 52 (+5 doubtful) |

Causes, each with a recorded example:

1. **Two ids for one effect.** 33,894 of 251,692 stored feed effects (13.5%) carry an `EffectId` different from the id in their `URI` (legislation.gov.uk re-keys an effect when it corrects it; "TOES" comments). The markup carries the `URI` id. Example: NISR 2004/222 reg.2(1) — feed `EffectId …c4575c`, `URI …abb9d4`; markup `Substitution ChangeId="key-…abb9d4-…"`. We read `EffectId` only (`ChangesFeed`, `effect_id: ~x"./@EffectId"`).
2. **A markup effect id no feed record holds.** Of 216 OH&S markup-only changes keyed by an effect id, 29 match a `URI` id (cause 1), 183 match no feed record at all, and 4 match an effect the feed places elsewhere. A keyed markup change never takes the id-less join. Example: SI 1977/500 reg.6(1), markup `…61b2cd` vs feed `…a11829`, same law, words, date.
3. **Copies counted as rival candidates.** One event appears several times to the id-less join:
   - **markup repeated per version:** HSWA s.28 has versions `section-28`, `section-28n1` and `section-28n2`. `d29p3040`, `d29p11453` and `d29p11784` all point to one note, "Words in s. 28(6) inserted … 2009 (c. 20) … Sch. 6 para. 42". The same holds for GB/NI versions in SI 2008/1597;
   - **legacy ids sharing one CommentaryRef:** HSWA s.27(1) by SI 2008/960 art.11(2) has three ChangeIds on one note;
   - **one feed effect staged in two rows:** `…0d80e0`, omitted for specified purposes 2013-04-25, fully 2013-10-01;
   - **a heading effect beside its body effect from one instruction:** SI 2008/1597 reg.21 by SI 2019/696 Sch.12 para 21(a).
4. **The amending provision is not used to choose.** All three sources name it:
   - the law text in its key;
   - the feed in `AffectingProvisions`;
   - the markup in its note's citation, as a pointer.

   The merge uses it only to break ties between distinct effect ids. It never uses it to narrow copies, and never to refuse a wrong partner. Two **over-joins** followed: feed art.16(4)(a) joined to markup whose note cites 16(4)(b) (HSWA s.50(3)); feed Sch.4 para 18(2)(a) joined to markup citing para 18(4) (HSWA s.27A).
5. **An operation-less feed effect** ("amended") has no family, so it never joins (HSWA s.52(1) by 1997 c.42 s.2: feed on s.52(1), markup and law text on s.52(1)(bb)).

## Goals and non-goals

**Goals:**
- One change per real event in the strata the check measures (J, U, C).
- The identity stated once, by what every source carries.
- Round 2 passes the agreed rule:
  - U and C have no wrong merge left unfixed or unclassed;
  - J pooled under 2% wrong changes and under 5% wrong pairs at the 95% upper bound;
  - golden from inputs 27/27.

**Non-goals:**
- The readers' own values (operation, level, date, territory: CV-S02–S06).
- Joining events by different amending laws ("as inserted by" chains, SI 2020/1460 amending SI 2019/696's insertion).
- Schedules of the amended law (v0.1 limit).

## Approach

An **event's identity** is, in order:

1. **Its effect id:** the feed's `EffectId`, or its `URI` id (both carried).
2. **Else its source provision:** (amending law, amending provision), plus its operation family where both sides know it, on the same provision or one above or below it.

Before any id-less record looks for a partner, each source's records of one event are **one candidate**:
- markup by note, `CommentaryRef`;
- feed by effect id, stages together;
- law text by key.

Data flow, all within `ChangeVocabulary`, with no new table. `Merge` (330 lines today) becomes the thin orchestrator. The new logic goes in two pure modules taking change lists as arguments:
- `Merge.Candidates`: each source's records of one event grouped into one candidate;
- `Merge.Partner`: the partner choice below.

1. **Feed (`ChangesFeed` parses, `Readers.Feed` carries).** `ChangesFeed` parses the effect id in `URI` into the `Effect` struct (`uri_id`). Where it differs from `EffectId`, `Readers.Feed` carries it as a claim (`:feed, :uri_id`). The merge maps a markup key equal to a `URI` id onto the feed's key and keeps the markup id as an alias. *Fixes cause 1.*
2. **Markup reader (`Readers.Markup`).** Carry the note id as a claim (`:markup, :note`), a pointer for identity. Read the cited law from the note's text when it has no `Citation` URI ("S.I. 2004/ 1822", HSWA s.28(5)(b) `d29p11427`), as an identity-only pointer (`:markup, :cited_text`), never `by` (Decision 3).
3. **`Merge.Candidates`, before joining.**
   - Group markup changes by (note, law) on each provision: copies (version repeats, several ChangeIds on one note) become one candidate with aliases.
   - Group a feed effect's stages (keys `id@date`) as one candidate.
   - A keyed markup change whose id no feed record holds (by `EffectId` or `URI`) joins as id-less, keeping its id as an alias.

   *Fixes cause 2 and part of 3.*
4. **`Merge.Partner`, choosing a partner.** For an id-less record, candidates are the events by the same amending law, on its provision or one above or below it:
   1. where both sides name the amending provision, they must be related (`related?`, the existing ancestor test), always, not only to break ties: *fixes over-joins and the rival copies;*
   2. then the same operation family, unless one side has none: *fixes cause 5;*
   3. then, if several remain, the exact operation;
   4. then a body effect over a heading effect, where the record isn't itself a heading change. A record is a heading change when:
      - **feed:** its `AffectedProvisions` names a heading, carried as `:feed, :heading`. The level claim can't tell this apart: `Readers.Feed` already makes a heading effect `:words` (`@words_level`), the same as a words change in the body;
      - **law text:** its instruction names "the heading" (the reader's KH class);
      - **markup:** the change sits inside a `Title` element.

   Join only when one event is left. Otherwise stay apart, as now (a visible gap). *Fixes causes 3 and 4.*
5. **One effect, staged.** `same_day?` changes from a filter to a choice: a dated law-text record keeps an effect whose stages include its date and joins that stage. An effect with no stage of that date stays a candidate, and the record joins its first stage. Distinct effects (not stages of one) on other days stay excluded, as now (Coronavirus Act 2020 s.78: sunset 2022, NI continuation 2024, two removals).

The existing rules stay: `precise/1` (one effect id, markup placement wins), `inside_words?`, `other_source?` (no snowball), `joined_instruction`; `same_day?` as in step 5.

Reader faults surfaced by the check are fixed in the same round (Jason 2026-10-28, recorded in the session doc's round 1):
- the markup citation with a stray space (item 2 above);
- the amending-law reader's two-operation clause ("after 'a notifier' add 'or applicant' and for '2001' substitute '2015'", NISR 2015/339 reg.34(2)(b): CV-S06's open bug), as two rules;
- the "repealed" Addition: see Open questions.

## Source authority

Identity is not a value. Joining two records makes their claims one change's. The evidence order per attribute (`Evidence`) then decides each value as now:
- the law text is primary where it speaks;
- the markup places;
- the feed dates.

Notes stay pointers for identity. The note id and the note's provision citation decide only which records are one event.

What happens today, and isn't changed by this design:
- every claim is stored in `provision_change_claims`, pointers included (7,228 `markup cited` rows, 6,296 `markup affecting`);
- the note's cited law is the last fallback for the stored `by` (`Evidence`: `by: [law_text, feed, markup cited]`): 1,295 stored changes take `by` from it.

That is a note-derived fact, so it is raised as Open question 3, not settled here. The new claims (`:markup :note`, `:feed :uri_id`, `:feed :heading`) feed no attribute in `Evidence`.

## What good looks like

The CV-S07 check, unchanged (skill `merge-check`, `mix lat.merge_check`):
- U and C re-checked in full;
- J on a new seed, pooled from the items unchanged since checked;
- golden from inputs;
- the join rate published.

Measures the design can't define for itself: the strata are computed from the merged changes by `MergeStrata`, and the judgement is an agent's against the sources' own records.

## Alternatives considered

- **Patch each cause as its own rule at the edge.** Rejected: it adds rules between sources, the pattern the vocabulary exists to retire (CV-00, "one vocabulary … merged by identity, never pairwise reconciling rules"). It also leaves the amending provision as a tie-breaker, which is what let the over-joins through.
- **Identity by content alone** (law, provision, operation, date) without ids. Rejected: dates differ legitimately between sources (staged commencement: SI 1992/2966 reg.3(3)(e), markup 2008 vs feed 2006). Operations differ too (markup shows a substitution as an insertion: `Conflicts`' `@agree`). Ids are exact where present.
- **Read the operation from the note's verb** (an Addition whose note says "repealed" as a removal). Rejected: notes are pointers, never facts (LR-25, Jason 2026-10-15).
- **A persisted event table** (one row per event, records linked). Rejected for now: no measured need. The merge is pure and runs per law in seconds, and `provision_changes` already holds the merged result.
- **Fix the markup reader to look up the feed's re-keyed id** instead of carrying `URI` in the feed. Rejected: the feed record itself names both ids. Carrying what the source says is the reader's job; matching is the merge's.

## Risks and limits

- **Over-join by looser identity.** The amending-provision requirement is stricter than today's rule wherever both sides name it, but where only one side does, family plus nearness decides, as now. The J re-check measures over-joins.
- **Pointer quality.** A note citing a wrong provision refuses the right join. It joins a wrong partner if it happens to name another candidate's provision. Seen once: Factories Act s.171 heading note cites "3(1)(d)", which doesn't exist (no partner, so a visible split). The J re-check measures over-joins, and the agent prompt asks whether the markup's note citation is related to the feed's affecting provision.
- **EU REACH:** one markup substitution covering the words of 2–3 points the feed records as separate effects. It stays apart. This is a known class, pending a policy decision (Open questions).
- **Run time:** the merge stays per law and pure. The rebuild is `lat.vocabulary --check --family` (~1.5 min for OH&S) plus `--golden` (~3 min). The two-operation reader fix needs one read pass (~10 min).
- **Not read yet:** events by different amending laws ("as inserted by"), and the amended law's Schedules.

## Backing out

- A restore point of `provision_changes`, `provision_change_claims`, `amendment_rules` and `extent_rules` before the read pass and rebuild (`nas-backup.sh --tables … --tag cv-s07-round2`).
- The code reverts by commit. The merge holds no state of its own.

## Decisions (Jason, 2026-10-28)

1. **The "repealed" Addition:** join by provision. Where the amending provision matches, the markup joins the law text's removal across families, and the law text's operation wins by evidence. With no law-text record the markup's "inserted" stands, as a known limit.
2. **EU REACH coarse markup:** leave apart as a known class (KM-EU), counted as such by the check.
3. **A note's cited law as stored `by`:** kept as the last fallback and documented as the one named exception: the note's structured `Citation` link, never its free text. So the stray-space read ("S.I. 2004/ 1822", from the note's words) is an identity-only pointer (`:markup, :cited_text`). It is never in `Evidence`'s `by`.

## Open questions (decided above)

1. **The "repealed" Addition** (HSWA s.84(5), s.1(1)(d); 1972/28 s.5(1)). Markup reads it as an insertion and the note says repealed. This design joins it to the law text's removal by the amending provision, where the family differs and the provision matches. The law text's operation then wins by evidence. Without a law-text record the markup's "inserted" stands, and reading the note's verb is ruled out. Is the join-by-provision enough, or should the markup reader look at what the Addition wraps?
2. **EU REACH coarse markup:** leave apart as a known class, or join one markup change to several feed events (one change per feed event, the markup as each one's placement)?
3. **A note's cited law as the stored `by`** (1,295 changes today, `Evidence`). Options:
   - keep it as the last fallback (a change only legacy markup records has no other amending law), and say so in the rules;
   - drop it from `by`, so those changes have no amending law until a feed or law-text record joins.

   The stray-space citation fix adds a few more either way.

