---
session: "Actor dictionary sync and Authorised Person reclass"
status: closed
opened: 2026-09-30
closed: 2026-09-30
outcome: success
related: ["fractalatai#68"]
depends_on: ["drrp/2026-09-30-drrp-spec-68"]

summary: >
  Legal's ActorDictionary had never loaded fractalaw's dictionary: its snapshot was stale
  (92 of 128 labels), it read only the old 'canonical:' key, it gave up on Zenoh at boot,
  and it discarded its subscriber handle so the subscription was undeclared. All fixed; it
  now reloads live from fractalaw's publishes. Spc: Authorised Person became government
  (Jason) on both sides together; fractalaw republished 52 laws and legal re-stamped the
  rest. A guard test keeps ActorDefinitions and the dictionary type in step.

decisions:
  - what: "Spc: Authorised Person is government"
    why: "Every sampled use exercises an enforcing authority's powers (warrants, requirements, entry); matches the Notifying Authority precedent (Jason)"
    result: "Legal 902e193 + fractalaw e5fac38; 328 rows in 63 laws; no verdict changed"
  - what: "Holder class comes from the dictionary type, checked by a test against ActorDefinitions"
    why: "Two hard-coded government sets drift silently"
    result: "actor_dictionary_test fails until both sides agree (it caught the AP flip)"

lessons:
  - title: "Legal's Phoenix hosts the Zenoh listener fractalaw connects to"
    detail: "Restarting mix phx.server mid-publish drops the connection and loses what is sent in the window (44 laws, resent). Check with fractalaw before restarting; verify arrival per law"
    tag: operations
  - title: "Keep Zenohex subscriber handles referenced"
    detail: "A discarded declare_subscriber handle is garbage-collected and undeclares the subscription: 'Subscribed' is logged but nothing arrives"
    tag: zenoh

bugs:
  - pattern: "ActorDictionary read only 'canonical:', so a fractalaw publish (label:/type:) would have emptied the table; government came from category, missing Crown, HM Forces and Notifying Authority"
    category: actor_dictionary
    module: legal/actor_dictionary.ex populate_ets/1
    affected: "whole dictionary (no DRRP impact: roles come from ActorDefinitions)"
    fix: "normalize_entries reads both formats, government from type, empty parse rejected (0e40670)"
    status: fixed
  - pattern: "ActorDictionary skipped Zenoh load and subscription permanently when the session wasn't ready at boot"
    category: actor_dictionary
    module: legal/actor_dictionary.ex init/1
    affected: "every restart"
    fix: "Retry load and subscribe every 5s, each step only until it succeeds (0e40670, ba47514)"
    status: fixed
  - pattern: "ActorDictionary discarded the declare_subscriber handle; the GC'd Zenohex resource undeclared the subscription, so dictionary puts never arrived"
    category: actor_dictionary
    module: legal/actor_dictionary.ex do_subscribe/0
    affected: "all fractalaw dictionary publishes"
    fix: "Keep the handle in GenServer state (2979c12)"
    status: fixed
---

# Session: Actor dictionary sync and Authorised Person reclass (CLOSED)

Split out of `2026-09-27-enrichment-readiness.md` on 2026-09-30.

## Todo

- ✅ Snapshot refreshed from fractalaw (`priv/data/actor-dictionary.yaml`, now fractalaw's file: 128 labels + `match_group`, ignored).
- ✅ Loader, retry and subscriber-handle fixes (see bugs); live reload confirmed ("Reloaded 130 actors from Zenoh publish", twice per publish).
- ✅ Guard test: `ActorDefinitions.government_label?/1` agrees with the dictionary `type` for every label.
- ✅ New labels need no legal change (Gvt: prefix; Ind: default governed).
- ✅ Authorised Person reclass: fractalaw republished 52 laws; `mix drrp.remap` re-stamped 21 + 23 rows (it now covers untyped rows, 937f76c); 511 AP actors all government, 225 active; 5 of 12 stale law-level lists re-rolled, the rest resolved under #68's held laws.
