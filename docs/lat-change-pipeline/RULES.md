# LAT Change Pipeline: Rules

**DRAFT — for Jason to confirm.** Drafted 2026-11-03 (retrospective action 9). Each rule says what the **code does today** on the OH&S core family. Where a ruling and the code differ, the rule says so under **Differs**. Conflicting or reversed rulings are listed at the end under [Open decisions](#open-decisions), numbered so they can be answered in one batch.

## How to read a rule

Each rule has:
- a **name** (a short descriptive slug);
- one plain sentence;
- an **example** (a real provision);
- the aim or **principles** it serves (`AIMS.md`: one aim, `binds-on-date`, and six principles);
- the **code** that applies it;
- its **test**;
- its **origin** (session file and the date of the ruling).

Paths are short:
- **Code** is under `backend/lib/sertantai_legal/scraper/change_vocabulary/` unless it starts with `Amendment.`, `AmendingLaw.` or `Commencement.` (then `backend/lib/sertantai_legal/scraper/`).
- **Tests** are under `backend/test/sertantai_legal/scraper/change_vocabulary/`, except those starting `amendment/` or `amending_law/` (under `backend/test/sertantai_legal/scraper/`).
- **Golden** means the 27 provisions in `backend/test/fixtures/change_vocabulary/golden.exs`, run from inputs by `mix lat.vocabulary --golden`. **Extended golden** means the 23 in `golden_extended.exs`.
- **Origins** name session files in `.claude/sessions/change-vocabulary/`, without their date prefix.

**The label in brief.** A provision row has periods in `lat_label_timeline`. Each period has:
- `status`;
- `in_force_from`;
- `territory`;
- `changed_by` (one law, for compliance);
- `changed_by_all` (every law that made the text);
- `commenced_by`.

The fold works out a tier for each field (`primary` = the legal text, `derived` = legislation.gov.uk), but the table does not store it.

---

## 0. Making laws

Step 0 (added 2026-11-04). Code: `backend/lib/sertantai_legal/scraper/making_laws.ex` (`MakingLaws`), task `mix lat.making_laws`; tests `backend/test/sertantai_legal/scraper/making_laws_test.exs` and `making_laws_checked_test.exs`. Origin: `.claude/sessions/lat-change-pipeline/2026-11-04-maritime-safety-making-laws.md`.

### `making-from-own-text`
A law is making when at least one of its own provisions states a requirement ("shall" or "must") on someone, read outside quoted inserted text and outside standard phrases ("shall be construed", "shall apply", "shall be guilty", "shall not affect", "shall extend to", "shall remain in force", "shall be conclusive evidence" and the rest, an aside between "shall" and its verb allowed), and outside commencement words the commencement reader reads as no statement of its own. One such provision makes the whole law making, whatever else it amends.
- **Example:** SI 2026/306 (EPIRB and PLB Registration… (Amendment) Regulations): reg. 5(1) "The owner and master of a ship must ensure that every EPIRB … is registered". It is making, despite "(Amendment)" in its title.
- **Not:** the Food and Environment Protection Act 1985 (Guernsey) Order 1987, art. 3 "Part II … shall extend to the Bailiwick" (extent, not a requirement).
- **Known limit:** a law that designates (areas, directives, enactments) states no "shall" and reads changes only or no verdict; a designation's own effect is left to a human review (SSI 2026/57, Environmental Protection Decision 1). A prohibition stated only as an offence ("A person who supplies … is guilty of an offence") is standard wording (NI Single-use Vapes Regulations 2024; 2 laws in Environmental Protection, below the triage size).
- **Serves:** `binds-on-date`, `law-text-wins` · **Code:** `MakingLaws.kind/2`, `classify/1` · **Test:** `making_laws_test` "an own requirement", "mixed", "standard wording: extent, a commencement read as no statement, evidence, an aside after shall" · **Origin:** making-laws (Jason 2026-11-04); environmental-protection-making-laws (2026-11-08)

### `changes-only-is-not-making`
A law whose operative provisions all change other laws (amend, revoke, modify, or commence them) is not making. Duties in the text it inserts belong to the law it amends.
- **Example:** Port State Control (Amendment) Regulations 2003 (SI 2003/1636): every provision amends or modifies the 1995 Regulations. Its old duty types had said making. A commencement worded "the day appointed for the coming into force of …" (EPA 1990 (Commencement No. 19) Order 2012) is a change too. So is a law that only modifies another ("has effect as if"): SI 2006/2988, reviewed to not making (Jason, Environmental Protection Decision 2).
- **Serves:** `binds-on-date`, `law-text-wins` · **Code:** `MakingLaws.kind/2` (the amending-law reader's clause operations and repeals tables) · **Test:** `making_laws_test` "amending only", "inserted text stating a duty" · **Origin:** making-laws (Jason 2026-11-04)

### `no-making-verdict-without-text`
Powers only ("may"), changes with powers, standard wording only (for example, text that is all repealed), no text held, or no provisions upstream (legislation.gov.uk holds a scanned print only, `NumberOfProvisions="0"`: the Cremation Regulations 1952) gives no verdict. The stored value stands, and the law goes to Jason's list.
- **Example:** Merchant Shipping (Port State Control) Regulations 2011: every regulation is ". . .". The register marks it in force (parked against the register).
- **Serves:** `unknown-over-guess` · **Code:** `MakingLaws.classify/1` · **Test:** `making_laws_test` "powers only", "standard wording only", "no text", "no provisions upstream" · **Origin:** making-laws (Jason 2026-11-04)

### `law-text-below-review-and-enrichment`
The text verdict is the resolver's `law_text` tier. It ranks below a human review and fractalaw's DRRP enrichment, and above every estimate: legacy duty types, triage, legacy `is_making` and the detector. Each tier it overrules is kept as dissent.
- **Example:** SI 2026/306's review said not making against its text; the review was corrected to making (Jason), not overruled by the text tier.
- **Serves:** `law-text-wins`, `unknown-over-guess` · **Code:** `Taxa.MakingResolver` (`@tiers`), `Legal.Making.evidence/1` · **Test:** `making_resolver_test` "the law's text …" · **Origin:** making-laws (Jason 2026-11-04)

### `lat-rows-for-making-laws-only`
LAT holds rows only for live making laws. Laws that only amend or commence are read from the XML store, never given rows. The Making laws step decides which laws are making and parses them before Sources.
- **Example:** Maritime Safety: 117 making (16 with rows before the step; 101 parsed in it), 51 not making. Environmental Protection: 116 making (53 with rows before; 63 parsed), 258 not making; only legislation.gov.uk's UK law is read (the family's 23 Australian laws are outside the pipeline).
- **Serves:** `binds-on-date` · **Code:** `mix lat.making_laws`, `mix lat.reparse --store only` · **Test:** pass rule 5 of the step · **Origin:** maritime-safety-meta Decision 1 (Jason 2026-11-04)

### `family-re-parses-its-parser-stale-laws`
Each family's Making laws step re-parses its laws that were parsed by older parser code, after a read-only text diff (`mix lat.text_diff --laws … --store only`) shows what would move. So the parser backlog clears family by family, and no whole-corpus re-parse is needed.
- **Example:** 165 of the 266 switched laws were parser-stale. The text diff moved 1 row (a duplicate heading in the Merchant Shipping Act 1979), and the re-parse re-stamped all 165.
- **Serves:** `binds-on-date` · **Code:** `mix lat.text_diff`, `mix lat.reparse --store only` · **Test:** `lat.stale --strict --switched` · **Origin:** silent staleness #193, Decision 1 (Jason 2026-11-07)

## 1. Status

### `five-statuses`
A period's status is one of `in_force`, `in_force_partial`, `prospective`, `repealed` or `repealed_saved`. Nothing else is written, and periods never overlap.
- **Example:** a row with an unknown status or two overlapping periods stops the write for its law.
- **Serves:** `binds-on-date` · **Code:** `LabelPeriods.violations/1`; `LabelSwitch.timeline/2` refuses to write · **Test:** `label_periods_test` "an overlap, an open period before another, an empty period, an unknown status" · **Origin:** `cv-05-consumers` (2026-10-31)

### `period-only-on-change`
A day opens a new period only when it changes a label field. A day that changes only tiers or nothing at all is merged into the running period.
- **Example:** a feed commencement re-stating a provision already in force opens no period.
- **Serves:** `binds-on-date` · **Code:** `Label.fold/3` (`visible/1`) · **Test:** golden · **Origin:** `cv-s09-label-fold` (round 1, 2026-10-30)

### `prospective-until-commenced`
A provision whose only commencement comes after its start is prospective until then. A made version's "Prospective" markup holds only as at the day its text is valid: a commencement after that day overrides it.
- **Example:** NISR 1997/248's made text marks every row prospective. The rows are in force from their commencement (730 rows were wrongly prospective before this rule).
- **Serves:** `binds-on-date`, `law-text-wins` · **Code:** `Label.Start.period/4` (`markup_prospective?/3`) · **Test:** `label_fold_test` "the markup's Prospective holds only as at the text's valid day" · **Origin:** `cv-s09-label-fold` (round 1, 2026-10-30)

### `inserted-into-uncommenced-host`
A row inserted into a provision that its own law has not yet brought into force is prospective until that law commences it.
- **Example:** 2007 c.19 s.7(3)(aa), inserted 2008-04-01 into s.7, is prospective until SI 2008/401 brings s.7 in on 2008-04-06.
- **Serves:** `binds-on-date` · **Code:** `Label.Start` (`host_prospective?/3`) · **Test:** `label_fold_test` "inserted into a provision not yet in force" · **Origin:** Jason 2026-10-30, `cv-s09-label-fold` (round 9)

### `partial-commencement-is-partial`
A commencement for some purposes only makes the provision partly in force. One on the start day makes it partly in force from the start, not prospective.
- **Example:** SI 1992/3004 reg.20(2).
- **Purposes include powers:** a stage in force only "for enabling the exercise of power to make regulations" is for some purposes (CJA 2003 s.254(6A)).
- **Serves:** `binds-on-date` · **Code:** `Label.Start.period/4`, `Label.Day.apply/4`; `Qualification` (purposes class) · **Test:** `label_fold_test` "a partial commencement on the start day"; `qualification_test` · **Origin:** `cv-s09-label-fold` (round 1, 2026-10-30); purposes include powers: Jason 2026-11-04, `maritime-safety-feed-reader` Decision 2

### `commencement-for-one-territory`
A commencement for one territory puts the provision in force there and widens where it is in force. Each such commencement opens a new period. A wholly-for-one-territory commencement ("for W. in so far as not already in force") counts as one. A provision already partly in force everywhere stays partly in force until every territory is wholly commenced: one status per period, and never "in force" where it is only partly in force.
- **Example:** CROW 2000 s.13 is in force for England in 2004 and for Wales in 2005. MSA 1995 s.85(8), partly in force from 2006-07-19: still partly in force after WSI 2007/204 (Wales, 2007-04-02), and in force everywhere from SI 2007/1375 (E, S, NI, 2007-07-01).
- **Serves:** `binds-on-date`, `unknown-over-guess` · **Code:** `Label.Day` (`commenced_for/4`, `full_in/2`, `partial_until_all/3`), `Label.Facts.territory_only/1` · **Test:** `label_fold_test` "a commencement for one territory"; "a row partly in force, fully commenced one territory at a time" · **Origin:** Jason 2026-10-30, `cv-s09-label-fold` (golden convention C13); the partial case Jason 2026-11-06 (option A, Gemini Flash agreeing), `maritime-safety-label-fold` Decision 2

### `most-specific-commencement`
A provision commenced in its own right takes no ancestor's commencement. Otherwise the nearest ancestor's applies, then the whole law's.
- **Example:** SI 2008/401 commences 2007 c.19 s.2(1) "except paragraph (d)", so (d) keeps its own date.
- **Serves:** `binds-on-date`, `law-text-wins` · **Code:** `Label.fold/3` (`nearest_commencements/1`) · **Test:** `label_fold_test` "the most specific commencement governs" · **Origin:** `cv-s09-label-fold` (batch 1, 2026-10-30)

### `commenced-through-its-parts`
A parent whose children are commenced one by one is partly in force from the first child's commencement.
- **Example:** European Union (Withdrawal) Act 2018 s.6 (golden).
- **Serves:** `binds-on-date` · **Code:** `ChangeVocabulary.Parts` (source `:parts`, derived) · **Test:** golden · **Origin:** `cv-03-readers` (2026-10-21); `cv-s09-label-fold` (round 1)

### `whole-new-text-ends-partial`
A whole substitution or insertion that is fully in force ends a partial status, because the partly commenced text is gone.
- **Example:** HSWA 1974 s.10, substituted by SI 2008/960.
- **Serves:** `binds-on-date` · **Code:** `Label.Day.apply/4` · **Test:** `label_fold_test` "a whole substitution fully in force ends a partial status" · **Origin:** `cv-s09-label-fold` (round 1)

### `removal-in-part-is-partial-only-if-kept`
A removal "in part" leaves the provision partly in force only when its text is kept (RetainText) or the removal is staged for some purposes. If the words are gone, it is a words repeal and opens a new version.
- **Example:** Factories Act 1961 s.125(2)(j).
- **Serves:** `binds-on-date` · **Code:** `Label.Day.apply/4` · **Test:** `label_fold_test` "a removal in part (C7)" · **Origin:** golden convention C7 (`cv-01-architecture-review`, 2026-10-21); `cv-s09-label-fold` (round 1)

### `modification-is-not-a-change`
A modification ("shall have effect as if …", "be read as if …") changes no text and opens no period.
- **Example:** SI 1981/917 reg.8(2): a 1993 "modified as follows … for regulation 8 substitute" is not a version (extended golden).
- **Serves:** `binds-on-date`, `law-text-wins` · **Code:** `Amendment.Reader` (`@modification`); `Placement` (`@text_changes`); `Readers.Feed` ("modified" has no level) · **Test:** extended golden SI 1981/917 reg.8(2) · **Origin:** Jason 2026-10-22 ("I agree the logic"); Jason 2026-10-30, `cv-s09-label-fold`
- **Forms** (Jason 2026-11-06, option A; Maritime Safety: Amending-law reader): "has effect as if", "shall have effect as if", "shall apply … as if", "applies … as if", "be read as if" and "be construed as if" are modifications, in the instruction's own words only. "as if" inside quoted or affected words is part of a real amendment ("omit 'and as if references …'", SI 2026/607; "before 'as if' insert", SI 2019/696). Deeming provisions and transitional savings ("shall continue to apply … as if …") are modifications. **One exception:** the older "shall have effect as if the following section(s) were inserted" (EMASA 1972 s.3 on Factories Act 1961 s.10A) is an insertion; legislation.gov.uk applies it as text. **In code** (Environmental Protection: Amending-law reader, 2026-11-10): `@modification` reads these forms in the instruction's own words with quotes removed (`Reader.no_change?/1`); SI 1995/3128 reg.10(3) on MSA 1995 s.97(1) gives no change. Review: `backend/data/code-reviews/2026-11-06-as-if-modifications*.md`.
- **Differs:** a pointer "Section 125 … shall be modified as follows—" now has its items read as insertions (SI 1988/1655 reg.23 on Factories Act 1961 s.125(7)–(9); `Amendment.Reader.items/4`, test `amendment/reader_test` "modified as follows"). See open decision 7.

---

## 2. In force from (dates)

### `in-force-from-current-text`
`in_force_from` is the day the current text took effect: the start, or the latest text change or commencement. It is empty while the provision is prospective or partly in force.
- **Example:** HSWA 1974 s.11(1) is in force from 1974 under its first wording, then from 2008 under the 2008 substitution.
- **Serves:** `binds-on-date` · **Code:** `Label.Start.period/4`, `Label.Day.apply/4` · **Test:** golden; `label_fold_test` "a change to it before the substitution: it was there" · **Origin:** D1, Jason 2026-10-13 (lat-refactor sessions); `cv-02-vocabulary` (2026-10-21); Jason 2026-10-31, `cv-06-switch-over`

### `commencement-opens-a-version`
Each commencement opens a period with its own date. Its law goes in `commenced_by`.
- **Example:** HSWA 1974 s.78 is commenced by SI 1974/1439.
- **Serves:** `binds-on-date` · **Code:** `Label.Day.apply/4` · **Test:** `label_fold_test` "commenced_by: a commencing order" · **Origin:** D1 (2026-10-13), re-stated 2026-10-21; split into `commenced_by` 2026-10-30 (see open decision 1)

### `renumbering-opens-a-period`
A renumbering is a text change. It opens a period dated by the renumbering and credited to its law.
- **Example:** SI 2017/544 reg.1(1) is in force from 2024-11-04 for its renumbered period (golden).
- **Serves:** `binds-on-date` · **Code:** `Label.Facts.text_changes/0` · **Test:** golden · **Origin:** golden convention C4 (`cv-01-architecture-review`, 2026-10-21)

### `date-from-the-law-first`
A change's date comes from the law's commencement (its clause and the orders read), then the law's own text, then the feed's first stage, then the feed.
- **Example:** HSWA 1974 s.47(4) is dated 2013-10-01 by ERRA 2013's commencement, not by the feed's earlier "specified purposes" stage.
- **Serves:** `law-text-wins` · **Code:** `Evidence` (`@table` `date`) · **Test:** `evidence_test` "a commencement read from the law dates the change over the feed" · **Origin:** Jason 2026-10-21, `cv-03-readers` (this reversed "effects first", 2026-10-18)

### `feed-placeholder-date-is-no-date`
A feed stage qualified "in accordance with" its law's own clause, and dated on the day that law was made (an SI) or passed (an Act), gives no date. legislation.gov.uk then holds the day as a placeholder for the clause it points to, so the change takes its date from another source or is left as a gap. A stage qualified this way on any other day keeps its date.
- **Example:** SI 2016/562's Schedule 2 changes to SI 2006/2988 and EPA 1990 Part IIA. The feed says "coming into force in accordance with art. 1(2)-(5)" and dates them 2016-05-04, the day the Order was made, but they come in on "the main commencement day", the Protocols' entry into force for the UK. Finance Act 2026 Sch.14 is the second case: "with effect in accordance with Sch. 14 para. 18", dated on Royal Assent.
- **Serves:** `unknown-over-guess` · **Code:** `Readers.AffectingMade` (the `{:law, :made}` claim, from `legal_register`'s made or enactment date); `Evidence` (`:not_made_day`) · **Test:** `affecting_made_test` · **Origin:** the agent pass, Environmental Protection: Evidence (Decision 4, Jason 2026-11-11; 15 changes in 2 laws)

### `partial-follows-its-date`
"Partial" is taken from the same source as the date. A date the law gives, with no partial claim of its own, is the day the change is fully in force.
- **Example:** HSWA 1974 s.47(4).
- **Serves:** `law-text-wins` · **Code:** `Evidence` (`partial_with_date/1`) · **Test:** `evidence_test` "partial is the date's" · **Origin:** `cv-s08-evidence` (batch 1, 2026-10-29)

### `territorial-stages-date-only-the-undated`
An amending provision commenced territory by territory and never in full dates its changes from its first stage, partly in force. It does so only where no other source dates the change: the stage ranks after the feed's date, names no commencing order, and an order for one territory alone dates nothing, because that order is a devolved Act's whole reach.
- **Example:** EA 1995 s.57 inserted EPA 1990 Part IIA, commenced for England on 2000-04-01, Scotland on 2000-07-14 and Wales in 2001. Part IIA is in force in part from 2000-04-01, no longer from EA 1995's making. HSWA's Railways Act 2005 changes keep the feed's 2006-04-01. TCPA 1990 s.78(4BA), by anaw 2015/4 for Wales only, keeps the feed's stages.
- **Serves:** `binds-on-date`, `unknown-over-guess` · **Code:** `Readers.AmendingCommencement` (`claims/3`); `Evidence` (`{:commencement, :date_staged}`, `:partial_staged`) · **Test:** `amending_commencement_test` "commenced territory by territory"; `evidence_test` "a territory-by-territory commencement's first stage" · **Origin:** Environmental Protection: Switch-over, Decision 3 (B), Jason 2026-11-12; each later stage as its own change (A) is parked with the Amending-law reader

### `schedule-commences-with-its-introducer`
A Schedule comes into force with the provision that gives it effect.
- **Example:** Energy Act 2013 Sch.12 is commenced by SI 2014/251.
- **Serves:** `law-text-wins` · **Code:** `Commencement.ScheduleEffect`; `Readers.AmendingCommencement` · **Test:** not found in the change-vocabulary suite · **Origin:** Jason 2026-10-29, `cv-s08-evidence`

### `no-royal-assent-for-acts-by-order`
An Act brought in by orders we don't hold has no start date, never Royal Assent. No period is written before the first dated day: the row is unknown until then.
- **Example:** Control of Pollution Act 1974 s.101 (golden: `in_force_from` empty).
- **Serves:** `unknown-over-guess` · **Code:** `LabelSource` (start), `LabelPeriods.periods/4` (no period from the 1900-01-01 placeholder) · **Test:** `label_periods_test` "no period from the placeholder start" · **Origin:** golden convention C10 (`cv-01-architecture-review`, 2026-10-21); `cv-06-switch-over` (2026-10-31)

### `left-to-an-order-date-unknown`
A provision its own law leaves to an order we don't hold reads in force from the law's start, with its in-force date unknown (a counted gap). It never takes the law's start as its in-force date. A dated insertion or a start-day commencement still dates it.
- **Example:** 157 rows in Environmental Protection, OH&S and Maritime Safety (`OwnCommencement` `:by_order`) read in force from the law's start with that day as in_force_from.
- **Serves:** `unknown-over-guess` · **Code:** `LabelSource` (`by_order`), `Label.Start` (`by_order_undated?/2`) · **Test:** `label_fold_test` "a row its own law leaves to an order we don't hold" · **Origin:** Jason 2026-11-11, Environmental Protection: Label fold, Decision 8 (the parked J6)

### `own-clause-early-start`
A row its own law's clause commences before the law's general start, once the law is made, begins on that day: prospective from the making, in force from the clause's day.
- **Example:** WSI 2026/103 brings Part 7 into force the day after it was made, though its general start is 2027-10-01 (1,720 rows in 4 laws).
- **Serves:** `law-text-wins`, `binds-on-date` · **Code:** `Label.Start.early_own/2`; gate check `start: an own commencement before the law's start dropped` · **Test:** `label_fold_test` "its own law's clause commencing it before the law's general start" · **Origin:** the agent pass, Environmental Protection: Label fold (2026-11-11)

### `feed-pending-dated-applies`
A change the feed holds prospective and not yet applied applies on its date where the feed gives one. legislation.gov.uk's text lags; the date stands. An undated one changes nothing (`Undated.pending?`).
- **Example:** 240 such changes in three families: 186 undated (skipped), 54 dated (applied).
- **Serves:** `source-authority` · **Code:** `Label.Undated` (`pending?/1`) · **Test:** `label_fold_test` "never one the feed holds prospective and unapplied" · **Origin:** Jason 2026-11-11, Environmental Protection: Label fold, Decision 9 (the parked J4)

### `royal-assent-only-when-nothing-else`
An Act with no commencement clause is in force on Royal Assent (Interpretation Act 1978 s.4). An amending Act's Royal Assent dates only what no other rule reaches. Its "first start" is its orders' earliest date, not its Royal Assent.
- **Example:** ERDRA 1998's changes to HSWA 1974 s.24 date from 1998-08-01 (SI 1998/1658), not from Royal Assent on 8 April.
- **Serves:** `law-text-wins`, `unknown-over-guess` · **Code:** `Readers.OwnCommencement`; `Readers.AmendingCommencement`; `Readers.AmenderStart.first_start/1` · **Test:** `amender_start_test` "an Act's Royal Assent only when nothing else dates it" · **Origin:** `cv-s08-evidence` (batch 1, 2026-10-29); `cv-06-switch-over` (batch 5, 2026-11-02)
- **Differs:** an Act whose own commencement section is repealed still falls back to Royal Assent (HSWA 1974 s.79 by the 1985 c.9 repeal; 1920 c.65). See open decision 9.

### `law-start-stored-with-the-build`
A law's own start is resolved by `LawStart` in the build, from the same input the old register's collector reads (`LawStart.Input`), and stored on the build's `changes_built` event. The label fold and golden read that, never the old register.
- **Example:** on 2026-11-07 the build's start equalled the old register's for all 285 built laws. The Factories Act 1961's is 1962-04-01, from its clause, not Royal Assent.
- **Serves:** `one-record-per-change`, `binds-on-date` · **Code:** `ChangeVocabulary.Build.start/1`, `Store.write/4`, `Store.start/1`, `LabelSource` (`start/1`) · **Test:** `law_start/input_test`; `store_db_test` "the law's start is stored with its build" · **Origin:** Jason 2026-11-02, `cv-06-switch-over` (then read from `lat_change_log`); moved to the build 2026-11-07, Maritime Safety: Switch-over (Jason: "Fix the bug as held by this step")

---

## 3. Territory

### `territory-from-extent-narrowed`
A row's territory starts as its extent. It is narrowed by its insertion's territory, by a commencement for one territory, and by the law's application clauses in force then.
- **Example:** SI 2013/1471 reg.15(5)(b) takes its inserting law's narrower extent.
- **Serves:** `binds-on-date`, `law-text-wins` · **Code:** `Label.Start` (`territory/5`) · **Test:** `label_fold_test` "its insertion's territory (C14)" · **Origin:** `cv-s09-label-fold` (2026-10-30)

### `devolved-law-applies-in-its-territory`
A devolved law's own provisions apply where its type puts it (wsi, anaw, asc → W; ssi, asp → S; the NI types → NI), or else where its own title does ("(Wales)", "(England)", "(England and Northern Ireland)", "(Scotland)"). The evidence is the law's own type or title, never its register extent.
- **Example:** SI 2017/544 extends to E+W and applies in W. Environmental Protection's 7,736 rows that differ on territory alone all come from this rule, against the old path's extent.
- **Serves:** `binds-on-date`, `law-text-wins` · **Code:** `Fold.own_territory/3`, `LawTerritory.territory/3`, `LawTerritory.title_place/1` · **Test:** golden SI 2017/544 reg.1(1) · **Origin:** `cv-s09-label-fold`; written down at Environmental Protection: Switch-over (2026-11-12). The title place can come from a cited law's title: SI 2021/1309, 28 rows, to look at

### `law-text-sets-territory`
A provision's own application clause, and its context in the law it amends, outrank the CLML's stated extent.
- **Examples:**
  - HSWA 1974 s.78 amends a GB-only Act, so it is E+W+S.
  - SI 2012/3038 reg.1A applies in NI only from 2021.
- **Serves:** `law-text-wins` · **Code:** `Readers.Application`; `Evidence` (`territory` order) · **Test:** `application_test` · **Origin:** Jason 2026-10-21 ("Agree c6 and c11"), `cv-01-architecture-review`; built 2026-10-22, `cv-03-readers`

### `application-is-not-a-version`
An application clause narrows where a provision applies. It never opens a new version of the text.
- **Example:** SI 2012/3038 reg.1A.
- **Serves:** `binds-on-date` · **Code:** `Label.Day.apply/4` (`:applied`) · **Test:** `application_test` "every provision applies in NI from the clause's date; not a new version" · **Origin:** `cv-03-readers` (2026-10-22)

### `application-to-cases-is-not-territory`
A sentence limiting which persons, things or activities a law covers is not territory. It is left for fitness (fractalaw).
- **Example:** "a disapplication of things" in an amending SI is read as no bound.
- **Serves:** `binds-on-date`, `prove-one-family` · **Code:** `AmendingLaw.Extent.Applies` (`ApplicationClause.cases?/1`) · **Test:** `amending_law/extent/applies_test` · **Origin:** Jason 2026-10-27, `cv-s05-extent-reader`; `application-scope-handoff`

### `change-territory-evidence-order`
A change's territory comes from:
1. the law's text;
2. the feed's application;
3. the markup's Extent;
4. the feed's effect extent, when narrower than the provision;
5. the affecting law's territory, but only for a removal whose text is kept and narrower than the provision;
6. a devolved legislature's competence, but only for an insertion by its own Act.

The amending provision's extent clause bounds whatever is chosen: extent is not application.
- **Example:** RTA 1988 s.4(6): the repeal is cut to E+W by SOCPA 2005 s.179, so the provision stays in force in Scotland from 2006.
- **Serves:** `law-text-wins` · **Code:** `Evidence` (`@table` `territory`, `bound/3`) · **Test:** `evidence_test` "the legal text wins over the markup and the feed"; `note_date_test` competence cases · **Origin:** `cv-01-architecture-review` (2026-10-21); `cv-03-readers` (2026-10-22)

### `no-default-territory`
A change that no source places has unknown territory, never "UK". A repeal of a provision whose extent is unknown leaves nothing in force.
- **Example:** SI 1987/605, revoked E+W+S with no extent held, reads repealed, not "in force NI".
- **Serves:** `unknown-over-guess` · **Code:** `Label.Facts.after_repeals/2` · **Test:** `label_fold_test` "an unknown extent leaves no remainder" · **Origin:** reply to Gemini, `cv-00-meta` (2026-10-21); `cv-s09-label-fold` (round 2)

### `unread-extent-gives-no-bound`
A sentence saying where provisions extend that is not read in full is recorded as unread. Its provisions get no bound, never the default.
- **Example:** SOCPA 2005 Sch.7 para 27(4) ("The repeal of section 4(8) extends also to Scotland") gave no bound until a later round read it.
- **Serves:** `unknown-over-guess` · **Code:** `AmendingLaw.Extent.Unread` · **Test:** `amending_law/extent_test` · **Origin:** Jason 2026-10-26, `cv-s05-extent-reader` (round 6)

### `powers-of-an-act-stating-no-extent`
An SI that states no extent extends as far as its enabling provisions. Each provision is placed by its parent Act's own extent clause. Where the parent Act states nothing of the provision, the provision takes the extent legislation.gov.uk states on it (`RestrictExtent`). "Nothing" means either of two cases:
- the parent states no extent at all (no default and no lists);
- the parent gives no default and none of its lists names the provision.

A statement on the provision left unread, or one over the whole Act, withholds it. The rule stays all or nothing: one provision with neither leaves the SI unbound.
- **Example:** the European Communities Act 1972 has no extent clause. Its s.2 is stated E+W+S+N.I., so the 45 Maritime Safety SIs made under s.2(2) are bound to the UK, where before they had no territory. The Government of Wales Act 2006 gives lists only, and none names s.150, so SI 2013/1821 takes s.150's stated extent. The Finance Act 1973's s.59(5) is conditional and unread over the whole Act, so the SIs made under its s.56 stay unbound.
- **Serves:** `law-text-wins`, `unknown-over-guess` · **Code:** `AmendingLaw.Extent.StatedExtent`, `Extent.Lookup.from_powers/3` (`silent_on?/2`), `Extent.Powers` · **Test:** `amending_law/extent/stated_extent_test`, `lookup_test` "a parent Act stating no extent", "a parent with lists and no default naming the provision nowhere" · **Origin:** Jason 2026-11-05, Decision 2, `maritime-safety-extent-reader`; widened by Jason 2026-11-09, Decision 2, `environmental-protection-extent-reader`

### `partly-excepted-provision-in-a-widening-list`
A list item that excepts part of its own provision is read where the list widens the extent: an "also" list, or "Only the following provisions … extend to Northern Ireland". The provision is in the list, and its excepted subdivisions are narrowed back to the default by a "not" list. In a list that sets or narrows the extent, the provision stays withheld (round 11): its excepted subdivisions would be carried with it, because narrowing is applied last and no list restores the default.
- **Example:** EPA 1990 s.164(4), "section 153 except subsection (1)(k) and (m)": s.153 extends to the UK, and s.153(1)(k) and (m) to E+W+S. The 22 SIs made under s.153 are bound to the UK.
- **Serves:** `law-text-wins` · **Code:** `Extent.ListItems` (`holding`), `Extent.Lists.lists/3`, `Lists.only_following/3` · **Test:** `extent/exceptions_test`, `environmental_protection_forms_test` "section 153 except subsection (1)(k) and (m)" · **Origin:** Jason 2026-11-09, Decision 3, `environmental-protection-extent-reader`

### `act-stating-no-clause-takes-whole-act-extent`
legislation.gov.uk often states an Act's extent once, on the whole Act (its root element), and on no provision. An Act stating no extent clause and no lists takes that whole-Act extent:
- as an enabling Act, for a provision that states none of its own;
- as an amending Act, as its changes' bound, but only where none of its provisions states a different extent.

The order is: the law's own default and lists, then an SI's powers, then this stated extent, then a devolved legislature's competence.
- **Example:** the Merchant Shipping (Pollution) Act 2006 states E+W+S+N.I. only on the whole Act. SI 2006/1265, made under its s.1, and the Wreck Removal Convention Act 2011's changes to the Merchant Shipping Act 1995 are bound to the UK, where before they had no territory.
- **Serves:** `law-text-wins`, `binds-on-date` · **Code:** `Extent.StatedExtent` (`root/1`, `uniform/1`), `Extent.stated`, `Extent.Lookup.of/2`, `Extent.Powers` · **Test:** `amending_law/extent/stated_extent_test`, `lookup_test` "an Act stating no clause" · **Origin:** Jason 2026-11-05, Decision 3, `maritime-safety-extent-reader`

### `ancestor-insertion-territory`
A row whose own insertion names no territory takes the territory of the nearest insertion holding it that does.
- **Example:** SI 1999/2228 reg.3B(10)(b): reg.3B was inserted by SI 2017/592 for England only, so the row is E, not E+W.
- **Serves:** `law-text-wins` · **Code:** `Label.Start` (`insertion_territory/4`); gate check `territory: an ancestor insertion's territory lost` · **Test:** `label_fold_test` "an ancestor's insertion territory narrows a row" · **Origin:** the agent pass, Environmental Protection: Label fold (2026-11-11; 10 rows in 4 laws)

### `insertion-takes-inserting-territory`
Inserted text takes the inserting law's narrower territory. Laws inserting the same row on the same day for different territories insert it in their union.
- **Example:** HSWA 1974 s.23(4)(a): SI 2005/1541 inserts it for E+W and SSI 2006/475 for S, so it is E+W+S.
- **Serves:** `binds-on-date` · **Code:** `Label.Start` (`insertion_territory/4`) · **Test:** `label_fold_test` "inserted the same day by laws for different territories" · **Origin:** Gemini golden review taken 2026-10-30 (C14); `cv-s09-label-fold` (round 9)

### `one-territory-repeal-narrows`
A whole repeal for some territories takes them out. The provision stays in force where it remains (also when it is repealed but saved in one territory).
- **Example:** SI 2010/404 reg.14 (golden).
- **Serves:** `binds-on-date` · **Code:** `Label.Facts.after_repeals/2`; `Label.Day.apply/4` · **Test:** golden · **Origin:** golden conventions C1, C12 (`cv-01-architecture-review`, 2026-10-21)

### `windsor-changes-reach-gb-only`
For an EU instrument the Windsor Framework keeps in NI, a UK change on or after 2020-12-31 reaches GB only. NI keeps the EU text.
- **Examples:**
  - CLP Art 2(17) is E+W+S from 2020-12-31.
  - REACH Art 140 is omitted for GB and stays in force in NI.
- **Serves:** `binds-on-date`, `law-text-wins` · **Code:** `Windsor.confine/2`; `Label.Day` (`:windsor`); `LabelRules` (`:windsor_ni`) · **Test:** `windsor_test`; `label_rules_test` "a UK change to a Windsor law" · **Origin:** Jason 2026-10-30 ("Hold a small Windsor list"), `cv-s09-label-fold`
- **Checked:** both entries (REACH, CLP) are checked by Jason (2026-11-11, Environmental Protection: Label fold, Decision 6), and `Windsor.listed?/1` requires the flag. This closes open decision 11.

---

## 4. Changed by and commenced by

### `changed-by-all-lists-the-makers`
`changed_by_all` lists every law that made the current text: several laws when parallel changes take effect together, and never the law itself.
- **Example:** SI 2000/1043 reg.11(3) from 2005-07-16 is changed by both SI 2005/894 and WSI 2005/1806.
- **Serves:** `binds-on-date` · **Code:** `Label.Facts.makers/2`, `by/2`; `Label.Day.apply/4` · **Test:** golden; `label_periods_test` "changed_by keeps one law …" · **Origin:** D1 (2026-10-13); golden convention C5 (2026-10-21); column added by Jason 2026-10-31 ("add, don't replace")

### `earlier-amendment-credited`
A law that amended the amending law before it took effect is credited too, where its change reaches the row.
- **Example:** REACH Art 127E is changed by SI 2019/758 and by SI 2019/858.
- **Serves:** `binds-on-date` · **Code:** `Label.Facts.earlier_amendment?/1`; `Label.Day`; `EffectVerb.made_by/1` · **Test:** `label_fold_test` "an earlier amendment to the amending law made the text too"; `effect_verb_made_by_test` · **Origin:** Jason 2026-10-30, `cv-s09-label-fold` (batch 2)

### `commenced-by-apart`
`commenced_by` holds the law that brought the text into force when it is not one of the text's makers. It is empty when the law commenced itself.
- **Example:** HSWA 1974 s.78 is commenced by SI 1974/1439.
- **Serves:** `binds-on-date` · **Code:** `Label.Facts.commencers/3` · **Test:** `label_fold_test` "commenced_by: a commencing order, apart from the laws that made the text" · **Origin:** Jason 2026-10-30, `cv-s09-label-fold` (batch 1). This superseded the 2026-10-21 ruling that put the commencing law in `changed_by`.

### `changed-by-one-law-for-compliance`
The table's single `changed_by` is the law that made the text, else the last law in `commenced_by`. Among several makers it is the principal maker, never an amender of the amending law before that law took effect (an earlier-amendment credit), unless only credits made the text. Of those it is the latest made, by year and then number, whatever the series.
- **Example:** REACH Art 127E(10) on 2020-12-31 writes SI 2019/758, the exit SI, not SI 2020/1577, which amended it before exit day. SI 1999/3242 reg.10(1)(c) on 2006-10-01 writes SSI 2006/457 over SI 2005/1541.
- **Serves:** `binds-on-date` · **Code:** `LabelPeriods.periods/4` (`one_law/2`) · **Test:** `label_periods_test` "changed_by: the law that made the text, never an amender of the amender"; "… the latest made by year then number"; "… the law that commenced it" · **Origin:** Jason 2026-10-31 ("add, don't replace"), `cv-05-consumers`; Jason 2026-11-06, Maritime Safety: Labels side by side, Decision 1 (A; Gemini concurred). This closes open decision 1.

### `repeal-credits-the-repealer`
On a repealed or repealed_saved period, `changed_by` holds the repealing laws.
- **Example:** NISR 1997/248 Pt IV is credited to the laws that revoked regulations 13–17.
- **Serves:** `binds-on-date` · **Code:** `Label.Day.apply/4`; `Label.Undated.repealed_at_start/3`; `Label.Containers.close/2` · **Test:** `label_containers_test` "credited to their laws" · **Origin:** `cv-s09-label-fold` (2026-10-30; no separate ruling)

### `by-from-the-law-first`
The law that made a change comes from the law's text, then the feed, then the note's structured citation link.
- **Example:** 1,295 stored changes take `by` from the note's `Citation` link alone.
- **Serves:** `law-text-wins` · **Code:** `Evidence` (`@table` `by`) · **Test:** `evidence_test` · **Origin:** `cv-01-architecture-review` (2026-10-21); the note exception is Jason 2026-10-28, `cv-s07-merge` (see open decision 3)

### `commenced-by-from-the-law-first`
The commencing law comes from the commencement reader (the law's clause, an order read). Failing that, it comes from the order the feed's stage names, which is derived.
- **Example:** HSWA 1974 s.51A(2)(b) is commenced by SI 2006/378, from the feed.
- **Serves:** `law-text-wins`, `coverage-from-lgu` · **Code:** `Evidence` (`commenced_by`); `Readers.Feed` · **Test:** `evidence_test` · **Origin:** `cv-s09-label-fold` (round 2, 2026-10-30)

### `as-amended-by-chain-credits-feed-law`
A two-link "as amended by" chain credits the law the feed names as affecting. The chain itself stays a pointer.
- **Example:** REACH as changed by SI 2019/1144, itself amended by SI 2020/1577.
- **Serves:** `coverage-from-lgu` · **Code:** no rule of its own: follows `by-from-the-law-first`; `Readers.Markup` cites no "(as amended by …)" aside · **Test:** none found · **Origin:** Jason 2026-10-29, `cv-s08-evidence`

### `unapplied-prospective-makes-nothing`
An undated change that the feed holds as prospective and unapplied is not in the text, so it is not credited.
- **Example:** PRA 2002's insertion of HSWA 1974 s.51A(2A)–(2B), never in force.
- **Serves:** `binds-on-date` · **Code:** `Label.Undated` (`pending?/1`) · **Test:** `label_fold_test` "a prospective change never applied" · **Origin:** `cv-06-switch-over` (batch 4, 2026-11-01)

### `expiry-is-the-laws-own`
A law's own sunset is a removal by the law itself, so it has no `changed_by`.
- **Example:** Coronavirus Act 2020 s.78.
- **Serves:** `law-text-wins` · **Code:** `Readers.Expiry` · **Test:** `expiry_test` · **Origin:** Jason 2026-10-22, `cv-04-merge-evaluator`

---

## 5. Existence and versions

### `exists-from-its-insertion`
A row is labelled from its law's start, or from the latest whole insertion of it or of anything holding it, whichever is later. It is never labelled from its law's start if it came later.
- **Examples:**
  - SI 2009/1348 reg.19B is labelled from 2011, not 2009.
  - HSWA 1974 s.51A(2E)(b) is labelled from 2005, inside an s.51A of 1998.
- **Serves:** `binds-on-date` · **Code:** `Label.Start.start/2` · **Test:** `label_fold_test` "inserted later: from its insertion"; "the latest insertion starts it" · **Origin:** `cv-s09-label-fold` (rounds 1 and 3, 2026-10-30)

### `never-before-its-maker`
No period credits a law, or begins its text, before that law existed. An undated whole insertion by a later law begins the row at that law's first dated record on the row or anything holding it, else at its making, with in_force_from unknown. An undated whole repeal by a later law, its text gone, reads repealed from the same day. An undated substitution or other maker by a law made after a period's start is not credited to it.
- **Examples:**
  - EPA 1990 Part IIA, inserted by EA 1995 s.57 with no source dating it, begins in 1995, not 1990 (674 rows).
  - EPA ss.30–50 and s.143, repealed by EA 1995 Sch.24, undated, read repealed from 1995, not 1990.
  - EPA s.126, substituted by 1999 c.28 with no date: its 1991 text keeps its own maker.
- **Serves:** `binds-on-date`, `unknown-over-guess` · **Code:** `Label.Start.inserter_born/5`, `made_after?/3`; `Label.Undated.date_late_repeals/2`; `LabelSource` (`made_of`) · **Test:** `label_fold_test` "Environmental Protection: Label fold (2026-11-11)" · **Origin:** Jason 2026-11-11, Environmental Protection: Label fold, Decisions 1 and 7 (the parked undated-change-before-its-law)

### `version-begins-with-its-sibling`
A territorial version with no insertion of its own begins no earlier than its sibling's dated insertion of the number, or of one holding it. Its in-force date is unknown.
- **Example:** EPA s.106(4A)[E+W] and (4B)(a)[E+W], inserted in the S text by SSI 2002/541 on 2002-12-05, are not labelled from 1990.
- **Serves:** `binds-on-date`, `unknown-over-guess` · **Code:** `Label.Start.sibling_born/5`; `LabelRules` (`before_insertion` skips another version's later insertion) · **Test:** `label_fold_test` "a version with no insertion of its own"; `label_rules_test` "a later insertion for another version" · **Origin:** Jason 2026-11-11, Environmental Protection: Label fold, Decision 4

### `heading-insertion-never-restarts`
A Part's or Chapter's insertion later than the row's own dated record (its commencement or insertion) never moves the row's start: the heading came round text already there.
- **Example:** EA 1995 ss.11–16A, there since 1996 or 2002, under the Chapter 1A heading WSI 2013/755 inserted.
- **Serves:** `binds-on-date` · **Code:** `Label.Start.start/2` (`container_after_own?/2`) · **Test:** `label_fold_test` "a container's later insertion never moves" · **Origin:** Jason 2026-11-11, Environmental Protection: Label fold, Decision 5

### `legacy-addition-never-moves-start`
An insertion claimed only by old-style markup (`d…p…` ids) does not move the start, unless the amending law's text or the feed also says "inserted". Such rows are listed apart as `legacy_unconfirmed`.
- **Examples:**
  - OSRPA 1963 ss.4–16 keep their start.
  - Factories Act 1961 s.10A moves, because EMASA 1972 s.3 says "as if … inserted".
- **Serves:** `law-text-wins`, `unknown-over-guess` · **Code:** `Label.Start.legacy_only?/1`; `LabelRules` (`:legacy_unconfirmed`) · **Test:** `label_fold_test` "a legacy markup Addition alone never moves it"; `label_rules_test` "listed apart" · **Origin:** Jason 2026-10-29, `cv-s08-evidence`; `cv-06-switch-over` (batch 2, 2026-11-01)
- **Differs:** `Label.Undated.makers/2` still counts such an insertion as the text's maker, which blanks the date (Factories Act 1961, 50 periods). See open decision 6.

### `evidence-it-existed`
A sub-provision under a whole substitution begins at that substitution, unless a source shows it was there before. The same holds for a number that the substitution's quote makes. Evidence that it was there:
- the text held predates the substitution (the made text predates everything);
- a dated change to it or under it;
- an order naming it;
- a repeal of it on the same day.

Numbers a quote drops are no evidence.
- **Examples:**
  - CLP Art 37(9) begins with SI 2026/484.
  - HSWA 1974 s.11(1) keeps its 1974 history.
- **Serves:** `law-text-wins`, `binds-on-date` · **Code:** `Label.Existence` (`born/5`, `begin/5`, `existed?/4`) · **Test:** `label_fold_test` "evidence it existed (Jason 2026-10-31)" · **Origin:** Jason 2026-10-30 ("quote alone is evidence"), reconciled 2026-10-31 ("Evidence it existed"), `cv-06-switch-over` (see open decision 8)

### `quote-new-numbers-are-inserted`
In a substitution, the numbers the instruction names stay substituted. Every other number its quote makes is inserted, children included.
- **Example:** "for subsection (2) substitute (2), (2A), (2B)": HSWA 1974 s.47(2A) and (2B) are inserted by ERRA 2013.
- **Serves:** `law-text-wins` · **Code:** `Amendment.Reader.NewNumbers` · **Test:** `amendment/reader_test` · **Origin:** Jason 2026-10-30, `cv-s09-label-fold` (rounds 5–6)

### `quote-dropped-numbers-are-repealed`
A whole substitution whose quote no longer makes an old number ends that provision.
- **Example:** SI 2026/867 on reg.12A.
- **Serves:** `law-text-wins` · **Code:** `Readers.AmendingLaw.Dropped` · **Test:** `amending_law_dropped_test` · **Origin:** `cv-s09-label-fold` (round 7, 2026-10-30)

### `reinsertion-of-an-existing-row-is-substitution`
A quote that "inserts" a row which a source shows was already there substitutes its text instead.
- **Example:** NISR 1999/305 reg.11(2)(a), in the 1999 made text, is re-quoted in 2003.
- **Serves:** `law-text-wins` · **Code:** `Label.Existence.reread/4` · **Test:** `label_fold_test` "a quote's insertion of a row in the made text held" · **Origin:** `cv-06-switch-over` (2026-10-31)

### `no-commencement-before-existence`
A commencement dated before the provision existed never reaches it.
- **Example:** CROW 2000 s.1A(a) is not reached by the law's own start record.
- **Serves:** `binds-on-date` · **Code:** `Label.fold/3` · **Test:** golden (CROW rows) · **Origin:** `cv-s09-label-fold` (round 2, 2026-10-30)

### `child-change-never-reaches-parent`
A change to a child never opens a period on its parent. A whole-provision change reaches the rows under it only when a source states that it is whole.
- **Example:** a markup Addition on CROW 2000 s.1, wrapping s.1(6A)–(6C) with no stated level, no longer reaches all of s.1.
- **Serves:** `binds-on-date` · **Code:** `Label.reaches?/2` · **Test:** `label_fold_test` "a change whose level no source states never reaches what lies under it" · **Origin:** golden convention C9 (2026-10-21); `cv-s09-label-fold` (round 2)

### `part-change-reaches-its-rows`
A whole change on a Part, Chapter or Title reaches the rows inside it. A Part row keeps its own heading changes.
- **Examples:**
  - REACH Art 139B, in Title XVA inserted by SI 2019/758.
  - CLP Title V keeps its heading change.
- **Serves:** `binds-on-date` · **Code:** `Label.fold/3` (`within/2`), `Label.containers/2` · **Test:** `label_fold_test` "a whole insertion of the Part holding it reaches it"; "a Part row keeps its own heading changes" · **Origin:** `cv-s09-label-fold` (round 5); `cv-06-switch-over` (round 1)

### `bracketed-part-is-a-locator`
A Part, Chapter or Title that a feed effect names in brackets beside a provision or range ("s. 130A-130E (Pt. 6) (Ch. 1A)") says where the provision sits; it is not a target. The change goes on the provisions alone. A container named outside brackets ("Pt. 4 heading", "s. 13 Pt. 4") stays a target.
- **Example:** MSA 1995: the 1997 Act's insertion of ss.130A–130E reached the whole of Part VI (773 rows, 529 losing their periods from 1996); it now reaches ss.130A–130E.
- **Serves:** `binds-on-date`, `coverage-from-lgu` · **Code:** `Readers.Feed.located/3` · **Test:** `feed_targets_test` "a Part or Chapter in brackets beside a provision locates it, never a target" · **Origin:** Jason 2026-11-06, Maritime Safety: Switch-over, Decision 2 (B; Gemini concurred). The store holds 310 such effects in 50 laws, 18 of which move a label.

### `earlier-amendment-in-either-form`
An amendment to an earlier amending law changes that law's provision, not this law's text: no operation, marked `earlier_amendment`. This holds whether the feed writes "… in earlier amending provision S.I. N/N" or names the law straight after "earlier amending" ("… in earlier amending S.S.I. 2019/103, reg. 10").
- **Example:** SSI 2009/440 reg.15(3)(b): "words substituted in earlier amending S.S.I. 2019/103, reg. 10" by SI 2020/1091 was read as a substitution in reg.15(3)(b)'s own words.
- **Serves:** `one-record-per-change` · **Code:** `EffectVerb.earlier_amendment?/1`, `EffectVerb.kind/1` (not `EffectKind`, which counts toward the parser's version) · **Test:** `effect_verb_earlier_test` · **Origin:** Jason 2026-11-09, Environmental Protection: Feed reader, Decision 2. The short form is 8 effects in the store: 7 in two Environmental Protection laws, none in OH&S or Maritime Safety.

### `each-stage-its-own-order`
Each stage of a change brought in by stages names the order that commenced it on that stage's date (`commenced_by`), never the first stage's. Where two orders commence one stage on the same date (one for E., one for W.), the stage names the first entry's order, a known limit until the stages are read by territory.
- **Example:** Environment Act 1995 Sch. 8 para. 8(5): repealed for E. on 2003-11-18 by SI 2003/2938, for W. on 2003-11-27 by WSI 2003/3034. Both stages had been credited to SI 2003/2938.
- **Serves:** `binds-on-date` · **Code:** `Readers.Feed` (`staged_removal/2`, `stage_claims/3`; commencements by `stage_facts/3`) · **Test:** `feed_facts_test` "a removal in stages: each stage credited to its own commencing order" · **Origin:** Jason 2026-11-09, Environmental Protection: Feed reader, Decision 4 (Gemini concurred). The fix reaches 50 effects in 4 Environmental Protection laws, 3 in one OH&S law and 1 in one Maritime Safety law.

### `container-repealed-with-last-child`
A Part, Chapter or Title is repealed (or repealed_saved) on the day its last child is, credited to the repealing laws. This is the one exception to `child-change-never-reaches-parent`.
- **Example:** NISR 1997/248 Pt IV.
- **Serves:** `binds-on-date` · **Code:** `Label.Containers.close/2` · **Test:** `label_containers_test` · **Origin:** Jason 2026-10-30, `cv-s09-label-fold` (round 6)

### `versions-share-history`
A provision with territorial versions (s.23[E+W], s.23[S]) shares its history up to the split. Before the split, a change counts if it overlaps the territory the row then had, or if the version's own text carries it. After the split, only the version's own territory counts.
- **Examples:**
  - SI 2008/1597 reg.21(2)(a)[NI] keeps SI 2015/1682.
  - HSWA 1974 s.23(4)[NI] goes back to its 1975 text.
- **Serves:** `binds-on-date` · **Code:** `Label.fold/3` (`for_version?/3`, `own_text_at_split/5`); `Label.Version` · **Test:** `label_fold_test` batches 7–9 · **Origin:** golden convention C3 (2026-10-21); Jason 2026-10-30 ("union before the split"), `cv-s09-label-fold` (rounds 7–8)

### `versions-split-when-texts-part`
The versions split on the first day a change under the provision appears in some versions' text and not the others. This can be earlier than legislation.gov.uk's version start.
- **Example:** HSWA 1974 s.16 splits in 2006, not 2015.
- **Serves:** `binds-on-date`, `law-text-wins` · **Code:** `Label.Version.diverged/3` · **Test:** `label_fold_test` "versions part when their texts do" · **Origin:** Jason 2026-11-01 ("when the section parts"), `cv-06-switch-over`

### `split-day-repeal-reaches-the-version`
On its split day, a version takes its own territory before that day's changes. A repeal on that day therefore reaches it.
- **Example:** HSWA 1974 s.14(7)[NI] is repealed (saved) by SI 2016/1142.
- **Serves:** `binds-on-date` · **Code:** `Label.Version.enter/4` · **Test:** `label_fold_test` "a version split the day its territory is repealed" · **Origin:** `cv-s09-label-fold` (round 9)

---

## 6. Undated changes

### `fold-uses-dated-changes`
The day-by-day fold uses only dated changes. An undated words change on a row with a dated start is left out and does not show on the label.
- **Example:** 2,048 OH&S rows were reached by a change no source dates (CV-S09 strata, 2026-10-29).
- **Serves:** `unknown-over-guess` · **Code:** `Label.fold/3` (filters `resolved.date != nil`) · **Test:** golden · **Origin:** `cv-s09-label-fold` (2026-10-29)
- **Differs:** Jason 2026-10-30 ("We do need a date, cannot have 1995 text as never in force") asks for the date to be found. Rows still undated are neither shown as gaps nor listed. See open decision 4.

### `note-points-to-a-date`
An undated change takes its date from the amending law's own commencement, at the amending provision that the feed record (else the note) names. The deepest named provisions decide. If they disagree, there is no date. The date is tiered derived.
- **Example:** SI 1995/2923 on Factories Act 1961 s.138.
- **Serves:** `law-text-wins`, `unknown-over-guess` · **Code:** `Readers.NoteDate`; `Label.Facts` (`pointed/3`) · **Test:** `note_date_test` · **Origin:** Jason 2026-10-22 ("Use Notes as pointers when we have a gap"), `cv-07-primary-coverage`

### `amender-first-start`
This is the last gap-filler. A change still undated takes the earliest day its amending law's own commencement rules date. It is never used for a change marked prospective.
- **Example:** the Building Act 1984 Sch.7 repeals of HSWA 1974 ss.61–71 are dated from 1984-12-01.
- **Serves:** `unknown-over-guess` (a lower bound), `binds-on-date` · **Code:** `Readers.AmenderStart` · **Test:** `amender_start_test` · **Origin:** Jason 2026-11-01 ("amending law's first start"), `cv-06-switch-over`
- **Differs:** the module says "a derived date", but its `via` claim is the string `"amender_first_start"`. `Facts.pointed/3` treats only `:note` and `:feed` as derived, so the label tiers this date primary. See open decision 12.

### `undated-insertion-made-the-text`
A whole insertion by another law that no source dates, on the row or its nearest ancestor, made the row's text, and that law is credited. The row's own law's commencements never reach it. This applies only when the law's text or the feed states the insertion.
- **Examples:**
  - HSWA 1974 s.34(6), inserted by the Gas Act 1986.
  - HSWA 1974 s.25A(1), inserted by CPA 1987.
- **Serves:** `binds-on-date`, `law-text-wins` · **Code:** `Label.Undated.insertion/3`, `makers/2`; `Label.fold/3` · **Test:** `label_fold_test` "an undated insertion by another law" · **Origin:** `cv-s09-label-fold` (rounds 2–4, 2026-10-30)

### `undated-substitution-leaves-date-unknown`
Text made by another law's whole substitution that no source dates leaves `in_force_from` empty from then. It never takes the date of the text it replaced.
- **Example:** HSWA 1974 s.22(4) by CPA 1987, before CPA's orders were fetched.
- **Serves:** `unknown-over-guess` · **Code:** `Label.Day` (`undated_maker?/2`) · **Test:** `label_fold_test` "text another law substituted, undated" · **Origin:** Jason 2026-10-30 ("until it is held, in_force_from is nil"), `cv-s09-label-fold` (batch 7)

### `undated-start-takes-undated-changes`
On a start no source dates, the row's undated words changes are credited, and so is the nearest undated substitution of an ancestor. On a dated start they are not.
- **Examples:**
  - REACH Art 118(2)(c).
  - REACH Art 40(1)(a).
  - CLP Art 54.
- **Serves:** `binds-on-date` · **Code:** `Label.Undated.words/2`, `ancestor_substitutions/3` · **Test:** `label_fold_test` "an undated words change on an undated start made its text" · **Origin:** Jason 2026-10-30, `cv-s09-label-fold` (batch 3)

### `undated-repeal-with-text-gone`
An undated whole repeal of the row or an ancestor, where the text no longer shows, makes the row repealed from its start, unless the feed holds that repeal prospective and unapplied: then it makes nothing (`unapplied-prospective-makes-nothing`).
- **Example:** CLP Art 25(5), deleted by Regulation (EU) 286/2011.
- **Not:** Ports Act 1991 s.29, a heading row with no text of its own, whose repeal by the Local Government Act 2003 Sch.8 is prospective and unapplied (it read repealed from 1991).
- **Serves:** `binds-on-date` · **Code:** `Label.Undated.repeals/3`, `repealed_at_start/3` · **Test:** `label_fold_test` "an undated whole repeal with its text gone", "an undated whole repeal never applied" · **Origin:** `cv-s09-label-fold` (round 3); `parked-owner-bugs` 2026-11-08

### `named-date-gap`
Some rows have a change no source dates, and the amending law's commencement is not held. These are named date gaps: listed in a file, listed apart by the rules check, and kept on their old label.
- **Example:** HSWA 1974 s.34(6) (Gas Act 1986).
- **Serves:** `unknown-over-guess`, `fix-where-owned` · **Code:** `KnownLimits`; `LabelSwitch.merge_kept/3`; list `backend/data/reports/change-vocabulary/cv-06-date-gaps.md` (7 rows) · **Test:** `label_switch_test` "a known limit keeps its old periods" · **Origin:** Jason 2026-11-01 ("Named gap"); 2026-11-02 (keep the old label), `cv-06-switch-over` (see open decision 5)

---

## 7. Source authority and evidence order

### `primary-first-derived-fills`
Each source has a tier:
- **primary:** the law's text and its commencement;
- **derived:** legislation.gov.uk's markup, its feed, the law's metadata, and "commenced through its parts".

For every attribute the primary sources come first. Derived sources fill only what the law's text doesn't say.
- **Example:** an operation the amending law states beats the feed's.
- **Serves:** `law-text-wins` · **Code:** `Evidence` (`@tiers`, `@table`) · **Test:** `evidence_test` "derived sources fill what the legal text doesn't say, marked derived" · **Origin:** Jason 2026-10-21, `cv-00-meta`

### `disagreements-reported-not-reconciled`
A primary and a derived claim that disagree are both kept, and the disagreement is reported as a conflict. Only like-for-like claims are compared:
- a substitution the markup shows as an insertion is no conflict;
- the order commencing a change is not the law making it, so there is no conflict between them.
- **Example:** HSWA 1974 s.84(5): the legacy markup says "inserted", the law says "repealed". This is no conflict, and the law wins.
- **Serves:** `law-text-wins`, `one-record-per-change` · **Code:** `Conflicts` (`values/1`, `like?/5`) · **Test:** `conflicts_test` · **Origin:** Jason 2026-10-21; `cv-04-merge-evaluator` (2026-10-22); `cv-s08-evidence` (2026-10-29)

### `operation-order`
The operation comes from the law's text, then commencement, then the feed, then the markup.
- **Example:** an Addition in the markup marks a substitution's new words. The feed's "substituted" was right in 12 of 12 cases.
- **Serves:** `law-text-wins` · **Code:** `Evidence` (`operation`) · **Test:** `evidence_test` "the feed's operation outranks the markup's" · **Origin:** Jason 2026-10-29, `cv-s08-evidence` (see open decision 13 for the history)

### `legacy-markup-fills-never-contradicts`
An old-style markup Addition placed inside a provision's text claims no operation. One placed round the provision's number claims "inserted". A legacy operation fills a gap but never contradicts the law.
- **Example:** Forestry Act 1967 s.1(4)(a), inserted by SI 1999/1747 (golden).
- **Serves:** `law-text-wins`, `coverage-from-lgu` · **Code:** `Readers.Markup`; `Conflicts.like?/5` · **Test:** `evidence_test` "a legacy markup operation fills a gap but never contradicts the law" · **Origin:** Jason 2026-10-29 (twice, the same day), `cv-s08-evidence` (see open decision 6)

### `level-order`
"Whole provision or words" comes from:
1. the law's text;
2. commencement;
3. the markup where it is sure (the number is wrapped, or part of the text is covered);
4. the feed, but only for the provision it placed the event on;
5. the markup's "covering all the words" signal.

If no source states the level, it reaches nothing below the row. An own repeal with no stated level, on a row still showing text, is a words repeal.
- **Example:** SI 2018/816 reg.23(1)(a)(ii).
- **Serves:** `law-text-wins` · **Code:** `Evidence` (`level`); `Readers.Markup.Level`; `Label.reaches?/2`; `Label.Day` · **Test:** `evidence_test` "the feed's level speaks only for the provision it placed the event on"; `markup_level_test` · **Origin:** `cv-s08-evidence` (batches 1 and 3, 2026-10-29); `cv-s09-label-fold` (round 4)

### `quoted-number-is-not-own`
The markup is sure of a whole provision only when the change wraps the provision's own number. A number inside quoted text (a BlockAmendment), with no row id of its own, belongs to the quote. A change that inserts quoted paragraphs changes the provision's words.
- **Example:** SI 2006/2988 reg.5(6), "For subsection (7), substitute—": a later insertion of the quoted (aa) and (ab) is words in reg.5(6), as its note says. Also SI 2019/775 reg.153(6) and PACE 1984 s.114(2)(b)(i); 312 changes across the store.
- **Serves:** `law-text-wins` · **Code:** `Readers.Markup` (`quoted/3`, `number/2`); `Readers.Markup.Level` · **Test:** `markup_level_test` "a number inside quoted text is not the provision's own" · **Origin:** Jason 2026-11-09, Environmental Protection: Markup reader, Decision 3 (found by the agent check, seed 61)

### `tier-per-field`
Each label field takes its tier from the changes that set it. It is derived if any of them is derived. A commencement date found through a feed or note pointer is derived. An empty field has no tier.
- **Example:** HSWA 1974 s.43(6): the text's makers keep their tier through a later commencement.
- **Serves:** `law-text-wins` · **Code:** `Label.Facts.tiers/3`; `Label.Day` (`retier/3`); `Label.Made` (the made period's emptied fields); `Gate.Label` (`tier: empty field`) · **Test:** `label_fold_test` "a field's tier changes only with its value"; `label_made_test` "the made period's emptied fields have no tier" · **Origin:** Jason 2026-10-21 ("every label value carries its tier"); `cv-04-merge-evaluator` (2026-10-22); tiers counted from round 3, `cv-s09-label-fold` (2026-10-30); the made period, `maritime-safety-label-fold` (2026-11-06)
- **Differs:** tiers are not written. `lat_label_timeline` has no tier column, so compliance never sees them. See open decision 12.

### `readers-carry-the-fold-decides`
A reader records what its source says, as a claim. What it means for a label is decided by the fold.
- **Example:** a feed commencement "for E.W.S." is carried as `in_force_for`, and the fold makes it a territory.
- **Serves:** `one-record-per-change` · **Code:** `Readers.Feed` (`in_force_for`); `Label.Facts.territory_only/1` · **Test:** `label_fold_test` "a commencement for one territory" · **Origin:** Jason 2026-10-23, `cv-s02-feed-reader`

### `one-record-per-event`
Sources are merged by identity: the effect id first, otherwise a secondary key (amended law, target, affecting law and provision, operation family, position). Each real event is one change.
- **Example:** HSWA 1974 s.27(1): three ChangeIds on one note, by SI 2008/960 art.11(2), are one change.
One instruction naming several provisions is one event: its other places take the event's feed facts, unless the feed records the instruction per place (another effect by the same law names the same amending provision). Then each place joins its own effect, or stays apart (Environmental Protection: Merge, Decision 3, 2026-11-10).

- **Serves:** `one-record-per-change` · **Code:** `Merge`, `Merge.Candidates`, `Merge.Partner`, `Merge.Precise`, `Merge.Shared`, `Merge.Copies`, `Merge.OwnCommencement`; the family gate `MergeGate` (`merges.json`) · **Test:** `merge_identity_test`, `merge_test`, `merge_own_commencement_test`, `merge_gate_test` · **Origin:** `cv-01-architecture-review` (2026-10-21); `docs/lat-change-pipeline/CHANGE-IDENTITY-DESIGN.md` (Jason 2026-10-28); the code gate, Maritime Safety: Merge (Decision 1, 2026-11-06)

### `new-provisions-carry-their-event`
A new provision that a joined change makes below it (an amendment substituting words that brings in new paragraphs) stays its own change. It still takes the event's key and the event's feed dates, which are marked as placed on the parent. Its operation, level and territory stay the law text's, and its own commencement still wins where it speaks.
- **Example:** 2009 c.25 Sch.21 para.34, "in subsection (6), for 'where' to the end substitute — (a) … (c)". MSA 1995 s.271(6)(a)–(c) are inserted on 25 Jul 2013, with s.271(6)'s effect; before, they had no date of their own or the Royal Assent date.
- **Serves:** `binds-on-date`, `one-record-per-change`, `unknown-over-guess` (the date is a source fact: legislation.gov.uk's markup wraps the new paragraphs under the one effect id) · **Code:** `Merge.Copies` · **Test:** `merge_copies_test` · **Origin:** Jason with Gemini 2026-11-06, Maritime Safety: Merge (Decision 2)

### `feed-is-the-coverage-baseline`
The feed and the markup give coverage. The law's text is read for territory, dates, its own clauses and changes not yet in the feed. Fetches go one hop out, whole documents counted, with Jason's go. An amendment to an amending law is one hop.
- **Example:** CV-07 fetched and read the 144 OH&S amending laws; it did not widen the reader to match the feed's 7,448 changes.
- **Serves:** `coverage-from-lgu` · **Code:** `mix lat.sources` (`Sources`, the CLML store) · **Test:** sources gate (`mix lat.sources --family F`) · **Origin:** Jason 2026-10-22, `cv-07-primary-coverage`; effects first (memory, 2026-10-18)

### `read-a-law-for-our-scope`
A law is read from our LAT rows to the law, never from the law to our rows. A scoped law (its LAT holds fragments only) is read for the scope we hold. A change beyond its fragments is outside our LAT scope: it is accounted for, but it is no row fault.
- **Example:** the Aggregates Tax and Devolved Taxes Administration (Scotland) Act 2024 is in the LAT only for s.64, the commencement power its two commencement Regulations are made under. Its 131 commencements of ss.1–63 are `outside_lat_scope`.
- **Serves:** `coverage-from-lgu` · **Code:** `MarkupPlacement.classify/3` (`held.scope`), `mix lat.markup_check` · **Test:** `markup_placement_test` "a scoped law: …" · **Origin:** Jason 2026-11-09, Environmental Protection: Markup reader, Decision 1 ("we are back-to-front … we should go from our LAT rows (our scope) to the law"). The Sources bug `scoped-law-body-not-needed` is the same direction at the fetch.

---

## 8. Notes

### `notes-never-decide`
A note's words never set a label field. A note may point to where to look: which records are one event, and which amending provision to read for a date.
- **Example:** an Addition whose note says "repealed" is not read as a repeal from the note's verb.
- **Serves:** `law-text-wins` · **Code:** `Readers.Markup` (note claims are `:note`, `:cited_text`, `:affecting`, which no evidence row uses except `:cited`) · **Test:** `conflicts_test`; `note_law_test` · **Origin:** memory `notes-are-hints` (2026-10-09, 2026-10-12, 2026-10-15); `cv-01-architecture-review` (2026-10-21)
- **Differs:** see `note-citation-as-last-by` and open decision 3.

### `note-for-identity`
A note's id and the provision it cites decide only which records are one event. The note never narrows copies or refuses a partner. A note citing the wrong paragraph never keeps a dated record apart from the one event on its provision that day.
- **Example:** HSWA 1974 s.28: three markup copies across its versions point to one note and are one change.
- **Serves:** `one-record-per-change` · **Code:** `Merge.Candidates`; `Merge.Partner`; `Readers.NoteLaw` (identity only) · **Test:** `merge_identity_test`; `note_law_test` · **Origin:** Jason 2026-10-22 ("decision - yes"), `cv-04-merge-evaluator`; Jason 2026-10-28, `cv-s07-merge`

### `note-citation-as-last-by`
When neither the law's text nor the feed names the law that made a change, the note's structured `Citation` link does. The note's free text never does.
- **Example:** HSWA 1974 s.28(5)(b) `d29p11427`: "S.I. 2004/ 1822" in the note's words is for identity only.
- **Serves:** `coverage-from-lgu` (in tension with `law-text-wins`) · **Code:** `Evidence` (`by: {:markup, :cited}`); `Readers.Markup` · **Test:** `note_law_test` · **Origin:** Jason 2026-10-28, `cv-s07-merge` (decision 3, "the one named exception")

### `note-only-placement-claims-no-level`
A change placed only by a note claims no level, except beside the provision the feed names.
- **Example:** Forestry Act 1967 s.1(4)(a).
- **Serves:** `law-text-wins` · **Code:** `Merge.Precise` · **Test:** `merge_precise_test` · **Origin:** `cv-s08-evidence` (batch 1, 2026-10-29)

---

## 9. Repeals and savings

### `repeal-everywhere-is-repealed-nowhere`
A whole repeal takes its territory out. With nothing left the row is repealed, with territory "nowhere" in the fold.
- **Example:** SI 2010/404 reg.14 (golden).
- **Serves:** `binds-on-date` · **Code:** `Label.Day.apply/4`; `Label.Facts.after_repeals/2` · **Test:** golden · **Origin:** golden conventions C1, C2 (`cv-01-architecture-review`, 2026-10-21)

### `repeal-period-as-the-table-records`
In the timeline, a repealed or repealed_saved period has `in_force_from` set to the repeal's day and an empty territory.
- **Example:** every repealed_saved period in the old timeline (5,727 of 5,727) does the same.
- **Serves:** `binds-on-date` · **Code:** `LabelPeriods.periods/4` · **Test:** `label_periods_test` "a repeal as the table records it" · **Origin:** Jason 2026-10-31 ("keep the table's rule"), `cv-06-switch-over`
- **Differs:** the fold's explicit "nowhere" (convention C2: "nowhere" is not the same as empty = unknown) becomes empty in the table. See open decision 2.

### `saving-makes-repealed-saved`
A repeal is repealed_saved when the law's text or the feed names a saving. Whether the saving reaches this row is not judged. The law's text is read first.
- **Examples:**
  - HSWA 1974 s.78.
  - SI 1992/3004 reg.27(2) for OSRPA (read from the law's text).
- **Serves:** `law-text-wins`, `binds-on-date` · **Code:** `Evidence` (`saved`); `Amendment.Reader.Savings`; `LabelRules` (`:saved_not_saved`) · **Test:** `amendment/reader/savings_test`; `label_rules_test` "a repeal its law's text saves, labelled repealed" · **Origin:** D3, `cv-03-readers` (2026-10-21); Jason 2026-10-30 ("D3 stands"); `cv-06-switch-over` (2026-10-31)

### `territorial-limit-is-not-a-saving`
"except in so far as it extends to Northern Ireland" limits where a repeal reaches. It is not a saving.
- **Example:** Factories Act 1961 s.77(2), by SI 1974/1941.
- **Serves:** `binds-on-date` · **Code:** `Amendment.Reader.Savings` · **Test:** `amendment/reader/savings_test` · **Origin:** `cv-06-switch-over` (batch 2, 2026-11-01)
- **Differs:** the limit's territory is not yet read, so the repeal is labelled everywhere (`cv-06b-routed-fixes`, bug 3).

### `purpose-removal-with-text-gone`
A removal of the provision kept for some purposes, with its text gone and not retained, makes it repealed (saved where a saving is named). If a later removal by the same law finishes it, the provision is partly in force until then.
- **Examples:**
  - SI 2009/716 reg.15.
  - HSWA 1974 s.47(5): partly in force from 2013-04-25 to 2013-10-01.
- **Serves:** `binds-on-date` · **Code:** `Label.Day.apply/4` (`finished_later?`) · **Test:** `label_fold_test` "revoked except for some purposes, its text gone" · **Origin:** `cv-s09-label-fold` (rounds 9–10, 2026-10-30)

### `substitution-dropping-the-row-is-its-repeal`
A whole substitution whose new text no longer holds the row is its repeal by the substituting law.
- **Example:** CLP Art 37A, replaced with Art 37 by SI 2026/484.
- **Serves:** `binds-on-date` · **Code:** `Label.Day` (`taken_away/3`) · **Test:** `label_fold_test` "a whole substitution whose new text no longer holds it" · **Origin:** `cv-s09-label-fold` (round 10)

### `own-repeal-beats-parent-substitution`
A row's own whole repeal outranks a substitution, on the same day, of a provision holding it.
- **Example:** SI 1999/3242 reg.22(2), by SI 2003/2457.
- **Serves:** `binds-on-date` · **Code:** `Label.Existence.own_repeal_first/2` · **Test:** `label_fold_test` "repealed, not remade" · **Origin:** `cv-06-switch-over` (round 1, 2026-10-31)

### `same-day-repeal-and-substitution`
When a whole repeal and a whole substitution fall on the same day and the revised text shows the substitution, the substitution governs. Both laws are credited.
- **Example:** CLP Art 45(4).
- **Serves:** `binds-on-date` · **Code:** `Label.Day.apply/4` · **Test:** `label_fold_test` "a same-day whole repeal and substitution" · **Origin:** `cv-s09-label-fold` (round 4)

### `revival-only-when-the-text-shows-it`
A repealed row comes back only with a later whole substitution or insertion of it or an ancestor, and only where the revised text, valid after that change, shows it. A body held only as made shows no later change.
- **Examples:**
  - SI 2022/1378 reg.9(9) comes back.
  - NISR 1993/37 reg.3(1)(d) stays repealed.
- **Serves:** `binds-on-date` · **Code:** `Label.Day` (`revised?/2`) · **Test:** `label_fold_test` "a body held only as made shows no later change" · **Origin:** `cv-s09-label-fold` (rounds 2, 3, 6)

### `sunset-is-a-removal`
A law's own sunset, and the orders continuing it, are removals. The latest order for a section and territory governs.
- **Example:** Coronavirus Act 2020 s.78 expires in Wales on 2022-03-25 and in NI on 2024-03-25.
- **Serves:** `law-text-wins` · **Code:** `Readers.Expiry` · **Test:** `expiry_test` · **Origin:** Jason 2026-10-22, `cv-04-merge-evaluator`

### `repeal-by-consolidation-as-drafted`
A repeal by a consolidating Act is labelled as the Act drafts it.
- **Example:** the Factories Act 1937 is repealed by the 1961 Act.
- **Serves:** `law-text-wins` · **Code:** no rule of its own. It needs the repeal read, and the 1937 case is a known limit (repeal tables not read) · **Test:** extended golden 1937/67 (failing, upstream) · **Origin:** Gemini golden review taken 2026-10-30, `cv-s09-label-fold`

### `amending-places-read-as-the-amended-law-numbers-them`
An amending instruction's place is read in the amended law's own numbering. A Schedule's paragraphs and a table's entries are never the law's own provisions.
- **The forms** (Environmental Protection: Amending-law reader, Decision 1 and Decision 2):
  - An Order's "article N" is reg.N, its rows' prefix (WSI 2013/755: "In article 11, for paragraphs (2) to (4) substitute" had made reg.2–reg.9).
  - A bare "paragraph N" (unbracketed), or the nearest lead-in naming a Schedule ("Amend Schedule 7 …", "Schedule 2 is amended in accordance with …"), places the instruction in a Schedule: no rule while Schedules are not read (2006 c.16 s.61(2) had made 1995 c.25 ss.2, 3).
  - "The entry relating to/for section N" names a table's entry, not section N. Its table's provision comes only from the instruction or its parents; otherwise there is no rule.
  - A repeals table's "In section 48—" over its list items is those items, never the whole section (2005 c.16 Sch.5).
  - A quote numbered only in its group's title ("45C Separate collection …", its Pnumber empty) is that number's provision (SSI 2012/148, asc 2026/4).
  - An "(i)" under a parent's letter is a sub-paragraph.
  - An id-less list of instructions under a provision ("(c) in the definition of “the IBC Code” for “1998” substitute “2007”;", numbered from the list's Start) is each item's own provision (SI 2011/2616 Sch.1 para.2; Amending-law reader: parked bugs). A list of places or words is its provision's words.
  - A range of brackets is every bracket between ("subsections (1) to (5) are repealed", "(1)(b)(i) to (iii)").
  - "In section 17— <items of words> shall cease to have effect" is those words, never the section (LGSA 1994 Sch.13).
  - A quote is the body of the provision named only for that number exactly, starting at (1) or (a) ("For Article 15a substitute— 1. 2." is never art.15's; "for regulation 45 … substitute— 80" never reg.45(80)).
  - An aside "as it has effect before … comes into force" names neither the law nor a place (asc 2023/3 Sch.13 para 72).
- **Serves:** `law-text-wins` · **Code:** `Reader.law_ref/4` (`:order`), `Reader.Scope` (`bare_paragraph?`, `schedule_lead_in?`), `Clauses.no_entry_names/1`, `Reader.rules/5`, `RepealTable.lead_in_items/1`, `AmendingLaw.Text` (`titled/3`), `AmendingLaw.Doc.ListItems`, `Targets` (`@bracket_range`, `body?/2`), `Clauses` (`words_listed?`, `no_effect_asides/1`), `LawNamed.placed_by/3` · **Test:** `amendment/reader/environmental_protection_forms_test.exs`, `amendment/reader/parked_forms_test.exs` · **Origin:** Environmental Protection: Amending-law reader (2026-11-10)

### `commencement-and-level-forms-of-an-amending-provision`
A commencement naming what an amendment inserts changes nothing. Words stay words however legislation.gov.uk marks them.
- **The forms** (Environmental Protection: Amending-law reader, Decision 1 and Decision 2):
  - Under a parent lead-in "the following regulations come into force …—", "regulation 6, insofar as new regulation 3(1)(a) … to be inserted" gives no rule. A definition's "the day when this section comes into force" and "the coming into force of this paragraph" are not commencements.
  - "in the appropriate place insert— <definition>" is words.
  - A quote marked as an inline amendment leaves an empty slot ("omit <quote>,", "after <quote> insert <quote>.") and is words, unless a provision named is what goes.
  - "the amount of £25 … substituted the amount of £50" is words.
  - "the definition of “X” shall be deleted and the following substituted / replaced with the following definition—" is one substitution (SI 1996/1592, SI 1997/2776).
- **Serves:** `law-text-wins` · **Code:** `Reader` (`no_change?/1`, `@commencing`), `Clauses.operation/1` (`words_inserted?`, `inline_words?`), `AmendingLaw.Operation` (`words?`) · **Test:** `environmental_protection_forms_test.exs` · **Origin:** Environmental Protection: Amending-law reader (2026-11-10)

### `repeal-table-rows-follow-their-enactment`
A repeals table that names an enactment in a row of its own gives the rows under it to that enactment, up to the next enactment named. When we don't hold that law, its rows go with it and are never given to another law. The rule holds whichever laws a read is for, all of them or only the law being built. "In full" is the whole section.
- **Example:** the Mines Regulations 2014 (SI 2014/3248) Sch. 3 lists "Mines and Quarries Act 1954", then "Section 19 | In full" and its other sections, then "Mines and Quarries (Tips) Act 1969". These had been read as whole-section repeals of HSWA 1974, the only law held, so 17 HSWA sections were repealed from 2015-04-06.
- **Serves:** `binds-on-date`, `law-text-wins` · **Code:** `Amendment.Reader.RepealTable.rows/2` (`named_rows/3`, `row_kind/1`), `Reader.ProvisionTable` (`@whole`) · **Test:** `repeal_table_test` "a row naming an enactment takes the rows under it …" · **Origin:** OH&S: Amending-law reader repair (2026-11-07), found by Maritime Safety: Switch-over's checked rows

---

## 10. Made, not yet in force

### `made-before-start-is-prospective`
A provision its own law commences exists from the law's making and is prospective until its start. This applies only where nothing else dates the provision. An amendment inserting words in it on the start day does not date it: only an insertion of the provision does.
- **Example:** SI 2017/469 art.1(1) and art.11. Words inserted on the start day: SI 1993/3138 reg.81 by SI 1994/541.
- **Serves:** `binds-on-date` · **Code:** `Label.Made.from/4`; `LabelRules` (`:no_made_period`) · **Test:** `label_made_test` (including "an insertion of words on the start day doesn't date the provision"); `label_rules_test` · **Origin:** LR-39; Jason 2026-10-31 ("add it"), `cv-06-switch-over`; the words case `maritime-safety-label-fold` (2026-11-06)
- **Own clause:** legislation.gov.uk's record of the law's own commencement (the law itself, no order) counts as its own clause and keeps the made period (WSI 2010/1821, SI 2025/1218: 232 rows; Jason 2026-11-11, Environmental Protection: Label fold, Decision 2; `Label.Made.own_clause?/2`).

### `law-commenced-by-order-begins-at-making`
A law with no start held but commenced by an order begins at its making, prospective, when a dated commencement follows. Otherwise its start stays unknown.
- **Examples:**
  - NISI 1997/1774 was made 1997-07-22 and commenced by SR 1998/235.
  - NISI 1998/2795's start stays unknown: its order is not held.
- **Serves:** `binds-on-date`, `unknown-over-guess` · **Code:** `Label.Made.by_order/2` · **Test:** `label_made_test` "from its making, prospective, when a dated commencement follows" · **Origin:** `cv-06-switch-over` (batch 2, 2026-11-01)

### `eu-law-has-no-made-period`
EU law gets no made period. Its start is unknown before its first dated change.
- **Example:** REACH and CLP.
- **Serves:** `unknown-over-guess` · **Code:** `Label.Made.by_order/2` (`UK_eu…`); `LabelRules` (`eu`) · **Test:** `label_made_test` (REACH stays undated) · **Origin:** `cv-06-switch-over` (2026-10-31)

---

## 11. Known limits and gaps

### `gap-is-not-wrong`
A value no source claims is a gap. It is published by cause, and never counted as wrong.
- **Example:** `commenced_by` for an EU amender.
- **Serves:** `unknown-over-guess` · **Code:** the check tools and quality statements (the `evidence-check` skill prompt) · **Test:** none in code · **Origin:** Jason 2026-10-29, `cv-s08-evidence`

### `known-limits-keep-the-old-label`
The named missing-repeal rows and the named date gaps keep the old register's label. Every other OH&S row, including the 47 known checked rows, takes the new one.
- **Example:** Factories Act 1961 s.8 keeps "repealed" (by the PDF-only SI 1977/746).
- **Serves:** `binds-on-date`, `fix-where-owned` · **Code:** `KnownLimits.sids/0`; `LabelSwitch.merge_kept/3` · **Test:** `label_switch_test` · **Origin:** Jason 2026-11-02, `cv-06-switch-over` (see open decision 5)

| Limit | Rows (OH&S) | What the label does | Listed in | Origin |
|---|---|---|---|---|
| Schedules are not parsed into LAT | 1,704 of 6,568 feed effects target a schedule we don't hold | No label on schedule provisions | `cv-00-meta` "Known limits" | Jason 2026-10-22 |
| Repeals no reader holds (PDF-only schedules, forms not read) | 39 | Old label kept | `backend/data/reports/change-vocabulary/cv-06a-known-limits.md` | Jason 2026-10-31 / 2026-11-02 |
| Date gaps: amending law's commencement not held | 7 | Old label kept | `backend/data/reports/change-vocabulary/cv-06-date-gaps.md` | Jason 2026-11-01 / 2026-11-02 |
| Checked rows judged wrong, fix owned by an earlier step | 47 | New label, flagged `known` | `backend/test/fixtures/change_vocabulary/switch_checked.json`; `cv-06b-routed-fixes` | Jason 2026-11-02 / 2026-11-03 |
| Insertions only legacy markup claims | 32 | Start not moved; listed apart | `mix lat.label_rules` (`legacy_unconfirmed`) | `cv-06-switch-over`, 2026-11-01 |
| EU directives after 2020-12-31 (Windsor) | 15 directives | No rule; Directive 90/269 Art 8b(1) held out of golden | `cv-s09-label-fold` bugs | Jason 2026-10-30 |
| EU law gets no change from its amending SIs' own text | 5 checked rows | Feed and markup only | `cv-06b-routed-fixes` bug 1 | 2026-11-02 |
| An amender revoked or withdrawn before it took effect is still credited | 2+ (NISR 1999/90 reg.2(1), 2003/34 reg.7(12)) | Credited | `cv-06b-routed-fixes` | 2026-11-02 |
| Commencement orders not held or PDF-only (HSWA orders Nos. 2–6; about 756 listed orders) | many | `in_force_from` empty or a later order's date | `cv-s04-commencement-reader` | Jason 2026-10-23 |
| Amending laws' schedules not held | CLP-wide; HSWA s.28(9) | Missed insertions | `cv-s09-label-fold` bugs | 2026-10-30 |
| Headings and signature blocks not folded | e.g. HSWA 1974 7 of 1,035 rows | Old periods only | `cv-05-consumers` | 2026-10-31 |
| Application to cases (scope) not read | 61 laws | Not territory; handed to fractalaw | `application-scope-handoff` | Jason 2026-10-27 |
| A laid-relative commencement ("on the 22nd day after the day on which these Regulations are laid": SI 2018/1221 reg.2) | Maritime Safety: 2 changes | Undated (`no_text_rules`) | `2026-11-05-maritime-safety-commencement-reader` Decision 1 (C) | Jason 2026-11-05 |
| A tax Act's year of effect ("has effect in relation to tax for the year 1992-93 …": TCGA 1992 s.289(1)) | Maritime Safety: 17 changes | Dated by Royal Assent (1992-03-06) | same, Decision 1 (D) | Jason 2026-11-05 |
| A legislation.gov.uk note pointer with note words in it ("s.26(5)(6)(subst.1982 c 36 s 39(2)") | Maritime Safety: 1 change | Falls to the law's by-order rule | same, Decision 1 (F) | Jason 2026-11-05 |
| One-law commencement wordings: a form found in one law (or its NI twin) below the triage size, named in the leftovers check rather than chased — a sector-only deferral (SI 2005/1643, NISR 2006/1 reg.15(3)), a treaty day notified in the Gazettes (SI 1998/1258), a list with no dash (SI 2002/3153), a bracketed "apart from" (1998 c.8 s.17(1)), and the others listed. Environmental Protection adds five: a day another instrument's start sets (WSI 2006/2797 art.3), an item's bracketed exception (2007 c.28 s.245(2)), an item qualified by its entries (2007 c.28 s.245(4)), an inverted "There shall come into force … sections …" (asp 2001/8 s.81(2)), "The provisions to which this subsection applies …" by order in England and in Wales (2008 c.17 s.325(4)) | Maritime Safety and OH&S: 12 statements; Environmental Protection: 5, under 10 rows | As read (often undated) | `leftovers.json` `known:` statuses ("RULES.md: one-law commencement wordings"); `2026-11-05-commencement-leftovers-reader-misses`; `2026-11-09-environmental-protection-commencement-reader` Decision 1 | plan triage rule, 2026-11-05; Jason 2026-11-09 (Decision 1) |
| One-law extent wordings: a form found in one law below the triage size, named in the extent gate (`withheld.json`) rather than chased. Examples: a qualified list item ("so far as relating to paragraphs 9 and 68 …", 2015 c.20 s.114), "(including paragraph 1, but not the rest, of Schedule 14)" (1999 c.22 s.109), lettered per-subsection extents ("In this section— (a) subsection (1) shall extend …", 2003 c.39 ss.100–101), a subject-matter extent ("To the extent that these Regulations concern the importation of …", SI 2005/1082) | Maritime Safety: 9 laws, 15 changes | No bound (unread withholds) | `withheld.json` `known:` statuses; `2026-11-05-maritime-safety-extent-reader` | plan triage rule, 2026-11-05 |
| Extent statements withheld by design, and one-law extent wordings (Environmental Protection): a qualified Schedule ("Schedule 24 … so far as relating to that Part", EA 1995 s.125(8)); a conditional whole-Act clause placing an enabling section nowhere (Finance Act 1973 s.59(5), 3 SIs); an unnumbered Schedule (SI 2012/2654); extent and application in one statement ("extends to England and Wales and applies to England only", SIs 2019/458, 2019/1517, 2020/1444); a provision with part of it excepted in a list that sets or narrows the extent (`partly-excepted-provision-in-a-widening-list`); three catalogue misreads held `pending:` (TULRCA 1992 s.301 "(apart from section 212A(6)) to Scotland", 1981 c.22 s.97, 1996 c.44 s.14), each at most one change; and 26 more one-law wordings under 10 changes | Environmental Protection: 36 causes, 267 changes | No bound (withheld); the 3 misreads as read | `withheld.json` `known:` statuses; `extent_patterns/expected.json` `pending:`; `2026-11-09-environmental-protection-extent-reader` | Jason 2026-11-09, Decisions 1 and 5 |
| One-law amendment wordings: a form found in one law below the triage size (under 3 changes), named in the amending-law gate (`disagreements.json`) rather than chased. Examples: "At the end of the Regulations insert— SCHEDULE …" read as words on the last regulation (SI 2014/1616); a table's numbers "for the first number in each row substitute" read whole (SI 2022/1269); quoted words "(1B)" read as a place (SI 2018/667); "omit paragraph (a) (<heading>), and the “or” following it" read as words (2015 c.20 s.55(a)); "omit … and substitute" kept as two records (SI 2018/1109); "delete “of” and insert" against the feed's one substitution (SI 2013/1473) | Maritime Safety: 8 wordings, 13 changes | The law's reading kept | `backend/data/reports/amending-reader/maritime-gate-review-1.md` (K1–K8) | 2026-11-06 |
| One-law amendment wordings (Environmental Protection), named in `disagreements.json` rather than chased: an abbreviated law name, "FA 2001", read as SI 2001/4027 (2023 c.30); an aside's places read as targets (SI 2008/1482 reg.8); a quote "6A" after "section 6(6)" read as sections (asc 2026/4 s.37); a quote of a regulation's body (NISR 2015/231); two laws in one sentence (1991 c.26 s.2(6)); "Omit Schedules 2A and 2B" read as s.75 (SI 2011/988); a list of places read in part (WSI 2013/755 Sch.5 para 40); Schedule captions naming regulations (SSI 2009/221 reg.2(16)); "any surviving reference to £25 is hereby repealed" (WSI 2004/909); an inline quote after "paragraph (3)(a)" (NIA 2016/13); the adjective "inserted" read as the operation (SI 2025/82) | Environmental Protection: 11 wordings, about 25 changes | The law's reading kept | `backend/data/reports/amending-reader/environmental-protection-gate-review-1.md` (EP-K2–K14) | 2026-11-10 |
| One-law merge forms below triage, named in the merge gate (`merges.json`): an EU consolidation marker with no cited law joined into a UK SI's change on the same Article (SI 2019/270, EU 2009/391 Art 6(1)); legislation.gov.uk's markup carrying effect ids its feed doesn't hold, so with the law's start misread each pair stays apart (SI 2018/1221 reg.3(2)(e), (j)); legislation.gov.uk's markup reaching a row its feed doesn't name (SI 2004/2883 reg.2(6) on reg.7C) | Maritime Safety: 3 forms, 6 changes | Merged as read | `backend/data/reports/merge/maritime-gate-review-1.md` | 2026-11-06 |
| Merge forms below triage (Environmental Protection and OH&S), named in the merge gate (`merges.json`), each record kept visible: one event in two id-less records, the law's text and legacy markup, with no feed effect (the merge joins an id-less record only to one with an id: 1999 c.29 s.367(3), (5)); the feed naming the operative provision ("the Schedule has effect") while the law's text or markup names the Schedule — unrelated provisions, so left apart (SI 2023/149 reg.2(1) on EPA s.33(8)(a); SI 1996/3022 reg.2 on the Factories Act s.68); two law-text records for one feed effect, the second left apart (NISR 2017/86 reg.20(a)(ii)); legislation.gov.uk's own ids: markup effect ids its feed doesn't place (SI 1999/3206 reg.4(e), wsi 2013/755 Sch.4 para.94(2), SI 1995/2036 Sch.3), an affecting provision named "s.73" for reg.73 (SI 2005/894), an alias joining a later law's "amendment to earlier affecting provision" with a commencement id (SI 1995/2038 reg.6(8)); an "in each place" words change kept on the parent (NISR 2010/160 reg.28 by NISR 2019/6) | 3 + 2 + 1 changes (Decision 1); legislation.gov.uk's ids 5; in each place 1 | Both records kept apart, as read | `backend/data/reports/merge/environmental-protection-gate-review-1.md`, `ohs-gate-review-2026-11-10.md` | Jason 2026-11-10, Environmental Protection: Merge (Decision 1) |
| One-change evidence forms below triage, named in the evidence gate (`evidence.json`): one change repealed by two provisions of one law commenced on different days, the table taking the first commencement claim not the earlier (2003 c.20 s.112(8) and Sch.8 on MSA 1995 s.311); a cross-heading's insertion read as words from the markup where the feed's provision is right (SI 2006/1244 on MSA 1995 h.162); legislation.gov.uk's markup wrapping a paragraph's number on a sentence's substitution, so the whole paragraph is chosen (SI 2019/270 reg.3(8)(b) on EU 2009/391 Art 8(1)) | Maritime Safety: 3 changes | Chosen as the table orders | `backend/data/reports/evidence/maritime-gate-review-1.md` | 2026-11-06 |
| Evidence forms from legislation.gov.uk's own records (Environmental Protection, OH&S, Maritime Safety), named in the evidence gate (`evidence.json`): a note citing a Welsh SI by its UK S.I. number (Citation URI `uksi/2011/971`, "S.I. 2011/971") where the feed has `wsi/2011/971`, one law under two names, so a `by` disagreement is reported though the feed's name is chosen and right (Decision 2: laws are never matched by year and number alone); the feed dating an amendment at the amended law's own later start (SSI 2025/28 on SSI 2024/269; SI 2025/369 on SI 2025/278), the law's date chosen; a feed year slip (SI 1996/1592: 2006 for 1996) and other later feed dates (SI 1996/2092 reg.21(8); SI 2025/514's day count); a substitution worded "for X insert Y" (SI 2015/1637 Sch. para 3(a)) and the feed's Type error where the law's text holds no claim (SI 2019/758 Sch.1 para 95(3)(d) on REACH Art 138(1)), the feed's inserted chosen; two orders commencing one provision on one day for two territories, commenced_by holding one (2003 c.38: SI 2004/690 and WSI 2004/999) | Welsh SI citations 29 changes in 5 laws; later amended-law starts 11; feed dates 4; operation 2; two orders 2 | Chosen as the table orders; the conflict kept visible | `backend/data/reports/evidence/environmental-protection-gate-review-1.md` | Jason 2026-11-11, Environmental Protection: Evidence (Decisions 1–3) |
| Label forms below triage (Environmental Protection), named in `labels.json`: SI 2025/1218's clause "18 months after the day on which they are made" gives 2027-05-18 while legislation.gov.uk's own record gives 2027-05-19, so the row reads prospective for the day; SSI 2025/165 reg.9's clause stage "subject to paragraph (5)" left on the general start; HSWA s.78's stored row extent E+W+S+NI where C11 gives E+W+S, so NI reads in force after the 2006 repeals (golden passes on its own extent) | 14 + 1 + 3 rows | As the fold reads them | `test/fixtures/label/labels.json`; the session | Jason 2026-11-11, Environmental Protection: Label fold |
| One-row label forms below triage, named in the label gate (`labels.json`): an undated whole repeal beside a dated one reads repealed from the start (MSA 1970 s.42(1): 1992 c.52 dated, NISI 1995/1980 undated); an amending law's change the law's text alone states left undated while its other changes are dated (SI 1975/2220 reg.2 by SI 1998/929); one subsection's deemed day taken as an amending Act's start (1997 c.28 s.28(5): MSA 1995 s.284(4), s.85(3) dated 1996-09-15) | Maritime Safety: 4 rows | Credited from the start, or dated too early | `test/fixtures/label/labels.json` | 2026-11-06 |
| An SI's introduction with no powers clause on legislation.gov.uk (the designation or draft-approval recital only, or no preamble: SI 2011/1043, 1999/1820, 1977/445) | Maritime Safety: 3 changes | No bound from powers | `withheld.json` | 2026-11-05 |
| An enabling Act not on legislation.gov.uk (stored as a 404: the Merchant Shipping (Registration, etc.) Act 1993, repealed 1996) | Maritime Safety: SI 1994/541, 24 changes | No bound from powers | `withheld.json` | 2026-11-05 |
| Provisions named by power or as Schedule entries, not by number ("so much of any provision of this Act as authorises the making of any order": ICTA 1988 s.843(3), SSCBA 1992 s.289(2); Schedule entries, SI 2003/835) | 3 statements | Undated by the clause | same | 2026-11-05 |

---

## 12. Store and build

### `earlier-families-rebuild-once-per-round`
During a step, gates and checks run on the family's own laws (`--family`, `--laws`). The families switched before it are brought up to date once per fix round, with `mix lat.vocabulary --build --stale`, before that round's regression gates. They are never rebuilt after each edit. The walk rebuilds only the stage an edit can change. A fold-only edit re-folds labels and rebuilds no change. A reader edit rebuilds every built law's changes, but folds labels again only where the output digest moved.
- **Example:** after the split (#194), one walk rebuilt 285 laws in 198 s and re-folded 266 switched laws in 95 s. Every change digest and timeline was byte-equal, and `lat.stale --strict --switched` gave 0. The Maritime switch-over had paid four full rebuilds in one step.
- **Serves:** `binds-on-date` · **Code:** `StaleStages`, `lat.vocabulary --build --stale`, `ChangeVocabulary.Version`, `FoldVersion` · **Test:** `architecture/stage_split_test.exs`, `stale_stages_test.exs` · **Origin:** stage versions #194 (scaling review item 1, Jason 2026-11-07)

## Convention letters in code comments

Code comments and the golden file still cite the 2026-10 convention letters. Here they are by rule name:

| Letter | Rule |
|---|---|
| C1, C12 | `one-territory-repeal-narrows` |
| C2 | `repeal-everywhere-is-repealed-nowhere` |
| C3 | `versions-share-history`, `versions-split-when-texts-part` |
| C4 | `renumbering-opens-a-period` |
| C5 | `changed-by-all-lists-the-makers`, `earlier-amendment-credited` |
| C6, C11 | `law-text-sets-territory` |
| C7 | `removal-in-part-is-partial-only-if-kept` |
| C8 | `windsor-changes-reach-gb-only` |
| C9 | `child-change-never-reaches-parent` |
| C10 | `no-royal-assent-for-acts-by-order` |
| C13 | `commencement-for-one-territory` |
| C14 | `insertion-takes-inserting-territory` |
| D1 | `in-force-from-current-text`, `commencement-opens-a-version` |
| D3 | `saving-makes-repealed-saved` |
| rule 9 | `modification-is-not-a-change` |

---

## Open decisions

Each item gives the rulings with their dates, what the code does now, the aim at stake, and a recommendation. Answer by number (keep, change or a different option).

### 1. What `changed_by` means — DECIDED 2026-11-06
- **Decided:** Jason 2026-11-06 (Maritime Safety: Labels side by side, Decision 1, A): the principal maker, then the latest made; see `changed-by-one-law-for-compliance`. The note below is kept as the record.
- **Rulings:**
  - 2026-10-13 (D1): the laws that made the current text. A commencement is a version, and its law is credited.
  - 2026-10-21: golden normalised to D1, so the commencing order is in `changed_by` (HSWA s.78 had [], 2021 c.30 s.8 had SI 2022/48: applied unevenly).
  - 2026-10-30: `commenced_by` split off, so `changed_by` holds the text's makers only.
  - 2026-10-31 (`cv-05`): one law kept for compliance, "the last listed".
  - 2026-10-31 (`cv-06`): "the law that made the text, else the law that commenced it — the old labels' meaning".
- **Code:**
  - `LabelPeriods` writes `List.last(changed_by_all) || List.last(commenced_by)`.
  - The list is sorted by name, so with several makers the choice is alphabetical. SI 2000/1043 reg.11(3) gets WSI 2005/1806, and REACH Art 127E gets SI 2019/858, the amender of the amender.
  - On repeal periods it is the repealer.
- **Aim:** `binds-on-date`.
- **Recommendation:**
  - Keep the 2026-10-31 meaning: the text's maker, else the commencer.
  - Choose among several makers deliberately: the maker of the latest dated change, and never an earlier-amendment credit.
  - State that a repealed period names the repealer.
  - Compliance should read `changed_by_all` for the full answer.

### 2. A repealed row's territory: "nowhere" or empty
- **Rulings:**
  - 2026-10-21 (convention C2): territory has an explicit "nowhere", distinct from empty = unknown.
  - 2026-10-31: "keep the table's rule": a repealed period's territory is empty, and `in_force_from` is the repeal's day.
- **Code:** the fold makes "nowhere"; `LabelPeriods` writes empty (and keeps "nowhere" with any other status).
- **Serves:** `unknown-over-guess` (empty already means unknown) vs `binds-on-date`.
- **Recommendation:** write "nowhere" for repealed periods once compliance can read it. Until then the status already says "repealed", so keep the table's rule for v0.1 and record it as a known difference.

### 3. Notes: pointers, or a source of facts?
- **Rulings:**
  - 2026-10-09, 2026-10-12, 2026-10-15: never a fact from a note, "for any field, ever".
  - 2026-10-21: notes are never claims.
  - 2026-10-22: the note as a pointer for identity ("decision - yes").
  - 2026-10-22: notes point to where to read a date ("Use Notes as pointers when we have a gap").
  - 2026-10-28: the note's structured citation as the last fallback for `by`, "the one named exception".
- **Code:**
  - Identity and date pointers are in use (`Merge.Partner`, `Readers.NoteDate`); dates found this way are tiered derived.
  - `Evidence` takes `by` from `{:markup, :cited}` for 1,295 changes.
- **Serves:** `law-text-wins`, `unknown-over-guess` vs `coverage-from-lgu`.
- **Recommendation:**
  - Restate the rule as "notes point; they never decide": pointers to identity and to where to read are kept.
  - Keep the `by` exception only as a pointer to the law to read. Once that law's text or the feed confirms the law, it is no longer an exception.
  - Until then, show it as derived and count it in the quality statement.

### 4. Undated changes on a dated start
- **Rulings:**
  - 2026-10-30, J5: "We do need a date, cannot have 1995 text as never in force": credit it, and find the date.
  - 2026-10-30, batch 7: an undated substitution whose order is not held keeps `in_force_from` empty until the order is held.
  - 2026-10-30, round 10: an undated change after a dated start is upstream; the reader must attach the amending law's date.
  - 2026-10-30, H7: on a dated start, an undated words change "stays a gap".
  - 2026-11-01: date it at the "amending law's first start".
  - 2026-11-01: "Named gap".
- **Code:**
  - Undated whole substitutions empty `in_force_from`.
  - Undated words changes on a dated start are dropped silently (`fold-uses-dated-changes`; 2,048 rows were reached by one at 2026-10-29).
  - `AmenderStart` dates some changes at a lower bound.
  - 7 rows are named gaps on their old label.
- **Serves:** `unknown-over-guess`, `binds-on-date`.
- **Recommendation:**
  - One rule: find the date from the law (`NoteDate`, then the amending law's commencement).
  - If none is found, the period shows "date unknown" and the row is listed as a gap by cause.
  - Treat `AmenderStart` as a lower bound shown as such ("not before"), not as the date.

### 5. Known-limit rows keep the old label
- **Ruling:** 2026-11-02: the 39 missing-repeal rows and the named date gaps keep the old label.
- **Code:** `LabelSwitch.merge_kept/3`.
- **Problem:** the old label can be the very guess the new rules forbid. HSWA 1974 s.79's old repeal is dated at Royal Assent by default.
- **Aim:** `unknown-over-guess` vs `binds-on-date`.
- **Recommendation:**
  - Keep the old label for the 39 missing repeals: the old "repealed" is right, and the revised text says so.
  - For date gaps, write the new label with `in_force_from` empty, not the old guessed date.

### 6. Old-style markup Additions
- **Rulings:**
  - 2026-10-29: a legacy Addition "claims no operation".
  - The same day, after golden failed: "round the number = inserted".
  - 2026-10-30 (round 4): a markup-only insertion credits its law but doesn't drop the row's own commencements.
  - 2026-11-01: a legacy-only insertion never moves the start, and is listed apart.
- **Code:**
  - `Start.legacy_only?/1` ignores such insertions for the start.
  - `Undated.makers/2` still counts them as the text's maker. This blanked 50 Factories Act 1961 periods after its start moved to 1962 (`cv-06b`).
- **Serves:** `law-text-wins`, `unknown-over-guess`.
- **Recommendation:**
  - One rule everywhere: a legacy-only Addition places a change and may credit its law, but never moves a start or blanks a date.
  - Fix `Undated.makers` in the fold step (it is routed to `cv-06b`).

### 7. Modifications vs amendments
- **"as if" part ruled 2026-11-06** (Jason, option A): see `modification-is-not-a-change`, Forms. Still open: "modified as follows" followed by plain text amendments.
- **Rulings:**
  - 2026-10-22: a modification changes no label.
  - 2026-10-30 ("rule 9"): "modified as follows … for regulation 8 substitute" is not a version (SI 1981/917 reg.8(2)).
  - 2026-11-01 (`cv-06` batch 2, no explicit ruling): "Section 125 … shall be modified as follows—" has its items read as insertions (Factories Act 1961 s.125(7)–(9)).
- **Code:** both cases are applied, by different paths.
- **Aim:** `law-text-wins`.
- **Recommendation:** decide by the drafting, not the case.
  - "as if …" and "modified … in its application to …" are modifications.
  - "modified as follows" with plain text amendments is an amendment.
  - Check SI 1981/917 reg.8(2) and SI 1988/1655 reg.23 against that test, and record the result in one rule.

### 8. "The quote alone is evidence" vs "evidence it existed"
- **Rulings:**
  - 2026-10-30: a substitution's quote alone is evidence that a child is new.
  - 2026-10-31: "Evidence it existed": a child predates the substitution where a source shows it, otherwise it begins at the substitution.
- **Code:** `Label.Existence` applies the reconciled rule.
- **Aim:** `law-text-wins`.
- **Recommendation:** confirm the reconciled rule (`evidence-it-existed`) as the only one, and retire the 2026-10-30 wording.

### 9. Royal Assent as a start
- **Rulings:**
  - 2026-10-21 (C10): never Royal Assent for an Act commenced by orders.
  - 2026-10-29: Royal Assent only where no other rule reaches.
  - 2026-11-02: an amending Act's first start is its orders', not Royal Assent.
  - 2026-11-02: HSWA s.79 is a "named gap" because the repealing Act's commencement section is itself repealed.
- **Code:**
  - The narrowed rules apply in the readers.
  - An Act whose commencement section is repealed still falls back to Royal Assent (HSWA s.79 via 1985 c.9; 1920 c.65, open since 2026-10-30).
  - (Done 2026-11-07: the law's own start is stored with the build, `law-start-stored-with-the-build`.)
- **Aim:** `unknown-over-guess`.
- **Recommendation:**
  - Royal Assent is a start only for an Act that says nothing else, as enacted.
  - If the commencement section is repealed in the revised text, read the as-enacted section. If it is not held, the start is unknown.
  - (Done 2026-11-07: the start is off `lat_change_log`.)

### 10. Golden: frozen or grown
- **Rulings:**
  - 2026-10-29: "golden grows to about 50 before round 1".
  - 2026-10-30: "growing golden mid-workflow was a mistake": back to 27, and the 23 new cases held for the next pass.
  - 2026-10-31: "stick with the passing 27 golden".
- **Code:** `golden.exs` (27), `golden_extended.exs` (23).
- **Problem:** the 27 were also edited by rulings during the pass (D1 2026-10-21, HSWA s.78 2026-10-24, `commenced_by` 2026-10-30, TCPA/EUWA 2026-10-30).
- **Aim:** `prove-one-family`.
- **Recommendation:**
  - Golden is frozen for a pass.
  - A ruling that changes an expected value is dated in the golden file, and re-runs the steps it affects.
  - The extended 23 join at the next family's pass, from the first step.

### 11. The Windsor list is relied on unchecked
- **Closed 2026-11-11** (Environmental Protection: Label fold, Decision 6): Jason checked both entries; `Windsor.listed?/1` requires `checked: true`. EP's retained EU instruments are not listed (parked with the EU directives).
- **Ruling:** 2026-10-30: "hold a small Windsor Framework Annex 2 list, checked by Jason".
- **Code:**
  - Both entries are `checked: false`.
  - `Windsor.listed?/1` ignores the flag, and the rules check and 160 OH&S rows (territory E+W+S+NI → E+W+S) rely on it.
  - EU directives are held out with no rule.
- **Serves:** `law-text-wins`, `binds-on-date`.
- **Recommendation:**
  - Jason checks the two citations.
  - Until then, the code should require `checked: true` before it confines a change, or the 160 rows should be listed as resting on an unchecked source.
  - Directives: hold the Annex 2 list for the family's 15 directives before writing a rule.

### 12. Tiers are carried but not delivered
- **Rulings:**
  - 2026-10-21: "every label value carries its tier".
  - 2026-10-22: tiers per field, derived when read.
  - 2026-10-30: tiers count in the check.
  - Two tier questions are still unruled: repealed_saved when the saving comes from the feed, and `commenced_by` when its law comes from the feed.
- **Code:**
  - The fold computes tiers. `lat_label_timeline` has no tier column, so compliance never sees them.
  - Golden has no expected tiers.
  - `AmenderStart` dates are tiered primary despite being documented as derived.
- **Serves:** `law-text-wins`, `binds-on-date`.
- **Recommendation:**
  - Decide whether compliance needs tiers in v0.1. If yes, add a column (one JSON map) with the switch of the next family. If no, drop "carries its tier" from the aims of v0.1 and keep tiers for the conflict report only.
  - Either way, fix the `AmenderStart` tier and rule the two open questions as derived.

### 13. The evidence order was reversed twice
- **Rulings:**
  - 2026-10-18: "effects first".
  - 2026-10-21 (CV-01 draft): markup, then feed, then the amending law.
  - 2026-10-21 (authority): the law's text first.
  - 2026-10-29: the feed above the markup for operation.
- **Code:** law text, then commencement, then feed, then markup (`Evidence`).
- **Serves:** `law-text-wins`, `coverage-from-lgu`.
- **Recommendation:** confirm the current table as written in this file. Any change to it goes through this file first.

### 14. The pass rule changed four times
- **Rulings:**
  - 2026-10-22/23: no wrong outside known patterns.
  - 2026-10-24: no new defect in the sample.
  - 2026-10-28: pooled 95% upper bound under 2% (rows) and 5% (laws).
  - 2026-10-31: 15 rows per cause plus a pooled bound.
  - 2026-11-01: decided by code (rules plus checked rows plus golden), "a pass that doesn't rely on agents".
- **Code:** `mix lat.verdicts` (bounds), and `mix lat.label_rules` with `mix lat.label_checked` (switch-over).
- **Aim:** `prove-one-family`.
- **Recommendation:**
  - The code-decided pass is the default for every step.
  - An agent sample is used only to find new classes, costed.
  - The pass rule is fixed in the step's plan and never changed mid-step.

### 15. Fixing other steps' code inside a step
- **Rulings:**
  - 2026-10-26: route work to its owning session.
  - 2026-10-28: "misreads only".
  - 2026-10-29: "fix every class in CV-S08".
  - 2026-10-30: fold batches included reader fixes.
  - 2026-10-31: "U12 first"; "all of it".
  - 2026-11-02: "boiling the ocean": name and route, never fix by default.
- **Code:** fixes made before 2026-11-02 stay. `cv-06b` holds the routed ones.
- **Aim:** `fix-where-owned`.
- **Recommendation:**
  - Route by default.
  - Fix in-step only a class over the step's threshold that blocks its pass, with Jason's go for that class.
  - Name everything else as a known limit.

### 16. "One re-parse and one relabel for v0.1"
- **Ruling:** 2026-10-21.
- **What happened:**
  - One LAT re-parse of 128 laws (2026-10-23).
  - About ten amending-law read passes and many rebuilds (2026-10-25 to 2026-11-02).
  - One relabel (2026-11-02).
- **Aim:** `prove-one-family`.
- **Recommendation:** restate it as "one relabel per family, written once after its pass". Re-reads and rebuilds are allowed after a pre-flight shows which laws change, with a restore point and Jason's go.

### 17. Savings that may not reach the row
- **Ruling:** 2026-10-30 ("D3 stands"): repealed_saved whenever a saving is named, without judging whether it reaches the row (Gemini's amendment to SI 2008/2337 reg.5 not taken).
- **Code:** as ruled. Savings read from the law's text (2026-10-31) doubled repealed_saved rows on OH&S (494 → 925).
- **Aim:** `binds-on-date`.
- **Recommendation:**
  - Keep it for v0.1, because judging reach needs a new reader.
  - Publish the share of repealed_saved rows whose saving names other provisions, so a user knows "saved" may not apply to them.
