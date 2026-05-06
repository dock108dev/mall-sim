# Retro Games Interactable Matrix

Canonical inventory of every Day-1 interactable shipped in
`game/scenes/stores/retro_games.tscn`. Use this matrix to verify that each
"Press E" prompt either drives a real controller response, surfaces an
intentional informational label, or stays disabled until the corresponding
flow lands.

## How interaction wiring works

- **Interactable layer.** `Interactable._ready` zeroes the wrapper's own
  `collision_layer`/`collision_mask` and reparents authored `CollisionShape3D`
  children under a synthetic `InteractionArea` child on layer 16. The
  player's `interaction_ray.gd` casts from the screen centre with
  `interaction_mask = 16` and `ray_distance = 2.5` m, so walls (layer 1) and
  store-fixture bodies (layer 2) never occlude an interactable that sits
  behind them in depth.
- **Trigger geometry.** Each row lists the authored `BoxShape3D` size used
  for the InteractionArea hit volume (the same dimensions appear in the
  `Trigger shape (W×H×D m)` column). The shared `slot_collision` resource is
  used by every shelf slot — it is sized so a slot trigger touches but does
  not overlap its tightest in-scene neighbour spacing (ConsoleShelf at
  0.30 m).
- **Day-1 handler status.** `wired` means a controller signal listener
  exists and produces a visible response (panel, notification, state
  transition). `informational` means the wrapper is enabled but ships with
  an empty `prompt_text` so `interaction_ray._build_action_label` renders a
  context label without a `Press E` cue. `disabled` means
  `enabled = false` is set on the scene node, which short-circuits both
  hover focus and the dispatch path inside `Interactable.interact`.

## Matrix — pre-existing Day-1 interactables

