# Phase 5 — Final Backlog Report

## Summary

85 issues created across 6 waves and 6 milestones. Local issue archive complete. Machine manifests created. Planning universe is now closed.

## Issue Counts

### By Wave

| Wave | Name | Count |
|---|---|---|
| wave-1 | Foundation + First Playable | 20 |
| wave-2 | Core Loop Depth | 22 |
| wave-3 | Progression + Content Expansion | 18 |
| wave-4 | Polish + Replayability | 10 |
| wave-5 | Store Mechanics + Completion | 8 |
| wave-6 | Secret Thread | 7 |
| **Total** | | **85** |

### By Milestone

| Milestone | Count |
|---|---|
| M1 Foundation + First Playable | 20 |
| M2 Core Loop Depth | 22 |
| M3 Progression + Content Expansion | 18 |
| M4 Polish + Replayability | 10 |
| M5 Store Expansion | 6 |
| M6 Long-tail + Secret Thread | 9 |
| **Total** | **85** |

### By Store / System Area

| Area | Count | Notes |
|---|---|---|
| Core gameplay systems | 25 | Inventory, economy, time, customers, interaction |
| UI / UX | 12 | HUD, panels, menus, tooltips, accessibility |
| Sports store | 5 | Content, store def, customers, authentication |
| Retro games store | 4 | Deep dive, implementation, content, refurbishment |
| Video rental store | 4 | Deep dive, implementation, content, rental lifecycle |
| PocketCreatures store | 4 | Deep dive, implementation, content, pack opening |
| Electronics store | 4 | Deep dive, implementation, content, depreciation |
| Design docs | 7 | Sports, content scale, customer AI, events, economy, progression, UI, mall |
| Content / data pipeline | 5 | Validation, templates, CI, content sets |
| Tooling / debug | 2 | Debug console, validation script |
| Production / QA | 5 | Save/load, exports, performance, QA, polish |
| Progression / completion | 4 | Unlocks, milestones, 30-hr tracking, completion |
| Secret thread | 7 | State tracking, clues, delivery, escalation, endings, validation |

### Issue Types

| Type | Count |
|---|---|
| Implementation (code) | 48 |
| Design docs | 8 |
| Content creation | 7 |
| Tooling | 5 |
| UI implementation | 10 |
| Production / QA | 7 |

## What Stayed in Docs (Not Issues)

These topics are covered by authoritative repo docs and do NOT have corresponding GitHub issues:

- Game pillars (`GAME_PILLARS.md`) — constraints, not tasks
- Core loop design (`CORE_LOOP.md`) — describes what the loop IS, not how to build it
- Architecture decisions (`ARCHITECTURE.md`, `SYSTEM_OVERVIEW.md`) — reference, not work items
- Art direction (`ART_DIRECTION.md`) — guidelines, not production tasks (until art production begins)
- Asset pipeline (`ASSET_PIPELINE.md`) — process doc
- Naming conventions (`NAMING_CONVENTIONS.md`) — reference
- Save system design (`SAVE_SYSTEM_PLAN.md`) — spec doc; implementation is issue 026
- Build targets (`BUILD_TARGETS.md`) — spec doc; implementation is issue 070
- Risk registry (`RISKS.md`) — tracking doc
- Secret thread framework (`SECRET_THREAD.md`) — scope doc; implementation is issues 079-085
- Planning orchestrator docs — internal tooling

## What Is Intentionally Deferred But Represented

These areas are represented by issues in later waves/milestones but are explicitly not first-wave work:

| Area | Issue(s) | Wave | Why Deferred |
|---|---|---|---|
| Mall environment | 049, 058 | wave-3 | Needs multiple stores to matter |
| Build mode | 047, 048 | wave-3 | Needs basic store working first |
| Staff hiring | 064 | wave-4 | Late-game feature |
| Tutorial | 065 | wave-4 | Needs all core systems first |
| Accessibility | 066 | wave-4 | Polish phase |
| Secret thread | 079-085 | wave-6 | Non-critical, needs core systems |
| Performance pass | 069 | wave-4 | Needs enough systems to profile |
| Export builds | 070 | wave-4 | Needs playable game first |
| 3-5 playthroughs QA | 078 | wave-5 | Needs near-complete game |

## GitHub Upload Status

**Not uploaded.** GitHub CLI auth is not configured in this environment. The complete local archive exists at `docs/production/github-issues/` with 85 issue files, INDEX.md, DEPENDENCY_MAP.md, and WAVE_PLAN.md. All machine manifests exist at `planning/manifests/`. Upload can be performed by:

1. Authenticating with `gh auth login`
2. Creating milestones: `gh api repos/dock108dev/mall-sim/milestones -f title="M1 Foundation + First Playable"` (repeat for each)
3. Creating labels: `gh label create "store:sports" --color EDEDED` (repeat for each)
4. Creating issues from each file: parse the markdown and use `gh issue create`

Alternatively, a script can be written to batch-upload from `final-issue-universe.json`.

## Universe Closure Confirmation

The planning universe is now **closed**. The `closed-universe-freeze.json` manifest defines:

- 85 issues included
- 6 milestones included
- 6 waves included
- 7 allowed artifact classes (code, content, docs, tests, builds, bugs, doc updates)
- 7 prohibited actions (no new issues, tracks, milestones, scope expansion)
- 7 allowed modifications (update existing, mark progress, split sub-tasks, close with rationale)
- Exception process for genuinely missing workstreams

The next phase should be able to operate entirely within this universe.
