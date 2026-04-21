# Code Quality Cleanup Report

Date: 2026-04-19 (updated 2026-04-21)

## Scope

Cleanup pass over `game/autoload/`, `game/scripts/`, and `game/scenes/` GDScript
sources. Excluded: `addons/` (vendored GUT). No behavioral changes were made.

---

## Dead code removed

### `AMBIENT_BUS` alias constant — `game/autoload/audio_manager.gd`

`const AMBIENT_BUS: String = AMBIENCE_BUS` was defined and used only twice
internally in the same file (`_create_players()`). The alias existed to smooth
over an earlier naming inconsistency. All uses now reference `AMBIENCE_BUS`
directly, matching the canonical constant and the AudioServer bus name.

### `_apply_locale()` wrapper — `game/autoload/settings.gd`

A two-line pass-through function that only called `_apply_locale_preference()`.
`apply_settings()` now calls `_apply_locale_preference()` directly. Direct
callers in `_ready()` and `_on_preference_changed()` already bypassed the wrapper.

---

## Files refactored

### `game/autoload/settings.gd` — constant naming

`const settings_path: String` renamed to `const SETTINGS_PATH: String` to match
the `ALL_CAPS_SNAKE` convention used by every other constant in the same file
(`COMMON_RESOLUTIONS`, `REBINDABLE_ACTIONS`, `FONT_SIZE_VALUES`, etc.).
All 7 internal call sites updated.

### `game/autoload/difficulty_system.gd` — constant reference update

5 references to `Settings.settings_path` updated to `Settings.SETTINGS_PATH`
following the rename above.

### `game/autoload/audio_manager.gd` — doc-comment syntax fix

A `##` doc-comment marker was misused as a trailing inline comment inside
`_setup_event_handler()`. GDScript `##` is a declaration doc-comment and should
appear before a declaration, not free-floating inside a function body.
Changed to `#`.

---

## Consistency changes

| File | Change |
|------|--------|
| `game/autoload/settings.gd` | `settings_path` → `SETTINGS_PATH` (ALL_CAPS constant) |
| `game/autoload/difficulty_system.gd` | 5× `Settings.settings_path` → `Settings.SETTINGS_PATH` |
| `game/autoload/audio_manager.gd` | Removed `AMBIENT_BUS` alias; `##` trailing comment → `#` |

---

## Files still over 500 LOC

None split in this pass — each carries justified complexity or needs dedicated
test coverage before safe extraction.

| LOC | File | Status |
|-----|------|--------|
| ~1226 | `game/scenes/world/game_world.gd` | Scene composition root; five-tier init is load-bearing. Split only with full integration coverage. |
| ~1199 | `game/scripts/core/save_manager.gd` | Migration-chain hotspot; split only with per-version isolation tests. |
| ~1050 | `game/autoload/data_loader.gd` | Boot-critical loader; backward-compat API section intentional. |
| ~926 | `game/scripts/content_parser.gd` | Dense JSON-to-resource mapping; candidate for type-specific helper extraction. |
| ~871 | `game/scripts/systems/customer_system.gd` | Candidate for spawn/state helper extraction. |
| ~846 | `game/scripts/systems/inventory_system.gd` | Core state owner; split with inventory regression coverage. |
| ~743 | `game/scripts/systems/order_system.gd` | Multi-responsibility; extract supplier/cart helpers later. |
| ~723 | `game/scripts/systems/ambient_moments_system.gd` | Candidate for scheduler/history helper extraction. |
| ~707 | `game/scripts/characters/shopper_ai.gd` | Candidate for state/behavior helper extraction. |
| ~685 | `game/scripts/stores/video_rental_store_controller.gd` | Candidate for rental/returns helper extraction. |
| ~679 | `game/scripts/world/storefront.gd` | Mixed world-building; extract presentation helpers later. |
| ~667 | `game/autoload/audio_manager.gd` | Core autoload; isolate player-pool helpers in a future pass. |
| ~655 | `game/scripts/systems/checkout_system.gd` | Runtime-critical; split only with checkout regression coverage. |
| ~653 | `game/autoload/settings.gd` | Persistence/wiring hotspot; refactor with settings coverage. |
| ~638 | `game/scripts/systems/secret_thread_system.gd` | Candidate for state-transition helper extraction. |
| ~628 | `game/scripts/characters/customer.gd` | Candidate for movement/state helper extraction. |
| ~627 | `game/scripts/systems/seasonal_event_system.gd` | Candidate for calendar/config helpers. |
| ~611 | `game/scripts/systems/economy_system.gd` | Core state owner; split only with economy regression coverage. |
| ~559 | `game/scripts/systems/build_mode_system.gd` | Candidate for grid normalization and transition helpers. |
| ~557 | `game/scripts/systems/store_state_manager.gd` | Candidate for persistence/query helper extraction. |
| ~545 | `game/scenes/ui/day_summary.gd` | Candidate for section-render helper extraction. |
| ~531 | `game/autoload/staff_manager.gd` | Candidate for scene lookup and data helpers. |
| ~531 | `game/scripts/systems/fixture_placement_system.gd` | Candidate for validation/save helpers. |
| ~527 | `game/scripts/stores/electronics_store_controller.gd` | Dense due to lifecycle + demo + warranty; flagged for follow-up. |
| ~513 | `game/scripts/ui/day_summary_panel.gd` | Candidate for row/formatting helper extraction. |
| ~513 | `game/scripts/characters/customer_animator.gd` | Candidate for per-animation builder helpers. |

