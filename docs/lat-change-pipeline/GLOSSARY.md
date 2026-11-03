# LAT Change Pipeline: Glossary

Plain definitions of the words used in the [README](README.md), the [Workflow](WORKFLOW.md), the check skills and the sessions. The second half maps the codes used in the archived sessions (CV-…, U12, K1 …) to names, so those sessions can be read.

## Terms

### Sources and documents

- **LAT (Legal Article Text).** Our parse of a law's text into one row per provision (`legal_articles`). A row's id is its `section_id`, e.g. `UK_ukpga_1974_37:s.52(1)(b)`. Rows use our ref grammar: `s.N(x)` for Acts, `reg.N(x)` for regulations, `art.Article N` for EU law, `sch.N.para.M` for schedules.
- **CLML.** legislation.gov.uk's XML for a law. We hold it locally in the **CLML store** (`backend/data/cache/clml/`): body, schedules, introduction, and some "as enacted" copies.
- **Changes feed.** legislation.gov.uk's list of changes to a law, one **effect** per change: its type ("words substituted"), the provisions affected, the amending law and provision, in-force dates, extent, savings. Stored as feed pages in the CLML store. Semi-structured; derived.
- **Effect id.** The feed's id for one effect, `key-` plus 32 hex characters. legislation.gov.uk sometimes re-keys a corrected effect, so one effect may carry two ids (`EffectId` and the id in its `URI`); both count.
- **Change markup.** The `Addition`, `Substitution` and `Repeal` elements in a law's revised CLML text, each with a `ChangeId` and a note. Structured; derived.
- **Legacy ChangeId.** A markup id with no effect id inside it (`d29p5797`, `M_F_…`), from before the feed. Its change can only be matched through its note's pointers.
- **Note (commentary).** The F, C, I, E … notes legislation.gov.uk attaches to text. A note is a **pointer**: it says where to look (which law, which amending provision). It is never a fact. See [LEGISLATION-GOV-UK-NOTE-TYPOLOGY.md](LEGISLATION-GOV-UK-NOTE-TYPOLOGY.md).
- **Primary / derived.** The two **tiers** of source. Primary: the legal text (the amending law's instruction, its commencement clause and orders, its extent and application clauses, the amended law's own clauses). Derived: legislation.gov.uk's markup and feed. The primary text wins where it speaks.
- **Extent and application.** Extent is where a provision is law (E, W, S, NI). Application is where it has effect, which can be narrower (a UK-extent law that applies in NI only). Both feed the territory label.
- **Territorial version.** A provision legislation.gov.uk holds as two or more texts, one per territory (`s.23[E+W]`, `s.23[S]`). Each version is its own row and shares the history before the split.
- **Backlog.** Changes the amending law's text states that legislation.gov.uk hasn't recorded or applied yet.

### The pipeline's units

