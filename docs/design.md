# Design — Mallcore Sim

## 1. What the game is

A 2000s specialty-retail sim. The player runs a single small store inside a
mall: stock shelves, set prices, ring up customers at the register, and close
the day to settle wages and rent. Setting: late 1990s / early 2000s mall —
CRT TVs, used cartridges, paper price tags, and the mid-day phone-call event.

The shipping store is **Retro Game Store** (canonical id `retro_games`). The
beta strip-to-bones cut removed the four legacy stores (sports memorabilia,
video rental, pocket creatures, consumer electronics) along with their
scenes, controllers, item catalogs, customer pools, and per-store systems.

## 2. Player-experience loop

```
Morning open → stock shelves → set/adjust prices → AI customers browse
  → interact: haggle / checkout / store mechanic
→ midday event (decision card)
→ evening close → day summary
  → optional: spend earnings on fixtures / upgrades
→ next day
```

At cadence: market/seasonal events fire, reputation tier changes, and the
`StoreCustomizationSystem` allows daily featured-display and poster choices.

## 3. Non-negotiables

1. **Legibility before depth** — if the player cannot answer "what can I do now?" in 3 seconds, the screen is broken.
2. **One complete loop before adding more** — vertical slice wins over breadth; no new mechanics while `return false` / `return null` stubs exist in active store controllers.
3. **Card-based hub, first-person store interior.** The shipping flow is hub mode (`debug/walkable_mall = false` in `project.godot`): on a new run, `GameWorld._auto_enter_default_store_in_hub` emits `EventBus.enter_store_requested(GameManager.DEFAULT_STARTING_STORE)` and `StoreDirector` injects the store under `StoreContainer`. Inside the store, the player walks the interior in first person via `StorePlayerBody` (`game/scripts/player/store_player_body.gd`). The orbit overhead camera (`PlayerController` in `game/scripts/player/player_controller.gd`) is a debug-only view toggled by `toggle_debug_camera` (F1). Setting `debug/walkable_mall = true` opts into the unfinished walkable `mall_hallway.tscn` variant.
4. **Content is data** — stores, items, milestones, and customers are JSON files loaded via `DataLoaderSingleton` into `ContentRegistry`; no hardcoded content in scripts.
5. **No trademarks** — all store names, console names, game titles, team names, athlete names, and flavor text must be original parody. The `content-originality` CI job (`.github/workflows/validate.yml`) and `scripts/validate_originality.sh` are the enforcement mechanisms.

## 4. Store roster

Single shipping store, defined in
`game/content/stores/store_definitions.json`. Canonical IDs (used in code,
save files, and signals) match the `id` field in that file.

| Store (display name) | Canonical id | Signature mechanic |
|---|---|---|
| Retro Game Store | `retro_games` | Refurbishment queue and testing station: accept → diagnose → repair → relist with condition grade |

`GameManager.DEFAULT_STARTING_STORE` is `&"retro_games"`; this is the store
the hub auto-enters on a new run.

## 5. Progression model

- **Reputation tiers (4 levels):** gate customer volume and spending budget multipliers. Tier decays to floor 50 if revenue drops.
- **Unlock gates:** fixtures, surfaces, and difficulty thresholds unlock at day/revenue/reputation thresholds.
- **Constraint:** no new mechanics ship until the existing store's signature mechanic has a working end-to-end loop.

## 6. Out of scope for 1.0

- Walkable mall world (hub-mode only is the shipping flow)
- Multiplayer
- Procedurally generated store layouts
- Any second store beyond `retro_games`
- New mechanics before the shipping store's signature loop is end-to-end

## 7. Visual Anti-Patterns (merge-blockers)

See `docs/style/visual-grammar.md` for the full grammar. The following are
merge-blocking in any PR touching visual or UI code.

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