| # | Scene node path | Display name | Prompt text | Action verb | Interaction type (layer, mask) | Trigger shape (W×H×D m) | Required distance | Day-1 enabled | Day-1 handler | State | Test coverage | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `EntranceDoor/Interactable` | Glass Door | `Exit to Mall` | `Exit to Mall` | STOREFRONT (5) (16, 0) | 2.8 × 3.0 × 0.8 | ≈0.2 m from `entrance_marker` | true | `retro_games.gd::_on_entrance_door_interacted` — unlocks cursor and routes `GameManager` to `MALL_OVERVIEW` | active | `tests/gut/test_retro_games_zone_completeness.gd`; cross-store transition coverage in `tests/gut/test_*store*.gd` | Trigger volume offset 0.4 m inward from the door plane so the prompt fires before the player reaches the physical glass. |
| 2 | `checkout_counter/Interactable` | `Customer` (default) / `No customer waiting` (disabled-reason) | `Ring up customer` | `Interact` (default) | REGISTER (1) (16, 0) | 1.9 × 1.5 × 0.7 | ≈0.65 m from `QueueMarker1` | true | `RegisterInteractable.interact` — fires the Day-1 first-sale path on E-press when the head-of-queue customer is parked at the register; falls through to PlayerCheckout's panel for Day 2+ | active | `tests/gut/test_retro_games_checkout_prompt_state.gd`, `tests/gut/test_register_interactable.gd` | The wrapper's script is now `RegisterInteractable`, which gates `can_interact()` on a head-of-queue customer parked at the counter. The legacy `Checkout/Register` Interactable inside the same fixture ships `enabled = false` and is documented under row 2a below. |
| 2a | `Checkout/Register` | Cash Register | `Checkout` | `Interact` (default) | REGISTER (1) (16, 0) | 0.6 × 0.45 × 0.45 | n/a — disabled | false | none | disabled | — | Same fixture as row 2; kept disabled so its prompt never overlaps the active `checkout_counter/Interactable`. Re-enable only if the manual checkout flow ships and overrides the auto-complete path. |
| 3 | `CartRackLeft/Slot1`–`Slot10` | Cartridge Slot | `""` (driven by `ShelfSlot._refresh_prompt_state`) | `Stock` | SHELF_SLOT (0) (16, 0) | 0.3 × 0.3 × 0.3 (per slot) | ≈0.55 m from rack body face | true (10× slots) | `ShelfSlot.interact` + `retro_games.gd::_on_slot_changed` price/label refresh | active | `tests/unit/test_shelf_slot.gd`; `tests/gut/test_retro_games_*stocking*.gd` | Slots auto-route prompt copy through `ShelfSlot._refresh_prompt_state` (empty/full/placement-mode states). The empty-ghost child renders intentional empty stock so the slot reads from FP eye height before placement mode opens. |
| 4 | `CartRackRight/Slot1`–`Slot10` | Cartridge Slot | `""` | `Stock` | SHELF_SLOT (0) (16, 0) | 0.3 × 0.3 × 0.3 (per slot) | ≈0.55 m from rack body face | true (10× slots) | same as row 3 | active | same as row 3 | Mirror of row 3 on the +X side. |
| 5 | `GlassCase/Slot1`–`Slot6` | Display Case Slot | `""` | `Stock` | SHELF_SLOT (0) (16, 0) | 0.3 × 0.3 × 0.3 (per slot) | ≈0.65 m from case face (player walks to the centre island) | true (6× slots) | same as row 3 plus `accepted_category = "cartridges"` filter via `ShelfSlot.accepts_category` | active | `tests/gut/test_retro_games_fixture_geometry.gd::test_glass_case_slots_rest_on_case_top` | The case body uses `mat_glass_display.tres` (alpha 0.6+ verified by `test_glass_case_material_is_visible_from_overhead`). Slot triggers along Z (depth 0.3 m) just touch on the back-row pair — `intersect_ray` selects the closer one. |
| 6 | `ConsoleShelf/Slot1`–`Slot4` | Console Slot | `""` | `Stock` | SHELF_SLOT (0) (16, 0) | 0.3 × 0.3 × 0.3 (per slot) | ≈0.45 m from shelf face | true (4× slots) | same as row 3 (`slot_size = "large"`) | active | `tests/gut/test_retro_games_fixture_geometry.gd::test_console_shelf_*` | Tightest neighbour spacing in the store at 0.30 m on X — slot triggers touch but do not overlap; raycast picks the nearest one. |
| 7 | `AccessoriesBin/Slot1`–`Slot5` | Accessory Slot | `""` | `Stock` | SHELF_SLOT (0) (16, 0) | 0.3 × 0.3 × 0.3 (per slot) | ≈0.5 m from bin face | true (5× slots) | same as row 3 | active | accessories-rack coverage in zone-completeness tests | The bin is rotated 90° so its long axis runs along Z; trigger size remains a cube. |
| 7a | `Checkout/ImpulseSlot1`–`ImpulseSlot3` | Impulse Slot / Impulse Item | `""` | `Stock` | SHELF_SLOT (0) (16, 0) | 0.3 × 0.3 × 0.3 (per slot) | ≈0.55 m from queue marker | true (3× slots) | same as row 3 (`slot_size = "small"`) | active | `tests/gut/test_retro_games_*stocking*.gd` | Front-of-counter impulse slots; carried under the Checkout fixture. |
| 8 | `testing_station/Interactable` | Testing Station | `Coming Soon` | `Interact` (default) | ITEM (2) (16, 0) | 1.4 × 0.8 × 0.6 | n/a — disabled | false | none — testing flow not yet wired | disabled | `tests/gut/test_retro_games_zone_completeness.gd` (presence) | Visual zone (CRT prop, neon panels, `Coming Soon` Label3D) lives under the sibling `crt_demo_area` and stays visible so the parked feature reads as deliberate scenery. |
| 9 | `refurb_bench/Interactable` | Refurbishment Bench | `Refurbish Gear` | `Interact` (default) | BACKROOM (3) (16, 0) | 1.6 × 0.9 × 0.7 | n/a — quarantined | scene-level `true`, runtime `false` on Day 1 via `_apply_day1_quarantine` | none | quarantined Day 1 | `tests/gut/test_retro_games_*quarantine*.gd` | `RetroGames._apply_day1_quarantine` toggles the parent's `visible` and the wrapper's `enabled` on Day 1. **Day 2+ leak:** quarantine releases on day ≥ 2 (and in debug builds), so the bench shows `Press E to View Refurbish Gear` with no listener until the refurb flow is wired through `RefurbishmentSystem.start_refurbishment`. Track as a follow-up before exposing Day 2 gameplay. |
| 10 | `delivery_manifest/Interactable` | Delivery Manifest | `Examine Manifest` | `Examine` | ITEM (2) (16, 0) | 0.6 × 0.5 × 0.5 | ≈0.4 m from front-counter approach | true | `retro_games.gd::_on_delivery_manifest_examined` — emits `EventBus.delivery_manifest_examined` once per day | active | manifest exam coverage in zone-completeness suite | First-day "look at the order list" ritual. |
| 11 | `featured_display/Interactable` | Featured Display | `Update Featured` | `Update` | ITEM (2) (16, 0) | 1.0 × 0.85 × 0.6 | ≈0.45 m from front display | true | `retro_games.gd::_on_featured_display_interacted` — cycles `StoreCustomizationSystem.cycle_featured_category` and posts a notification | active | featured-display coverage in zone-completeness + customization suites | Falls back to a notification when `StoreCustomizationSystem` is unreachable (test seam). |
| 12 | `release_notes_clipboard/Interactable` | Release Notes Clipboard | `Read Release Notes` | `Read` | ITEM (2) (16, 0) | 0.5 × 0.4 × 0.5 | ≈0.5 m from queue side of the counter | true | `retro_games.gd::_on_release_notes_clipboard_interacted` — emits a `notification_requested` flavour line | active | zone-completeness suite | Pre-open-ritual flavour; today the response is a single notification. |
| 13 | `poster_slot/Interactable` | Poster Slot | `Change Poster` | `Change` | ITEM (2) (16, 0) | 0.7 × 1.0 × 0.3 | ≈0.4 m from entrance pillar | true | `retro_games.gd::_on_poster_slot_interacted` — calls `StoreCustomizationSystem.cycle_poster` and posts a notification | active | zone-completeness suite | Poster cycling is the entry-side customization ritual. |
| 14 | `hold_shelf/Interactable` | Hold Shelf | `Review Holds` | `Review` | ITEM (2) (16, 0) | 1.4 × 0.4 × 0.32 | ≈0.5 m from register-side approach | true | `RetroGamesHolds.on_hold_shelf_interacted` (wired via `_wire_zone_artifacts`) | active | holds-list coverage under retro-games-specific suites | Wall-mounted near the register; the trigger spans into the right wall but the wall sits on layer 1 and does not occlude the layer-16 ray. |
| 15 | `back_room/back_room_damaged_bin/Interactable` | Damaged Bin | `Inspect Damaged Items` | `Inspect` | RETURNS_BIN (6) (16, 0) | 0.9 × 0.55 × 0.65 | n/a — disabled | false (this audit added `enabled = false`) | none | disabled | `tests/gut/test_retro_games_zone_completeness.gd` (presence) | The damaged bin currently exists as an inventory location tag (`InventorySystem.DAMAGED_BIN_LOCATION = "back_room_damaged_bin"`) for returned defective copies. Re-enable when a customer-returns review flow lands and is connected through `_wire_zone_artifacts`. |

