# Mallcore Sim — Architecture

## Overview

2D Godot 4.6.2 retail simulator. Players manage five specialty stores in a 2000s-era mall across a day cycle: stock → price → sell → close → summary. GDScript throughout. All content lives as validated JSON under `game/content/`.

The spine of the UI is a **clickable management hub with ambient walkable flavor** (Mall Tycoon 2002 pattern). The hub is the only long-lived gameplay scene; store mechanics live inside slide-out drawers over the hub, not in separate scenes.

## Autoload Tiers (16 singletons)

Godot fires autoloads in declaration order in `project.godot`. Our singletons form five tiers; no tier-N singleton may reference a tier-(N+1) singleton at init time.

| Tier | Autoload | Role |
|------|----------|------|
| 1 — Data | `DataLoader` | Reads every file under `game/content/` into raw dicts. |
| 1 — Data | `ContentRegistry` | Two-pass validation (parse + schema, then cross-reference). Crashes loud on failure. |
| 2 — Core | `EventBus` | Central signal bus. Only permitted cross-system channel. |
| 2 — Core | `GameManager` | Owns day number, active store, day-cycle state machine. |
| 2 — Core | `Settings` | Persists player preferences; read by UI + Audio. |
| 3 — Systems | `AudioManager` | Music/SFX; crossfades on drawer open. |
| 3 — Systems | `StaffManager` | Assignments and wages across stores. |
| 3 — Systems | `ReputationSystem` | Per-store reputation; feeds PriceResolver. |
| 3 — Systems | `DifficultySystem` | Traffic + price-sensitivity modifiers. |
| 3 — Systems | `UnlockSystem` | Progression-gated feature unlocks. |
| 3 — Systems | `CheckoutSystem` | Processes sales; emits `item_sold` with full `PriceBreakdown`. |
| 3 — Systems | `MarketTrendSystem` | Active trends; PriceResolver trend multiplier. |
| 4 — Presentation | `EnvironmentManager` | Lighting + environment per store. |
| 4 — Presentation | `CameraManager` | Camera framing; drawer-open push-in. |
| 4 — Presentation | `OnboardingSystem` | Tutorial flows; writes to `ObjectiveStrip`. |
| 4 — Presentation | `TooltipManager` | Tooltip lifecycle; no overlapping popups. |
| 5 — Boot | `boot.gd` | Final content-integrity pass; transitions to main menu or error screen. |

## Boot Sequence

```
Tier 1  DataLoader → ContentRegistry        # content loaded + validated
Tier 2  EventBus → GameManager → Settings    # bus up, state machine ready
Tier 3  Systems wire to EventBus             # no direct node refs
Tier 4  Presentation layer ready             # camera, tooltips, onboarding
Tier 5  boot.tscn                            # final sanity check → main menu
```

If `ContentRegistry.validate_all()` returns errors, boot switches to `ValidationErrorScreen.tscn` with the full error list (not just the first failure). The game never loads with silently skipped content.

## Content Validation (two-pass)

**Pass 1 — Parse + Schema.** Every JSON file under `game/content/` is parsed with line/column error capture. Each record is checked against a schema in `content_schema.gd`. Missing required fields are fatal; unknown fields are warnings.

**Pass 2 — Cross-Reference.** Builds an ID registry per content type (items, events, milestones, triggers, threads). Then:
- Duplicate IDs → fatal.
- Every reference (`target_id`, `trigger_ids[]`, `precondition_ids[]`) must resolve.
- Prerequisite graphs are DFS-checked for cycles.
- Reachability pass flags orphan content (not fatal; warning).

Pass 2 errors surface all at once on the error screen; designers fix a batch per boot, not one per boot.

## PriceResolver Multiplier Chain

Every price calculation routes through `PriceResolver.resolve(item_id, context) -> PriceBreakdown`. No other code computes final prices. Eleven ordered multipliers, compound (multiplicative) except market events (additive within the category, then applied multiplicatively).

