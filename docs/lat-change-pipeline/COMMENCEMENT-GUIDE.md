# Commencement: How a Law Comes Into Force

*A guide for later sessions. Written 2026-10-19 after the Commencement Ruleset meta (CR-00 → CR-09) and LR-43. Code: `backend/lib/sertantai_legal/scraper/commencement/`, `law_start.ex`, `law_start/`. Print any law's rules: `mix lat.commencement --law UK_ukpga_1990_43`.*

---

## 1. In plain words

A law being *made* and a law being *live* are two different things.

When Parliament passes an Act, or a minister makes a set of Regulations, the text exists from that day — but its duties usually don't bite yet. The law itself says when they start. Sometimes that's simple ("these Regulations come into force on 1 October 2024"). Often it isn't:

- **Some parts start at once, others later.** "Sections 1 and 2 come into force on the day this Act is passed; the rest on 1 April."
- **Some parts wait for a minister.** "…on such day as the Secretary of State may by order appoint." The minister then makes a short *commencement order* — sometimes ten of them over several years — each switching on a few more sections.
- **Some parts start only partly.** "…for the purpose of making regulations" (so the power to write rules exists before the duties do), or "in relation to Wales" (England comes later, or never).
- **Some parts start by reference to something else.** "On exit day", "at the same time as section 83 of the 2022 Act".

And a change to a law has its own start. When an Act amends another Act, the amendment takes effect only when *that* provision of the amending Act comes into force — which may again be by its own clause, or by a later order.

So for every provision we label, "when did this become live, and where?" means reading the law's own commencement clause, the commencement orders made under it, and — for a change — the commencement of the law that made the change. legislation.gov.uk records much of this as editorial *effects* ("coming into force" entries in its changes feed) for laws from about 2002 on; for older laws we read the text.

We turn all of that into one simple, readable form — a **rule** — and let one piece of code date any provision from the rules alone.

---

## 2. The abstraction

### 2.1 Readers → rules → one evaluator

```
law's own clause ─┐
commencement orders ─┼─► readers ──► rules (commencement_rules) ──► evaluator ──► a provision's in-force entries
feed "coming into force" effects ─┘                                                     │
                                                         ┌──────────────────────────────┤
                                     labelled law's rows (commencement collector)   amending changes (amending-law collector)
```

