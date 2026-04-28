## Tests the Day 1 inventory placement loop end-to-end:
##   1. Retro Games store seeds backroom items from `starting_inventory` JSON.
##   2. `InventorySystem.assign_to_shelf` emits `item_stocked`.
##   3. HUD `ItemsPlacedLabel` increments from 0 to 1 on first placement.
##   4. Dev-only `dev_force_place_test_item` fallback works in debug builds.
extends GutTest


const STORE_ID: StringName = &"retro_games"
const _HudScene: PackedScene = preload(
	"res://game/scenes/ui/hud.tscn"
)


var _data_loader: DataLoader
var _inventory: InventorySystem
var _previous_data_loader: DataLoader
var _previous_store_id: StringName


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_previous_data_loader = GameManager.data_loader
	_previous_store_id = GameManager.current_store_id
	GameManager.data_loader = _data_loader
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)
	GameManager.current_store_id = STORE_ID


func after_each() -> void:
	GameManager.data_loader = _previous_data_loader
	GameManager.current_store_id = _previous_store_id


# ── AC 1: Starting inventory loads from store_definitions.json ────────────────

func test_retro_games_content_entry_lists_starting_inventory_ids() -> void:
	var entry: Dictionary = ContentRegistry.get_entry(STORE_ID)
	assert_false(
		entry.is_empty(),
		"ContentRegistry must contain a retro_games entry"
	)
	var starting: Variant = entry.get("starting_inventory", [])
	assert_true(
		starting is Array,
		"retro_games.starting_inventory must be an Array"
	)
	assert_gt(
		(starting as Array).size(),
		0,
		"retro_games.starting_inventory must list ≥1 item id"
	)
	for raw_id: Variant in starting as Array:
		assert_true(
			raw_id is String or raw_id is Dictionary,
			"starting_inventory entries must be String ids or Dictionary specs"
		)


func test_retro_games_seed_starter_inventory_populates_backroom() -> void:
	var controller: RetroGames = RetroGames.new()
	add_child_autofree(controller)
	controller.set_inventory_system(_inventory)
	# Trigger the seed path the controller normally runs on store_entered.
	# Calling _on_store_entered directly avoids needing the whole scene tree.
	controller._on_store_entered(STORE_ID)
	var backroom: Array[ItemInstance] = (
		_inventory.get_backroom_items_for_store(String(STORE_ID))
	)
	assert_gte(
		backroom.size(),
		1,
		(
			"InventorySystem backroom must contain ≥1 retro_games item after "
			+ "_on_store_entered seeds the starter inventory"
		)
	)


func test_retro_games_seed_is_idempotent_when_inventory_already_populated() -> void:
	var controller: RetroGames = RetroGames.new()
	add_child_autofree(controller)
	controller.set_inventory_system(_inventory)
	controller._on_store_entered(STORE_ID)
	var first_count: int = (
		_inventory.get_backroom_items_for_store(String(STORE_ID)).size()
	)
	controller._on_store_entered(STORE_ID)
	var second_count: int = (
		_inventory.get_backroom_items_for_store(String(STORE_ID)).size()
	)
	assert_eq(
		first_count,
		second_count,
		"Re-entering an already-populated store must not double-seed"
	)


# ── AC 2/3: assign_to_shelf emits item_stocked with valid ids ─────────────────

func test_assign_to_shelf_emits_item_stocked_with_valid_ids() -> void:
	var def: ItemDefinition = _first_retro_games_item()
	if def == null:
		pass_test("No retro_games item definitions — skip")
		return
	var item: ItemInstance = ItemInstance.create(
		def, "good", 0, def.base_price
	)
	item.current_location = "backroom"
	_inventory.add_item(STORE_ID, item)

	var observed: Array[Array] = []
	var observer: Callable = (
		func(instance_id: String, slot_id: String) -> void:
			observed.append([instance_id, slot_id])
	)
	EventBus.item_stocked.connect(observer)
	var ok: bool = _inventory.assign_to_shelf(
		STORE_ID, StringName(item.instance_id), &"cart_left_1"
	)
	EventBus.item_stocked.disconnect(observer)

	assert_true(ok, "assign_to_shelf should return true on success")
	assert_eq(observed.size(), 1, "item_stocked must fire exactly once")
	assert_eq(
		observed[0][0],
		item.instance_id,
		"item_stocked must carry the placed instance_id"
	)
	assert_eq(
		observed[0][1],
		"cart_left_1",
		"item_stocked must carry the target slot_id"
	)


# ── AC 4: HUD ItemsPlacedLabel increments after a real placement ──────────────

func test_hud_items_placed_label_increments_from_zero_to_one() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	hud._items_placed_count = 0
	hud._update_items_placed_display(0)
	var label: Label = hud.get_node("TopBar/ItemsPlacedLabel")
	assert_string_contains(
		label.text, "0", "Label should start showing 0"
	)

	var def: ItemDefinition = _first_retro_games_item()
	if def == null:
		pass_test("No retro_games item definitions — skip")
		return
	var item: ItemInstance = ItemInstance.create(
		def, "good", 0, def.base_price
	)
	item.current_location = "backroom"
	_inventory.add_item(STORE_ID, item)

	# HUD's _refresh_items_placed pulls inventory via
	# GameManager.get_inventory_system(), which find_children's for an
	# InventorySystem in the tree. Our before_each adds one as a child of the
	# test root, so the lookup resolves.
	_inventory.assign_to_shelf(
		STORE_ID, StringName(item.instance_id), &"cart_left_1"
	)
	# inventory_changed runs synchronously through HUD's handler; no await.
	assert_eq(
		hud._items_placed_count,
		1,
		"HUD _items_placed_count must increment to 1 after first placement"
	)
	assert_string_contains(
		label.text, "1", "ItemsPlacedLabel text must reflect 1 placed item"
	)


