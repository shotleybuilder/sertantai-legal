# Title: Law change notification subscriptions (free tier)

**Started**: 2026-02-26

## Todo
- [x] Architectural decision: sertantai-legal vs sertantai-hub ownership
- [x] Decide notification vehicles (email, in-app, webhook)
- [x] Design subscription filter model
- [x] Design change detection mechanism
- [x] Create GH issue on sertantai-hub#9 (subscriptions, matching, delivery)
- [x] Create GH issue on sertantai-legal#30 (HubNotifier webhook)
- [x] Implement HubNotifier module (#30)
- [x] Wire into scraper pipeline
- [x] Add configuration (dev/runtime)
- [x] Build and verify (1110 tests, 0 failures)

## Decisions
- sertantai-legal detects changes (already does), signals hub via webhook
- sertantai-hub owns subscriptions, matching, and delivery (like auth)
- Notification phases: email → in-app → webhooks/Slack
- Free tier: 3 subscriptions, daily digest, email only
- HubNotifier is fire-and-forget (Task.Supervisor), doesn't block scraper

## Key Files
- `lib/sertantai_legal/scraper/persister.ex` — integration point
- `lib/sertantai_legal/zenoh/change_notifier.ex` — parallel pattern to follow
- `lib/sertantai_legal/integrations/hub_notifier.ex` — new module

**Ended**: 2026-02-27
**Committed**: 627f96a
