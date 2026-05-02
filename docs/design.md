# Design — Mallcore Sim

## 1. What the game is

A 2000s specialty-retail mall sim. The player manages five stores inside a mall hub. Each store has a distinct signature mechanic layered on top of the shared retail transaction loop. Setting: late 1990s / early 2000s mall — VHS tapes, CRT TVs, trading-card craze, sports collectibles under glass, consumer electronics.

## 2. Player-experience loop

```
Morning open → stock shelves → set/adjust prices → AI customers browse
  → interact: haggle / checkout / store mechanic
→ evening close → day summary
  → optional: spend earnings on fixtures / upgrades
→ next day
```

At cadence: unlock new store, market/seasonal event fires, reputation tier changes.

## 3. Non-negotiables

1. **Legibility before depth** — if the player cannot answer "what can I do now?" in 3 seconds, the screen is broken.
2. **One complete loop before five partial ones** — vertical slice wins over breadth; no new mechanics while `return false` / `return null` stubs exist in active store controllers.
3. **Management hub, not walkable world** — player-controller movement is behind a debug flag only; the mall is navigated by clicking store cards.
4. **Content is data** — stores, items, milestones, and customers are JSON files loaded via `DataLoaderSingleton` into `ContentRegistry`; no hardcoded content in scripts.
5. **No trademarks** — all store names, console names, game titles, team names, athlete names, and flavor text must be original parody; boot-time content validator is the enforcement mechanism.

## 4. Store roster

Display names below match `game/content/stores/store_definitions.json`.
Canonical IDs (used in code, save files, and signals) are the second column.

| Store (display name) | Canonical id | Signature mechanic |
|---|---|---|
| Retro Game Store | `retro_games` | Refurbishment queue: accept → diagnose → repair → relist with condition grade |
| PocketCreatures Card Shop | `pocket_creatures` | Pack opening + meta-shift price swings + tournament scheduling |
| Video Rental | `rentals` | Rental tracking with tape-wear state, overdue detection, late-fee checkout |
| Consumer Electronics | `electronics` | Demo-unit designation + warranty dialog at checkout |
| Sports Memorabilia | `sports` | Multi-state authentication: cost → grading states → partial-information outcome → multiplier |

## 5. Progression model

- **Reputation tiers (4 levels):** gate customer volume and spending budget multipliers. Tier decays to floor 50 if revenue drops.
- **Unlock gates:** new stores, fixtures, and surfaces unlock at day/revenue/reputation thresholds.
- **Constraint:** no new store unlocks until existing active stores have a working signature mechanic (Phase 0 exit criterion).

## 6. Out of scope for 1.0

- Walkable mall world (management hub only)
- Multiplayer
- Procedurally generated store layouts
- Any store beyond the five-store roster
- New mechanics before Phase 0 exit criteria are cleared

## 7. Visual Anti-Patterns (merge-blockers)

See `docs/style/visual-grammar.md` for the full grammar. The following are merge-blocking in any PR touching visual or UI code.

| Anti-pattern | Sign of it | Consequence |
|---|---|---|
| Brown soup | HUD panel tone applied to 3D world materials, or vice versa | Merge-blocker |
| Store accent as body fill | Panel background = CRT Amber; Retro Games wall painted Amber | Merge-blocker |
| Below-18pt body text | New label at 14pt, 16pt, or `font_size = 12` | Merge-blocker |
| Reinvented camera controller | New `class_name StoreOrbitCamera extends Camera3D` | Merge-blocker — reuse `BuildModeCamera` |
| Reinvented outline shader | New `mat_glow_highlight.tres` alongside existing `mat_outline_highlight.tres` | Merge-blocker |
| Art outside palette | `Color(0.6, 0.2, 0.9, 1)` in any `.tres` or `.tscn` | Merge-blocker |
| Parallel prop pipelines | PR adds both `.gltf` imports AND `CSGMesh3D` props for the same fixture | Merge-blocker — PICK ONE |
| Ambient motion stealing input | Camera drift responds to mouse movement or steals focus | Merge-blocker |