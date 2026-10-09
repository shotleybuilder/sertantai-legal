# legislation.gov.uk Note Typology

What the annotations (`<Commentary>` notes: F1, C2, I3, …) in legislation.gov.uk CLML are, and which of them can tell the LAT where text applies. Written for the LAT parser refactor (LR-02, `.claude/sessions/lat-refactor/`) after a review showed notes being misread as territory.

Two parts: what the corpus holds (measured on the local CLML store, 1,068 laws, 2026-10-09), and what legislation.gov.uk documents (research, sources cited).

## 1. The corpus

Scripts: `backend/data/reports/lat-refactor/note-typology*.{json,txt}` (examples in `note-typology-examples.json`). Counts are distinct notes per law.

### 1.1 Types

| Type | Notes | Lead verb (before " by ") |
|---|---|---|
| F | 51,537 | substituted 21,778 · inserted 17,515 · repealed 11,575 · other 609 · amended 52 |
| C | 16,149 | modified/applied/excluded/extended 13,463 · other 2,311 · amended 268 |
| I | 11,095 | commenced ("in force") 11,083 |
| M | 5,961 | marginal citations ("1906 c. 14.") 4,680; some "amended/inserted" wording |
| E | 1,048 | extent statements (almost all free prose) |
| P | 154 | powers exercised |
| X | 46 | editorial |

Only **F** notes describe changes to the text. **E** notes are prose about whole provisions ("This version of this provision extends to England and Wales only; a separate version has been created for Scotland only") — they label territorial *versions*, which the parser already takes from `RestrictExtent` / `Versions`. Only one E note uses a "(X.)" form.

### 1.2 How an F note names territory

| Form | Example | F notes |
|---|---|---|
| none | "Words in s. 5 substituted (1.1.2017) by …" | 42,661 (83%) |
| **bare** "(X.)" | "Words in s. 143(7) inserted (N.I.) (5.11.1993) by …"; "S. 143(1)–(7) repealed (E.W.) by …" | 5,506 (+ ~250 mixed with other forms) |
| **dated "for X."** | "S. 15(1A) inserted (6.4.2012 for E.) by …"; "(19.9.2004 for E., 28.5.2005 for W.)" | ~500 (+ ~700 mixed) |
| purposes / catch-all | "(11.1.2024 for specified purposes, 2.12.2025 in so far as not already in force)"; "for remaining purposes"; "otherwise" | ~2,000 |
| except | "(1.10.2023 except in relation to W., 6.4.2024 for W.)"; "except in relation to ss. 13-15" | ~370 |
| prospective | "(… and otherwise prosp.)" | ~150 |
| named | "disapplied in relation to Scotland (with effect from 1.4.2015)" | rare |

The forms differ in kind. A **bare "(X.)"** sits with the verb: *where the change was made*. A **dated "date for X."** sits inside the dates bracket: *when the change took effect, territory by territory* — commencement. "For specified purposes", "in so far as not already in force", "otherwise", "prosp." are commencement vocabulary too.

### 1.3 Bare "(X.)" is the Extent attribute in words

Change elements (`Addition`, `Substitution`, `Repeal`) that carry **both** an `Extent` attribute and a note with a territory:

