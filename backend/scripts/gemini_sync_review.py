#!/usr/bin/python3
"""Gemini code review of the Baserow sync pipeline.

Adapted from fractalaw's gemini_code_review.py pattern.
Creates a cached context with the sync source code, then runs
targeted review prompts against it.

Usage:
    source ~/.bashrc
    python3 backend/scripts/gemini_sync_review.py
"""

import os
import sys
import json
import google.genai as genai


def read_file(path):
    with open(path) as f:
        return f.read()


def build_code_context():
    """Assemble all sync-related code into a single context string."""
    base = "backend/lib/sertantai_legal"
    sections = []

    files = [
        (f"{base}/sync/engine.ex", "Engine — sync orchestration (LRT → LAT → Actor Tuples → linking)"),
        (f"{base}/sync/delta_detector.ex", "DeltaDetector — new/updated/deleted row classification"),
        (f"{base}/sync/actor_tuple_sync.ex", "ActorTupleSync — normalised actor↔DRRP tuple table"),
        (f"{base}/sync/providers/baserow.ex", "Baserow provider — API operations, field specs, type mapping"),
        (f"{base}/sync/profile_query.ex", "ProfileQuery — LRT/LAT queries with checkpoint and aggregation"),
        (f"{base}/sync/sync_configuration.ex", "SyncConfiguration — provider config, credentials, policies"),
        (f"{base}/sync/sync_row_mapping.ex", "SyncRowMapping — source_id ↔ external_row_id tracking"),
        (f"{base}/sync/sync_job.ex", "SyncJob — job status, counters, checkpoint"),
        (f"{base}/legal/actor_dictionary.ex", "ActorDictionary — Zenoh-loaded actor vocabulary"),
        ("backend/lib/mix/tasks/sync.run.ex", "mix sync.run — CLI task for manual sync"),
    ]

    for path, label in files:
        try:
            content = read_file(path)
            sections.append(f"## {label}\n\n```elixir\n{content}\n```\n")
        except FileNotFoundError:
            print(f"  Warning: {path} not found, skipping")

    # Include the briefing docs for context
    for path, label in [
        ("backend/data/actor-tag-usage-map.md", "Actor tag usage map — how actor data flows"),
        ("backend/data/fractalaw-actors-struct-migration.md", "Actors struct design — Hohfeldian positions"),
    ]:
        try:
            content = read_file(path)
            sections.append(f"## {label}\n\n{content}\n")
        except FileNotFoundError:
            pass

    return "\n\n".join(sections)


