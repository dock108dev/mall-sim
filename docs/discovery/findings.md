# Findings

## 1. Player Movement & Input

- Player avatar: `game/scripts/player/store_player_body.gd` (`StorePlayerBody`, `CharacterBody3D`). WASD read in `_physics_process` (~lines 75–92), gated by `InputFocus.current() == &"store_gameplay"` (lines 112–116). Pushes its own context in `_ready()` (line ~57); on failure raises `ErrorBanner` via `_fail_spawn()` (lines 160–168).
- Orbit camera controller: `game/scenes/player/player.gd` (separate from store avatar — handoff unverified).
- Input map (`project.godot` lines 77–192): `move_forward/back/left/right`, `interact` (E), `toggle_inventory` (I), plus a `close_day` action.
- InputFocus autoload: `game/autoload/input_focus.gd` — stack of contexts (`store_gameplay`, `mall_hub`, `modal`, `main_menu`).
- Tests: `tests/unit/test_input_focus.gd`. No integration test for in-store movement.

## 2. Store Visuals & Interactables

- Store scenes: `game/scenes/stores/{retro_games,video_rental,pocket_creatures,electronics,sports_memorabilia}.tscn`. Each contains door/floor/walls/counter/shelves/register fixtures (e.g. retro_games.tscn has 4 shelf fixtures, counter, register zone).
- ShelfSlot: `game/scripts/stores/shelf_slot.gd` (extends `Interactable`, `interaction_type = SHELF_SLOT`). Highlight only active during `_placement_active` (line ~190); Label3D for item data created only via `set_display_data()` (lines 157–169) — not visible by default.
- Interactable base: `game/scripts/components/interactable.gd`.
- StoreController: `game/scripts/stores/store_controller.gd`; registers interactables (line 42); has `current_objective_text` field (line 16).
- Missing: ambient "Press E" floating prompts, register-zone affordance, look-at highlighting.

## 3. Tutorial System

- Two parallel systems:
  - `game/scripts/systems/tutorial_system.gd` — global 9-step FSM (WELCOME, CLICK_STORE, OPEN_INVENTORY, PLACE_ITEM, SET_PRICE, WAIT_FOR_CUSTOMER, CLOSE_DAY, DAY_SUMMARY, FINISHED). Skip via `skip_tutorial()` (line 149). Listens to EventBus signals (`gameplay_ready`, `store_entered`, `panel_opened`, `item_stocked`, `price_set`, `customer_purchased`, `day_close_requested`) at lines 77–103.
  - `game/autoload/tutorial_context_system.gd` — per-store JSON-driven hints from `game/content/tutorial_contexts.json`. Emits `tutorial_context_entered` on store entry (~line 147).
- Overlay UI: `game/scripts/ui/tutorial_overlay.gd` + `game/scenes/ui/tutorial_overlay.tscn`. Bottom-bar CanvasLayer (layer=2). Skip button (line 17) emits `EventBus.skip_tutorial_requested` (line 49).
- Localization keys (e.g. `TUTORIAL_WELCOME`) — fail mode unknown.
- Coordination between the two systems unverified.

## 4. First-Action Affordance

- HUD objective label: `game/scenes/ui/hud.tscn` / `game/scenes/ui/hud.gd` (line 81).
- ObjectiveDirector autoload: `game/autoload/objective_director.gd`.
- Objective rail: `game/scenes/ui/objective_rail.tscn`.
- StoreController exposes `current_objective_text` but no code observed that sets it to "Press I to open inventory" upon store entry.

## 5. Inventory + Shelf + NPC + Money Loop