| Attribute vs the note's territory | Elements |
|---|---|
| **equal** | **16,107 (97.8%)** |
| note narrower | 231 — dated commencement: "(16.3.2006 for W. for specified purposes, 6.4.2006 for E., …)" on Extent="E.W." |
| disjoint | 74 — "(1.4.2023 except in relation to W., 5.9.2023 for W.)" on Extent="E" |
| note wider | 66 — "inserted (E.W.)" on Extent="W" (the amending Act's extent; the words apply to W) |

Where the note's form is bare "(X.)", it matches the attribute. Every disagreement is a dated/commencement form, or the amending Act's extent.

### 1.4 How often the attribute is missing

| Element | With Extent | Without | …citing a bare "(X.)" note | …citing a dated note |
|---|---|---|---|---|
| Addition | 11,816 | 198,643 | 16,608 | 9,746 |
| Substitution | 4 | 70,935 | 5,605 | 1,369 |
| Repeal RetainText | 7,530 | 13,018 | 5,121 | 1,451 |

So ~27,000 change elements carry their territory only in a bare "(X.)" note — the same form that agrees with the attribute 98% of the time where both exist. ~12,500 cite only a dated (commencement) note.

## 2. What legislation.gov.uk documents

Sources: [Glossary] https://www.legislation.gov.uk/help · [Guide] *Guide to Revised Legislation* (Oct 2013) https://www.legislation.gov.uk/pdfs/GuideToRevisedLegislation_Oct_2013.pdf · [UG] CLML User Guide https://legislation.github.io/clml-schema/userguide.html · [XSD] https://github.com/legislation/clml-schema (schemaCommentary, schemaChanges, schemaLegislationMetadata).

### 2.1 Types (official)

Seven `CommentaryType` values [XSD]: **F** textual amendments "where there is authority to change the text" · **C** changes to "meaning, scope or application … without … authority to alter the text" (modified, applied, excluded, extended) · **I** commencement, "only if there is some complexity in the commencement" · **E** extent, "used very sparingly … where there are multiple versions of a provision for different geographic extents" · **M** marginal citations · **P** powers exercised (commencement orders) · **X** editorial. Only F, M, X have in-text markers; C, E, I, P relate to whole provisions [Guide p.21].

### 2.2 Authority and stability

- Editorial, not law: "an editorial comment on the text" [UG]; for effects that don't change the text the words "can do no more than give an indication of their general nature. The user is … advised to consult the affecting legislation itself" [Guide p.13]. Older annotations may have the wrong type [Guide p.9]; pre-2006 NI annotations are all F-notes in a non-standard format.
- **Machine-drafted from structured effects data**: "Our Editorial system uses the effects data to generate editorial update tasks … as well as the commentaries that editors insert" [UG]. Editors apply them and may edit them.
- **F/C/I numbers are not identifiers** — "the 3rd occurrence … in the legislation you have opened" [Guide p.21]: they change with the view and the version. `Commentary/@id` is the handle; modern ids (`key-<32hex>`) are the effect's id (empirical, not documented). Superseded annotations are removed in new versions [Guide p.22].

### 2.3 Territory: extent, application, commencement

- `Extent` on Addition/Substitution/Repeal: "the geographical extent (or territorial application) of the change, where it is more limited than … the parent provision" [XSD schemaChanges].
- A bare **"(E.W.)" after the verb** is the same thing in words: the worked example "S. 10A(1)(a) repealed (E.W.) (1.4.2010) by …" is "the limited extent repeal … for England and Wales only" [UG]. Both come from the effect's `AffectedTerritorialApplication`: "the editor must indicate that the amendment only extends to/applies in specific territories" [XSD].
- A **"(6.4.2012 for E.)" in the dates** is the effect's `InForce/@Qualification` — "for E.", "for E.W.", "for S. for specified purposes", "wholly in force" [XSD schemaLegislationMetadata]: *the change was brought into force for that territory on that date*. One effect has "one amendment for each time its affecting provision … comes into force in full, in part or for specified extents or purposes" [XSD InForce]. It is **commencement, not extent** — the Guide's example: a substitution "in relation to the whole of that extent … brought into force for England on 1 January 2006 and for Wales on 1 February 2007" [Guide p.22].
- Extent vs territorial application are deliberately conflated on the site (to be separated "when resources and priorities permit") [Guide p.23]; `RestrictExtent` is for retrieval, not a precise legal extent [Guide p.23].

### 2.4 Structure

Semi-structured: a documented template (provision · effect · date or "prosp." · affecting provision · savings · commencing instrument) [Guide p.12] and partly controlled vocabularies (verbs, abbreviations, InForce qualifications), no published grammar; free text otherwise, with historical and NI variation.

## 3. Consequences for the LAT

1. **Territory of a change** (brackets, `excluded_extent`) = its `Extent` attribute, else the **bare "(X.)"** clause(s) of its **F** note — documented as the same fact (§2.3) and measured as equal 97.8% of the time where both exist (§1.3). This covers ~27,000 elements that carry territory only in the note (§1.4).
2. **Never** take territory from: dated "date for X." qualifiers, "for specified purposes", "in so far as not already in force", "otherwise", "prosp." (commencement, §2.3); C, I, E, M, P, X notes (not textual changes; E notes describe versions the parser already reads from `RestrictExtent`).
3. **Commencement by territory** belongs to row **status** (`in_force_partial` where in force for some territories), not territory — a separate change, outside LR-02.
4. The structured source behind both is the **changes feed** (effects: `AffectedTerritorialApplication`, `InForce` with qualifications), joinable by commentary id = effect id for modern notes. Reading territory from effects rather than note text is the cleaner long-term route; note text is a derived, editable rendering.
5. F-numbers are view-specific; anything stored or matched must use `Commentary/@id` (the LAT already keys notes by id and `change_id`).
