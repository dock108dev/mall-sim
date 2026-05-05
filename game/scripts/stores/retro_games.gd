## Controller for the retro game store. Manages lifecycle, testing stations,
## refurbishment queue integration, and quality grade assessment.
class_name RetroGames
extends StoreController

const STORE_ID: StringName = &"retro_games"
const STORE_TYPE: StringName = &"retro_games"
const TESTING_STATION_FIXTURE_ID: String = "testing_station"
const GRADES_PATH: String = "res://game/content/stores/retro_games/grades.json"
## Ordered condition tiers used by refurb actions.
const CONDITION_ORDER: PackedStringArray = [
	"poor", "fair", "good", "near_mint", "mint",
]
## Display name on the checkout counter Interactable when a customer is
## queued. Paired with an empty verb so the InteractionPrompt renders an
## informational label without a "Press E" cue — Day 1 customers
## auto-complete checkout via PlayerCheckout.process_transaction(), so the
## counter has no player-driven verb to advertise.
const _CHECKOUT_PROMPT_NAME_ACTIVE: String = "Customer at checkout"
## Display name on the checkout counter Interactable when no customer is
## queued. Paired with an empty verb so the InteractionPrompt renders the
## label without a "Press E" cue.
const _CHECKOUT_PROMPT_NAME_IDLE: String = "No customer waiting"
## NodePath to the orbit camera controller authored in retro_games.tscn. Held
## as a constant so the F3 debug toggle and the FP-startup disable share one
## source of truth for the lookup.
const _ORBIT_CONTROLLER_PATH: NodePath = ^"PlayerController"
## Marker3D that triggers `GameWorld._spawn_player_in_store`. Presence of this
## node means the store opens in first-person, so the orbit controller must
## ship disabled (process_mode propagates to the orbit camera's
## `InteractionRay`, eliminating the duplicate raycast under E-press).
const _PLAYER_ENTRY_SPAWN_PATH: NodePath = ^"PlayerEntrySpawn"
## Name of the FP body GameWorld spawns under the store root.
const _FP_BODY_NAME: StringName = &"Player"
## Action that toggles the debug overhead orbit view. Bound to F3 in the
## project InputMap; see project.godot.
const _ACTION_TOGGLE_DEBUG: StringName = &"toggle_debug"
const _CAMERA_SOURCE_DEBUG_OVERHEAD: StringName = &"debug_overhead"
const _CAMERA_SOURCE_PLAYER_FP: StringName = &"player_fp"
## Path to the entrance glass-door Interactable. Pressing E on the door
## releases the cursor and routes the FSM to MALL_OVERVIEW so the player
## leaves the store interior in the same way the day-summary "Return to
## Mall" button does (see GameWorld._on_day_summary_mall_overview_requested).
const _ENTRANCE_DOOR_INTERACTABLE_PATH: NodePath = ^"EntranceDoor/Interactable"
## Position of the spawned time-clock interactable, near the entrance and
## offset from the door so the player walks past it on entry. Authored
## programmatically rather than in the .tscn so the spawn can react to
## ShiftSystem state without requiring a scene-edit round-trip.
const _TIME_CLOCK_NAME: StringName = &"TimeClock"
const _TIME_CLOCK_POSITION := Vector3(5.5, 1.0, 8.0)
const _TIME_CLOCK_BODY_SIZE := Vector3(0.4, 0.6, 0.18)
const _TIME_CLOCK_COLLISION_SIZE := Vector3(0.7, 1.0, 0.7)
## Platform showcased by `new_console_display`. The ShortageLabel pulls live
## stock state from PlatformSystem and updates the in-store sign so the player
## reads "BACK ORDERED" or "IN STOCK" without opening a panel.
const _NEW_CONSOLE_PLATFORM_ID: StringName = &"vecforce_hd"
const _NEW_CONSOLE_DISPLAY_PATH: NodePath = ^"new_console_display"
const _NEW_CONSOLE_LABEL_PATH: NodePath = ^"new_console_display/ShortageLabel"
## StoreCustomizationSystem featured-category id matched against
## `featured_category_changed` to decide when to emit the weird-inventory
## hidden-thread trigger. Mirrored from
## StoreCustomizationSystem.FEATURED_CATEGORY_NEW_CONSOLE_HYPE so we don't
## reach across the autoload tree at static-init time.
const _NEW_CONSOLE_HYPE_CATEGORY: StringName = &"new_console_hype"

const _POSTER_DISPLAY_NAMES: Dictionary = {
	&"new_releases": "New Releases",
	&"retro_revival": "Retro Revival",
	&"sports_season": "Sports Season",
	&"family_fun": "Family Fun",
}

