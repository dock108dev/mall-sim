## Tests InventoryPanel filtering, tab switching, footer calculation, and
## context menu action gating.
extends GutTest

const _INVENTORY_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/inventory_panel.tscn"
)


var _data_loader: DataLoader
var _inventory_system: InventorySystem
var _previous_data_loader: DataLoader
var _previous_store_id: StringName


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_previous_data_loader = GameManager.data_loader
	_previous_store_id = GameManager.current_store_id
	GameManager.data_loader = _data_loader
	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(_data_loader)


func after_each() -> void:
	GameManager.data_loader = _previous_data_loader
	GameManager.current_store_id = _previous_store_id


func _create_test_item(
	def_id: String, condition: String, location: String
) -> ItemInstance:
	var def: ItemDefinition = _data_loader.get_item(def_id)
	if not def:
		return null
	var item: ItemInstance = ItemInstance.create(
		def, condition, 0, def.base_price
	)
	item.current_location = location
	_inventory_system.register_item(item)
	return item


func test_backroom_items_filter() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		pass_test("No item definitions loaded — skip")
		return
	var def: ItemDefinition = items[0]
	var store_type: String = def.store_type
	var item_back: ItemInstance = _create_test_item(
		def.id, "good", "backroom"
	)
	var item_shelf: ItemInstance = _create_test_item(
		def.id, "good", "shelf:slot_01"
	)
	assert_not_null(item_back)
	assert_not_null(item_shelf)
	var backroom: Array[ItemInstance] = (
		_inventory_system.get_backroom_items_for_store(store_type)
	)
	var shelf: Array[ItemInstance] = (
		_inventory_system.get_shelf_items_for_store(store_type)
	)
	var all_items: Array[ItemInstance] = (
		_inventory_system.get_items_for_store(store_type)
	)
	assert_eq(backroom.size(), 1, "Backroom tab should show 1 item")
	assert_eq(shelf.size(), 1, "Shelves tab should show 1 item")
	assert_eq(all_items.size(), 2, "All tab should show 2 items")


func test_search_filter_by_name() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.size() < 2:
		pass_test("Need at least 2 item defs — skip")
		return
	var def_a: ItemDefinition = items[0]
	var def_b: ItemDefinition = items[1]
	_create_test_item(def_a.id, "good", "backroom")
	_create_test_item(def_b.id, "good", "backroom")
	var search_text: String = def_a.item_name.to_lower().substr(0, 3)
	var all_items: Array[ItemInstance] = (
		_inventory_system.get_backroom_items()
	)
	var filtered: Array[ItemInstance] = []
	for item: ItemInstance in all_items:
		if item.definition.item_name.to_lower().find(search_text) != -1:
			filtered.append(item)
	assert_true(
		filtered.size() >= 1,
		"Search should match at least 1 item"
	)


func test_condition_filter() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		pass_test("No item definitions loaded — skip")
		return
	var def: ItemDefinition = items[0]
	_create_test_item(def.id, "mint", "backroom")
	_create_test_item(def.id, "poor", "backroom")
	var all_items: Array[ItemInstance] = (
		_inventory_system.get_backroom_items()
	)
	var mint_only: Array[ItemInstance] = []
	for item: ItemInstance in all_items:
		if item.condition == "mint":
			mint_only.append(item)
	assert_eq(
		mint_only.size(), 1,
		"Condition filter 'mint' should match 1 item"
	)


func test_rarity_filter() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	var common_def: ItemDefinition = null
	var rare_def: ItemDefinition = null
	for def: ItemDefinition in items:
		if def.rarity == "common" and not common_def:
			common_def = def
		elif def.rarity == "rare" and not rare_def:
			rare_def = def
		if common_def and rare_def:
			break
	if not common_def or not rare_def:
		pass_test("Need common + rare items — skip")
		return
	_create_test_item(common_def.id, "good", "backroom")
	_create_test_item(rare_def.id, "good", "backroom")
	var all_items: Array[ItemInstance] = (
		_inventory_system.get_backroom_items()
	)
	var rare_only: Array[ItemInstance] = []
	for item: ItemInstance in all_items:
		if item.definition.rarity == "rare":
			rare_only.append(item)
	assert_eq(
		rare_only.size(), 1,
		"Rarity filter 'rare' should match 1 item"
	)


func test_footer_value_calculation() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		pass_test("No item definitions loaded — skip")
		return
	var def: ItemDefinition = items[0]
	var item_a: ItemInstance = _create_test_item(
		def.id, "good", "backroom"
	)
	var item_b: ItemInstance = _create_test_item(
		def.id, "good", "backroom"
	)
	assert_not_null(item_a)
	assert_not_null(item_b)
	var total: float = item_a.get_current_value() + item_b.get_current_value()
	assert_true(
		total > 0.0,
		"Footer total value should be positive"
	)
	var visible_items: Array[ItemInstance] = [item_a, item_b]
	assert_almost_eq(
		InventoryFilter.total_value(visible_items), total, 0.01,
		"Footer helper should sum item current values"
	)


