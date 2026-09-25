# Extent is not application (#162, #163)

- **`geo_extent` / `geo_region` record EXTENT:** the legal system(s) a law forms part of. English and Welsh SIs both extend to `E+W`.
- **They do not record APPLICATION**, i.e. where a law operates. For example, the Smoke-free (Premises and Enforcement) Regs extend to E+W but apply to England only.
- **Application is published by fractalaw** as `application_regions` / `application_source` / `application_evidence` (#163). Screening gates on application. When application is null, it falls back to `geo_extent`, treated as an upper bound only.

## How extent is resolved

`SertantaiLegal.Scraper.ExtentResolver` takes the first source with a verdict, in this order:

| Rank | `geo_extent_source` | Evidence |
|---|---|---|
| 1 | `law_level` | `Legislation/@RestrictExtent`, unless the document is unrevised (`document_status = final`) |
| 2 | `lat_provisions` | union of LAT `extent_code` |
| 3 | `contents_items` | union of `ContentsItem/@RestrictExtent`, **revised documents only** |
| 4 | `text_clause` | whole-instrument clauses: "These Regulations extend to …" |
| 5 | `type_code` | floor: ssi/asp/ssa → S; nisr/nia/apni/nisi/nisro → NI; wsi/anaw/asc/mwa → E+W |

**Rules:**
- **It never defaults to `UK`.** On unrevised documents every ContentsItem carries the placeholder `E+W+S+N.I.`; that placeholder is what mislabelled devolved laws as `UK`.
- **`geo_extent_source = null` means legacy or unverified.** A value set before #162 and not confirmed by any source is kept, not cleared. Treat it as an upper bound only.
- **When a new value may replace a stored one:**
  - a better- or equal-ranked source replaces the stored value;
  - an unknown result never overwrites.
- **When extent is re-resolved:**
  - at scrape time (from the metadata and extent stages);
  - after each LAT persist;
  - by `mix extent.resolve`, which is dry run by default; `--apply` snapshots first.

# geo_extent

**Geo_Pan_Region** in the legl donor app.
geo_extent in this app - this is mislabelled.  Should be geo_region because it includes Uk and GB as aggregates of the countries.

Single selection only.

- UK
- GB
- E+W
- E+S
- E
- W
- S
- NI

# geo_region

**Geo_Region** in the legl donor app.
These are the countries of the UK.  And the column should be called geo_country. 

Multiple selections are possible.

- England
- Wales
- Scotland
- Northern Ireland

# geo_country

**Geo_Extent** in the legl donor app.
geo_country in this app - this is mislabelled.  Should be geo_extent.

A complex field content.  Here's an example:

🇬🇧 E+W+S+NI
section-1, section-2, section-3, section-4, section-5, section-6, section-7, section-8, section-9, section-10, section-11, section-12, section-13, section-14, section-15, section-16, section-17, section-18, section-19, section-20, section-21, section-22, section-23, section-24, section-25, section-25A, section-26, section-27, section-27A, section-28, section-29, section-30, section-31, section-33, section-34, section-35, section-36, section-37, section-38, section-40, section-41, section-42, section-43, section-43A, section-44, section-45, section-46, section-47, section-48, section-49, section-50, section-51, section-52, section-53, section-54, section-77, section-78, section-79, section-80, section-81, section-82, section-83, section-84, section-85, schedule-2-paragraph-1, schedule-2-paragraph-2, schedule-2-paragraph-3, schedule-2-paragraph-4, schedule-2-paragraph-4A, schedule-2-paragraph-5, schedule-2-paragraph-6, schedule-2-paragraph-7, schedule-2-paragraph-8, schedule-2-paragraph-9, schedule-2-paragraph-10, schedule-2-paragraph-11, schedule-9-paragraph-3
🏴󠁧󠁢󠁥󠁮󠁧󠁿 🏴󠁧󠁢󠁷󠁬󠁳󠁿 🏴󠁧󠁢󠁮󠁩󠁲󠁿 E+W+NI
section-39, schedule-2-paragraph-12
🏴󠁧󠁢󠁥󠁮󠁧󠁿 🏴󠁧󠁢󠁷󠁬󠁳󠁿 🏴󠁧󠁢󠁳󠁣󠁴󠁿 E+W+S
section-11A, section-51A, section-55, section-56, section-57, section-58, section-59, section-60, section-75, schedule-3-paragraph-1, schedule-3-paragraph-2, schedule-3-paragraph-3, schedule-3-paragraph-4, schedule-3-paragraph-5, schedule-3-paragraph-6, schedule-3-paragraph-7, schedule-3-paragraph-8, schedule-3-paragraph-9, schedule-3-paragraph-10, schedule-3-paragraph-11, schedule-3-paragraph-12, schedule-3-paragraph-13, schedule-3-paragraph-14, schedule-3-paragraph-15, schedule-3-paragraph-16, schedule-3-paragraph-17, schedule-3-paragraph-18, schedule-3-paragraph-19, schedule-3-paragraph-20, schedule-3-paragraph-21, schedule-3-paragraph-22, schedule-3-paragraph-23, schedule-3A-paragraph-1, schedule-3A-paragraph-2, schedule-7-paragraph-1, schedule-7-paragraph-2, schedule-7-paragraph-3, schedule-7-paragraph-4, schedule-7-paragraph-5, schedule-7-paragraph-6, schedule-7-paragraph-7, schedule-7-paragraph-8, schedule-7-paragraph-9, schedule-8-paragraph-1, schedule-8-paragraph-2, schedule-8-paragraph-3, schedule-9-paragraph-1, schedule-9-paragraph-2
🏴󠁧󠁢󠁥󠁮󠁧󠁿 🏴󠁧󠁢󠁷󠁬󠁳󠁿 E+W
section-61, section-63, section-64, section-70, section-71, section-76
