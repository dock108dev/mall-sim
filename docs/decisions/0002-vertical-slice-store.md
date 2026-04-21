# Decision 0002: Retro Games as the Phase 4 Vertical Slice Store

**Date:** 2026-04-21
**Status:** Accepted
**Supersedes:** `docs/decisions/vertical-slice-anchor.md` (informal note; this is the canonical record)

## Decision

**Retro Games** is the vertical slice store for Phase 4. All other store mechanics
are deferred until the Retro Games end-to-end loop passes the interaction audit.

## Context

The Phase 0 interaction audit (see `tools/interaction_audit.md`) evaluated both
candidate stores — Retro Games and Sports Memorabilia — against the slice
selection framework documented in `docs/research/vertical-slice-store-selection.md`.

Current default starting store (`game_manager.gd:9`) is `&"sports"` (Sports
Memorabilia). Changing it to `&"retro_games"` is a prerequisite for Phase 4.

## Rationale

| Axis | Retro Games | Sports Memorabilia |
|---|---|---|
| Mechanic legibility | Clean / Repair / Restore — one glance, one decision | Grading submits to an offscreen authority; payoff deferred to a later day |
| Feedback latency | Sprite state swap + price delta visible within ~1.5 s | Provenance result arrives asynchronously |
| Content surface | 552-line item catalog; 3-tier condition; store config fully populated | 480-line catalog; sports seasons add a second time-axis to track |
| Controller maturity | `retro_games.gd` (450 lines, 37 functions): testing + refurbishment + save/load all implemented | `sports_memorabilia_controller.gd` (589 lines): authentication + provenance add complexity before first sale is satisfying |
| Audit checkpoint coverage | `refurbishment_completed` already wired in `audit_overlay.gd` | No dedicated checkpoint; grading callback is async |

Sports Memorabilia is technically larger and is the current default store, but
its signature mechanics (authentication + grading) require the player to
understand probability distributions before making a first sale. Retro Games'
refurbishment loop — stock → test → refurbish → price → sell — is teachable in
under 60 seconds and produces unambiguous numeric feedback on every action.

## Consequences

- `DEFAULT_STARTING_STORE` in `game_manager.gd` must be changed from `&"sports"`
  to `&"retro_games"` at the start of Phase 4 (ISSUE-004 or equivalent).
- Pocket Creatures, Video Rental, Electronics, and Sports Cards mechanics are
  deferred until the Retro Games slice passes the full interaction audit (Phase 4
  complete).
- All Retro Games item names must be invented — no Nintendo, Sega, Atari, or Sony
  IP. Content validation at boot enforces this via `validate.yml` banned-terms regex.
- The Sports Memorabilia controller remains in the codebase as Phase 6 work; it
  must not regress during Phase 4 development.