- **Readers** handle all prose and XML, once per source document: `Commencement.OwnClause` (a law's own clause, via `LawStart` / `LawStart.Provisions`), `Commencement.Order` (a commencement order's text), `Commencement.Effects` (an Act's feed effects).
- **Rules** are stored in `commencement_rules` (`Commencement.Store`) and printable one per line.
- **The evaluator** (`Commencement.Evaluator`, pure) dates any provision from the rules — for the labelled law's own rows (`ChangeCollector.Commencement`), for an amending provision (`Commencement.Amending`), for a row left to orders (CR-07).
- **One path:** only the readers may read commencement wording (architecture test `commencement_read_test.exs`).

### 2.2 The rule (`Commencement.Rule`)

Bringing into force only. No expiry, no retrospective flag — "deemed to have come into force on 1 April" is simply that date.

| Field | Values | Meaning |
|---|---|---|
| `commences` | a law name | whose provisions come into force |
| `scope` | `:all` · `:rest` · `[ref]` | everything; "the remaining provisions" / "otherwise"; or refs in LAT's grammar — `"s.12(3)"`, `"reg.5"`, `"pt.II"`, `"pt.6.ch.1"`, `"sch.13.para.70(a)"`, a range `"s.1..s.5"` |
| `except` | `[ref]` | refs the scope leaves out ("except section 74") |
| `when` | `{:date, d}` | a date |
| | `{:after, :made \| :passed, {n, :day \| :month}}` | counted from making / passing |
| | `{:named_day, :exit_day \| :ip_completion_day}` | a statutory day |
| | `{:appointed, how}` | a day fixed later (by order, notice, event) — undated until another rule dates it |
| | `{:with, "law:ref"}` | with another provision's commencement |
| | `:unread` | a statement we couldn't read |
| `territory` | `nil` · `"E"`, `"W"`, `"S"`, `"NI"`, `"E+W"` … | where it starts (nil: wherever the provision extends) |
| `purposes` | `nil` · `:for_making_secondary_legislation` · `:in_relation_to` · `:for_specified_purposes` | how far; non-nil = partial (the words verbatim in `source.text`) |
| `source` | `%{law, ref, text}` | the clause or article read, verbatim |
| `treatment` | catalogue name | which reading produced it (§3) |

A rule with a territory or purposes is **partial**. Readable form (`Rule.to_text/1`):

```
s.4 — 1992-01-02 — everywhere, in relation to — order_date — UK_uksi_1991_2905 reg.3: "… section 4, except so far as it relates to breach of condition notices"
s.4 — 1992-07-27 — everywhere, fully — order_date — UK_uksi_1992_1630 reg.2: "… section 4, so far as it is not yet in force"
```

### 2.3 How the evaluator decides

- **Which rules reach a provision:** its own ref, a bracket ancestor (`s.12` for `s.12(3)(a)`), a container (`pt.2`, the provision's Part / Chapter), a range (document order or number), `:rest`, `:all`; minus `except`.
- **Within one source, the most specific wins:** own ref, then ancestor, then `:rest`, then `:all`. "s.62 on 23 March 2027; otherwise on Royal Assent" dates s.62 once.
- **A partial rule completes the general one:** where the most specific rules are all partial, the next rule down still applies, partly — fully in force once both have started (Quarries Regulations reg.26: classified tips 2006, the rest 2007).
- **Across sources every covering rule applies, in date order;** a full commencement supersedes earlier partial ones (Order 1 "for the purpose of making regulations", Order 2 "the remaining provisions").
- **Territory:** entries for territories that together cover the provision's extent make it full (E 2000 + W 2001 + S 2000 → EPA Part 2A fully in force).
- **Output** (`Evaluator.in_force/1`): the partial starts before the full one (qualified in the feed's words — "for E.", "for specified purposes", "for certain purposes"), then the full start. Labels show `in_force_partial` between them.

### 2.4 Which source wins

| Provision | Order of sources |
|---|---|
| A labelled law's row | its own clause (law-level start: `LawStart` catalogue; provision sentences: `LawStart.Provisions`); where its own feed records no commencement for the row, its commencement orders (CR-07) |
| An amending provision (the change on our row) | **effects first** — the amending Act's feed "coming into force" entries; else its own clause (read from the CLML we hold, one hop) and the orders its notes cite (`Commencement.Amending`) |
| Never | note text (notes only point at which law / order to read); an Act's Royal Assent or a staged clause's earliest date as an amending provision's date |

---

## 3. The ways a law comes into force

Each form below is read today; the treatment name is what `mix lat.commencement` / `mix lat.law_start --law X --fresh` shows.

### 3.1 The whole law, from its own clause or metadata (`LawStart.catalogue/0`)

Tried in this order; the first that decides wins.

| Treatment | Form | Example |
|---|---|---|
| `lrt_metadata` | the register's coming-into-force date | most SIs |
| `clml_coming_into_force` | CLML `ukm:ComingIntoForce` (earliest) | |
| `eu_entry_into_force` | an EU regulation / decision: EUR-Lex entry into force, or a date its text states | |
| `clause_date` | "These Regulations come into force on 1st April 2020" | |
| `clause_made_relative` | the day after making; N days / months after; "the expiration of 21 days beginning with the day on which it is made"; the first day of the following month | SI 2017/469 art.1(2) (made + 1 day) |
| `clause_named_day` | "on IP completion day" (31 Dec 2020; also immediately before / after); "on exit day" (31 Jan 2020 — but **31 Dec 2020 for an instrument made before exit day**: EU (Withdrawal Agreement) Act 2020 Sch. 5 para. 1(1), unless it disapplies that) | SI 2018/1370, SI 2019/696 (CR-09) |
| `clause_staged` | "…in accordance with paragraphs (2) and (3)": the earliest date its paragraphs state (the law's start; never an amending provision's date) | GLA Act 1999 s.425 |
| `act_enactment` | an Act whose clause states no date: Royal Assent (Interpretation Act 1978 s.4) | |
| `by_order` | "on such day as the Secretary of State may by order appoint" — the whole law | Utilities Act 2000 s.110 |
| `tied_to_other_law` | "at the same time as section 83 of the 2022 Act comes into force" | |
| `eu_directive` | an EU directive: binds Member States, never in force in the UK itself (known limit) | |
| `eu_publication_relative` | an EU text dated from OJ publication with a consolidation's metadata (known limit) | |
| `clause_unread` / `no_clause` | listed for review | |

### 3.2 Particular provisions, from the law's own clause (`LawStart.Provisions`, `OwnClause`)

| Form | Rule | Example |
|---|---|---|
| "Regulation 12 shall come into operation on 31st May 2015" | named refs, a date (`provision_dated`) | |
| "Sections 1 and 2 come into force on such day as … may by order appoint" | named refs, `appointed` (`provision_by_order`) | |
| "The remaining provisions of this Act come into force on …" / "Otherwise …" / "The preceding provisions …" | `:rest`, never the commencement provision itself | WCA 1981 s.74(3) |
| "…except regulation 73", "other than section 128" | `except` | |
| "This Part", "Part II", "Chapter 1 of Part 6", "paragraph (4)", "this section" | containers / relative refs | |
| Qualified: "so far as it relates to …", "for the purposes of …", "in relation to Wales", "comes into force in Wales on …", "with respect to any tip which was not a classified tip" | partial rule (territory or purpose); completes the general rule | Quarries (NI) 2006 reg.26; 2010/29 FWMA s.49(3) |
| A qualifier covering only the items after it: "regulations 2, 5, 10 and 11, and, so far as they relate to sections 12 to 14, regulations 3, 6 and 7" | plain group + qualified group | uksi 1988/819 reg.1(2); asp 2005/13 s.33 |
| A provision's own words anywhere in the law: "This section shall come into force on the passing of this Act" | that provision, its date | Utilities Act 2000 s.68(2) |
| Partly in on a date, the rest left to orders | J6: by order, in force as at the revised text, since unknown; the partial entry kept | EPA 1990 s.164(2)/(3) |

Conditions and descriptions name nothing: "If the condition in subsection (5) is met …", "a provision … to which subsection (2) applies" (Coronavirus Act 2020 s.87(4)).

### 3.3 Commencement orders (`Commencement.Order`)

An order commences the Act it defines as "the Act" (or names). Forms read:

| Form | Example |
|---|---|
| Inline: "Sections 17 to 22 of, and Schedule 4 to, the Act shall come into force on 2nd April 1994." | SI 1994/571 |
| A statement with items below it: "The following provisions … come into force on 1st October 2006— (a) section 1(4); (b) section 11, so far as not already commenced; …" | SI 2006/2541 |
| Items first, date last (older orders): "The following provisions of the … Act 1981, namely— (a) Part I …; (b) … shall come into force on 28th September 1982." | SI 1982/1217 (WCA) |
| Appointed-day sentence: "1st April 1996 is the day appointed for the coming into force of— …" | SI 1996/323 |
| Made-relative: "the day after this Order is made" | SI 2012/873 |
| A Schedule table dated by its title or the article introducing it: "Provisions coming into force on 23rd March 1997 \| Section 1 \| …" | SI 1997/1082 |
| Items: sections (ranges, subsections), Schedules, Parts, "paragraphs … of Schedule N", "in Schedule 13 to the Act, paragraphs …", "Schedule 6, paragraphs 18(1) … and 20", a bare list under "the following paragraphs of Schedule 22—", a wrapped list's tail "… 29 and 30 of Schedule 15" | SI 1996/186, 1991/1042 |
| A section through its Schedule: "section 116 in so far as it relates to paragraphs 2(1) to (3) of Schedule 21" → the paragraphs fully, the section partly | SI 1995/1983 |
| Partial: "so far as it relates to", "to the extent that it relates to", "for specified purposes", "except", "in relation to England" | SI 2009/400 |
| Full again: "so far as not already in force", "so far as it is not yet in force", "in so far as that sub-paragraph is not already in force", "for all remaining purposes" | SI 1992/1630, 1996/186 |
| Territory: from the item, its statement, the order's title ("(England) Order"), or the instrument type (WSI → Wales, SSI → Scotland, NISR → NI) | SI 2000/340 |

Not the Act's: another law's provisions named in an item ("the repeal of section 1 of the Control of Pollution Act 1974", "… into the 1991 Act"); "in Part II, the repeals of …" (a place, not an item); "provisions … which are specified in Schedule 3 to this Order" (a subset, never the whole Schedule).

### 3.4 Feed effects (`Commencement.Effects`)

legislation.gov.uk's "coming into force" effects on an Act (from ~2002): provision refs, the commencing instrument and article, each in-force date, and a qualification — "wholly in force", "so far as not already in force" (full); "for specified purposes"; "for E." / "for W." / "for E.W." (territory); "for the insertion of s. 120A for E. and the insertion of s. 120B for specified purposes" (reaches only the named inserted sections). A prospective entry is `appointed`.

### 3.5 Amending provisions (`Commencement.Amending`)

The change on our row starts when the provision that made it does: effects first; else the amending law's own clause (§3.1–3.2, read from its CLML) and the orders its notes cite (§3.3). A repeals table is dated by its own entry before the section introducing it (1994 c.19 Sch. 18, not s.66(8)). A whole Schedule whose entries came in on different dates gives no date.

---

## 4. Live methods not yet operationalised

| Method | What happens today | Where it bites |
|---|---|---|
| **Dates relative to an event per case** — "for the purposes of their application to an activity …, on the day immediately following the relevant date in relation to the application in question" | undated | EPA 1990 Part II via SI 1994/1096 art.3 |
| **Event-triggered commencement** — "on the day the Treaty enters into force for the UK", "when the first regulations under section 5 come into force" | `appointed` (undated) | rare in our corpus |
| **`with` another provision** — "at the same time as section 83 of the 2022 Act" | the law-level `tied_to_other_law` is a known limit; the evaluator supports `{:with, ref}` but no reader resolves the other provision's date | 11 laws |
| **Para. 1(3) regulations** varying the exit-day reading (EU(WA)A 2020 Sch. 5) | not read; para. 1(2) express disapplication is | none found |
| **Orders a law's notes don't cite and its feed doesn't record** — an earlier stage of a "so far as not already in force" order | a later date than the real one (the completion order's) | Merchant Shipping and Maritime Security Act 1997 Sch. 6 (17 changes) |
| **A qualifier on one item of a bare paragraph list** — "68(2) in so far as it requires …" | read over the whole list (partial) | SI 1996/186, 6 rows (open bug) |
| **Staged clause, sentences unread** — LR-33's earliest date stands for rows no sentence names | the earliest date | 207 laws' law-level rule is `clause_staged` |
| **Unread clauses / no clause** | listed, no date | law-level `clause_unread`: 49 laws |
| **EU directives / publication-relative EU texts** | known limits (no UK in-force date) | `eu_directive`, `eu_publication_relative` |
| **Rows left to orders that no feed effect, held order or read clause dates** (orders not found by title search, unread order forms) | J6 (in force as at the revised text, since unknown) | 17,440 rows `commenced_by_order` |
| **Register metadata disagreeing with the text** | `lrt_metadata` wins for the law's start | 5 of 506 laws checked |
| **Expiry, sunset, retrospective effect** | out of scope by decision (Jason 2026-10-18): an ending is a change like a repeal; "deemed to have come into force on" is that date | — |

Where a reading is missing, the label says so: the row stays unknown, or in force "since unknown" (J6) — never a guessed date.

---

## 5. Quality and measures (2026-10-19)

- Amending changes dated vs the dates their notes state (a yardstick, never a source): **99.1%** (3,710 / 3,742).
- Effects tier vs the feed: 97.0%; own-clause tier vs the feed: 99.6%; order tier vs note dates: 96.5% → improved in CR-08.
- Labels: unknown today 16,359; undated_change 15,189; commenced_by_order 17,440 (`mix lat.wave_preview --all --relabel`).

Sessions: `.claude/sessions/commencement-rules/` (CR-00 meta and CR-01–09), `lat-refactor/` LR-33, LR-34, LR-39, LR-43. Next: the amendment ruleset (`amendment-rules/2026-10-19-ar-00-meta.md`, pending) — the same readers → rules → evaluator pattern for *what* a change does.