const _FEATURED_DISPLAY_NAMES: Dictionary = {
	&"new_console_hype": "New Console Hype",
	&"old_gen_clearance": "Old-Gen Clearance",
	&"used_bundles": "Used Bundles",
	&"sports_games": "Sports Games",
	&"accessories": "Accessories",
	&"family_friendly": "Family-Friendly Games",
}

## Hold-list / reservation manager. Addressed externally as `controller.holds`.
var holds: RetroGamesHolds = null
## Inventory-variance / discrepancy tracker. Addressed as `controller.audit`.
var audit: RetroGamesAudit = null

var _testing_station_slot: Node = null
var _refurbishment_system: RefurbishmentSystem = null
var _testing_system: TestingSystem = null
var _testing_available: bool = false
var _store_definition: Dictionary = {}
var _initialized: bool = false
## Maps instance_id → grade_id for all graded items this session.
var _item_grades: Dictionary = {}
## Maps grade_id → grade entry dict (loaded from grades.json at boot).
var _grade_table: Dictionary = {}
## Reference to the checkout counter Interactable so the prompt can swap
## between idle and customer-waiting states without recomputing the path.
var _checkout_counter_interactable: Interactable = null
## Mirrors the register queue size as observed from EventBus.queue_advanced
## so the checkout counter prompt can reflect "No customer waiting" vs
## "Customer at checkout" with no Press-E verb (Day 1 customers
## auto-complete checkout via PlayerCheckout.process_transaction()).
var _register_queue_size: int = 0
## True while the F3 debug overhead orbit view is the active camera. Tracks
## the toggle so a second F3 press restores first-person without needing to
## inspect CameraAuthority state.
var _debug_overhead_active: bool = false
## Reference to the entrance glass-door Interactable so the connect/disconnect
## stays single-source in `_ready` and `_exit_tree`.
var _entrance_door_interactable: Interactable = null
## True after we've already emitted display_exposes_weird_inventory for the
## current day so toggling featured back to new-console-hype doesn't double-up.
var _weird_inventory_signal_fired_today: bool = false


func _ready() -> void:
	holds = RetroGamesHolds.new(self)
	audit = RetroGamesAudit.new(self)
	initialize()
	super._ready()
	_find_testing_station()
	_connect_slot_signals()
	# retro_games.tscn ships `checkout_counter/Interactable`; reaching here
	# without it indicates a scene edit dropped the node. Warn once at boot
	# rather than on every queue_advanced refresh — see EH-07.
	_checkout_counter_interactable = get_node_or_null(
		"checkout_counter/Interactable"
	) as Interactable
	if _checkout_counter_interactable == null:
		push_warning(
			"RetroGames: checkout_counter/Interactable not found; "
			+ "register prompt will not flip between idle and "
			+ "customer-waiting states."
		)
	_connect_checkout_prompt_signals()
	_connect_entrance_door()
	_disable_orbit_controller_for_fp_startup()
	_spawn_time_clock_interactable()
	_wire_zone_artifacts()
	_connect_platform_shortage_signals()
	_refresh_new_console_display_label()
	_connect_store_customization_signals()


## Initializes Retro Games lifecycle state and EventBus wiring.
func initialize() -> void:
	if _initialized:
		return
	store_type = String(STORE_ID)
	_connect_lifecycle_signals()
	_store_definition = ContentRegistry.get_entry(STORE_ID)
	_connect_store_signal(EventBus.inventory_item_added, _on_inventory_item_added)
	_connect_store_signal(EventBus.item_stocked, _on_item_stocked)
	_load_grades()
	_initialized = true


## Sets the RefurbishmentSystem reference.
func set_refurbishment_system(system: RefurbishmentSystem) -> void:
	_refurbishment_system = system


## Sets the TestingSystem reference.
func set_testing_system(system: TestingSystem) -> void:
	_testing_system = system


## Returns the TestingSystem, or null if not set.
func get_testing_system() -> TestingSystem:
	return _testing_system


## Returns the RefurbishmentSystem, or null if not set.
func get_refurbishment_system() -> RefurbishmentSystem:
	return _refurbishment_system


## Returns the loaded store definition data from ContentRegistry.
func get_store_definition() -> Dictionary:
	return _store_definition.duplicate(true)


## Returns the testing station slot node, or null if not placed.
func get_testing_station_slot() -> Node:
	return _testing_station_slot


## Returns true if the store has a testing station fixture placed.
func has_testing_station() -> bool:
	return _testing_station_slot != null