| Order | Multiplier | Source | Range |
|-------|-----------|--------|-------|
| 10 | Difficulty | `DifficultySystem` | 1.00–1.40 |
| 20 | Condition | Item state | 0.10–1.35 |
| 30 | Authenticity | `AuthenticationSystem` | 0.05–1.30 |
| 40 | Warranty / Provenance | `WarrantyManager` | 0.90–1.20 |
| 50 | Lifecycle | Content metadata | 0.55–1.35 |
| 60 | Reputation | `ReputationSystem` | 0.70–1.40 |
| 70 | Trend | `MarketTrendSystem` | 0.65–1.35 |
| 80 | Seasonal | `SeasonCycleSystem` | 0.80–1.25 |
| 90 | Market Event | `RandomEventSystem` | 0.50–2.50 |
| 100 | Meta Shift | `MetaShiftSystem` | 1.00 → peak |
| 110 | Random Variance | Seeded RNG | ±20 % |

**Determinism.** Variance is seeded by `hash(item_id + tick)`. Same item, same tick = same price. Safe for save/load and replay.

**Floor.** Final price is clamped to ≥2 % of base to prevent zero/negative prices.

**Audit trace.** `PriceBreakdown` is a `Dictionary` with one entry per multiplier: `{factor, label, detail, skipped}`. Skipped multipliers appear with `factor=1.0, skipped=true` so the player sees what was considered. The debug overlay renders the breakdown as a horizontal bar chart with per-bar tooltips.

## EventBus Signal Model

Cross-system communication is signals only. Direct node refs (`get_node("/root/…")`) between systems are banned.

Past-tense naming convention:

| Signal | Publisher | Payload |
|--------|-----------|---------|
| `item_sold` | `CheckoutSystem` | `(store_id, item_id, final_price, breakdown)` |
| `day_closed` | `GameManager` | `(day_number, summary)` |
| `day_started` | `GameManager` | `(day_number)` |
| `haggle_resolved` | `HaggleSystem` | `(accepted, offer, counter)` |
| `reputation_changed` | `ReputationSystem` | `(store_id, delta, new_value)` |
| `trend_activated` | `MarketTrendSystem` | `(trend_id, affected_tags)` |
| `event_triggered` | `RandomEventSystem` | `(event_id, effect_dict)` |
| `season_changed` | `SeasonCycleSystem` | `(old_season, new_season)` |
| `milestone_reached` | `ProgressionSystem` | `(milestone_id)` |
| `storefront_clicked` | `StorefrontCard` | `(store_id)` |
| `drawer_opened` / `drawer_closed` | `DrawerHost` | `(store_id)` |
| `objective_changed` | `ObjectiveDirector` | `(payload: {objective, action, key, hint})` |

## UI Architecture: Hub + Drawer

The mall hub (`game/scenes/mall/mall_hub.tscn`) is the persistent root gameplay scene.

- **Hub:** top-down diorama. Five `StorefrontCard` nodes, one per store. Each card is an `Area2D` + sub-viewport showing an idle diorama of the frontage (stock bar, reputation pips, ambient customers).
- **DrawerHost:** a single `CanvasLayer` that hosts slide-out store UIs. Tween-driven (`custom_minimum_size.x`), not `AnimationPlayer`. `MOUSE_FILTER_STOP` on the drawer, `MOUSE_FILTER_IGNORE` on root HUD so clicks reach the world when the drawer is closed.
- **ObjectiveStrip:** `CanvasLayer` autoload, layer 10, top-right, three slots (objective / next action / key hint). Content from `objectives.json`. Auto-hides after day 3.
- **DaySummaryPanel:** modal light-panel dialog launched on `day_closed`. Always names one "story beat" even on zero-revenue days.
- **No player avatar, no walkable-world store scenes.** Walkable ambience is decorative customer sprites in the hub only.

## Store Controller Hierarchy

Each store has **exactly one** controller extending `StoreController` (`game/scripts/stores/store_controller.gd`). Parallel controllers are a structural bug.

