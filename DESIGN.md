# Design — Mallcore Sim

Full detail: [docs/design.md](docs/design.md)

## What the game is

A 2000s specialty-retail mall sim. The player manages five stores inside a mall hub. Each store has a distinct signature mechanic layered on the shared retail transaction loop. Setting: late 1990s / early 2000s — VHS tapes, CRT TVs, trading-card craze, sports collectibles under glass, consumer electronics.

## Player-experience loop

```
Morning open → stock shelves → set/adjust prices → AI customers browse
  → interact: haggle / checkout / store mechanic
→ evening close → day summary
  → optional: spend earnings on fixtures / upgrades
→ next day
```

At cadence: unlock new store, market/seasonal event fires, reputation tier changes.

## Non-negotiables

1. **Legibility before depth** — if the player cannot answer "what can I do now?" in 3 seconds, the screen is broken.
2. **One complete loop before five partial ones** — no new mechanics while `return false` / `return null` stubs exist in active store controllers.
3. **Management hub, not walkable world** — player-controller movement is behind a debug flag only.
4. **Content is data** — stores, items, milestones, and customers are JSON loaded via `DataLoaderSingleton` into `ContentRegistry`; no hardcoded content in scripts.
5. **No trademarks** — all names must be original parody; boot-time content validator enforces this.

## Store roster

| Store | Signature mechanic |
|---|---|
| Retro Game Vault | Refurbishment queue: accept → diagnose → repair → relist with condition grade |
| Pocket Creatures | Pack opening + meta-shift price swings + tournament scheduling |
| Video Rental Depot | Rental tracking with tape-wear state, overdue detection, late-fee checkout |
| Digital Horizons | Demo-unit designation + warranty dialog at checkout |
| Stadium Relics | Multi-state authentication: cost → grading states → partial-information outcome → multiplier |

## Progression model

- **Reputation tiers (4):** gate customer volume and spending budget multipliers. Tier decays to floor 50 if revenue drops.
- **Unlock gates:** new stores, fixtures, surfaces unlock at day/revenue/reputation thresholds.
- **Constraint:** no new store unlocks until all active stores have a working signature mechanic (Phase 0 exit criterion).

## Out of scope for 1.0

Walkable mall world, multiplayer, procedurally generated layouts, stores beyond the five-store roster, new mechanics before Phase 0 exit criteria are cleared.

## Visual anti-patterns (merge-blockers)

Brown soup (HUD tone on 3D materials), store accent as body fill, below-18pt body text, reinvented camera controller, reinvented outline shader, art outside palette, parallel prop pipelines, ambient motion stealing input. See `docs/style/visual-grammar.md`.