- **Reader.** Code that reads one source and emits claims. One job: carry what the source says, never decide between sources.
- **Rule (stored reading).** What a primary reader read, kept so the build need not re-read the text: `amendment_rules`, `commencement_rules`, `extent_rules`.
- **Claim.** One source's statement about one attribute of one change: source (`feed`, `markup`, `law_text`, `commencement`, `law`, …), attribute (`operation`, `level`, `date`, `territory`, `by`, …), value, and the ref it came from. Stored in `provision_change_claims`.
- **Pointer claim.** A claim used only to decide identity (a note's cited law, the affecting provision), never as a label value.
- **Change record (merged change).** One real change event on one provision, with every source's claims about it. A row of `provision_changes`.
- **Key and aliases.** A change record's id: the effect id when any source carries one, else a source's own id (`law:element id` for the amending law's text, `LAW:commencement:<row>@<date>` for a commencement, a legacy ChangeId). Aliases list every other id merged in.
- **Target.** The provision a change acts on, in our ref grammar. `*` is the whole law.
- **Operation.** What the change does: `inserted`, `substituted`, `repealed`, `repealed_in_part`, `renumbered`, `commenced`, `applied`. Modifications ("applied with modifications") have none: they are not text changes.
- **Level.** `words` (some of the provision's words changed) or `provision` (the whole provision). Only a whole-provision change reaches the provisions under it.
- **Staged change.** A commencement in steps: partly first ("for specified purposes"), fully later. Each stage is its own change, keyed `id@date`.
- **Merge identity.** How the merge decides two records are one event: the same effect id; else the same amending law and amending provision (related, not contradicting), the same operation family, on the same provision or one above or below it. One partner or none: with several it stays apart. See [CHANGE-IDENTITY-DESIGN.md](CHANGE-IDENTITY-DESIGN.md).
- **Join, split, over-join, misplaced.** A join puts two sources' records of one event together. A split leaves one event as two changes. An over-join puts two events in one change. Misplaced: the sources put one event on different provisions.
- **Join rate.** The share of law-text and markup changes that found their feed effect.
- **Evidence table.** One table (`ChangeVocabulary.Evidence`) saying, per attribute, which source's claim wins, in order, with a few named conditions. Primary sources first.
- **Evidence tier.** The tier (primary or derived) of the source that won an attribute. Each label field carries one. Worked out on read, not stored.
- **Conflict.** A disagreement the pipeline reports, never reconciles: a **value** conflict (the law and legislation.gov.uk differ on one change), **unjoined** (the law's text alone beside a likely same event from legislation.gov.uk), **uncovered** (one side states a change the other doesn't), **unread** (legislation.gov.uk states a change whose amending provision we haven't read).
- **Like for like.** Comparing only things that mean the same: the markup shows a substitution as an `Addition`, so that is no conflict with the feed's "substituted".

### Labels

- **Label.** The four facts compliance reads for a provision: status, in force from, territory, changed by (with `commenced_by` and `changed_by_all` beside them).
- **Status.** `in_force`, `in_force_partial` (partly in force, or revoked for one purpose with the text kept), `prospective` (made, not yet in force), `repealed`, `repealed_saved` (repealed everywhere but kept alive by a saving).
- **In force from.** When the current text took effect. Empty while prospective or partly in force. On a repeal, the repeal's day.
- **Changed by / changed_by_all / commenced_by.** `changed_by_all`: every law that made the current text. `changed_by`: one law, the maker of the current text, else the law that commenced it (what compliance read before). `commenced_by`: the law that brought the text into force apart from its makers, typically a commencement order; empty when a law commenced itself.
- **Territory.** Where the provision applies in a period. "Nowhere" (empty, with a repeal) is distinct from unknown (no period).
- **Label fold.** The pure code (`ChangeVocabulary.Label`) that reads a provision's changes in date order and opens a new period each day a label field changes.
- **Period.** One state of a provision, `valid_from` to `valid_to` (exclusive; open when empty). A row of `lat_label_timeline`.
- **Version (of a label).** A period opened by a text change or a commencement: `in_force_from` moves to that day.
- **Made period.** A law made but not yet in force: the provision is prospective from the making to its start, where its own law commences it.
- **Conventions.** The agreed rules the fold follows, numbered C1–C14, D1 and D3 (listed under Former codes).
- **Old path.** How labels were built before: `ChangeCollector` → `lat_change_log` → `LabelProjection`. Still used for every family not yet switched.

### Checks and quality

- **Family.** A group of laws in the register (about 50 in all), e.g. "OH&S: Occupational / Personal Safety" (149 laws with LAT). The pipeline runs family by family.
- **Switched family.** A family whose `lat_label_timeline` is written from the merged changes. Listed in `config :sertantai_legal, :label_families`.
- **Golden set (golden).** A fixed set of hand-verified provisions (27 for the OH&S pass) with their correct label periods, the acceptance test every step runs (`test/fixtures/change_vocabulary/golden.exs`). **Golden from inputs**: rebuilt from the sources (`mix lat.vocabulary --golden`), not scored from stored changes. Golden is frozen for a pass; new cases go to the **extended golden** (`golden_extended.exs`) for the next pass.
- **Pattern catalogue.** Every form of one kind in the whole store (feed types, markup shapes, commencement sentences, orders, extent sentences, amending instructions), classed, each with real examples and expected readings as test fixtures. A new form fails the catalogue test until it is accepted, fixed or marked pending.
- **Census.** A full count and classing of one population (for example every disagreement), rather than a sample.
- **Strata.** The groups a check sorts its population into, each checked in its own way (in full, by pattern, or by sample). Each step has its own letters; see Former codes.
- **Our faults / own fault.** A fault in the current step's own code. The pass counts these.
- **Upstream fault.** A fault caused by an earlier step (a reader, the merge, the evidence table), or by legislation.gov.uk's own data. Logged with its owning step, not counted against the current step.
- **Fold fault.** The label fold's own fault: a period wrong given the changes it was handed.
- **Gap.** A value no source gives (an order we don't hold, no date anywhere). Counted with its cause, never called wrong, never filled by a guess.
- **Known limit.** A named, counted class of rows the pipeline knowingly gets wrong or leaves open (for example, repeals in schedules legislation.gov.uk holds only as PDF). At the switch, known-limit rows keep their old label.
- **Known class / NEW.** In an agent check, a finding that fits a logged class is known; one that fits none is NEW and goes to Jason.
- **Checked rows.** Rows an agent or Jason has judged, kept with their accepted label in a fixture (`switch_checked.json`). Code compares current labels with them: the regression net.
- **Table rules.** Each fault class written as a check over every row of the family (`LabelRules`, `mix lat.label_rules`).
- **Code-decided pass.** A step passes on checked rows, table rules, catalogues and golden from inputs, not on an agent's verdict.
- **Agent check.** A Claude agent judging a seeded sample against the sources under a written prompt in the step's skill. Now used only to find new classes.
- **Seed.** The number that fixes a sample's draw (`Measures.Draw`). The same seed draws the same sample; a new round uses a new seed.
- **Verdict file.** An agent's per-item verdicts as JSON, saved under `backend/data/reports/change-vocabulary/verdicts/`, pooled by `mix lat.verdicts`.
- **Pooled 95% upper bound.** From the pooled samples since the last fix, the exact one-sided Clopper–Pearson upper bound on the error rate. 0 wrong in 149 items gives under 2%.
- **Quality statement.** A step's published account of what its data is, how it was checked, its measured accuracy and coverage, and its known limits.
- **Read pass.** Re-reading the amending laws' text into `amendment_rules` (`mix lat.amending --read`), one law at a time. Long; ask first.
- **Build / rebuild.** Turning a law's sources and rules into its stored changes (`mix lat.vocabulary --build | --check`).
- **Stale.** A built law whose code version or inputs moved since its build (`mix lat.stale`).
- **Restore point.** A backup of just the tables a run will write, taken seconds before it (`./scripts/nas/nas-backup.sh --tables … --tag …`), so the run can be rolled back.
- **Tell-tale.** A measured pattern in one step's output that points to a fault in another part of the system (often the LAT parser).
- **Parking list.** A section of a step session listing new work found mid-step, each with its owning step. Not done in-step.

## Former codes

Archived sessions (`.claude/sessions/change-vocabulary/`) use codes. Pending ones are being moved to `.claude/sessions/lat-change-pipeline/` under names. The pipeline was called the **change vocabulary** (CV) until 2026-11-03; the code still uses that name.

### Sessions

| Code | Name now | What it was |
|---|---|---|
| CV-00 | Meta plan | The pipeline's plan: goal, source authority, the per-family recipe, known limits |
| CV-01 | Architecture review | Inventory of every source and reconciling rule; the design; the first golden set |
| CV-02 | The change record (thin slice) | The claim and change record, proven end to end on two golden cases |
| CV-03 | First readers | Feed and markup readers; the amending-law reader adapted to emit claims |
| CV-04 | First merge and store | Merge by identity, the change store, the conflict report, the expiry reader |
| CV-05 | Labels side by side | Step 12 (once "step 12a") |
| CV-06 | Switch-over | Step 13 (once "step 12b") |
| CV-06a | Switch-over: repeal tables | Repeals in schedule tables read before the switch (an amending-law reader fix) |
| CV-06b | Faults parked from the switch-over | Earlier steps' faults found at the switch, by owning step (pending) |
| CV-07 | Primary coverage | Reading the law's text for territory, dates and the backlog on OH&S |
| CV-S01 | Sources | Step 1 |
| CV-S02 | Feed reader | Step 2 |
| CV-S02a | Parser tell-tales | LAT parser fixes the feed check exposed (row naming, unnumbered list items) |
| CV-S02b | Feed pattern catalogue | The catalogue over every stored feed |
| CV-S03 | Markup reader | Step 3 |
| CV-S04 | Commencement reader | Step 4 |
| CV-S05 | Extent reader | Step 5 ("extent and application reader") |
| CV-S05a | Extent recall sweep | Finding extent sentences the catalogue missed |
| CV-S05b | — | Never used |
| CV-S05c | Extent shape mining | Classing dropped list items (census classes A–F) |
| CV-S05d | Extent whole-reader census | An independent finder compared with the reader over every law |
| CV-S05e | Extent census as a task | The census as a mix task (pending) |
| CV-S05f | Target-named extent statements | Extent statements naming the amended provision |
| CV-S05g | Extent agreement measure | The reader's territory against the feed's (pending) |
| CV-S06 | Amending-law reader | Step 6 |
| CV-S07 | Merge | Step 7 |
| CV-S08 | Evidence | Step 8 |
| CV-S09 | Label fold | Step 9 |
| CV-S10 | Measures | Step 10 |
| CV-S11 | Store and build | Step 11 (numbered S12 for one day, 2026-10-30/31) |
| CV-S12 | Retrospective: process reset | After the switch (numbered S11 for one day) |

Other sessions in the folder: "Reader run time" (making catalogues and checks quicker), "Amendment reader and extent decomposition" (splitting two large modules), "Application scope hand-off to fractalaw" (pending).

### Label conventions (stable; still used)

| Code | Rule |
|---|---|
| C1 | A repeal for one territory with the text kept: the row stays in force, territory narrowed |
| C2 | Territory has an explicit "nowhere", distinct from unknown |
| C3 | Territorial versions carry the shared history before the split, with that time's full territory |
| C4 | A renumbering opens a period |
| C5 | `changed_by` lists every law when parallel changes take effect together |
| C6 | A provision's own application clause sets its territory over the instrument's extent |
| C7 | Revoked for one purpose with the text kept: partly in force |
| C8 | EU retained law in NI (Windsor Framework): a GB-only change leaves NI with the EU text |
| C9 | A change to a child never opens a period on its parent |
| C10 | An Act commenced by an order we don't hold: in force from unknown, never Royal Assent |
| C11 | A provision's legislative context (HSWA s.78 amends a GB-only Act) sets territory over the CLML extent |
| C12 | Repealed but saved in one territory: in force with the remaining territory |
| C13 | A commencement for one territory is in force there; each later territory's commencement widens it |
| C14 | Inserted text takes the inserting law's narrower extent |
| D1 | `in_force_from` is when the current text took effect; `changed_by` the laws that made it |
| D3 | A repeal with savings is `repealed_saved` |

### Strata letters (one letter, several meanings)

| Step | Letters |
|---|---|
| Amending-law reader | **A** agreeing with legislation.gov.uk; **D** disagreeing (the census); **L** law text only |
| Merge | **J** joined (two or more sources); **U** unjoined (law text beside a likely same event); **C** candidates (single-source beside another source's change) |
| Evidence | **V** value conflicts; **D** markup against feed with no primary claim; **A** agreeing |
| Label fold | **G** golden; **S** shapes (rows each fold rule acts on); **T** today differs; **R** random |

A and D mean different things in the amending-law reader and Evidence. J and U also name class series below.

### Fault and class codes

Codes restarted in many rounds and collided. Read a code with its session. The slug is the descriptive name to use from now on (`bug-raise` skill).

| Code | Where | Slug and meaning |
|---|---|---|
| K1 | Feed, Markup | `schedule-not-parsed`: schedules and EU annexes are not LAT rows (a v0.1 limit) |
| K1–K10 | Extent rounds 1–5 | Not recorded; restated as the KU…KT classes below |
| K2, K4, K5 | Feed | `eu-row-name-nbsp`, `unnumbered-list-item-rows`, `doubled-brackets`: parser faults fixed by the parser tell-tales session |
| K3 | Feed, Markup | `clml-structure-fault`: legislation.gov.uk ids contradicting nesting or skipping a level |
| K6 | Feed, Merge | `feed-duplicate-effect`: the feed lists one effect twice |
| K7 | Feed | `eurlex-date-in-comments`: an EU in-force date in comments only, a pointer |
| K8 | Feed; Label | Feed: `commencement-territory-carried` (carried, applied by the fold). Label: C8 not applied, before the Windsor list was held |
| K9 | Feed, Markup | `placed-on-every-version`: a change placed on every territorial version |
| K10 | Feed | `nested-schedule-id-short-name`: schedule ids named short by the shared namer |
| K11 | Feed | `second-date-in-free-text`: a later date only in a qualification's words |
| K12 | Feed | `staged-modification-one-change`: staged modifications stay one change |
| M1–M3, P1 | Markup | One effect as Addition here and Substitution there; insertion plus paired substitution; feed vs markup disagreement; a note citing a law in untagged text |
| M1 | Merge; Label fold | Merge: `uri-id-alias` (re-keyed effect ids). Label fold round 5: the feed's self-commencement not joined to the reader's; round 8: a regression on version history |
| KU | Extent | `extent-statement-unread`: a qualified statement left unread, its bound withheld (counted) |
| KU1 | Extent | `unnumbered-schedule-same-extent`: read as covering every amendment |
| KP | Extent; Merge | Extent: `enabling-powers-not-read`. Merge: `body-markup-under-heading-id` |
| KP-1AA | Label fold | `clml-id-skips-1AA`: HSWA s.50(1AA)'s paragraphs filed under s.50 |
| KE | Extent | `eu-extent-not-read` |
| KC | Extent | `devolved-competence-only` |
| KN | Extent; Merge | Extent: `provision-named-in-no-list`. Merge: `note-cites-missing-provision` |
| KD | Extent; Amending | Extent: `text-data-fault` (repealed version stored, numbers in words). Amending: `drafting-slip` in the law |
| KS | All | `schedule-row-missing`: a schedule change with no row (v0.1) |
| KL | Extent | `list-read-in-part`, counted |
| KX | Extent; Merge | Extent: `exception-item-keeps-default`. Merge: `as-inserted-by-chain` (an event under another amending law) |
| KX-territory | Evidence | `chain-territory-cut`: a chain's territory cut to the later law's extent |
| KW, KT, KQ | Extent | Withheld but doubtful; text faults and refs to nothing; an ambiguous item after "and" |
| KA | Extent | `application-to-cases`: which things or persons a law covers, not where; handed to fractalaw. The retrospective notes KA meant more than one thing across rounds (to confirm which) |
| KM | Amending, Merge | `lgu-coarser-than-law`: markup or feed coarser than the law |
| KM-EU | Merge | `eu-one-changeid-several-points`: left apart by design |
| KL-EU-list | Merge | `eu-list-item-on-article` |
| KJ, KJ2 | Amending, Merge | `law-text-paired-wrongly` / `identical-effects-left-apart` (merge faults seen from the reader) |
| KH, KB | Amending | `cross-heading-as-words`; `deepest-place-not-held` |
| KR, KR-range | Amending; Merge | `repeals-table-joining-word` (fixed); `range-reaches-later-insertion` |
| KC-effect, KC-order | Evidence | `has-effect-from-unread`; `order-held-not-read` |
| KMV | Evidence | `moved-words-as-renumbered` |
| KF-type | Evidence, Label | `feed-type-error-wins` |
| KC10 | Label | `start-undated` (C10): a gap |
| K-legacy | Label | `legacy-addition-as-insertion` |
| KO-two, KF-later, KEU-eif | Label | `order-commences-two-acts`; `later-inforce-date-dropped`; `eu-entry-into-force-pointer` |
| QL/QB, RR, LA, TR, WL-reach, Parts | Label (upstream) | A quote's last item not inserted; a "sections … are repealed" form unread; an "amended as follows" lead-in lost; an NI-only order rule with no change; a whole-law rule not reaching; a parent's commencement blocked by a later part |
| U1–U15 | Label fold round 1 on | Upstream classes, each owned by an earlier step: U1 `revoked-amender-credited`; U2 `range-also-on-parent`; U3 `relative-clause-read-as-commencing`; U4 `general-commencement-full-on-ancestor`; U5 `second-commencement-rule-not-stored`; U6 `order-not-commenced-by`; U7 `level-defaults-to-provision`; U8 `feed-abolition-unmapped`; U9 `legacy-repeal-read-as-insertion`; U10 `extent-not-applied` (C6/C11/C14); U11 `made-version-prospective`; U12 `repeal-table-missing` (fixed in part at the switch-over); U13 `order-law-identity` (uksi for wsi or ssi); U14 `feed-type-wins-for-modification`; U15 `order-carve-out-read-full` |
| F1–F8 | Label fold round 1 | Fold classes: start at insertion; versions split at their start; one-territory commencement; C8; whole substitution ends partial; start-day partial commencement; words gone not C7; commenced through parts |
| H1–H7, J1–J5, L1–L3, O1–O5, Q1–Q3, EW, NN | Label fold rounds 5–10 | Fold fixes and questions, one batch each; read in the round's table. J1–J5 here are not the old path's J rules |
| P3–P10, V8–V10 | Label fold rounds 2–11 | Upstream reader and feed faults found by the fold check |
| J1–J6, T1 | Old path (`LabelProjection`) | J1 start; J2 markup wins today; J4 outstanding repeal; J5 inserted by note; J6 left to orders; T1 undated change blanks. Retired for switched families |
| A–F | Extent census | Classes of dropped list items (A: only the first of several "(a) … (b) …" read; B: an item with its own exception dropped; C: plain items dropped with a qualified companion; D: a qualified item dropped silently; E: one-offs; F: to confirm) |
| S1–S17, R1–R16 | Extent census | The independent finder's flagged shapes and residuals |
| R1–R10 | Commencement reader | Fix batch for clause lead-ins and forms (2026-10-24) |
| N1–N4 | Commencement reader (round 4); Label fold (round 5) | Different defects in each: in the commencement session, rule-level misreads behind sampled rules (a qualifier spread over a list; SI 1964/191's split; a qualifier after the date; other laws' provisions in an order's items); in the label fold, commencement-reader faults (a sub-provision's commencement lost; "68(1)(c) and (2)" read as s.68(1)(2)) |
| D1–D5 | Feed (seed 7); Extent (round 6) | Defect numbers in one round, unrelated to convention D1 |