## Returns true if the given item is valid for the testing station.
func can_test_item(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	if item.definition.store_type != String(STORE_ID):
		return false
	if item.tested:
		return false
	return true


## Places an item on the testing station and marks it as tested.
## Returns true on success.
func test_item(instance_id: String) -> bool:
	if not _inventory_system:
		push_warning("RetroGames: no InventorySystem set")
		return false
	if not _testing_station_slot:
		push_warning("RetroGames: no testing station placed")
		return false
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not can_test_item(item):
		push_warning("RetroGames: item '%s' cannot be tested" % instance_id)
		return false
	item.tested = true
	return true


## Inspects item_id and emits inspection_ready with condition and grade data.
## Returns false if item_id cannot be resolved.
func inspect_item(item_id: StringName) -> bool:
	if not _inventory_system:
		push_warning("RetroGames: inspect_item called without InventorySystem")
		return false
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		push_warning("RetroGames: inspect_item — item '%s' not found" % item_id)
		return false
	var condition_data: Dictionary = {
		"instance_id": item.instance_id,
		"item_name": item.definition.item_name if item.definition else "",
		"condition": item.condition,
		"current_grade": _item_grades.get(item.instance_id, ""),
		"grades": _grade_table.values(),
	}
	EventBus.inspection_ready.emit(item_id, condition_data)
	return true


## Records grade_id on item_id, emits grade_assigned, then resolves and emits
## item_priced via PriceResolver. Returns false on invalid inputs.
func assign_grade(item_id: StringName, grade_id: String) -> bool:
	if not _inventory_system:
		push_warning("RetroGames: assign_grade called without InventorySystem")
		return false
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		push_warning("RetroGames: assign_grade — item '%s' not found" % item_id)
		return false
	if not _grade_table.has(grade_id):
		push_warning("RetroGames: assign_grade — unknown grade_id '%s'" % grade_id)
		return false
	_item_grades[item.instance_id] = grade_id
	EventBus.grade_assigned.emit(item_id, grade_id)
	var price: float = get_item_price(item_id)
	EventBus.item_priced.emit(item_id, price)
	return true


## Returns the current sale price for an inventory item resolved via
## PriceResolver. Applies the explicitly assigned grade; falls back to the
## item's current condition tier so Clean/Repair/Restore each produce a
## distinct multiplier visible in the AuditStep log.
func get_item_price(item_id: StringName) -> float:
	if not _inventory_system:
		return 0.0
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item or not item.definition:
		return 0.0
	var multipliers: Array = []
	var grade_id: String = _item_grades.get(item.instance_id, "")
	if grade_id.is_empty():
		grade_id = item.condition  # condition tier as fallback grade
	if not grade_id.is_empty() and _grade_table.has(grade_id):
		var grade: Dictionary = _grade_table[grade_id]
		multipliers.append({
			"label": "Condition",
			"factor": float(grade.get("price_multiplier", 1.0)),
			"detail": str(grade.get("label", grade_id)),
		})
	var vintage_trend: float = MarketTrendSystemSingleton.get_trend_modifier(&"vintage")
	if vintage_trend != 1.0:
		multipliers.append({
			"slot": "trend",
			"label": "Vintage Trend",
			"factor": vintage_trend,
			"detail": "Vintage shelf trend: %.2f" % vintage_trend,
		})
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		item_id, item.definition.base_price, multipliers
	)
	return result.final_price


## Applies a single-tier condition bump (Clean action). Returns false if the
## item cannot be advanced or is not found.
func refurbish_clean(item_id: StringName) -> bool:
	return _apply_refurb_tier(item_id, 1)


## Applies a two-tier condition bump (Repair action).
func refurbish_repair(item_id: StringName) -> bool:
	return _apply_refurb_tier(item_id, 2)


## Restores item to mint condition (Restore action).
func refurbish_restore(item_id: StringName) -> bool:
	return _apply_refurb_tier(item_id, CONDITION_ORDER.size() - 1)


## Queues an item for refurbishment via the RefurbishmentSystem.
func _queue_refurbishment(item_id: StringName) -> void:
	if not _refurbishment_system:
		push_warning("RetroGames: no RefurbishmentSystem set")
		return
	_refurbishment_system.start_refurbishment(String(item_id))


## Advances item condition by `steps` tiers (capped at mint) and emits
## refurbishment_completed. Does not use the queue; single-click for the
## vertical slice. Returns false if item cannot be found or is already at max.
func _apply_refurb_tier(item_id: StringName, steps: int) -> bool:
	if not _inventory_system:
		push_warning("RetroGames: _apply_refurb_tier called without InventorySystem")
		return false
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		push_warning("RetroGames: _apply_refurb_tier — item '%s' not found" % item_id)
		return false
	var current_idx: int = CONDITION_ORDER.find(item.condition)
	if current_idx < 0:
		current_idx = 0
	var max_idx: int = CONDITION_ORDER.size() - 1
	if current_idx >= max_idx:
		push_warning("RetroGames: item '%s' is already at max condition" % item_id)
		return false
	var new_idx: int = mini(current_idx + steps, max_idx)
	var new_condition: String = CONDITION_ORDER[new_idx]
	item.condition = new_condition
	EventBus.refurbishment_completed.emit(String(item_id), true, new_condition)
	return true