# ── AC 5: Dev force-place fallback ────────────────────────────────────────────

func test_dev_force_place_test_item_returns_false_without_inventory() -> void:
	var controller: StoreController = StoreController.new()
	add_child_autofree(controller)
	controller.initialize_store(STORE_ID)
	var ok: bool = controller.dev_force_place_test_item()
	assert_false(
		ok,
		"dev_force_place_test_item must return false with no inventory_system"
	)


func test_dev_force_place_test_item_returns_false_with_empty_backroom() -> void:
	if not OS.is_debug_build():
		pass_test("Release build — dev fallback intentionally disabled")
		return
	var controller: StoreController = StoreController.new()
	add_child_autofree(controller)
	controller.initialize_store(STORE_ID)
	controller.set_inventory_system(_inventory)
	var ok: bool = controller.dev_force_place_test_item()
	assert_false(
		ok,
		"dev_force_place_test_item must fail when backroom has no items"
	)


func test_dev_force_place_test_item_places_emits_and_increments() -> void:
	if not OS.is_debug_build():
		pass_test("Release build — dev fallback intentionally disabled")
		return
	# Use the real retro_games scene so the controller has actual ShelfSlot
	# children to target. The scene root is engine-typed Node3D with the
	# RetroGames script attached, so we route calls through `Node` reflection
	# rather than a static cast (which the parser rejects).
	var scene: PackedScene = load("res://game/scenes/stores/retro_games.tscn")
	assert_not_null(scene, "retro_games scene must load")
	var root: Node = scene.instantiate()
	add_child_autofree(root)
	assert_true(
		root.has_method("dev_force_place_test_item"),
		"retro_games scene root must expose dev_force_place_test_item"
	)
	root.call("set_inventory_system", _inventory)
	# Seed at least one backroom item so the fallback has something to place.
	var def: ItemDefinition = _first_retro_games_item()
	if def == null:
		pass_test("No retro_games item definitions — skip")
		return
	var item: ItemInstance = ItemInstance.create(
		def, "good", 0, def.base_price
	)
	item.current_location = "backroom"
	_inventory.add_item(STORE_ID, item)

	var stocked_count: Array[int] = [0]
	var observer: Callable = (
		func(_instance_id: String, _slot_id: String) -> void:
			stocked_count[0] += 1
	)
	EventBus.item_stocked.connect(observer)
	var ok: bool = root.call("dev_force_place_test_item")
	EventBus.item_stocked.disconnect(observer)

	assert_true(ok, "dev_force_place_test_item must succeed")
	assert_eq(
		stocked_count[0], 1,
		"dev_force_place_test_item must emit item_stocked exactly once"
	)
	var shelf_count: int = (
		_inventory.get_shelf_items_for_store(String(STORE_ID)).size()
	)
	assert_eq(
		shelf_count, 1,
		"placed count (shelf items) must increment from 0 to 1"
	)


# ── AC 2: Toggle inventory action opens/closes the panel ─────────────────────

func test_toggle_inventory_action_opens_and_closes_panel() -> void:
	var focus: Node = get_tree().root.get_node_or_null("InputFocus")
	assert_not_null(focus, "InputFocus autoload required")
	if focus == null:
		return
	focus._reset_for_tests()
	focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var panel_scene: PackedScene = preload(
		"res://game/scenes/ui/inventory_panel.tscn"
	)
	var panel: InventoryPanel = panel_scene.instantiate() as InventoryPanel
	panel.inventory_system = _inventory
	add_child_autofree(panel)

	var press: InputEventKey = InputEventKey.new()
	press.pressed = true
	press.keycode = KEY_I
	press.physical_keycode = KEY_I
	# Toggle open.
	panel._unhandled_input(press)
	assert_true(panel.is_open(), "I key must open the InventoryPanel")
	assert_eq(
		focus.current(),
		InputFocus.CTX_MODAL,
		"opening must push CTX_MODAL on top of CTX_STORE_GAMEPLAY"
	)

	# Toggle closed via I again.
	panel._unhandled_input(press)
	assert_false(panel.is_open(), "second I press must close the panel")
	assert_eq(
		focus.current(),
		InputFocus.CTX_STORE_GAMEPLAY,
		"closing must restore CTX_STORE_GAMEPLAY"
	)

	# Re-open then close via Escape (ui_cancel).
	panel._unhandled_input(press)
	assert_true(panel.is_open())
	var cancel: InputEventKey = InputEventKey.new()
	cancel.pressed = true
	cancel.keycode = KEY_ESCAPE
	cancel.physical_keycode = KEY_ESCAPE
	panel._unhandled_input(cancel)
	assert_false(panel.is_open(), "Escape must close the InventoryPanel")
	assert_eq(
		focus.current(),
		InputFocus.CTX_STORE_GAMEPLAY,
		"Escape close must restore CTX_STORE_GAMEPLAY"
	)
	panel._reset_for_tests()
	focus._reset_for_tests()


# ── helpers ───────────────────────────────────────────────────────────────────

func _first_retro_games_item() -> ItemDefinition:
	for def: ItemDefinition in _data_loader.get_items_by_store(String(STORE_ID)):
		if def != null:
			return def
	return null
