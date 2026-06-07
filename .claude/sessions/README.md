# Session Index

Sessions grouped by area. Newest first within each group.

## Scraper

LRT scraping from legislation.gov.uk, parsing pipeline, cascade, session management.

| Date | Session | Issue | Summary |
|------|---------|-------|---------|
| 2026-05-15 | [lrt-scrape-session-skill](2026-05-15-lrt-scrape-session-skill.md) | — | /lrt-scrape skill, skip workflow, ~w[] sigil fix, Function calc fixes, Feb 2026 scrape QA+sync |
| 2026-03-10 | [fallback-metadata-research](2026-03-10-fallback-metadata-research.md) | — | Research: fallback metadata sources for older UK laws |
| 2026-03-07 | [issue-43](2026-03-07-issue-43.md) | [#43](https://github.com/shotleybuilder/sertantai-legal/issues/43) | Auto Parse All fails with JSON file enoent on reparse |
| 2026-03-07 | [issue-44](2026-03-07-issue-44.md) | [#44](https://github.com/shotleybuilder/sertantai-legal/issues/44) | Session detail rows don't update after confirm/save |
| 2026-01-27 | [cascade-layer-separation](2026-01-27-cascade-layer-separation.md) | — | Cascade layer separation refactor |
| 2026-01-27 | [cascade-update-form-enhancements](2026-01-27-cascade-update-form-enhancements.md) | — | Cascade update form enhancements |
| 2026-01-24 | [consolidate-stats-affected-by-fields](2026-01-24-consolidate-stats-affected-by-fields.md) | — | Consolidate stats text fields to JSONB |
| 2026-01-22 | [parse-review-modal-refactor](2026-01-22-parse-review-modal-refactor.md) | — | Parse review modal refactor |
| 2026-01-21 | [cascade-parse-endpoint](2026-01-21-cascade-parse-endpoint.md) | — | Separate endpoint for cascade parse management |
| 2026-01-21 | [improved-parsing-feedback](2026-01-21-improved-parsing-feedback.md) | — | Improved parsing feedback UI |
| 2026-01-21 | [issue-6](2026-01-21-issue-6.md) | [#6](https://github.com/shotleybuilder/sertantai-legal/issues/6) | DB table for scrape session records |
| 2026-01-18 | [manual-debug-parser-review](2026-01-18-manual-debug-parser-review.md) | — | Manual debug of parser and review modal |
| 2026-01-16 | [fix-parser-regressions](2026-01-16-fix-parser-regressions.md) | — | Fix parser regressions |
| 2026-01-16 | [implementation-parser-review](2026-01-16-implementation-parser-review.md) | — | Parser review implementation |
| 2026-01-10 | [fix-cascade-parser-errors](2026-01-10-fix-cascade-parser-errors.md) | — | Fix cascade parser errors |
| 2026-01-10 | [scraping-diff-bug-fixes](2026-01-10-scraping-diff-bug-fixes.md) | — | Scraping diff bug fixes |
| 2026-01-08 | [scrape-session-ui-db-flag](2026-01-08-scrape-session-ui-db-flag.md) | — | Scrape session UI + DB flag |
| 2026-01-04 | [scraping-bug-fix](2026-01-04-scraping-bug-fix.md) | — | Scraping bug fix |
| 2026-01-04 | [persisted-count-diff-ui](2026-01-04-persisted-count-diff-ui.md) | — | Persisted count diff UI |
| 2025-12-29 | [scraper-troubleshooting](2025-12-29-scraper-troubleshooting.md) | — | Scraper troubleshooting |
| 2025-12-21 | [legislation-gov-uk-scraper](2025-12-21-legislation-gov-uk-scraper.md) | — | Initial scraper implementation |
| 2025-12-21 | [scraper-ui](2025-12-21-scraper-ui.md) | — | Scraper UI |

## LAT

LAT parsing, sessions, queue, cleanup, taxa classification.

| Date | Session | Issue | Summary |
|------|---------|-------|---------|
| 2026-06-05 | [eu-lat-parsing](2026-06-05-eu-lat-parsing.md) | — | EU LAT parser extension, 24 tests, DRRP enrichment QA, family keywords 24%→96% |
| 2026-06-03 | [lat-parser-fixes-l3-queue](2026-06-03-lat-parser-fixes-l3-queue.md) | [#73](https://github.com/shotleybuilder/sertantai-legal/issues/73), [#88](https://github.com/shotleybuilder/sertantai-legal/issues/88), [#90](https://github.com/shotleybuilder/sertantai-legal/issues/90) | Sort key Roman numeral + position fix, L3 applicability queue filter |
| 2026-06-03 | [onboarding-phase5b-lat-taxa](2026-06-03-onboarding-phase5b-lat-taxa.md) | [#88](https://github.com/shotleybuilder/sertantai-legal/issues/88), [#89](https://github.com/shotleybuilder/sertantai-legal/issues/89), [#90](https://github.com/shotleybuilder/sertantai-legal/issues/90) | LAT taxa schema + ProvisionSubscriber + DataServer fix, end-to-end enrichment proven |
| 2026-04-24 | [issue-77](2026-04-24-issue-77.md) | [#77](https://github.com/shotleybuilder/sertantai-legal/issues/77) | Fix annotation counts — classify refs via Commentaries block lookup |
| 2026-04-24 | [issue-76](2026-04-24-issue-76.md) | [#76](https://github.com/shotleybuilder/sertantai-legal/issues/76) | Inject [Repealed]/[Revoked] markers for empty provisions |
| 2026-04-24 | [issue-75](2026-04-24-issue-75.md) | [#75](https://github.com/shotleybuilder/sertantai-legal/issues/75) | Fix inline element text order — Term, Addition, Substitution, Repeal |
| 2026-04-23 | [issue-70](2026-04-23-issue-70.md) | [#70](https://github.com/shotleybuilder/sertantai-legal/issues/70) | LAT parse audit dashboard at /admin/lat/audit |
| 2026-04-21 | [issue-69](2026-04-21-issue-69.md) | [#69](https://github.com/shotleybuilder/sertantai-legal/issues/69) | Fix Part/Ch/Sch blob duplication + Diagnostics module + mix lat.audit |
| 2026-04-14 | [issue-57](2026-04-14-issue-57.md) | [#57](https://github.com/shotleybuilder/sertantai-legal/issues/57) | Audit: LAT session DB persistence already in place; closed stale issue |
| 2026-04-21 | [lat-queue-bugs](2026-04-14-lat-queue-bugs.md) | — | Reopened: raised gridlite-kit#28 (applyConfig columns) + #29 (grouped view static snapshots) |
| 2026-04-14 | [lat-queue-bugs](2026-04-14-lat-queue-bugs.md) | — | LAT queue: inline edit persistence, duplicates, function display, TanStack DB mutations |
| 2026-03-30 | [issue-58](2026-03-30-issue-58.md) | [#58](https://github.com/shotleybuilder/sertantai-legal/issues/58) | LAT session records missing Family column |
| 2026-03-26 | [issue-56-lat-deletion](2026-03-26-issue-56-lat-deletion.md) | [#56](https://github.com/shotleybuilder/sertantai-legal/issues/56) | Admin option to delete LAT rows for revoked laws |
| 2026-03-23 | [issue-55-lat-queue-bugs](2026-03-23-issue-55-lat-queue-bugs.md) | [#55](https://github.com/shotleybuilder/sertantai-legal/issues/55) | LAT queue shows parsed records + dialog shows 0 eligible |
| 2026-03-08 | [lat-parsing](2026-03-08-lat-parsing.md) | [#48](https://github.com/shotleybuilder/sertantai-legal/issues/48) | LAT parsing session workflow |
| 2026-03-01 | [lat-parsing-ui](2026-03-01-lat-parsing-ui.md) | — | LAT parsing UI and workflow updates |
| 2026-02-23 | [lat-queue](2026-02-23-lat-queue.md) | — | LAT queue page |
| 2026-02-22 | [lat-admin-ui](2026-02-22-lat-admin-ui.md) | — | LAT admin UI |
| 2026-02-22 | [issue-23-lat-table](2026-02-22-issue-23-lat-table.md) | [#23](https://github.com/shotleybuilder/sertantai-legal/issues/23) | LAT table implementation |
| 2026-01-30 | [taxa-review-modal](2026-01-30-taxa-review-modal.md) | — | Taxa review modal enhancement |
| 2026-01-30 | [issue-13](2026-01-30-issue-13.md) | [#13](https://github.com/shotleybuilder/sertantai-legal/issues/13) | Staged parser — parallel taxa execution |
| 2026-01-30 | [frontend-sse-stability](2026-01-30-frontend-sse-stability.md) | — | Frontend SSE stability for large law parsing |
| 2026-01-29 | [issue-10](2026-01-29-issue-10.md) | [#10](https://github.com/shotleybuilder/sertantai-legal/issues/10) | Taxa parser: large law strategy — chunked processing |
| 2026-01-29 | [issue-12](2026-01-29-issue-12.md) | [#12](https://github.com/shotleybuilder/sertantai-legal/issues/12) | Backend cancellation for SSE parse streams |
| 2026-01-29 | [issue-13](2026-01-29-issue-13.md) | [#13](https://github.com/shotleybuilder/sertantai-legal/issues/13) | Parse fails to start after cancel without refresh |
| 2026-01-29 | [enrichment-metrics](2026-01-29-enrichment-metrics.md) | — | Hook up enrichment parser to performance metrics |
| 2026-01-28 | [taxa-parsing-performance](2026-01-28-taxa-parsing-performance.md) | — | Taxa classification parsing performance review |
| 2026-01-28 | [admin-session-management](2026-01-28-admin-session-management.md) | — | Cascade data management — read, update, delete |

## Electric / PGLite / Sync

ElectricSQL, PGLite local store, shape management, data sync service.

| Date | Session | Issue | Summary |
|------|---------|-------|---------|
| 2026-06-06 | [change-plan-phase-cd](2026-06-06-change-plan-phase-cd.md) | — | Phase C: decide→register wiring, grouped view, ChangeNotifier summaries + email stub |
| 2026-06-06 | [change-plan-phase-b](2026-06-06-change-plan-phase-b.md) | — | Change notifications: summary/list/decide endpoints, nav badge, /app/changes review page |
| 2026-06-06 | [change-mgmt-phase-a](2026-06-06-change-mgmt-phase-a.md) | — | Change detection: status changes, new law matching, enrichment hooks, materiality, 18 tests |
| 2026-06-06 | [applicability-audit-trail](2026-06-06-applicability-audit-trail.md) | [#99](https://github.com/shotleybuilder/sertantai-legal/issues/99) | Audit trail: event table, activity feed, undo, match reason explainability |
| 2026-06-06 | [org-model-admin](2026-06-06-org-model-admin.md) | [#105](https://github.com/shotleybuilder/sertantai-legal/issues/105), [#106](https://github.com/shotleybuilder/sertantai-legal/issues/106) | Org model (per-org users), DRRP actor matching, per-user PGLite stores, family filter |
| 2026-06-05 | [applicability-screening-ui](2026-06-05-applicability-screening-ui.md) | #98-#104 | Screening UI: two-panel split, /app layout, stats dashboard, 5 API endpoints |
|------|---------|-------|---------|
| 2026-06-04 | [baserow-polish](2026-06-04-baserow-polish.md) | — | LRT field refinements: Family/Status/Type→single_select, Domain/Region/Fitness→multi_select |
| 2026-06-04 | [goldilocks-model](2026-06-04-goldilocks-model.md) | — | Provision-level LAT aggregation: 748 complete duties vs 1,529 fragments, 853 total Baserow rows |
| 2026-06-03 | [baserow-lat-resync](2026-06-03-baserow-lat-resync.md) | [#91](https://github.com/shotleybuilder/sertantai-legal/issues/91), [#92](https://github.com/shotleybuilder/sertantai-legal/issues/92), [#93](https://github.com/shotleybuilder/sertantai-legal/issues/93), [#94](https://github.com/shotleybuilder/sertantai-legal/issues/94) | Duty-focused LAT schema, DRRP filter, queue refactor, 2491 rows synced, meta-plan design decisions |
| 2026-06-03 | [onboarding-phase5](2026-06-03-onboarding-phase5.md) | [#87](https://github.com/shotleybuilder/sertantai-legal/issues/87) | Multi-select fields, master holder vocabulary, LAT sync with parent links, 729 rows in Baserow |
| 2026-06-03 | [onboarding-phase4](2026-06-03-onboarding-phase4.md) | — | First customer sync: QinetiQ auth org, Baserow JWT auth, 106 L3 laws synced, table preparation |
| 2026-06-02 | [onboarding-phase3](2026-06-02-onboarding-phase3.md) | — | OrgApplicability resource, Enhesa seed, sync engine L3 filter, applicability QA skill |
| 2026-04-11 | [data-sync-phase3-prod-deploy](2026-04-11-data-sync-phase3-prod-deploy.md) | — | Prod deploy, first full sync, admin /admin/sync page |
| 2026-04-11 | [data-sync-phase2](2026-04-11-data-sync-phase2.md) | — | Delta export/import Mix tasks for dev→prod promotion |
| 2026-03-21 | [issue-50-sync-phase1](2026-03-21-issue-50-sync-phase1.md) | [#50](https://github.com/shotleybuilder/sertantai-legal/issues/50) | Sync service Phase 1 |
| 2026-03-19 | [subscription-sync-service-planning](2026-03-19-subscription-sync-service-planning.md) | — | Subscription/sync service foundational planning |
| 2026-03-08 | [issue-46](2026-03-08-issue-46.md) | [#46](https://github.com/shotleybuilder/sertantai-legal/issues/46) | Filter triggers Electric shape deletion (now fixed by architecture change) |
| 2026-03-07 | [issue-42](2026-03-07-issue-42.md) | [#42](https://github.com/shotleybuilder/sertantai-legal/issues/42) | Electric sync 401 — auth token not attached to shapes |
| 2026-03-02 | [issue-40](2026-03-02-issue-40.md) | [#40](https://github.com/shotleybuilder/sertantai-legal/issues/40) | Electric sync fails: relative VITE_ELECTRIC_URL breaks URL |
| 2026-03-02 | [issue-38](2026-03-02-issue-38.md) | [#38](https://github.com/shotleybuilder/sertantai-legal/issues/38) | Migrate to PGLite as local store |
| 2026-01-23 | [fix-electric-sync-browser-crash](2026-01-23-fix-electric-sync-browser-crash.md) | — | Fix ElectricSQL sync browser crash |
| 2026-01-03 | [electricsql-admin-lrt](2026-01-03-electricsql-admin-lrt.md) | — | ElectricSQL migration for /admin/lrt |
| 2026-01-04 | [optimise-electricsql-admin-lrt](2026-01-04-optimise-electricsql-admin-lrt.md) | — | Optimise ElectricSQL admin LRT |

## GridLite / Table Views

GridLite kit, TanStack DB adapter, saved views, table components.

| Date | Session | Issue | Summary |
|------|---------|-------|---------|
| 2026-05-13 | [gridlite-upgrade](2026-05-13-gridlite-upgrade.md) | — | Upgrade gridlite-kit 0.5.1→0.6.1, adapters→0.7.1; raised lib #30 (workspace:^ leak) + #31 (TDZ bug) |
| 2026-03-30 | [issue-68](2026-03-30-issue-68.md) | [#68](https://github.com/shotleybuilder/sertantai-legal/issues/68) | TanStack DB index suggestions + console cleanup |
| 2026-03-30 | [issue-67](2026-03-30-issue-67.md) | [#67](https://github.com/shotleybuilder/sertantai-legal/issues/67) | GridLite groups show (Empty) labels |
| 2026-03-30 | [issue-66](2026-03-30-issue-66.md) | [#66](https://github.com/shotleybuilder/sertantai-legal/issues/66) | Migrate to svelte-gridlite-kit 0.5.0 |
| 2026-03-27 | [issue-61-gridlite-bugs](2026-03-27-issue-61-gridlite-bugs.md) | [#61](https://github.com/shotleybuilder/sertantai-legal/issues/61) | GridLite view sidebar, column resize, grouping, filter bugs |
| 2026-03-14 | [issue-49](2026-03-14-issue-49.md) | [#49](https://github.com/shotleybuilder/sertantai-legal/issues/49) | admin/lrt Function column shows '-' |
| 2026-03-13 | [svelte-gridlite-kit-migration](2026-03-13-svelte-gridlite-kit-migration.md) | — | Migrate svelte-table-kit → svelte-gridlite-kit |
| 2026-03-01 | [lrt-admin-table-views](2026-03-01-lrt-admin-table-views.md) | [#37](https://github.com/shotleybuilder/sertantai-legal/issues/37) | LRT admin: migrate to table views + sidebar |
| 2026-01-07 | [debug-saved-views-svelte-table-kit](2026-01-07-debug-saved-views-svelte-table-kit.md) | — | Debug saved views in svelte-table-kit |
| 2026-01-07 | [debug-filter-admin-lrt](2026-01-07-debug-filter-admin-lrt.md) | — | Debug filter on admin LRT |

## Admin UI

Admin pages, modals, dashboard, record cards, analytics.

| Date | Session | Issue | Summary |
|------|---------|-------|---------|
| 2026-05-04 | [amends-tab](2026-05-04-amends-tab.md) | [#79](https://github.com/shotleybuilder/sertantai-legal/issues/79) | Amends tab: title column, amends-family-qa skill, 💙 family QA via amends consensus |
| 2026-04-24 | [issue-78](2026-04-24-issue-78.md) | [#78](https://github.com/shotleybuilder/sertantai-legal/issues/78) | Reparse from audit, bulk reparse, deep-links, family picker |
| 2026-04-23 | [issue-71](2026-04-23-issue-71.md) | [#71](https://github.com/shotleybuilder/sertantai-legal/issues/71) | /admin/lat Structure tab: outline view with collapse, position ordering, search |
| 2026-03-26 | [issue-54-analytics-fitness-column](2026-03-26-issue-54-analytics-fitness-column.md) | [#54](https://github.com/shotleybuilder/sertantai-legal/issues/54) | Fix analytics page — "fitness" column doesn't exist in PGLite |
| 2026-03-10 | [lrt-record-card](2026-03-10-lrt-record-card.md) | — | LRT record card (back of card) |
| 2026-03-08 | [issue-45](2026-03-08-issue-45.md) | [#45](https://github.com/shotleybuilder/sertantai-legal/issues/45) | Analytics dashboard for reparse sessions |
| 2026-03-08 | [admin-lrt-ui](2026-03-08-admin-lrt-ui.md) | — | Admin LRT UI improvements |
| 2026-03-07 | [ui-improvements](2026-03-07-ui-improvements.md) | — | Iterative UI improvements |
| 2026-03-14 | [lrt-detail-taxa-fitness](2026-03-14-lrt-detail-taxa-fitness.md) | — | Add taxa and fitness to admin LRT detail view |
| 2026-02-23 | [admin-dashboard](2026-02-23-admin-dashboard.md) | — | Admin dashboard |
| 2026-02-02 | [collapsible-sections](2026-02-02-collapsible-sections.md) | — | Collapsible sections for ParseReviewModal |
| 2026-02-02 | [parse-review-modal-field-ordering](2026-02-02-parse-review-modal-field-ordering.md) | — | Fix ParseReviewModal field ordering |
| 2026-01-24 | [parse-review-modal-enhancements](2026-01-24-parse-review-modal-enhancements.md) | — | ParseReviewModal diff-first layout + session-less reparse |
| 2026-01-28 | [issue-11](2026-01-28-issue-11.md) | [#11](https://github.com/shotleybuilder/sertantai-legal/issues/11) | Extensible telemetry and performance metrics |
| 2025-12-29 | [issue-5](2025-12-29-issue-5.md) | [#5](https://github.com/shotleybuilder/sertantai-legal/issues/5) | Admin data view and edit |

## Browse UI

Public browse page, landing experience.

| Date | Session | Issue | Summary |
|------|---------|-------|---------|
| 2026-02-26 | [browse-curation-enforcement](2026-02-26-browse-curation-enforcement.md) | — | Browse curation and enforcement |
| 2026-02-21 | [legal-landing-phase2](2026-02-21-legal-landing-phase2.md) | — | Legal landing — Phase 2 frontend auth |
| 2026-02-19 | [legal-landing](2026-02-19-legal-landing.md) | — | Legal landing experience — auth wiring |
| 2026-02-09 | [issue-19](2026-02-09-issue-19.md) | [#19](https://github.com/shotleybuilder/sertantai-legal/issues/19) | Add global search to browse page |
| 2026-02-05 | [issue-18](2026-02-05-issue-18.md) | [#18](https://github.com/shotleybuilder/sertantai-legal/issues/18) | Blanket Bog browse page |

## Auth

Authentication, OAuth, JWT, admin auth.

| Date | Session | Issue | Summary |
|------|---------|-------|---------|
| 2026-03-01 | [issue-36](2026-03-01-issue-36.md) | [#36](https://github.com/shotleybuilder/sertantai-legal/issues/36) | Electric proxy auth for admin + Playwright testing |
| 2026-02-23 | [github-oauth-admin](2026-02-23-github-oauth-admin.md) | — | GitHub OAuth for admin |
| 2026-02-18 | [proxy-to-gatekeeper](2026-02-18-proxy-to-gatekeeper.md) | — | Proxy to gatekeeper migration |
| 2026-02-18 | [auth-ui](2026-02-18-auth-ui.md) | — | Auth UI for sertantai-hub |
| 2026-02-13 | [auth-integration](2026-02-13-auth-integration.md) | — | JWT validation + Electric proxy |

## Infrastructure

Deployment, Zenoh P2P, production, change notifications.

| Date | Session | Issue | Summary |
|------|---------|-------|---------|
| 2026-04-23 | [issue-72](2026-04-23-issue-72.md) | [#72](https://github.com/shotleybuilder/sertantai-legal/issues/72) | Fix pre-push: Node 25 localStorage, sobelow to_atom, dialyxir OTP 28 crash |
| 2026-04-12 | [nas-backup-family-apps](2026-04-12-nas-backup-family-apps.md) | — | PG 17 upgrade for hub + auth; NAS scripts deferred (no data) |
| 2026-04-12 | [pg17-upgrade](2026-04-12-pg17-upgrade.md) | — | Upgrade dev PG 15→17, rebuild + NAS restore on laptop |
| 2026-04-08 | [nas-data-sync-layer1](2026-04-08-nas-data-sync-layer1.md) | — | NAS data sync Layer 1: SMB mount, export/import scripts, CI fixes |
| 2026-02-27 | [issue-34-change-notifications](2026-02-27-issue-34-change-notifications.md) | [#34](https://github.com/shotleybuilder/sertantai-legal/issues/34) | Wire up ChangeNotifier for sync events |
| 2026-02-27 | [issue-32-33-zenoh-admin-dashboard](2026-02-27-issue-32-33-zenoh-admin-dashboard.md) | [#32](https://github.com/shotleybuilder/sertantai-legal/issues/32), [#33](https://github.com/shotleybuilder/sertantai-legal/issues/33) | Zenoh admin dashboard |
| 2026-02-27 | [issue-31-zenoh-taxa-subscriber](2026-02-27-issue-31-zenoh-taxa-subscriber.md) | [#31](https://github.com/shotleybuilder/sertantai-legal/issues/31) | Zenoh taxa subscriber — receive DRRP from fractalaw |
| 2026-02-27 | [arrow-ipc-format-negotiation](2026-02-27-arrow-ipc-format-negotiation.md) | — | Arrow IPC format negotiation for DataServer |
| 2026-02-26 | [zenoh-p2p-lrt-sharing](2026-02-26-zenoh-p2p-lrt-sharing.md) | — | P2P Zenoh — publish LRT/LAT/amendments to fractalaw |
| 2026-02-26 | [law-change-notifications](2026-02-26-law-change-notifications.md) | — | Law change notifications |
| 2026-02-09 | [production-deployment](2026-02-09-production-deployment.md) | — | Production deployment |

## Data Quality / Schema

Schema alignment, data migration, CSV import, audits, analytics, field consolidation.

| Date | Session | Issue | Summary |
|------|---------|-------|---------|
| 2026-06-05 | [enhesa-quality-report](2026-06-05-enhesa-quality-report.md) | — | Enhesa QA report: 76% precision, 90% recall. customer-quality-report skill created |
| 2026-06-04 | [aggregate-qq-sites](2026-06-04-aggregate-qq-sites.md) | — | All 24 QQ CSVs imported, ~45 misidentified SSIs fixed, 34 laws LAT-parsed, NAS snapshot |
| 2026-06-02 | [onboarding-phase2](2026-06-02-onboarding-phase2.md) | [#84](https://github.com/shotleybuilder/sertantai-legal/issues/84), [#85](https://github.com/shotleybuilder/sertantai-legal/issues/85), [#86](https://github.com/shotleybuilder/sertantai-legal/issues/86) | Customer onboarding Phase 2: fix Auto Parse family assignment, SI code mappings, EU graph-based family inference |
| 2026-05-21 | [phase-2-7-frontend-au-integration](2026-05-20-phase-2-7-frontend-au-integration.md) | — | Phase 2.7: Multi-country frontend — single shape sync, country selector, 20K+ records |
| 2026-05-20 | [phase-2-5-au-state-portal-parsers](2026-05-19-phase-2-5-au-state-portal-parsers.md) | — | Phase 2.5: State enrichment — VIC/NT slugs, NSW feed, QLD tables, ACT client. 544/887 enriched, 99+ repealed |
| 2026-05-19 | [phase-2-4-au-federal-parse-pipeline](2026-05-19-phase-2-4-au-federal-parse-pipeline.md) | — | Phase 2.4: Relationships from Versions API, making_review scoping, FunctionCalculator bug fix |
| 2026-05-19 | [phase-2-3-au-data-qa](2026-05-19-phase-2-3-au-data-qa.md) | — | Phase 2.3: State file jurisdiction fix, federal OData enrichment (143 records), canonical IDs |
| 2026-05-19 | [phase-2-2-au-data-acquisition](2026-05-19-phase-2-2-au-data-acquisition.md) | — | Phase 2.2: AU seed import — 885 records, 98% family coverage, category-aware classification |
| 2026-05-18 | [phase-2-1-au-country-module](2026-05-18-phase-2-1-au-country-module.md) | — | Phase 2.1: Countries.Au module, AU partitions, 16 tests, first multi-country addition |
| 2026-05-18 | [phase-1-6-verification-cleanup](2026-05-18-phase-1-6-verification-cleanup.md) | — | Phase 1.6: Drop _old tables, remove legacy /api/uk-lrt/ routes, Phase 1 complete |
| 2026-05-18 | [phase-1-5-frontend-generalisation](2026-05-18-phase-1-5-frontend-generalisation.md) | — | Phase 1.5: Direct partition sync, /api/laws/ routes, country+source_url in types |
| 2026-05-18 | [phase-1-4-scraper-abstraction](2026-05-18-phase-1-4-scraper-abstraction.md) | — | Phase 1.4: Audit-only — scraper already sound, skipped mass-move, plan updated |
| 2026-05-18 | [phase-1-3-country-module-pattern](2026-05-18-phase-1-3-country-module-pattern.md) | — | Phase 1.3: Countries behaviour + Uk module, all internal UkLrt→LegalRegister refs migrated |
| 2026-05-18 | [phase-1-2-backend-resource-generalisation](2026-05-18-phase-1-2-backend-resource-generalisation.md) | — | Phase 1.2: LegalRegister/LegalArticle resources, API routes, controllers, Electric proxy rewrite |
| 2026-05-18 | [phase-1-1-schema-migration](2026-05-18-phase-1-1-schema-migration.md) | — | Phase 1.1: Partition uk_lrt→legal_register, lat→legal_articles by country, backwards-compat views |
| 2026-05-17 | [australian-ehs-hr-research](2026-05-17-australian-ehs-hr-research.md) | — | Research: AU EHS/HR law expansion, codebase audit, ADR-1 table partitioning, 11-session implementation plan |
| 2026-05-05 | [missing-titles](2026-05-05-missing-titles.md) | [#83](https://github.com/shotleybuilder/sertantai-legal/issues/83) | Fetched 1,546 missing title_en from legislation.gov.uk — zero remaining |
| 2026-05-05 | [family-qa-green](2026-05-05-family-qa-green.md) | [#83](https://github.com/shotleybuilder/sertantai-legal/issues/83) | Family QA all 💚 families: ~260 reclassifications, FINANCE eliminated as primary, 91 titles populated, parser updated |
| 2026-05-04 | [issue-79-enacted-by](2026-05-04-issue-79-enacted-by.md) | [#79](https://github.com/shotleybuilder/sertantai-legal/issues/79) | Enacted By tab: parser fixes, PUBLIC: Data family, family QA across all 💙 families (~60 reclassifications) |
| 2026-05-04 | [issue-82](2026-05-04-issue-82.md) | [#82](https://github.com/shotleybuilder/sertantai-legal/issues/82) | Remove 5 redundant linked_* columns, +45,921 edges from source columns |
| 2026-04-25 | [issue-79](2026-04-25-issue-79.md) | [#79](https://github.com/shotleybuilder/sertantai-legal/issues/79) | law_edges table, Model B family QA, si_code_families, enacted-by-qa skill |
| 2026-04-23 | [issue-74](2026-04-23-issue-74.md) | [#74](https://github.com/shotleybuilder/sertantai-legal/issues/74) | Fix section/sub_section text duplication — same class as #69 |
| 2026-04-23 | [issue-73](2026-04-23-issue-73.md) | [#73](https://github.com/shotleybuilder/sertantai-legal/issues/73) | Fix sort_key: encode full hierarchy, not just provision/paragraph |
| 2026-03-26 | [issue-60-status-parser-bug](2026-03-26-issue-60-status-parser-bug.md) | [#60](https://github.com/shotleybuilder/sertantai-legal/issues/60) | Status parser incorrectly marks in-force laws as revoked |
| 2026-03-12 | [live-status-assurance-metrics](2026-03-12-live-status-assurance-metrics.md) | — | Live status assurance metrics |
| 2026-03-12 | [ohs-data-quality-audit](2026-03-12-ohs-data-quality-audit.md) | — | OH&S data quality audit |
| 2026-03-06 | [issue-39](2026-03-06-issue-39.md) | [#39](https://github.com/shotleybuilder/sertantai-legal/issues/39) | LRT schema extension: 7 fitness/applicability columns |
| 2026-02-02 | [remove-legacy-stats-columns](2026-02-02-remove-legacy-stats-columns.md) | — | Remove legacy stats columns |
| 2026-02-02 | [issue-16](2026-02-02-issue-16.md) | [#16](https://github.com/shotleybuilder/sertantai-legal/issues/16) | Consolidate role article columns into JSONB |
| 2026-02-02 | [issue-15](2026-02-02-issue-15.md) | [#15](https://github.com/shotleybuilder/sertantai-legal/issues/15) | Consolidate POPIMAR article columns into JSONB |
| 2026-01-30 | [issue-14](2026-01-30-issue-14.md) | [#14](https://github.com/shotleybuilder/sertantai-legal/issues/14) | Consolidate holder/article columns into JSONB |
| 2026-01-23 | [split-amend-stages](2026-01-23-split-amend-stages.md) | [#9](https://github.com/shotleybuilder/sertantai-legal/issues/9) | Split amend stages + live reconciliation |
| 2026-01-20 | [issue-7](2026-01-20-issue-7.md) | [#7](https://github.com/shotleybuilder/sertantai-legal/issues/7) | Filter self-references from amendment relationships |
| 2026-01-17 | [split-duty-type-purpose](2026-01-17-split-duty-type-purpose.md) | — | Split duty_type into duty_type and purpose |
| 2026-01-17 | [migrate-airtable-csv-data](2026-01-17-migrate-airtable-csv-data.md) | — | Migrate Airtable CSV data |
| 2026-01-17 | [fix-enacted-by-format](2026-01-17-fix-enacted-by-format.md) | — | Fix enacted_by format |
| 2026-01-17 | [derive-domain-field](2026-01-17-derive-domain-field.md) | — | Derive domain field |
| 2025-12-26 | [issue-4](2025-12-26-issue-4.md) | [#4](https://github.com/shotleybuilder/sertantai-legal/issues/4) | Taxa |
| 2025-12-25 | [issue-3](2025-12-25-issue-3.md) | [#3](https://github.com/shotleybuilder/sertantai-legal/issues/3) | Function field |
| 2025-12-24 | [issue-2](2025-12-24-issue-2.md) | [#2](https://github.com/shotleybuilder/sertantai-legal/issues/2) | Populate enacting field from enacted_by |
| 2025-12-23 | [issue-1](2025-12-23-issue-1.md) | [#1](https://github.com/shotleybuilder/sertantai-legal/issues/1) | Port Amend.workflow() — amendment BFS traversal |
| 2025-12-22 | [schema-alignment](2025-12-22-schema-alignment.md) | — | Schema alignment |

## AI

AI integration, responsibility parsing, DRRP, taxa enrichment.

| Date | Session | Issue | Summary |
|------|---------|-------|---------|
| 2026-06-07 | [actors-consumer-migration](2026-06-07-actors-consumer-migration.md) | [#107](https://github.com/shotleybuilder/sertantai-legal/issues/107) | Migrate consumers to Hohfeldian actors struct (position=active), usage map, log cleanup |
| 2026-06-07 | [fractalaw-actors-migration](2026-06-06-fractalaw-actors-migration.md) | [#107](https://github.com/shotleybuilder/sertantai-legal/issues/107) | Actors struct + extraction_method on LegalArticle, (inferred) cleanup, 4800 provisions populated |
| 2026-06-06 | [auto-screening-build](2026-06-06-auto-screening-build.md) | [#102](https://github.com/shotleybuilder/sertantai-legal/issues/102) | Phase 8a-8d: org profile, scored matching, seed preview, source badges, uncategorized tier |
| 2026-06-05 | [auto-screening](2026-06-05-auto-screening.md) | [#102](https://github.com/shotleybuilder/sertantai-legal/issues/102) | Auto-screening plan: scored matching, 3 external reviews, governance guidelines |
| 2026-02-24 | [taxa-rust-migration-package](2026-02-24-taxa-rust-migration-package.md) | — | Taxa Rust migration package |
| 2026-02-24 | [duty-detection-research](2026-02-24-duty-detection-research.md) | — | Duty detection research |
| 2026-02-24 | [issue-25](2026-02-24-issue-25.md) | [#25](https://github.com/shotleybuilder/sertantai-legal/issues/25) | Issue #25 |
| 2026-02-24 | [issue-24](2026-02-24-issue-24.md) | [#24](https://github.com/shotleybuilder/sertantai-legal/issues/24) | Issue #24 |
| 2026-02-22 | [ai-taxa-integration](2026-02-22-ai-taxa-integration.md) | — | AI taxa (DRRP) integration |
| 2026-02-26 | [lat-record-detail-modal](2026-02-26-lat-record-detail-modal.md) | — | LAT record detail modal |
| 2026-02-03 | [ai-responsibility-parsing](2026-02-03-ai-responsibility-parsing.md) | [#17](https://github.com/shotleybuilder/sertantai-legal/issues/17) | AI-enhanced responsibility parsing |
| 2026-02-02 | [taxa-parser-responsibilities](2026-02-02-taxa-parser-responsibilities.md) | — | Taxa parser responsibilities field analysis |
