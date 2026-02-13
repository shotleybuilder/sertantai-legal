# Auth Integration: JWT Validation + Electric Proxy

**Started**: 2026-02-13
**Issues**: #20 (Electric auth proxy), #18 (3-tier feature gating)

## Todo

### Phase 1: sertantai-auth — Basic JWT issuance (separate project)
- [ ] sertantai-auth issuing JWTs with `sub`, `organization_id`, `services: ["legal"]`
- [ ] `SHARED_TOKEN_SECRET` configured and available to sertantai-legal
- [ ] sertantai-auth deployed to production

### Phase 2: sertantai-legal — JWT validation + Electric proxy (#20)
- [ ] JWT validation plug (verify tokens using `SHARED_TOKEN_SECRET`)
- [ ] Electric proxy controller (`GET /api/electric/v1/shape`)
- [ ] Proxy appends `?secret=ELECTRIC_SECRET` to upstream Electric requests
- [ ] Frontend ELECTRIC_URL updated to `/api/electric`
- [ ] Remove nginx `/electric/` proxy location
- [ ] Production data flowing through authenticated proxy

### Phase 3: sertantai-auth — Tier claims (separate project)
- [ ] Add tier claim to JWTs (`legalTier: blanket_bog | flower_meadow | atlantic_rainforest`)
- [ ] Tier assigned at registration/subscription

### Phase 4: sertantai-legal — Tier gating (#18)
- [ ] Read tier from JWT claims in frontend auth store
- [ ] Feature-gate UI components by tier
- [ ] Electric proxy enforces table access by tier (e.g. free tier = uk_lrt only)

## References
- **SKILL.md**: `.claude/skills/production-deployment/SKILL.md`
- **Electric Auth Guide**: https://electric-sql.com/docs/guides/auth
- **Electric Security Guide**: https://electric-sql.com/docs/guides/security
- **Tier Plan**: `.claude/plans/issue-18-future-tiers-and-views.md`
