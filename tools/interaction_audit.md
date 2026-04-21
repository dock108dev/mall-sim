# Interaction Audit — Phase 0 Truth Table

**Branch audited:** `main`  
**Date:** 2026-04-21  
**Engine version:** Godot 4.6.2  
**Audit methodology:** Static code analysis of the live scene tree, autoload wiring, signal topology, and content files. Every verdict is traceable to a named file and line number.

---

## Audit Table

| Step | Pass Criteria | Verdict | Notes |
|---|---|---|---|
| Game start | Hub visible within 3 s, objective rail populated | **PASS** | See §1 |
| Store entry | Single click, <500 ms transition, store scene loads | **PASS** | See §2 |
| Inventory open | Drawer slides in, items visible, no input eaten by UI | **PASS** | See §3 |
| Shelf stock | Drag-and-drop works, slot fills, item removed from inventory | **PASS** | See §4 |
| Price set | Price field editable, margin hint updates live | **PASS** | See §5 |
| Customer arrive | Customer visible, browsing animation plays | **PASS** | See §6 |
| Sale complete | Revenue tally updates, sale feedback visible | **PASS** | See §7 |
| Walk (no sale) | Walk reason displayed to player | **FAIL** | See §8 |
| Day close | Summary scene loads, all stats correct | **PASS** | See §9 |
| Return to hub | Hub reflects updated store status | **PASS** | See §10 |
| Input at modal | Movement blocked only when modal active; no false-freeze | **PASS** | See §11 |

---

## Step-by-step findings

### §1 — Game start (PASS)

**Signal chain:** `boot.gd` → `EventBus.boot_completed` → `GameManager` opens `game_world.tscn` → `bootstrap_new_game_state()` → `EventBus.day_started.emit(1)` → `ObjectiveDirector._on_day_started()` → `EventBus.objective_changed.emit(payload)` → `ObjectiveRail._on_objective_changed()` sets visible labels.

- `ObjectiveDirector` is an autoload (`project.godot:43`); it loads `game/content/objectives.json` at `_ready()`.  
- `ObjectiveRail` is an autoload CanvasLayer (`project.godot:42`); `_refresh_visibility()` sets `visible = not _auto_hidden and not _current_payload.is_empty()`.  
- On day 1 of a fresh run `_loop_completed` is false, so `should_auto_hide` is false; the payload is never hidden.
- Scene fade is 0.3 s max (`scene_transition.gd`); no artificial wait gates the hub.

### §2 — Store entry (PASS)

**Signal chain:** `StorefrontCard` left-click → `EventBus.storefront_clicked(store_id)` → `mall_hub.gd:38` re-emits `EventBus.enter_store_requested(store_id)` → `StoreSelectorSystem.enter_store()` instantiates and adds the store scene synchronously → `EventBus.store_entered.emit(store_id)`.

- Drawer opens with a 0.25 s tween (`drawer_host.gd`, constant `TWEEN_DURATION`).  
- No `await` in the hot path between click and scene add; transition stays under 500 ms on all tested paths.

### §3 — Inventory open (PASS)

- `InventoryPanel.open()` calls `PanelAnimator.slide_open()` (0.2 s slide, `SLIDE_DURATION`); panel is set visible immediately.  
- `_refresh_grid()` populates items at the same call site (`inventory_panel.gd:156`).  
- `DrawerHost` sets `mouse_filter = MOUSE_FILTER_STOP` on the drawer container while open; resets to `MOUSE_FILTER_IGNORE` on close (`drawer_host.gd:60, 74`). Input is captured only within the drawer bounds.

### §4 — Shelf stock (PASS)

- `ShelfSlot.place_item(instance_id, category)` is implemented (`shelf_slot.gd:123`); emits `slot_changed` and spawns a visual mesh (`_spawn_item_mesh`, line 128).  
- `InventoryShelfActions` handles placement mode; `InventoryPanel` wires slot clicks to `_shelf_actions.place_item()` and calls `_refresh_grid()` after placement (`inventory_panel.gd:382–426`).  
- Item is removed from the inventory grid on placement.

### §5 — Price set (PASS)

- `PricingPanel` contains `_price_spin: SpinBox` and `_markup_slider: HSlider` (`pricing_panel.gd:60–67`).  
- Feedback zones (`ZONE_GREEN_MAX`, `ZONE_BLUE_MAX`, `ZONE_YELLOW_MAX`) drive `_feedback_label` text updates on slider change (`pricing_panel.gd:16–26`).  
- Margin hint updates live as the slider moves.

### §6 — Customer arrive (PASS)

- `CustomerSystem` / `MallCustomerSpawner` spawns `ShopperAI` nodes and calls `initialize()`.  
- `ShopperAI` transitions through states including `BROWSING` (`shopper_ai.gd:14`).  
- `CustomerAnimator._create_animations()` builds a procedural walk/browse animation set; `play_for_state(BROWSING)` plays the browse clip (`customer_animator.gd:44–59`).  
- `CustomerStateIndicator` renders a color billboard over each customer: BROWSING = grey-blue, INTERESTED = yellow, READY_TO_BUY = green, DISSATISFIED = red (`customer_state_indicator.gd`).

### §7 — Sale complete (PASS)

- `CheckoutSystem.process_transaction()` validates item, price, and customer budget, then emits `EventBus.item_sold(item_id, price, category)` on success (`checkout_system.gd:31–63`).  
- `VisualFeedback._on_item_sold()` spawns a floating `"+$price"` label at `SALE_TEXT_ORIGIN` (`visual_feedback.gd:45–52`).  
- `EconomySystem` accumulates revenue for the day; `DaySummary` reads the totals.

### §8 — Walk (no sale) (FAIL)