REVIEW_PROMPTS = [
    {
        "id": "delta_sync_correctness",
        "title": "Delta Sync Correctness",
        "prompt": """Review the DeltaDetector module and how Engine.sync_lrt uses it.

Specifically:
1. Is the three-way classification (new/updated/deleted/unchanged) correct? Are there edge cases where a row could be misclassified?
2. The timestamp comparison: source.updated_at > mapping.last_synced_at. What if clocks drift? What if a row is updated but updated_at doesn't change (e.g., only JSONB subfield changed)?
3. When no source_timestamps are provided, all matched rows are treated as "updated" (safe default). Is this the right behaviour for LAT/Actor Tuples which don't have updated_at?
4. The deleted detection: source_id in mappings but not in source. This correctly detects profile-filtered-out laws. But what about laws whose family was removed from the sync profile — should they be deleted or archived?
5. The batch_update path injects "id" (Baserow row ID) into the row map. Is this safe? Could it conflict with a field named "id"?
6. Are there race conditions if two sync runs overlap?"""
    },
    {
        "id": "actor_tuple_model",
        "title": "Actor Tuple Data Model",
        "prompt": """Review the ActorTupleSync module and how it integrates with the sync pipeline.

1. The tuple composite key "actor|position|drrp_type" — is pipe a safe delimiter? Could actor labels contain pipes?
2. The tuple extraction query crosses legal_articles × actors × drrp_types. Is the cross-product correct, or should tuples only be created for (actor, position) pairs that actually occur together with that DRRP type in the same provision?
3. The linking logic (link_lat_to_tuples in engine.ex) queries all LAT provisions and matches against tuples. For large registers (10K+ provisions), is this performant? Should it be batched?
4. Tuples are "governed only" by default (excluding Gvt/EU/Crown). Is this always correct? A government agency managing compliance might want government actor tuples too.
5. The Actor Tuples table has no update path — tuples are created but never updated or deleted on incremental sync. What happens when fractalaw reclassifies an actor's position?
6. The many-to-many link from LAT → Actor Tuples: Baserow handles this natively, but does the link survive when LAT rows are updated (batch_update)? Or does the link need to be re-set?"""
    },
    {
        "id": "baserow_api_robustness",
        "title": "Baserow API Robustness",
        "prompt": """Review the Baserow provider (baserow.ex) for API robustness.

1. Rate limiting: Baserow SaaS has API rate limits. The sync pushes 200 rows per batch. For 2000+ LAT rows that's 10+ API calls in rapid succession. Is there any rate limit handling? Back-off? Retry?
2. The ensure_fields + update_select_options pattern: we list existing fields, then create missing ones, then update options on existing selects. Is this atomic? What if another process modifies fields between list and create?
3. JWT expiry: the JWT is obtained once at sync start. For a 2-minute sync, is there a risk the JWT expires mid-sync?
4. Error handling: batch_create failures halt the entire sync. Should partial failures be handled (e.g., first 5 batches succeed, 6th fails — the first 5 rows exist but aren't tracked in mappings)?
5. The dynamic select options (querying DB for distinct values): this runs SQL queries during field spec generation. If the DB has unexpected values (null, empty string, very long strings), could this break the Baserow API call?
6. The link_row field creation uses direct Req.post instead of going through the provider abstraction. Is this intentional? Should it be part of the provider interface?"""
    },
    {
        "id": "provision_aggregation",
        "title": "Provision Text Aggregation Quality",
        "prompt": """Review the query_lat_aggregated SQL in profile_query.ex.

1. The text rollup uses string_agg with \\n separator and adds blank lines before sub-sections. Does this produce correct formatting for all section_type combinations? What about:
   - Nested paragraphs within sub_articles
   - Schedule provisions
   - Provisions with no text (empty structural nodes)
2. The governed_actors subquery unions actors struct (position=active, canonical) with flat governed_actors (for null-struct provisions). Is the UNION correct? Could it produce duplicates?
3. The duty_sub_type subquery takes the first non-null value by sort_key. Is this the right approach? Could a provision have multiple duty_sub_types across its children?
4. The DRRP filter clause: "EXISTS child with drrp_types && $2". This finds provisions where ANY child has a matching DRRP type. But the aggregated text includes ALL children, not just the matching ones. Is this correct for duty-only filtering?
5. The section_id construction: law_name || ':' || CASE 's.'/'reg.' || provision. This works for UK Acts and SIs. What about EU regulations (art.), Welsh Acts, NI statutory rules?
6. Performance: the query has 4 correlated subqueries per group. For 200+ laws with 30+ provisions each, is this efficient? Would CTEs or window functions be faster?"""
    },
    {
        "id": "architecture_fitness",
        "title": "Architecture Fitness for Production",
        "prompt": """Step back and review the overall sync architecture for production readiness.

1. The sync is currently "full replace" for LAT and Actor Tuples (only LRT has delta). What's the impact of this on a customer who has enriched their Baserow data (notes, actions, evidence linked to LAT rows)?
2. The --clean flag deletes all rows. In production, this should probably require confirmation or be admin-only. What safeguards are missing?
3. The engine runs synchronously in a mix task. For production, should it be an async job (Oban, Task.Supervisor)? What about progress reporting?
4. Error recovery: if the sync fails midway (e.g., after LRT but before LAT), the state is inconsistent. LRT rows exist but LAT links are broken. How should this be handled?
5. Multi-tenant: the engine uses sync_config.organization_id for scoping. Could a misconfigured sync accidentally push one org's data to another org's Baserow?
6. The actor dictionary is loaded from Zenoh on startup. If it's stale or empty (Zenoh down, snapshot old), vocabulary validation warns but doesn't block. Could stale vocabulary cause sync failures later (Baserow rejects unknown select values)?
7. Monitoring: what observability is missing? Should sync runs emit telemetry events? Log structured metrics?"""
    },
]