---

## Flagged for follow-up (not changed in this pass)

**Duplicate haggle thresholds** — `HaggleSystem` defines `INSULT_MOVE_THRESHOLD`
(0.02) and `CUSTOMER_CONCESSION_THRESHOLD` (0.15) independently of the identical
constants in `HaggleSession`. `HaggleSession.is_insulting_counter()` already
encapsulates the comparison; `HaggleSystem` should delegate to that method rather
than reimplementing the check. Deferred: requires verifying both paths produce
identical results before consolidating.

**`Settings.VOLUME_BUS_MAP` underused** — `VOLUME_BUS_MAP` maps preference keys
to bus names but `_apply_audio()` addresses buses with hardcoded strings,
duplicating the mapping. Consider driving `_apply_audio()` from the map in a
future settings-coverage pass.

---

## Pass 2 — 2026-04-21

### Dead code removed

**Commented compatibility markers — `game/scenes/ui/fixture_catalog.gd`**

27 lines of commented-out variable declarations and method references existed
under a "Compatibility markers for legacy static validators" heading. These
commented fragments served no executable purpose and referenced the now-canonical
`game/scripts/ui/fixture_catalog_panel.gd` implementation. Removed; the one-line
`extends` is self-documenting.

**Commented compatibility markers — `game/scenes/ui/haggle_panel.gd`**

16 lines of the same pattern removed for the same reason. The `extends` line
alone describes the wrapper relationship without noise.

**Deprecated font-size aliases — `game/scripts/ui/ui_theme_constants.gd`**

`FONT_SIZE_HEADER`, `FONT_SIZE_TITLE`, and `FONT_SIZE_SMALL` were declared as
aliases for the canonical `FONT_SIZE_H2`, `FONT_SIZE_H1`, and `FONT_SIZE_CAPTION`
constants with a comment noting they were "kept for call-sites not yet migrated."
A full project search confirmed zero call-sites remain. Removed.

### Consistency changes

**`SLOT_STORE_IDS` rename — `game/scripts/world/mall_hallway.gd` and `game/scenes/world/game_world.gd`**

`var SLOT_STORE_IDS: Array[StringName] = []` used `SCREAMING_SNAKE_CASE` reserved
by convention for `const` declarations. This is a mutable member variable that is
populated in `_ready()` and read externally. Renamed to `slot_store_ids` (7 occurrences
in `mall_hallway.gd`, 1 in `game_world.gd`).

**`print()` → `push_warning()` — `game/scenes/debug/accent_budget_overlay.gd`**

One `print()` call in `_sample_viewport()` replaced with `push_warning()` to
match the diagnostic pattern used throughout the project (`push_error` /
`push_warning`). This was the only `print()` call remaining outside test files.

### Files still over 500 LOC (unchanged from Pass 1)

No additional splits in this pass. The table in Pass 1 remains accurate with
updated line counts in parentheses where drift occurred:

| LOC | File | Note |
|-----|------|------|
| 1302 | `game/scenes/world/game_world.gd` | No change |
| 1286 | `game/scripts/core/save_manager.gd` | No change |
| 1101 | `game/autoload/data_loader.gd` | No change |
| 942 | `game/scripts/content_parser.gd` | No change |
| 886 | `game/scripts/systems/customer_system.gd` | No change |
| 846 | `game/scripts/systems/inventory_system.gd` | No change |

---

## Pass 3 — 2026-04-21

### Dead code removed

**Redundant ordinal annotations — `game/scripts/components/interactable.gd`**

`InteractionType` enum members carried trailing `## 0` through `## 6` comments
annotating their implicit ordinal values. GDScript enums are implicitly numbered
from zero; the annotations added no information and misused `##` (GDScript
doc-comment syntax) as inline trailing comments. Removed all seven.

### Consistency changes

**`InteractionRayScript` rename — `game/scripts/world/mall_hallway.gd`**

Local variable `InteractionRayScript: GDScript` used `PascalCase`, which by
project convention is reserved for `class_name` types. Renamed to
`interaction_ray_script` (2 occurrences — declaration and `.set_script()` call).

**Untyped `result` variable — `game/autoload/audit_overlay.gd`**

`var result = _results.get(key)` lacked a type annotation. `Dictionary.get()`
returns `Variant`; annotated as `var result: Variant` to match the project
convention of typing all non-trivial locals.

### Files still over 500 LOC (unchanged from Pass 2)

No splits in this pass. Table from Pass 2 remains accurate.