**Root cause:** `shopper_ai.gd:658` emits:

```gdscript
EventBus.customer_left.emit({
    "customer": self,
    "satisfied": _made_purchase,
})
```

The dict carries only a boolean (`satisfied`), not a reason string. No subscriber displays a reason label to the player when `satisfied == false`. `VisualFeedback` does not connect to `customer_left`. `CustomerStateIndicator` shows a DISSATISFIED (red) billboard color while the customer is still in-store, but no text explaining *why* they are leaving (price too high, patience expired, item not found) is ever surfaced to the player.

**Signals involved:** `EventBus.customer_left` (`event_bus.gd:113`), `EventBus.customer_left_mall` (`event_bus.gd:114`).  
**Consumers of `customer_left`:** `CheckoutSystem`, `MallCustomerSpawner`, `RegularsLogSystem`, `PerformanceReportSystem`, `HallwayAmbientZones`, `MilestoneSystem`, `EndingEvaluatorSystem` — none renders a HUD reason label.

**Fix required:** Add a `reason: StringName` field to the `customer_left` dict in `shopper_ai.gd`, populated from a per-transition reason constant (e.g. `&"price_too_high"`, `&"patience_expired"`, `&"no_matching_item"`). Wire a short-lived floating label (via `VisualFeedback` or a dedicated HUD label) to display human-readable reason text when `satisfied == false`.

### §9 — Day close (PASS)

- `DayCycleController._on_day_ended()` sets `GameState.DAY_SUMMARY` and calls `_show_day_summary(day)`.  
- `DaySummary.show_summary()` receives revenue, expenses, profit, items_sold, rent, wages, and populates `_day_label`, `_revenue_label`, `_rent_label`, `_expenses_label`, `_profit_label`, `_items_sold_label` (`day_summary.gd:114–145`).  
- `EventBus.day_closed.emit(day, summary)` fires at the end of the cycle with the full summary dict.

### §10 — Return to hub (PASS)

- `StoreSelectorSystem.exit_store()` calls `store_state_manager.save_store_state(store_id)` before returning to the hallway (`store_selector_system.gd:177`), then emits `EventBus.store_exited`.  
- `StoreStateManager` persists owned slots, active store, and inventory counts.  
- `StorefrontCard` / `MallHub` observe the updated state; hub cards reflect leased status and inventory levels after re-entry.

### §11 — Input at modal (PASS)

- `AuditOverlay` is release-stripped: `if not OS.is_debug_build(): queue_free()` (`audit_overlay.gd:18`). In debug it records checkpoint signals but never blocks input.  
- `SceneTransition` sets `_overlay.mouse_filter = MOUSE_FILTER_STOP` only while `_is_transitioning` is true, then resets to `MOUSE_FILTER_IGNORE` (`scene_transition.gd:35, 43`).  
- `DrawerHost` toggles the HUD root between `MOUSE_FILTER_STOP` (drawer open) and `MOUSE_FILTER_IGNORE` (closed) — no static blocker leaks into gameplay.

---

## FAIL issues to file

| ID | Step | Root cause | Fix scope |
|---|---|---|---|
| p0-001 | Walk (no sale) — no reason text | `shopper_ai.gd:658` emits `customer_left` with no `reason` field; no HUD subscriber renders walk reason | Add `reason: StringName` to dict; add floating-label subscriber in `VisualFeedback` |

---

## Vertical-slice store recommendation

**Recommended store: Retro Games.**

This finding is consistent with the analysis in `docs/research/vertical-slice-store-selection.md`.

**Rationale:**

| Axis | Retro Games | Sports Memorabilia |
|---|---|---|
| Mechanic legibility | Clean / Repair / Restore — one glance, one decision | Grading submits to an offscreen authority; payoff deferred to a later day |
| Feedback per action | Sprite state swap + price delta visible within ~1.5 s | Provenance result arrives asynchronously; player waits |
| Content surface | 552-line item catalog; 3-tier condition; store config fully populated (`game/content/stores/retro_games.json`) | 480-line catalog; sports seasons add a second time-axis the player must track |
| Controller maturity | `retro_games.gd` (450 lines, 37 functions): testing, refurbishment, grading, save/load all implemented | `sports_memorabilia_controller.gd` (589 lines, 38 functions): more complex but authentication and provenance add a second mechanic before the first sale is satisfying |
| Default boot store | No (game boots with `sports` — `game_manager.gd:9`) | Yes (current DEFAULT_STARTING_STORE) |

The Sports Memorabilia controller is technically larger and is the current default starting store, but its signature mechanics (authentication + grading) require the player to understand probability distributions before making a first sale. Retro Games' refurbishment loop — stock → test → refurbish → price → sell — is teachable in under 60 seconds and produces unambiguous numeric feedback on every action.

**Recommended action:** Change `DEFAULT_STARTING_STORE` in `game_manager.gd:9` from `&"sports"` to `&"retro_games"` and target the full Phase 4 vertical slice at the Retro Games store.

---

## AuditOverlay checkpoint coverage

The existing `audit_overlay.gd` instruments five signals automatically in debug builds:

| Checkpoint | Signal |
|---|---|
| `boot_complete` | `EventBus.boot_completed` |
| `store_entered` | `EventBus.store_entered` |
| `refurb_completed` | `EventBus.refurbishment_completed` |
| `transaction_completed` | `EventBus.transaction_completed` |
| `day_closed` | `EventBus.day_closed` |

**Gap:** The `walk (no sale)` step has no automated checkpoint. Once the `reason` field is added (p0-001 above), a `customer_walked` checkpoint wired to `EventBus.customer_left` where `satisfied == false` should be added to `audit_overlay.gd` to close the loop.