## Serializes retro-games-specific state for saving.
func get_save_data() -> Dictionary:
	return {
		"testing_available": _testing_available,
		"item_grades": _item_grades.duplicate(),
		"hold_list": holds.get_save_data(),
	}


## Restores retro-games-specific state from saved data.
func load_save_data(data: Dictionary) -> void:
	_testing_available = bool(data.get("testing_available", false))
	var grades_data: Variant = data.get("item_grades", {})
	if grades_data is Dictionary:
		_item_grades = grades_data as Dictionary
	var hold_data: Variant = data.get("hold_list", null)
	if hold_data is Dictionary:
		holds.load_save_data(hold_data as Dictionary)


func _load_grades() -> void:
	var data: Variant = DataLoader.load_json(GRADES_PATH)
	if not (data is Dictionary):
		push_error(
			"RetroGames: failed to load %s as Dictionary" % GRADES_PATH
		)
		return
	var grades_arr: Variant = (data as Dictionary).get("grades", [])
	if grades_arr is not Array:
		push_error("RetroGames: grades.json 'grades' key must be an Array")
		return
	for entry: Variant in grades_arr as Array:
		if entry is not Dictionary:
			continue
		var grade_entry: Dictionary = entry as Dictionary
		var gid: Variant = grade_entry.get("id", "")
		if gid is not String or (gid as String).is_empty():
			continue
		var raw_mult: Variant = grade_entry.get("price_multiplier", 1.0)
		var mult: float = float(raw_mult) if (raw_mult is float or raw_mult is int) else 0.0
		if not is_finite(mult) or mult <= 0.0:
			push_warning("RetroGames: skipping grade '%s' — invalid price_multiplier" % (gid as String))
			continue
		_grade_table[gid as String] = grade_entry


