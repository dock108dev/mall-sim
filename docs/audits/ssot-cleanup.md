# SSOT Cleanup Audit

## Diff-Driven Deletion Summary

1. **Removed runtime store-state shadow writes into `GameManager`.**
   `StoreStateManager` no longer syncs `active_store_id` or owned stores into `GameManager`, and runtime callers now resolve store identity through `StoreStateManager` via `GameManager.get_active_store_id()` / `GameManager.get_owned_store_ids()`.

2. **Deleted legacy save/load fallbacks that bypassed `StoreStateManager`.**
   `SaveManager` no longer falls back to `GameManager.current_store_id`, `GameManager.owned_stores`, legacy `metadata`, legacy `store_type`, `_apply_loaded_owned_stores()`, `_restore_owned_slots_with_fallback()`, or `_migrate_legacy_owned_store_array()`.

3. **Removed tests that only preserved deleted compatibility behavior.**
   Save-manager coverage was updated to seed canonical store state through `StoreStateManager`, and the unit test that validated legacy v0 `metadata/store_type` + `owned_stores` migration was deleted.

4. **Deleted the GameManager-owned-store mutation path.**
   `GameManager.own_store()` is gone; ownership registration now happens only through `StoreStateManager.owned_slots`.

## SSOT Verification

| Domain | Authoritative module | Notes |
| --- | --- | --- |
| Active store identity | `StoreStateManager.active_store_id` | Runtime reads now use `GameManager.get_active_store_id()` as a read-through helper only. |
| Owned stores / storefront ownership | `StoreStateManager.owned_slots` | Ordered store lists now come from `StoreStateManager.get_owned_store_ids()`. |
| Save/load store restoration | `SaveManager` + `StoreStateManager.restore_owned_slots()` | Save files restore canonical slot ownership first, then set the active store. |
| Save metadata preview store | `save_metadata.active_store_id` | Legacy `metadata.store_type` fallback was removed. |
| Current day | `TimeSystem.current_day` | Unchanged in this pass; still exposed through `GameManager.get_current_day()` as a read-through legacy helper. |

## Risk Log

1. **Retained legacy `GameManager.current_store_id` and `GameManager.owned_stores` fields.**
   They remain in the autoload as compatibility shims for older tests, but production code no longer uses them as a source of truth.

2. **Retained v0 save migration shell.**
   Version migration still exists, but it now normalizes into `save_metadata.active_store_id` + `owned_slots` and drops legacy `metadata` / `store_type` on migration.

## Sanity Check

- No code references remain to deleted symbols: `GameManager.own_store`, `_apply_loaded_owned_stores`, `_restore_owned_slots_with_fallback`, `_migrate_legacy_owned_store_array`.
- Runtime code no longer reads `GameManager.current_store_id` or `GameManager.owned_stores`; those references are now confined to legacy tests.
- Focused regression slice passed:
  `res://tests/unit/test_save_manager.gd`, `res://tests/gut/test_save_manager.gd`, `res://game/tests/test_store_state_system.gd`, `res://tests/unit/test_store_selector_system.gd`, `res://tests/gut/test_economy_system.gd`.
