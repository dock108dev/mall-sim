# SSOT Cleanup Audit — 2026-04-17

## Diff-Driven Deletion Summary

No `main...HEAD` diff was available for this pass, so the cleanup was driven from the live runtime graph, `ARCHITECTURE.md`, and current code references.

| Removed path | Why it was deleted |
|---|---|
| `game/scripts/systems/ordering_system.gd` | Legacy parallel ordering path. `OrderSystem` is the active stock-order owner in `game_world.tscn` and save/load. Keeping both preserved duplicate ordering state and supplier-tier behavior. |
| `game/scenes/world/game_world.tscn` `OrderingSystem` node | Runtime instantiated both `OrderSystem` and `OrderingSystem`. The duplicate node kept a superseded order pipeline alive. |
| `game/scenes/world/game_world.gd` `ordering_system` wiring | Deleted initialization and SaveManager wiring for the removed legacy system. |
| `game/scripts/core/save_manager.gd` `OrderingSystem` serialization hooks | Current saves no longer write or read the removed `ordering_system` payload. |
| `game/scripts/world/mall_geometry_builder.gd` | Unreferenced world-builder helper that still created its own `WorldEnvironment`, conflicting with the single `EnvironmentManager` authority. |
| `tests/integration/test_supplier_tier_unlock.gd` | Validated removed `OrderingSystem` behavior rather than the active `OrderSystem` path. |
| `tests/integration/test_milestone_supplier_tier_unlock_chain.gd` | Same removed behavior; deleted with the legacy runtime path. |
| `game/scripts/systems/store_state_manager.gd` `get_setup_fee_for_owned_store_count()` | Unused compatibility wrapper for count-as-slot semantics. `get_setup_fee_for_slot_index()` is the direct API. |
| `game/scenes/ui/order_panel.gd` legacy comment marker | Removed stale comment referencing the deleted `ordering_system` symbol. |
| `game/scripts/core/save_manager.gd` top-level `metadata` write | New saves now write only `save_metadata`; the duplicate top-level metadata block was a legacy compatibility artifact. |

## SSOT Verification

| Domain | Authoritative module |
|---|---|
| Current day | `TimeSystem.current_day` |
| Active store | `StoreStateManager.active_store_id` |
| Owned storefronts | `StoreStateManager.owned_slots` |
| Active camera | `CameraManager.active_camera` via `EventBus.active_camera_changed` |
| World environment | `EnvironmentManager` |
| Stock ordering | `OrderSystem` |
| Supplier tier rules | `SupplierTierSystem` static utility, consumed by `OrderSystem` and milestone signals |

Additional cleanup applied to enforce those owners:

1. `CustomerSystem` no longer falls back to `get_viewport().get_camera_3d()`; it uses `CameraManager` only.
2. `OrderSystem` now tracks the active store from `EventBus.active_store_changed` instead of falling back to `GameManager.current_store_id`.
3. `docs/architecture.md` was updated to document `OrderSystem`, not the deleted `OrderingSystem`.

## Risk Log

| Retained legacy | Why it was kept |
|---|---|
| `GameManager.current_day` | Still acts as a read-through compatibility surface over `TimeSystem`. It is widespread enough that deleting it safely requires a larger refactor. |
| `GameManager.current_store_id` and `GameManager.owned_stores` shadows | Still have broad fanout across runtime and tests. They remain the largest unresolved SSOT violation from this pass. |
| Save migration helpers in `SaveManager` | Old-format load paths still exist. Backward compatibility is no longer a goal, but those branches were not removed in this edit set because they are tangled with broader save/load coverage. |
| Historical issue docs under `docs/production/github-issues/` and research notes | They still mention `OrderingSystem`, but they are historical planning artifacts, not live runtime documentation or code. |

## Sanity Check

Runtime and test references to deleted symbols were cleared:

| Symbol | Status |
|---|---|
| `OrderingSystem` / `ordering_system` in `game/` and `tests/` | 0 references |
| `MallGeometryBuilder` / `mall_geometry_builder` in `game/` and `tests/` | 0 references |
| `game_world.tscn` duplicate ordering node | removed |
| Save payload key `ordering_system` from current writes | removed |
| `docs/architecture.md` live architecture reference | updated to `OrderSystem` |

Historical issue docs still mention `OrderingSystem` as archived planning context and are intentionally retained.