func test_move_to_backroom_updates_location() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		pass_test("No item definitions loaded — skip")
		return
	var def: ItemDefinition = items[0]
	var item: ItemInstance = _create_test_item(
		def.id, "good", "shelf:slot_01"
	)
	assert_not_null(item)
	assert_true(item.current_location.begins_with("shelf:"))
	_inventory_system.move_item(item.instance_id, "backroom")
	assert_eq(
		item.current_location, "backroom",
		"Item should be in backroom after move"
	)


func test_all_tab_includes_both_locations() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		pass_test("No item definitions loaded — skip")
		return
	var def: ItemDefinition = items[0]
	var store_type: String = def.store_type
	_create_test_item(def.id, "good", "backroom")
	_create_test_item(def.id, "fair", "shelf:slot_02")
	_create_test_item(def.id, "mint", "backroom")
	var all_items: Array[ItemInstance] = (
		_inventory_system.get_items_for_store(store_type)
	)
	assert_eq(
		all_items.size(), 3,
		"All tab should include backroom + shelf items"
	)


func test_get_store_inventory_returns_display_rows() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		pass_test("No item definitions loaded — skip")
		return
	var def: ItemDefinition = items[0]
	var item: ItemInstance = _create_test_item(
		def.id, "good", "backroom"
	)
	assert_not_null(item)
	var rows: Array[Dictionary] = _inventory_system.get_store_inventory(
		StringName(def.store_type)
	)
	assert_eq(rows.size(), 1, "Store inventory should include test item")
	assert_eq(
		rows[0]["display_name"], def.item_name,
		"Display row should expose the content display name"
	)
	assert_eq(
		rows[0]["location"], "backroom",
		"Display row should expose the current location"
	)
	assert_true(
		float(rows[0]["current_price"]) > 0.0,
		"Display row should expose a positive current price"
	)


func test_inventory_row_includes_icon_slot() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		pass_test("No item definitions loaded — skip")
		return
	var item: ItemInstance = _create_test_item(
		items[0].id, "good", "backroom"
	)
	assert_not_null(item)
	var row: PanelContainer = InventoryRowBuilder.build(item)
	var hbox: HBoxContainer = row.get_child(0) as HBoxContainer
	assert_not_null(hbox, "Inventory row should have content container")
	assert_true(
		hbox.get_child(1) is TextureRect,
		"Inventory row should include an icon TextureRect"
	)


func test_context_menu_shows_retire_actions_for_written_off_tape() -> void:
	GameManager.current_store_id = &"rentals"
	var item: ItemInstance = _create_manual_rental_item(
		"written_off_tape",
		"poor",
		"backroom"
	)
	var controller: VideoRentalStoreController = (
		VideoRentalStoreController.new()
	)
	add_child_autofree(controller)
	controller.set_inventory_system(_inventory_system)
	controller._wear_tracker.initialize_item(item.instance_id, item.condition)
	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP):
		controller._wear_tracker.record_return(item.instance_id)

	var panel: InventoryPanel = (
		_INVENTORY_PANEL_SCENE.instantiate() as InventoryPanel
	)
	panel.inventory_system = _inventory_system
	panel.rental_controller = controller
	add_child_autofree(panel)
	panel._show_context_menu(item)

	assert_true(
		_popup_menu_has_text(panel._context_menu, "Retire (Sell)"),
		"Written-off tapes should expose the retirement sale action"
	)
	assert_true(
		_popup_menu_has_text(panel._context_menu, "Write Off"),
		"Written-off tapes should expose the write-off action"
	)


func test_context_menu_hides_retire_actions_for_still_rentable_poor_tape() -> void:
	GameManager.current_store_id = &"rentals"
	var item: ItemInstance = _create_manual_rental_item(
		"poor_but_rentable_tape",
		"poor",
		"backroom"
	)
	var controller: VideoRentalStoreController = (
		VideoRentalStoreController.new()
	)
	add_child_autofree(controller)
	controller.set_inventory_system(_inventory_system)
	controller._wear_tracker.initialize_item(item.instance_id, item.condition)

	var panel: InventoryPanel = (
		_INVENTORY_PANEL_SCENE.instantiate() as InventoryPanel
	)
	panel.inventory_system = _inventory_system
	panel.rental_controller = controller
	add_child_autofree(panel)
	panel._show_context_menu(item)

	assert_false(
		_popup_menu_has_text(panel._context_menu, "Retire (Sell)"),
		"Poor tapes should not show retirement actions before they are written off"
	)
	assert_false(
		_popup_menu_has_text(panel._context_menu, "Write Off"),
		"Poor tapes should not show write-off until the tracker marks them unrentable"
	)


