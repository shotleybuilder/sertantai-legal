# Legal Landing - Phase 2 Frontend Auth

**Started**: 2026-02-21
**Continues**: Phase 1 complete (commit 83053c8)

## Todo
- [ ] 2a: Auth guard — redirect unauthenticated users to hub
- [ ] 2b: Electric shape requests — cookie sent automatically (verify)
- [ ] 2c: Handle 401 in Electric sync onError
- [ ] 2d: Root redirect `/` → `/browse`

## Notes
- Phase 1 backend complete: EdDSA/JWKS, LoadFromCookie, all shapes via Gatekeeper
- HttpOnly cookie can't be read from JS — auth guard must infer from API 401 responses
- Electric requests go through Phoenix proxy (same-origin) — cookie sent automatically