### Trigger-shape audit summary

The audit widened the shared `slot_collision` resource in this scene from
`Vector3(0.2, 0.2, 0.2)` to `Vector3(0.3, 0.3, 0.3)`, matching the canonical
`game/scenes/stores/components/shelf_slot.tscn` component. The 0.3 m cube is
the largest size that does not overlap the tightest in-scene neighbour
spacing (ConsoleShelf at 0.30 m on X), and removes the previous "stand
inside the fixture body to lock onto a slot" failure mode. Cart rack, glass
case, accessory bin, impulse, new-release, old-gen and bargain-bin slots
all share the same shape and benefit from the wider trigger.

All non-slot interactables ship trigger shapes that approximate or exceed
the visual prop bounds (entrance door, checkout counter, refurb bench,
testing station, manifest, clipboard, hold shelf, damaged bin, posters,
featured display). No additional widening was required.

The InteractionRay's 2.5 m maximum cast distance combined with the
layer-16-only mask means the player can lock onto any of the matrix rows
above from a natural standing position roughly 0.4–1.0 m from the prop face
— matching the BRAINDUMP target.

## Adjacent BRAINDUMP zone interactables (out of audit scope)

These additional interactables live in the same scene and are documented
here for completeness; their wiring status was verified as part of this
audit pass but they are not in the issue's "15 pre-existing" list. They are
either already wired or render an unanchored "Press E" prompt that should be
addressed in a follow-up store-zones audit.