def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("Error: GEMINI_API_KEY not set. Run: source ~/.bashrc")
        sys.exit(1)

    client = genai.Client(api_key=api_key)

    print("Extracting sync code sections...")
    code_context = build_code_context()
    print(f"Code context: {len(code_context):,} chars (~{len(code_context) // 4:,} tokens)")

    print("Creating Gemini cache...")
    cache = client.caches.create(
        model="gemini-2.5-flash",
        config={
            "display_name": "sertantai-baserow-sync-review",
            "system_instruction": """You are a senior Elixir developer reviewing a Baserow sync pipeline for a legal compliance SaaS platform (SertantAI).

The codebase syncs UK legal register data (laws + duty provisions + actor classifications) from PostgreSQL to Baserow (no-code database). It uses:
- Ash Framework for data layer (Elixir)
- Baserow REST API for target (batch create/update/delete with JWT auth)
- Zenoh P2P mesh for actor dictionary loading
- ElectricSQL for frontend sync (separate from this pipeline)

The sync pipeline: query laws → format for Baserow → detect delta (new/updated/deleted) → push via API → save row mappings → link tables.

Key domain concepts:
- LRT = Legal Register Transport (laws)
- LAT = Legal Articles (duty provisions within laws, aggregated at provision level)
- Actor Tuples = normalised (actor, position, drrp_type) table enabling "Employer Duties" queries
- DRRP = Duties, Rights, Responsibilities, Powers (Hohfeldian legal relations)
- Position = active (bears obligation) / counterparty (holds claim) / beneficiary / mentioned

Focus your review on: correctness, edge cases, production robustness, data integrity, and missed failure modes. Be specific — cite function names, line patterns, and give concrete scenarios. Don't suggest style changes.""",
            "contents": [
                {"role": "user", "parts": [{"text": f"Here is the complete Baserow sync pipeline source code for review:\n\n{code_context}"}]},
                {"role": "model", "parts": [{"text": "I've loaded the Baserow sync pipeline source code including Engine, DeltaDetector, ActorTupleSync, Baserow provider, ProfileQuery, configurations, and supporting modules. Ready for targeted review questions."}]},
            ],
            "ttl": "3600s",
        },
    )

    print(f"Cache created: {cache.name}")
    print(f"Token count: {cache.usage_metadata}")
    print()

    results_dir = "backend/data/code-reviews"
    os.makedirs(results_dir, exist_ok=True)

    for review in REVIEW_PROMPTS:
        print(f"Running review: {review['title']}...")
        try:
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=review["prompt"],
                config={
                    "cached_content": cache.name,
                    "temperature": 0.3,
                    "max_output_tokens": 4096,
                    "thinking_config": {"thinking_budget": 2048},
                },
            )

            result_path = f"{results_dir}/{review['id']}.md"
            with open(result_path, "w") as f:
                f.write(f"# Code Review: {review['title']}\n\n")
                f.write(f"**Model**: Gemini 2.5 Flash (cached context)\n")
                f.write(f"**Date**: 2026-06-11\n")
                f.write(f"**Scope**: sertantai-legal Baserow sync pipeline\n\n")
                f.write(response.text or "(no response)")

            print(f"  → {result_path}")
        except Exception as e:
            print(f"  Error: {e}")

    print(f"\nDone. Review results in {results_dir}/")
    print(f"Cache valid for 1 hour: {cache.name}")


if __name__ == "__main__":
    main()
