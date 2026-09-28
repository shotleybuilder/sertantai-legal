# Live status parse fix: plan brief (2026-09-28)

## Context
SertantAI-legal holds a UK legal register of about 19K laws. The `live` status is one of:
- ✔ In force
- ⭕ Part Revocation / Repeal
- ❌ Revoked / Repealed / Abolished

Customer compliance screening in sertantai-compliance reads it. The Making funnel, which queues laws for article-text parsing and duty enrichment, skips Revoked laws. **A false "Revoked" hides live legal duties from customers; a false "in force" or part-revoked only creates review work.**

`live` is taken from the legislation.gov.uk "changes affected" table. Each row has a revoking law, a target (e.g. "Regulations", "Act", "s. 3", "Sch. 2 para. 4"), an affect (e.g. "revoked", "repealed in part", "words repealed") and an applied flag ("Yes" / "Not yet" / …). A title marker "(revoked)" or a doc status of revoked overrides it to Revoked.

The current rule is in `Amending.determine_live_status/1`. A row is a whole revocation when:
- the affect contains "in full", or
- the affect is repeal/revoke **and** the target is empty, a whole-instrument word, or "whole instrument".

The partial markers are "in part", "except", "words", "entry", "comma" and "power to". Any whole row gives Revoked. Revocation rows with no whole row give Part. No revocation rows give In force. The "Applied" column is ignored, so unapplied revocations count, which is correct.

The revocation rows are stored per law as JSONB (`affect`, `target`, `applied` per revoker) for 4,520 of the 4,642 Revoked laws. A recompute can therefore run offline.

## Bugs found
1. The commencement row "Appointed day(s) for spec. repeals in Sch.11…" with target "Act" was counted as a whole repeal (the Coal Industry Act 1994 is wrongly Revoked).
2. "revoked in pt" / "revoked in pt." were not recognised as partial.
3. Overseas-territory revocations were counted as UK whole revocations: "revoked (Pitcairn)", "(Sovereign Base Areas)", "(British Indian Ocean Territory)".
4. **Territorial revocations were treated as whole.** Examples:
   - the Control of Pollution (Amendment) Act 1989 was repealed only by a Scottish SSI;
   - the Special Waste Regs 1996 were revoked by an E+W SI plus a Welsh WSI and are still in force in Scotland.
5. `live_description` is written only by the metadata stage and never recomputed. 1,088 Revoked laws carry legacy text "Current legislation" / "Revised – has been amended".
6. Nothing records the kind of revocation (unapplied, with savings) or the revoking law and date. The downstream peer fractalaw asked for this.

Rare edge cases also exist on whole rows: extent markers in the affect ("revoked (S.)", "(E.W.)", "(N.I.)") and prospective markers ("(prosp.)").

## Territorial sizing (4,130 Revoked laws that have whole rows)
I compared the union of the whole-revoker extents with the law's `geo_extent`. For revokers missing from the DB, the jurisdiction is inferred from the type code (ssi/asp → S, wsi → W, nisr/nia → NI). 466 laws come out uncovered:
- **Strong, about 64:** all whole revokers are devolved instruments (SSI/WSI/NISR), which legally cannot revoke outside their jurisdiction. Example: a UK SI revoked only by an SSI.
- **Weak, about 400:** a UK-level revoker (ukpga/uksi) whose *recorded* `geo_extent` is narrower than the law's. The uncovered region is NI (200), S+NI (134), S (49) and others.
  - Some are real (Special Waste Regs).
  - Many look like loose metadata: old GB-only SIs labelled extent "UK", and WSIs whose legal extent is E+W though they apply only to Wales (15 cases).

## Plan
1. **Pure module `Scraper.LiveStatus`** (dependency-injected: rows plus the law's type and extent plus revoker info `%{name => %{extent, date}}`). It provides:
   - `revocation?/1`: excludes commencement / appointed-day rows, so they stop listing the commencing law as a rescinder;
   - `whole?/1`: adds "in pt", overseas-territory qualifiers and prospective markers as not-whole;
   - `decide/2`, returning a struct.
   
   The struct holds:
   - `live`: the existing 3 values, unchanged vocabulary; territorial counts as Part;
   - `kind`: in_force | part_revoked | territorial | revoked | revoked_unapplied | revoked_with_savings;
   - `description`: derived, e.g. "Revoked by UK_uksi_2011_1524 (not yet applied to text)" or "Revoked in E+W by …; in force in S";
   - `evidence` (JSONB): the whole rows, applied, with_savings, revokers with dates (revoker md_date, as `latest_rescind_date` already uses), revoked and remaining regions, and the basis (devolved_revoker | revoker_extent | affect_marker).
   
   The law's jurisdiction for devolved law types comes from the type (wsi → W), not geo_extent. That removes the WSI E+W noise.
2. **New `live_evidence` JSONB column** on legal_register. It is excluded from the delta export to production until compliance adds it.
3. **Staged parser:** revoker extents and dates are looked up in the DB (an impure module). It sets `live`, `live_description` and `live_evidence` together. The title / doc-status override becomes a kind with source "title".
4. **`mix live.recompute`:** a dry-run CSV diff by default; `--apply` snapshots first. The guard: change `live` only where the old rule applied to the stored rows reproduces the current `live`, and the new rule differs. That isolates exactly this fix and never touches laws whose status came from elsewhere (title marker, legacy import, EU law). `live_description` / `live_evidence` are rewritten for every law with stored rows.
   - Descriptions that contradict `live` on laws without stored rows become a neutral "Revoked (source not recorded)".
5. **Follow-up:** Revoked + Making laws (287) that flip to Part / In force re-enter the Making funnel.

## Open questions
1. **The weak territorial bucket (~400).** The options are:
   - (a) trust the UK-level revoker's recorded extent → Part (territorial);
   - (b) treat UK-level revokers as whole (current behaviour) and flag the extent gap in the evidence for review;
   - (c) a middle rule, e.g. trust the revoker extent only when the uncovered region is S (separate legal system, common real case) but not NI-only.
   
   Given the asymmetric costs above, which would you choose?
2. Is "revoked with savings" rightly Revoked, and "revoked (prosp.)" rightly not whole?
3. Anything missing from the recompute guard?