| Scene node path | Day-1 handler | Status / follow-up |
|---|---|---|
| `BackroomDoor/BackroomInteractable` | none | Renders `Press E to View Open Backstock` with no listener. Out of scope here — track as a follow-up. |
| `used_game_wall/Interactable` | none | Browse zone wrapper; no listener wired. Follow-up. |
| `new_release_wall/Interactable` | none | Browse zone wrapper; no listener wired. Follow-up. |
| `old_gen_shelf/Interactable` | none | Browse zone wrapper; no listener wired. Follow-up. |
| `new_console_display/Interactable` | none for the Examine prompt; the `ShortageLabel` is updated live by `_refresh_new_console_display_label` | Follow-up. |
| `bargain_bin/Interactable` | none | Browse zone wrapper; no listener wired. Follow-up. |
| `employee_area/Interactable` | none | Zone wrapper; no listener wired. Follow-up. |
| `back_room/back_room_inventory_shelf/Interactable` | wired (`RetroGamesAudit.open_back_room_inventory_panel`) | Already active. |
| `TimeClock/Interactable` (spawned at runtime by `_spawn_time_clock_interactable`) | wired via `ClockInInteractable` script | Already active. Programmatically authored, not in the .tscn. |

## Reserved — hidden-thread interactables (next audit pass)

Seven additional interactable nodes are planned for a follow-up
hidden-thread audit pass that has not yet landed in the scene. When those
nodes are added, append rows for each below using the same column shape as
the matrix above. Until then this section serves as a placeholder so the
follow-up implementer can drop rows into a known location without restating
the documentation contract.

| # | Scene node path | Display name | Prompt text | Action verb | Interaction type (layer, mask) | Trigger shape (W×H×D m) | Required distance | Day-1 enabled | Day-1 handler | State | Test coverage | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| H-1 | _reserved_ | _reserved_ | _reserved_ | _reserved_ | _reserved_ | _reserved_ | _reserved_ | _reserved_ | _reserved_ | _reserved_ | _reserved_ | _reserved_ |
| H-2 | _reserved_ | | | | | | | | | | | |
| H-3 | _reserved_ | | | | | | | | | | | |
| H-4 | _reserved_ | | | | | | | | | | | |
| H-5 | _reserved_ | | | | | | | | | | | |
| H-6 | _reserved_ | | | | | | | | | | | |
| H-7 | _reserved_ | | | | | | | | | | | |

## Maintenance rules

- When adding a new interactable to `retro_games.tscn`, add a row to this
  matrix in the same patch.
- If you flip `enabled` on a row, update the `Day-1 enabled` and `State`
  columns and explain the reason in `Notes`.
- If you change the shared `slot_collision` size again, update the
  `Trigger shape` column for every shelf-slot row and re-validate the
  tightest-neighbour spacing constraint (currently 0.30 m at
  `ConsoleShelf`).
- Keep the matrix's column shape stable — automation may parse this file
  for audit dashboards.
