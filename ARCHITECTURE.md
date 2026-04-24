# Architecture — Mallcore Sim

Full detail: [docs/architecture.md](docs/architecture.md)

## Boot Flow

`game_world.gd` drives a 5-tier init on scene ready:

1. **Tier 1 — Data loading:** `DataLoaderSingleton` reads JSON; `ContentRegistry` builds typed catalogs. Boot-time content validator runs: parody-name check, `type` field, cross-reference.
2. **Tier 2 — Autoload services:** `GameManager`, `AudioManager`, `AudioEventHandler`, `EventBus` confirm ready via `_on_system_ready`.
3. **Tier 3 — Store controllers:** Each controller inits from `ContentRegistry`. Controllers are autoload-adjacent singletons, not scene nodes.
4. **Tier 4 — World systems:** `checkout_system`, `haggle_system`, `inventory_system`, `reputation_system`, day-cycle clock, customer spawner start in dependency order.
5. **Tier 5 — UI layer:** HUD, mall overview, and store entry scenes attach and request `CameraAuthority` slots.

## Autoloads

| Autoload | Purpose | File |
|---|---|---|
| `DataLoaderSingleton` | Reads JSON at boot; exposes raw dicts to `ContentRegistry` | `game/autoload/data_loader_singleton.gd` |
| `ContentRegistry` | Typed catalogs; canonical query surface | `game/autoload/content_registry.gd` |
| `EventBus` | Central signal relay — all cross-system comms; direct cross-node refs are merge-blocked | `game/autoload/event_bus.gd` |
| `GameManager` | Runtime state: current store, day phase, progression flags, reputation tier | `game/autoload/game_manager.gd` |
| `AudioManager` | Audio buses, ambient track scheduling, SFX pool | `game/autoload/audio_manager.gd` |
| `AudioEventHandler` | Translates `EventBus` signals to `AudioManager` — only audio caller | `game/autoload/audio_event_handler.gd` |

## Signal Bus Model

All inter-system communication flows through `EventBus`. Signal prefixes: `store_`, `day_`, `customer_`, `inventory_`, `reputation_`, `progression_`, `ui_`.

## Scene Entry Points

| Scene | Role |
|---|---|
| `game/scenes/main/game_world.tscn` | Root; drives tier init |
| `game/scenes/ui/mall_overview.tscn` | Hub — store cards, per-store KPIs |
| `game/scenes/stores/<name>/<name>.tscn` | Per-store 3D interior |
| `game/scenes/ui/day_summary.tscn` | End-of-day summary |
| `game/scenes/ui/hud.tscn` | Persistent overlay |

Store entry is gated through `StoreDirector.enter_store(store_id)`. The parallel `_on_hub_enter_store_requested` crossfade path is deprecated (ISSUE-009).

## Content-Data Contract

All in-game content (stores, items, milestones, customers) lives in JSON files under `game/data/`. `DataLoaderSingleton` reads them at Tier 1; `ContentRegistry` exposes typed query methods. No content may be hardcoded in scripts.

## Visual Systems

Reuse mandated for: `BuildModeCamera` (orbit/pan/zoom), `CameraAuthority.request_current()` (single-camera assertion), `Interactable.highlight()` + `mat_outline_highlight.tres` (hover shader), `TooltipManager` (delayed tooltip), `PanelAnimator` (modal tweens). New visual controllers without ADR override are merge-blocked.