func _on_store_entered(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	_seed_starter_inventory()
	_testing_available = has_testing_station()
	_apply_accent_to_slots(UIThemeConstants.STORE_ACCENT_RETRO_GAMES)
	_apply_day1_quarantine()
	_refresh_checkout_prompt()
	EventBus.store_opened.emit(String(STORE_ID))


## Subscribes to the EventBus signal that reports register-queue size so the
## checkout counter prompt can mirror "customer waiting" vs "no customer".
## PlayerCheckout emits `queue_advanced` whenever the queue grows or shrinks
## (including the initial customer arrival) so it is the single source of
## truth for the prompt state.
func _connect_checkout_prompt_signals() -> void:
	_connect_store_signal(EventBus.queue_advanced, _on_queue_advanced)


func _on_queue_advanced(size: int) -> void:
	_register_queue_size = maxi(size, 0)
	_refresh_checkout_prompt()


## §F-109 — Updates the checkout counter Interactable's display label based on
## whether a customer is currently in the register queue. The prompt is
## purely informational ("Customer at checkout" / "No customer waiting") with
## an empty verb so the InteractionPrompt never renders a dead "Press E" cue —
## Day 1 customers auto-complete checkout via PlayerCheckout, so a player-
## driven verb on the counter would advertise an action that does nothing.
## Same dead-prompt removal contract as §F-111 shelf_slot empty-verb path.
##
## Silent return on null `_checkout_counter_interactable` is paired with the
## boot-time warning in `_ready` (EH-07): the missing-node case is logged
## once on entry rather than every queue_advanced tick, which would otherwise
## flood the log on a busy register.
func _refresh_checkout_prompt() -> void:
	if _checkout_counter_interactable == null:
		return
	if _register_queue_size > 0:
		_checkout_counter_interactable.display_name = (
			_CHECKOUT_PROMPT_NAME_ACTIVE
		)
	else:
		_checkout_counter_interactable.display_name = (
			_CHECKOUT_PROMPT_NAME_IDLE
		)
	_checkout_counter_interactable.prompt_text = ""


## Subscribes to the entrance-door Interactable so pressing E on the glass
## door releases the cursor and changes GameManager state to MALL_OVERVIEW.
## Silent return on a missing node mirrors the checkout-counter handling
## above: a missing scene node is logged once at boot via `push_warning` so
## the failure surfaces without flooding logs.
func _connect_entrance_door() -> void:
	_entrance_door_interactable = get_node_or_null(
		_ENTRANCE_DOOR_INTERACTABLE_PATH
	) as Interactable
	if _entrance_door_interactable == null:
		push_warning(
			"RetroGames: %s not found; 'Exit to Mall' interaction disabled."
			% String(_ENTRANCE_DOOR_INTERACTABLE_PATH)
		)
		return
	if not _entrance_door_interactable.interacted.is_connected(
		_on_entrance_door_interacted
	):
		_entrance_door_interactable.interacted.connect(
			_on_entrance_door_interacted
		)


## Releases the cursor and transitions the FSM to MALL_OVERVIEW. Mirrors the
## `_on_day_summary_mall_overview_requested` path in `GameWorld` so the door
## and the day-summary button leave the store the same way.
##
## §F-71 — Defense in depth: only run the cursor unlock + state transition
## while GameManager is in GAMEPLAY. The Interactable.interacted signal is
## already gated upstream by InputFocus (`_gameplay_allowed()` in
## `store_player_body.gd`) and by `interaction_ray._open_panel_count == 0`,
## so reaching this handler outside GAMEPLAY would require a future modal
## that bypasses both gates. Without this guard, an E-press in such a state
## would unlock the cursor without successfully changing state (the FSM
## would `push_warning("Invalid transition")`) — leaving the cursor visible
## and gameplay context still claimed but pointer-less.
func _on_entrance_door_interacted() -> void:
	if GameManager.current_state != GameManager.State.GAMEPLAY:
		return
	InputHelper.unlock_cursor()
	GameManager.change_state(GameManager.State.MALL_OVERVIEW)


## Hides refurb_bench from the Day 1 store floor so the introductory loop only
## exposes shelves and the register. It re-enables on Day 2+ or when running a
## debug build, satisfying the quarantine rule that non-Day-1 surfaces stay
## behind a debug-build flag or a later-day gate.
##
## testing_station is intentionally excluded: its Interactable ships disabled
## (the testing flow is not wired up yet) and the visual zone — CRT prop,
## bench, neon panels, "Coming Soon" Label3D — lives under crt_demo_area, which
## stays visible so the testing area reads as a deliberate parked feature
## rather than missing scenery.
##
## §F-41 — silent return on a missing node is intentional: future store
## variants may legitimately omit refurb_bench (e.g. an early-game
## retro_games.tscn before the fixture is authored). The quarantine is moot
## for missing nodes because nothing is rendered. A missing `Interactable`
## child on an existing node is also tolerated — toggling the parent's
## visibility is enough to suppress player interaction.
func _apply_day1_quarantine() -> void:
	var quarantined: bool = (
		GameManager.get_current_day() <= 1 and not OS.is_debug_build()
	)
	var bench: Node3D = get_node_or_null("refurb_bench") as Node3D
	if bench == null:
		return
	bench.visible = not quarantined
	var interactable: Interactable = bench.get_node_or_null(
		"Interactable"
	) as Interactable
	if interactable:
		interactable.enabled = not quarantined


func get_store_actions() -> Array:
	var actions: Array = super()
	actions.append({"id": &"test", "label": "Test", "icon": ""})
	actions.append({"id": &"refurbish", "label": "Refurbish", "icon": ""})
	return actions


func _on_store_exited(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	_apply_accent_to_slots(Color.WHITE)
	EventBus.store_closed.emit(String(STORE_ID))


func _apply_accent_to_slots(color: Color) -> void:
	for slot_node: Node in _slots:
		if slot_node is ShelfSlot:
			(slot_node as ShelfSlot).apply_accent(color)


func _on_inventory_item_added(
	store_id: StringName, item_id: StringName
) -> void:
	if store_id != STORE_ID:
		return
	_check_needs_refurbishment(item_id)


func _on_item_stocked(item_id: String, shelf_id: String) -> void:
	if not _testing_station_slot:
		return
	var station_slot_id: String = str(
		_testing_station_slot.get("slot_id")
	)
	if station_slot_id.is_empty() or shelf_id != station_slot_id:
		return
	_try_auto_test(item_id)


func _check_needs_refurbishment(item_id: StringName) -> void:
	if not _inventory_system or not _refurbishment_system:
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		return
	if _refurbishment_system.can_refurbish(item):
		EventBus.notification_requested.emit(
			"%s could be refurbished" % item.definition.item_name
		)


func _try_auto_test(item_id: String) -> void:
	if not _testing_system:
		return
	_testing_system.start_test(item_id)


## Connects all shelf slot slot_changed signals and price update signals so
## slot labels stay in sync when items are placed or prices are changed.
func _connect_slot_signals() -> void:
	for slot_node: Node in _slots:
		if not slot_node is ShelfSlot:
			continue
		var slot := slot_node as ShelfSlot
		if not slot.slot_changed.is_connected(_on_slot_changed):
			slot.slot_changed.connect(_on_slot_changed)
	_connect_store_signal(EventBus.price_set, _on_price_set)
	_connect_store_signal(EventBus.item_priced, _on_item_priced)


## Refreshes the display label on a single slot from the current inventory state.
func _refresh_slot_display(slot: ShelfSlot) -> void:
	if not _inventory_system:
		return
	var item_id: StringName = slot.get_item_id()
	if item_id.is_empty():
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item or not item.definition:
		return
	var price: float = get_item_price(item_id)
	slot.set_display_data(item.definition.item_name, item.condition, price)


func _on_slot_changed(slot: ShelfSlot) -> void:
	if not slot.is_occupied():
		slot.clear_display_data()
		return
	_refresh_slot_display(slot)


## Updates the display on whichever slot holds the priced item instance.
func _on_price_set(instance_id: String, _price: float) -> void:
	for slot_node: Node in _slots:
		if not slot_node is ShelfSlot:
			continue
		var slot := slot_node as ShelfSlot
		if slot.get_item_instance_id() == instance_id:
			_refresh_slot_display(slot)
			return


func _on_item_priced(item_id: StringName, _price: float) -> void:
	for slot_node: Node in _slots:
		if not slot_node is ShelfSlot:
			continue
		var slot := slot_node as ShelfSlot
		if slot.get_item_id() == item_id:
			_refresh_slot_display(slot)
			return


func _connect_store_signal(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


func _seed_starter_inventory() -> void:
	if _inventory_system == null:
		return
	if _store_definition.is_empty():
		_store_definition = ContentRegistry.get_entry(STORE_ID)
	RetroGamesStarterSeed.seed(STORE_ID, _store_definition, _inventory_system)


func _find_testing_station() -> void:
	for fixture: Node in _fixtures:
		if fixture.get("fixture_id") == TESTING_STATION_FIXTURE_ID:
			_assign_testing_station_slots(fixture)
			return
	for slot: Node in _slots:
		if slot.get("fixture_id") == TESTING_STATION_FIXTURE_ID:
			_testing_station_slot = slot
			return


func _assign_testing_station_slots(fixture: Node) -> void:
	for child: Node in fixture.get_children():
		if child.is_in_group("shelf_slot") or child.get("slot_id") != null:
			_testing_station_slot = child
			return


## Disables the legacy orbit `PlayerController` so it no longer ticks while
## the first-person body owns the camera. `PROCESS_MODE_DISABLED` propagates
## to children, which is the point — without it the orbit
## `PlayerController/StoreCamera/InteractionRay` keeps polling and fires a
## second interaction on every E-press alongside the FP body's own ray.
##
## §F-55 — Silent return when `PlayerEntrySpawn` is absent matches the
## orbit-only fallback in `GameWorld._spawn_player_in_store`: stores authored
## without an FP entry marker keep the orbit controller live as their sole
## camera. When `PlayerEntrySpawn` IS present but the orbit `PlayerController`
## is missing the scene contract is broken (the .tscn shipped without the
## debug-toggle target), so we surface the mismatch via `push_warning` so the
## F3 toggle's later `_toggle_debug_overhead_camera` warning is not the first
## signal of the authoring bug.
func _disable_orbit_controller_for_fp_startup() -> void:
	if get_node_or_null(_PLAYER_ENTRY_SPAWN_PATH) == null:
		return
	var orbit: Node = get_node_or_null(_ORBIT_CONTROLLER_PATH)
	if orbit == null:
		push_warning(
			"RetroGames: PlayerEntrySpawn present but %s missing — F3 debug toggle disabled"
			% String(_ORBIT_CONTROLLER_PATH)
		)
		return
	orbit.process_mode = Node.PROCESS_MODE_DISABLED
	_debug_overhead_active = false


## §F-58 — Gated on `OS.is_debug_build()` to match the established pattern for
## debug surfaces (`debug_overlay.gd`, `audit_overlay.gd`,
## `accent_budget_overlay.gd`, `store_controller.dev_force_place_test_item`).
## Release players who hit F3 by accident would otherwise unlock the cursor and
## reveal a top-down orbit view that bypasses the FP camera contract; the
## release-build short-circuit removes that surface entirely.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(_ACTION_TOGGLE_DEBUG):
		_toggle_debug_overhead_camera()


## Flips between the first-person camera and the legacy overhead orbit camera
## as a debug aid. The orbit controller is re-enabled (process_mode INHERIT)
## so its WASD pivot handler ticks again, the cursor is unlocked, and the
## orbit `StoreCamera` is made current via `CameraAuthority`. A second press
## reverses all three so the FP body resumes ownership.
##
## §F-65 — Silent return when either camera cannot be resolved keeps the F3
## toggle from crashing if the scene is partially loaded; the `push_warning`
## paths surface the missing node without aborting input handling. The
## debug-only F3 surface (§F-58) means a release player cannot reach these
## warnings; in debug builds the warning is the diagnostic.
func _toggle_debug_overhead_camera() -> void:
	var orbit: Node = get_node_or_null(_ORBIT_CONTROLLER_PATH)
	if orbit == null:
		push_warning(
			"RetroGames: PlayerController missing; cannot toggle debug camera"
		)
		return
	if not _debug_overhead_active:
		_enter_debug_overhead(orbit)
	else:
		_exit_debug_overhead(orbit)


func _enter_debug_overhead(orbit: Node) -> void:
	var orbit_cam: Camera3D = orbit.get_node_or_null("StoreCamera") as Camera3D
	if orbit_cam == null:
		push_warning("RetroGames: orbit StoreCamera missing; debug toggle aborted")
		return
	orbit.process_mode = Node.PROCESS_MODE_INHERIT
	if orbit.has_method("set_input_listening"):
		orbit.set_input_listening(true)
	CameraAuthority.request_current(orbit_cam, _CAMERA_SOURCE_DEBUG_OVERHEAD)
	InputHelper.unlock_cursor()
	_debug_overhead_active = true


func _exit_debug_overhead(orbit: Node) -> void:
	var fp_cam: Camera3D = _resolve_fp_camera()
	if fp_cam == null:
		push_warning(
			"RetroGames: FP body camera missing; staying in debug overhead"
		)
		return
	orbit.process_mode = Node.PROCESS_MODE_DISABLED
	CameraAuthority.request_current(fp_cam, _CAMERA_SOURCE_PLAYER_FP)
	InputHelper.lock_cursor()
	_debug_overhead_active = false


func _resolve_fp_camera() -> Camera3D:
	var body: Node = get_node_or_null(NodePath(_FP_BODY_NAME))
	if body == null:
		return null
	return body.get_node_or_null("StoreCamera") as Camera3D


## Builds the in-store time-clock prop and Interactable so the player has a
## physical surface to clock in/out at. Authored at runtime rather than in the
## .tscn so a single source-of-truth (this file) owns the prop layout.
##
## Idempotent: a re-entry into the store will hit the existing-node early
## return rather than spawning a duplicate stack.
func _spawn_time_clock_interactable() -> void:
	if get_node_or_null(NodePath(_TIME_CLOCK_NAME)) != null:
		return
	var root := StaticBody3D.new()
	root.name = String(_TIME_CLOCK_NAME)
	root.position = _TIME_CLOCK_POSITION
	add_child(root)

	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "Body"
	var box := BoxMesh.new()
	box.size = _TIME_CLOCK_BODY_SIZE
	body_mesh.mesh = box
	root.add_child(body_mesh)

	var interactable: ClockInInteractable = ClockInInteractable.new()
	interactable.name = "Interactable"
	interactable.interaction_type = Interactable.InteractionType.ITEM
	interactable.interactable_id = &"time_clock"
	interactable.store_id = STORE_ID
	root.add_child(interactable)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = _TIME_CLOCK_COLLISION_SIZE
	collider.shape = shape
	interactable.add_child(collider)


## Connects the BRAINDUMP zone artifact Interactables (delivery_manifest,
## poster_slot, featured_display, release_notes_clipboard,
## back_room_inventory_shelf, back_room_damaged_bin) so player examination
## drives the corresponding signals and panel toggles. Silent skip on a
## missing node is intentional — the .tscn ships these by default, but
## controller-level wiring should not crash a partially-loaded scene fixture.
func _wire_zone_artifacts() -> void:
	_connect_artifact("delivery_manifest/Interactable", _on_delivery_manifest_examined)
	_connect_artifact("poster_slot/Interactable", _on_poster_slot_interacted)
	_connect_artifact("featured_display/Interactable", _on_featured_display_interacted)
	_connect_artifact(
		"release_notes_clipboard/Interactable",
		_on_release_notes_clipboard_interacted,
	)
	_connect_artifact(
		"back_room/back_room_inventory_shelf/Interactable",
		_on_back_room_inventory_shelf_interacted,
	)
	_connect_artifact("hold_shelf/Interactable", holds.on_hold_shelf_interacted)


func _connect_artifact(path: String, callable: Callable) -> void:
	var node: Interactable = get_node_or_null(path) as Interactable
	if node == null:
		return
	if not node.interacted.is_connected(callable):
		node.interacted.connect(callable)


## Subscribes to the platform shortage signals so the new_console_display
## ShortageLabel reflects live VecForce HD stock state. Silent skip when
## PlatformSystem is unreachable supports unit-test seams that instantiate
## the scene without a full autoload tree.
func _connect_platform_shortage_signals() -> void:
	if not _has_platform_system():
		return
	_connect_store_signal(EventBus.platform_shortage_started, _on_platform_shortage_changed)
	_connect_store_signal(EventBus.platform_shortage_ended, _on_platform_shortage_changed)
	_connect_store_signal(EventBus.platform_restock_received, _on_platform_restock_received)
	_connect_store_signal(EventBus.day_started, _on_zone_day_started)


func _has_platform_system() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	return tree.root.has_node("PlatformSystem")


func _on_zone_day_started(day: int) -> void:
	audit.reset_for_new_day()
	# Walk holds list and expire any past-expiry slips so the morning props
	# render in the crumpled state. expire_stale emits hold_expired per slip,
	# which the prop-spawning listener consumes.
	holds.get_hold_list().expire_stale(day)


func _on_platform_shortage_changed(_platform_id: StringName) -> void:
	_refresh_new_console_display_label()


func _on_platform_restock_received(_platform_id: StringName, _qty: int) -> void:
	_refresh_new_console_display_label()


## Updates the in-store ShortageLabel under new_console_display so the player
## can read VecForce HD stock state from the shop floor. Reads PlatformSystem
## live; falls back to "IN STOCK" when the system is not installed (test seam).
func _refresh_new_console_display_label() -> void:
	var label: Label3D = get_node_or_null(_NEW_CONSOLE_LABEL_PATH) as Label3D
	if label == null:
		return
	var platform_name: String = "VecForce HD"
	var status_text: String = "IN STOCK"
	var status_color: Color = Color(0.65, 1.0, 0.7, 1)
	if _has_platform_system():
		var ps: Node = get_tree().root.get_node("PlatformSystem")
		var def: Variant = ps.call("get_definition", _NEW_CONSOLE_PLATFORM_ID)
		if def != null and def.get("display_name") is String:
			var display_name_value: String = String(def.get("display_name"))
			if not display_name_value.is_empty():
				platform_name = display_name_value
		var in_shortage: bool = bool(
			ps.call("is_shortage", _NEW_CONSOLE_PLATFORM_ID)
		)
		if in_shortage:
			status_text = "BACK ORDERED"
			status_color = Color(1.0, 0.55, 0.4, 1)
	label.text = "%s — %s" % [platform_name.to_upper(), status_text]
	label.modulate = status_color


# ── Zone artifact handlers ───────────────────────────────────────────────────

func _on_delivery_manifest_examined() -> void:
	if not audit.consume_delivery_manifest_examined():
		return
	var day: int = GameManager.get_current_day()
	EventBus.delivery_manifest_examined.emit(STORE_ID, day)


func _on_poster_slot_interacted() -> void:
	var customization: Node = _get_store_customization_system()
	if customization == null:
		EventBus.notification_requested.emit(
			"Poster slot — store customization system unavailable."
		)
		return
	var poster_id: StringName = customization.call("cycle_poster")
	EventBus.notification_requested.emit(
		"Poster: %s" % _poster_display_name(poster_id)
	)


func _on_featured_display_interacted() -> void:
	var customization: Node = _get_store_customization_system()
	if customization == null:
		EventBus.notification_requested.emit(
			"Featured display — store customization system unavailable."
		)
		return
	if not bool(customization.call("can_set_featured_category")):
		EventBus.notification_requested.emit("Ask Vic — display authority is his call for now.")
		return
	var category: StringName = customization.call("cycle_featured_category")
	EventBus.notification_requested.emit(
		"Featured: %s" % _featured_category_display_name(category)
	)


func _get_store_customization_system() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("StoreCustomizationSystem")


func _poster_display_name(poster_id: StringName) -> String:
	return String(_POSTER_DISPLAY_NAMES.get(poster_id, "(none)"))


func _featured_category_display_name(category: StringName) -> String:
	return String(_FEATURED_DISPLAY_NAMES.get(category, "(none)"))


func _on_release_notes_clipboard_interacted() -> void:
	EventBus.notification_requested.emit("Release notes — VecForce HD launch titles drop this week.")


func _on_back_room_inventory_shelf_interacted() -> void:
	audit.open_back_room_inventory_panel()


# ── Store customization wiring ───────────────────────────────────────────────


func _connect_store_customization_signals() -> void:
	var customization: Node = _get_store_customization_system()
	if customization == null:
		return
	if not customization.is_connected(
		&"featured_category_changed", _on_featured_category_changed
	):
		customization.connect(
			&"featured_category_changed", _on_featured_category_changed
		)
	# day_started reset is needed to clear the per-day signal latch.
	if not EventBus.day_started.is_connected(_on_customization_day_started):
		EventBus.day_started.connect(_on_customization_day_started)


func _on_customization_day_started(_day: int) -> void:
	_weird_inventory_signal_fired_today = false


func _on_featured_category_changed(category: StringName) -> void:
	if _weird_inventory_signal_fired_today:
		return
	if category != _NEW_CONSOLE_HYPE_CATEGORY:
		return
	if not holds.has_suspicious_vecforce_hd_hold():
		return
	EventBus.display_exposes_weird_inventory.emit(STORE_ID)
	_weird_inventory_signal_fired_today = true
