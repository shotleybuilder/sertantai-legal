# Zoom-out review: docs/CHANGE-IDENTITY-DESIGN.md (reviewer subagent, 2026-10-28)

1. **Major: pointers are already stored, and `:markup :cited` already decides a value.**
   - `Store` writes every claim (store.ex:60-73): `markup cited` 7,228 rows, `markup affecting` 6,296.
   - `Evidence` takes `by` from `{:markup, :cited}` as the last fallback (evidence.ex:115).
   - The design said pointers are never stored, and its text-parsed citation would widen a note-derived `by`.
   - Fix: state today's behaviour, and either exclude pointer claims or record why a note-derived `by` is acceptable.
2. **Major: new logic lands in modules already over size, and no module boundary is named.**
   - `Merge` is 330 lines, `Readers.Markup` 484, `Readers.Feed` 518.
   - Fix: name the boundaries (copy grouping and partner choice as pure modules, `Merge` as orchestrator), and say where the URI-id parse goes.
3. **Major: step 5 ("else the first stage") conflicts with the kept `same_day?` filter.**
   - `same_day?` (merge.ex:305-310) drops every candidate whose feed date differs.
   - Staged rows carry keys `id@date` with their own dates.
   - Fix: make the date match pick the stage without excluding the effect, or drop the clause.
4. **Nit: `:feed :heading` overlaps the heading-as-words classification** (`@words_level`, readers/feed.ex:509).
   - Fix: say why level can't tell body from heading, or reuse it.
