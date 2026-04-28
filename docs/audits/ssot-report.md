# SSOT Enforcement Report — 2026-04-27

Scope: all modified and new files on `main` as of the pass date.
Method: read each modified file, identify dead write-only state, duplicate
tracking, and zero-production-caller APIs; act or justify.

---

## Diff-Prioritized Deletions

### 1 — `game/autoload/difficulty_system.gd`: `_assisted` tracking state removed

| Symbol | Type | Reason |
|---|---|---|
| `_assisted: bool` | private field | write-only; only readable via `is_assisted()`, which has zero production callers |
| `_initialized: bool` | private field | write-only after the `_assisted` guard block was removed; no other reader existed |
| `is_assisted() -> bool` | public method | zero callers outside test files; not wired to any gameplay system or UI |
| Block in `set_tier()`: `if _initialized and _is_lower_tier(tier_id)` | code block | existed solely to set `_assisted = true`; removed with the flag |

**SSOT replacement:** `DifficultySystemSingleton.used_difficulty_downgrade` is the
canonical "player downgraded difficulty" flag. It is set by `pause_menu.gd`,
persisted through `save_manager.gd`, read by `save_load_panel.gd`,
`ending_screen.gd`, and `ending_evaluator.gd`. The `_assisted` flag was a
shadow that duplicated this responsibility without connecting to save/load.

**Test cleanup (matching deletions):**

| File | Removed |
|---|---|
| `tests/unit/test_difficulty_system.gd` | `test_is_assisted_false_on_fresh_instance`, `test_is_assisted_true_after_downgrade_to_easier_tier_on_day_greater_than_one`, `# --- Assisted mode ---` section header |
| `tests/gut/test_difficulty_system.gd` | `test_is_assisted_false_on_fresh_game` |
| `tests/gut/test_save_manager.gd` | `_saved_difficulty_assisted: bool`, `_saved_difficulty_initialized: bool`, their save/restore in `before_each`/`after_each`, and the manual `_assisted = false` / `_initialized = true` assignments in `_configure_difficulty` |

---

## Final SSOT Modules Per Domain

| Domain | SSOT |
|---|---|
| Difficulty tier selection and persistence | `DifficultySystem` (`game/autoload/difficulty_system.gd`) |
| "Player used assisted mode" flag | `DifficultySystemSingleton.used_difficulty_downgrade` (public field) |
| Scene transitions | `SceneRouter` autoload — sole caller of `change_scene_to_*` |
| Store ready declaration | `StoreDirector` autoload |
| Save schema version | `SaveManager.CURRENT_SAVE_VERSION` + `_get_migration_step()` registry |
| Content loading | `DataLoaderSingleton` + `ContentRegistry` |
| Input modal stack | `InputFocus` autoload |

---

## Risk Log: Intentionally Retained Legacy Code

### R1 — `save_manager.gd`: duplicate metadata keys

`_collect_save_data()` writes both `"day"` and `"day_number"` (same value),
and three timestamp keys: `"saved_at"`, `"last_saved_at"`, `"timestamp"` (all
the same `Time.get_datetime_string_from_system(true)` call).

**Why retained:** All six keys are actively read in production:

- `"day"` → `save_load_panel.gd:212` (slot card display)
- `"day_number"` → `save_load_panel.gd:222`, `main_menu.gd:279`
- `"timestamp"` → `save_load_panel.gd:223`, `main_menu.gd:232,280`
- `"saved_at"` → fallback source for `"last_saved_at"` normalization at `save_manager.gd:1291`
- `"last_saved_at"` → `test_save_manager_issue_117.gd:93`

Removing any of these requires a `CURRENT_SAVE_VERSION` bump and a new
migration step per the policy in the `SaveManager` class docstring. That is a
schema change requiring its own PR and fixture files — out of scope for a
destructive cleanup pass. Retained as-is.

### R2 — `data_loader.gd:398–406`: heuristic `event_config` routing

`_build_resource()` routes `content_type = "event_config"` via `source_path`
substring matching (`"seasonal"` → `parse_seasonal_event`, `"random"` →
`parse_random_event`, default → `parse_market_event`).

**Why retained:** The three event types share the `"event_config"` alias in
content JSON files. An in-code comment on line 399 documents the design
intent. The routing is stable (tied to directory names `seasonal/`,
`random/`) and has no known test failures. Reworking this would require
adding a `"subtype"` field to all event config files — a content-schema
change. Retained.

### R3 — `difficulty_system.gd`: dual config-load path

`_load_config()` calls `DataLoaderSingleton.get_difficulty_config()` first,
then falls back to `DataLoader.load_json(DIFFICULTY_CONFIG_PATH)` if the
result is empty.

**Why retained:** The static fallback exists so isolated unit tests that do
not boot the full autoload stack can still exercise the difficulty system.
Both load the same file; the fallback is never triggered in a running game.
Retained — documented design choice with no production ambiguity.

---

## Escalations

None. All findings were either acted on or justified above.

---

## Sanity Check

```
grep -rn "is_assisted\(\)\|_assisted\b\|_initialized\b" game/ tests/ --include="*.gd"
```

Expected result after this pass: zero hits for `is_assisted()` and
`_assisted` in game/; zero direct-field access to `_initialized` (the
variable no longer exists). The `"assisted"` string in UI and test files
(`_assisted_label`, `test_assisted_badge_*`, `_on_assisted_canceled`) refers
to the `used_difficulty_downgrade` save-metadata flag and is unaffected.