func _create_manual_rental_item(
	instance_id: String,
	condition: String,
	location: String
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "%s_def" % instance_id
	def.item_name = "Tape %s" % instance_id
	def.category = "vhs_tapes"
	def.store_type = "rentals"
	def.base_price = 10.0
	def.rarity = "common"
	var item := ItemInstance.new()
	item.definition = def
	item.instance_id = instance_id
	item.condition = condition
	item.current_location = location
	_inventory_system.register_item(item)
	return item


func _popup_menu_has_text(menu: PopupMenu, text: String) -> bool:
	for index: int in range(menu.get_item_count()):
		if menu.get_item_text(index) == text:
			return true
	return false


func test_move_to_shelf_closes_panel_and_enters_placement_mode() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		pass_test("No item definitions — skip")
		return
	var item: ItemInstance = _create_test_item(items[0].id, "good", "backroom")

	var panel: InventoryPanel = (
		_INVENTORY_PANEL_SCENE.instantiate() as InventoryPanel
	)
	panel.inventory_system = _inventory_system
	add_child_autofree(panel)

	# Directly arm the panel's open state to avoid InputFocus setup in tests.
	# close() needs _is_open true to proceed; _focus_pushed false means
	# _pop_modal_focus returns immediately (no stack pop needed).
	panel._is_open = true
	panel._selected_item = item

	var closed_names: Array[String] = []
	var on_closed: Callable = func(n: String) -> void: closed_names.append(n)
	EventBus.panel_closed.connect(on_closed)

	panel._on_context_action(1)

	EventBus.panel_closed.disconnect(on_closed)

	assert_false(
		panel.is_open(),
		"Panel must close when Move to Shelf is selected"
	)
	assert_true(
		panel._shelf_actions.is_placement_mode,
		"Placement mode must be active after Move to Shelf"
	)
	assert_eq(
		panel._selected_item,
		item,
		"_selected_item must survive close() so the placement click can find it"
	)
	assert_eq(
		closed_names.size(), 1,
		"panel_closed must fire exactly once"
	)

	panel._shelf_actions.exit_placement_mode()


func test_move_to_shelf_does_nothing_when_no_item_selected() -> void:
	var panel: InventoryPanel = (
		_INVENTORY_PANEL_SCENE.instantiate() as InventoryPanel
	)
	panel.inventory_system = _inventory_system
	add_child_autofree(panel)

	panel._is_open = true
	# _selected_item intentionally left null

	panel._on_context_action(1)

	assert_true(
		panel.is_open(),
		"Panel must stay open when no item is selected"
	)
	assert_false(
		panel._shelf_actions.is_placement_mode,
		"Placement mode must not activate without a selected item"
	)


func _find_label_by_name(parent: Node, target_name: String) -> Label:
	if parent is Label and parent.name == target_name:
		return parent as Label
	for child: Node in parent.get_children():
		var found: Label = _find_label_by_name(child, target_name)
		if found != null:
			return found
	return null


func test_row_renders_backroom_and_shelf_quantity_labels() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		pass_test("No item definitions loaded — skip")
		return
	var def: ItemDefinition = items[0]
	_create_test_item(def.id, "good", "backroom")
	_create_test_item(def.id, "good", "backroom")
	_create_test_item(def.id, "fair", "shelf:slot_01")
	var quantities: Dictionary = {
		def.id: {"backroom": 2, "on_shelf": 1},
	}
	var any_item: ItemInstance = _inventory_system.get_items_for_store(
		def.store_type
	)[0]
	var row: PanelContainer = InventoryRowBuilder.build(
		any_item, null, quantities
	)
	var backroom_label: Label = _find_label_by_name(row, "BackroomQtyLabel")
	var shelf_label: Label = _find_label_by_name(row, "ShelfQtyLabel")
	assert_not_null(
		backroom_label,
		"Row must include a Backroom quantity label"
	)
	assert_not_null(shelf_label, "Row must include a Shelf quantity label")
	assert_string_contains(
		backroom_label.text, "2", "Backroom qty label must show count"
	)
	assert_string_contains(
		shelf_label.text, "1", "Shelf qty label must show count"
	)


func test_row_quantity_labels_default_to_zero_when_missing() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		pass_test("No item definitions loaded — skip")
		return
	var def: ItemDefinition = items[0]
	var item: ItemInstance = _create_test_item(def.id, "good", "backroom")
	# No quantities map — the row builder must fall back to zero.
	var row: PanelContainer = InventoryRowBuilder.build(item)
	var backroom_label: Label = _find_label_by_name(row, "BackroomQtyLabel")
	var shelf_label: Label = _find_label_by_name(row, "ShelfQtyLabel")
	assert_string_contains(
		backroom_label.text, "0", "Missing entry must render Backroom: 0"
	)
	assert_string_contains(
		shelf_label.text, "0", "Missing entry must render Shelf: 0"
	)


func test_quantity_map_aggregates_per_definition() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.size() < 2:
		pass_test("Need at least 2 item defs — skip")
		return
	var def_a: ItemDefinition = items[0]
	var def_b: ItemDefinition = null
	for candidate: ItemDefinition in items:
		if candidate.store_type == def_a.store_type and candidate.id != def_a.id:
			def_b = candidate
			break
	if def_b == null:
		pass_test("Need two item defs in the same store — skip")
		return
	_create_test_item(def_a.id, "good", "backroom")
	_create_test_item(def_a.id, "good", "backroom")
	_create_test_item(def_a.id, "good", "shelf:slot_01")
	_create_test_item(def_b.id, "good", "shelf:slot_02")
	var rows: Array[Dictionary] = _inventory_system.get_store_inventory(
		StringName(def_a.store_type)
	)
	var qty_map: Dictionary = InventoryPanel._build_quantity_map(rows)
	assert_true(qty_map.has(def_a.id), "Map must include def A")
	assert_true(qty_map.has(def_b.id), "Map must include def B")
	assert_eq(int(qty_map[def_a.id]["backroom"]), 2)
	assert_eq(int(qty_map[def_a.id]["on_shelf"]), 1)
	assert_eq(int(qty_map[def_b.id]["backroom"]), 0)
	assert_eq(int(qty_map[def_b.id]["on_shelf"]), 1)


func test_select_button_triggers_placement_mode_for_backroom_item() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		pass_test("No item definitions — skip")
		return
	var item: ItemInstance = _create_test_item(items[0].id, "good", "backroom")
	var panel: InventoryPanel = (
		_INVENTORY_PANEL_SCENE.instantiate() as InventoryPanel
	)
	panel.inventory_system = _inventory_system
	add_child_autofree(panel)
	panel._is_open = true

	panel._on_select_for_placement(item, PanelContainer.new())

	assert_false(panel.is_open(), "Select must close the panel")
	assert_true(
		panel._shelf_actions.is_placement_mode,
		"Select must enter placement mode"
	)
	assert_eq(
		panel._selected_item, item,
		"Selected item must persist into placement mode"
	)
	panel._shelf_actions.exit_placement_mode()


func test_refresh_with_empty_store_id_falls_back_safely() -> void:
	var panel: InventoryPanel = (
		_INVENTORY_PANEL_SCENE.instantiate() as InventoryPanel
	)
	panel.inventory_system = _inventory_system
	add_child_autofree(panel)
	panel.store_id = ""
	# Should emit push_warning and render the empty state without crashing.
	panel._refresh_grid()
	assert_eq(
		panel._footer_count.text, "No active store",
		"Empty store must surface the no-store footer"
	)


func test_select_button_only_added_for_backroom_items() -> void:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		pass_test("No item definitions — skip")
		return
	var def: ItemDefinition = items[0]
	var backroom_item: ItemInstance = _create_test_item(
		def.id, "good", "backroom"
	)
	var shelf_item: ItemInstance = _create_test_item(
		def.id, "good", "shelf:slot_01"
	)
	var panel: InventoryPanel = (
		_INVENTORY_PANEL_SCENE.instantiate() as InventoryPanel
	)
	panel.inventory_system = _inventory_system
	panel.store_id = def.store_type
	add_child_autofree(panel)
	panel._add_item_row(backroom_item)
	panel._add_item_row(shelf_item)

	# Each row's overlay button is the second child of the PanelContainer.
	# A Select button, when added, parents under that overlay.
	var rows: Array[Node] = panel._grid.get_children()
	assert_eq(rows.size(), 2, "Both rows must render")
	var backroom_row: PanelContainer = rows[0] as PanelContainer
	var shelf_row: PanelContainer = rows[1] as PanelContainer
	var backroom_overlay: Button = backroom_row.get_child(1) as Button
	var shelf_overlay: Button = shelf_row.get_child(1) as Button
	assert_true(
		backroom_overlay.get_child_count() >= 1,
		"Backroom row's overlay must host a Select button child"
	)
	assert_eq(
		shelf_overlay.get_child_count(), 0,
		"Shelf row must not show a Select button"
	)