| Store | Controller | Signature Mechanic |
|-------|-----------|--------------------|
| Retro Games | `RetroGamesController` | Refurbishment (Clean / Repair / Restore) |
| Pocket Creatures | `PocketCreaturesStoreController` | Pack opening + meta shifts + tournaments |
| Video Rental | `VideoRentalStoreController` | New-release premium + late fees |
| Electronics | `ElectronicsStoreController` | Warranty upsell + demo units |
| Sports Cards | `SportsMemorabiliaController` | Multi-tier grading (PSA-style 1–10) |

Controllers never compute prices directly; they call `PriceResolver.resolve()` and hand off to `CheckoutSystem`. They never emit `item_sold` themselves — only `CheckoutSystem` does.

## Save File Versioning

`SaveManager` (`game/scripts/core/save_manager.gd`) owns persistence.

- Save includes `save_version: int` and `written_by_game_version: string`.
- Each version bump ships a pure `dict → dict` migration function (`migrate_vN_to_vN1`) registered in a `MIGRATIONS` dict. Load runs the chain in order.
- **Atomic writes:** write to `<path>.tmp`, verify, then rename. Mid-write corruption never clobbers a good save.
- **Content ID renames** are encoded in migrations via explicit alias tables.
- **Fixtures:** `testdata/saves/vNN_<description>.json` per version bump. Each migration has an isolated unit test; one integration test loads the oldest fixture through the full chain.

Bump when: field removed/renamed/type-changed, new required field without a sensible default, collection structure changes, content ID canonicalization. Do not bump for new optional fields or pure refactors.

## Content Layout

```
game/content/
  audio_registry.json
  customers/                 # archetypes + recurring minor characters
  economy/                   # base prices, supplier tiers
  endings/                   # ending condition descriptors
  events/                    # random + seasonal events
  fixtures.json              # fixture catalog
  haggle_dialogue.json
  items/                     # per-store item definitions
  localization/
  market_trends_catalog.json
  meta/                      # difficulty + unlock config
  meta_shifts.json           # Pocket Creatures meta rotations
  objectives.json            # ObjectiveStrip payloads
  onboarding/
  pocket_creatures_cards.json
  progression/               # milestone trees
  staff/
  stores/                    # per-store config + inventory seeds
  suppliers/
  tutorial_steps.json
  unlocks/
  upgrades.json
```

## Directory Tree

```
mall-sim/
  project.godot
  game/
    autoload/                # 16 singletons (tier order)
    content/                 # canonical JSON
    scenes/
      bootstrap/             # boot.tscn — entry
      mall/                  # mall_hub.tscn — persistent root
      ui/                    # ActionDrawer, ObjectiveStrip, DaySummaryPanel
      stores/                # one drawer scene per store
    scripts/
      core/                  # boot, save_manager, content_schema, constants
      stores/                # store controllers (one per store)
      systems/               # day cycle, customer sim, haggle, events, etc.
      ui/                    # UI component scripts
      debug/                 # AuditOverlay + debug console
  tests/
    run_tests.sh             # headless GUT runner
    audit_run.sh             # interaction audit runner
    gut/                     # GUT tests
  testdata/
    saves/                   # versioned migration fixtures
  docs/
    research/                # research (read-only, do not re-request)
    audits/                  # generated per-commit audit tables
    decisions/               # written decisions for gate moments
    archive/                 # retired scenes/scripts
  exports/                   # build output (gitignored)
```

## Testing Architecture

Three layers, all headless:

1. **Content integrity (GUT, parameterized).** Iterates every record in `ContentRegistry`; asserts required keys, type, and cross-ref resolution. Fails a record, not the suite.
2. **Signal-chain integration.** Instantiates a store controller, invokes a method, asserts a fixed sequence of `EventBus` signals with `watch_signals`.
3. **Interaction audit.** `tests/audit_run.sh` boots the game headless, injects synthetic input, parses `[AUDIT]` lines into a PASS/FAIL table. CI fails on any FAIL.

Excluded from automated testing: Godot engine internals, shader output, anything requiring a display server.