- Inventory UI: `game/scenes/ui/inventory_panel.tscn` (CanvasLayer). Action wrapper: `game/scripts/ui/inventory_shelf_actions.gd` → `place_item(slot, item, category)` calls `ShelfSlot.place_item(instance_id, category)` (shelf_slot.gd lines 118–126, spawns mesh at lines 193–201).
- NPC visual: `game/scripts/characters/customer_npc.gd` (`CustomerNPC`, states IDLE/BROWSING/APPROACHING_CHECKOUT/WAITING_IN_QUEUE/LEAVING; `send_to_checkout()` at line 77; nav agent in `customer_npc.tscn`).
- NPC AI: `game/scripts/characters/customer.gd`.
- Spawning: `game/scripts/systems/customer_system.gd` (`_update_mall_shoppers()` lines 88–133, density per HOUR_DENSITY 9–21).
- Checkout: `game/autoload/checkout_system.gd::process_transaction(npc)` (lines 20–68) emits `customer_purchased(store_id, item_id, price, customer_id)`.
- Economy: `game/scripts/systems/economy_system.gd::credit(amount, source)` (lines 102–109); HUD updates via `EventBus.money_changed` (hud.gd line 98) with tweened cash label.
- Gap: what triggers `process_transaction` when an NPC reaches a shelf/register is not visible in the scan — appears unwired or hidden in unread checkout/queue code.
- Gap: no link between placed `ShelfSlot` items and the NPC's purchase target / desired item.

## 6. Game State Machine

- `game/autoload/game_state.gd` — pure data (active_store_id, day, money, flags). Explicitly forbids scene/camera/input changes (header comment lines 1–16).
- `game/autoload/game_manager.gd` — FSM: MAIN_MENU, GAMEPLAY, PAUSED, GAME_OVER, LOADING, DAY_SUMMARY, BUILD (lines 14–29). Transitions validated. `is_tutorial_active` flag (line 38). No OVERVIEW vs IN_STORE split; no TUTORIAL state; modal handled via InputFocus stack.
- `game/autoload/scene_router.gd` — sole owner of scene transitions.
- BRAINDUMP's proposed unified `MAIN_MENU/OVERVIEW/IN_STORE/TUTORIAL/MODAL` enum does not exist; current design is layered (GameManager FSM + GameState data + InputFocus stack).

## 7. Boot, Hub, Store Entry

- Boot: `game/scenes/bootstrap/boot.tscn` + `game/scripts/core/boot.gd` (DataLoader.load_all, validation, lines 9–66).
- Main menu: `game/scenes/ui/main_menu.tscn`; "New Game" → `GameManager.start_new_game()` (lines 86–92) → LOADING → GAMEPLAY → mall_hub via SceneRouter.
- Mall hub (overview): `game/scenes/mall/mall_hub.tscn` + `mall_hub.gd`. How storefront-click triggers store-interior load is unverified.
- Game world: `game/scenes/world/game_world.tscn` (systems + stores + customers).
- StoreReadyContract referenced in scan but file/contents not directly read.

## 8. Day Cycle

- `game/scripts/systems/day_cycle_controller.gd` — handles `EventBus.day_close_requested` (line ~125), shows DaySummary panel (lines 133–150), advances via TimeSystem.
- `close_day` input action exists (e.g. F5).
- TimeSystem: `game/scripts/systems/time_system.gd` (phases, advance_to_next_day).

## 9. Debug HUD

- HUD: `game/scenes/ui/hud.tscn` / hud.gd. Cash label (lines 19–24), top bar (time, speed, reputation).
- BRAINDUMP-requested debug counters (Items Placed / Customers / Sales) are not present as a panel; data exists in EconomySystem/CustomerSystem but unrouted to UI.

## 10. Localization

- en/es translation files in `game/assets/localization/`, loaded via project.godot lines 196–197. tr() keys used throughout. Missing-key fallback behavior unverified.

## 11. Tests

- ~50 unit tests under `tests/unit/` (test_input_focus, test_tutorial_system, test_shelf_slot, test_save_manager, etc.).
- Integration tests under `tests/integration/`.
- No end-to-end "Day 1 core loop" test.

## 12. Camera / Authority

- `game/autoload/` may contain a CameraAuthority (referenced in game_state header). Not directly read. Handoff between mall-hub orbit cam and store-interior follow cam unverified.
