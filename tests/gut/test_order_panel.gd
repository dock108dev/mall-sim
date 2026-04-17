## Tests OrderPanel catalog filtering, cart flow, and active-store refresh.
extends GutTest

const _ORDER_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/order_panel.tscn"
)

var _order_system: OrderSystem
var _inventory_system: InventorySystem
var _reputation_system: ReputationSystem
var _progression_system: ProgressionSystem
var _economy_system: EconomySystem
var _saved_data_loader: DataLoader
var _saved_store_id: StringName = &""


func before_each() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()
	_saved_data_loader = GameManager.data_loader
	_saved_store_id = GameManager.current_store_id
	GameManager.data_loader = DataLoaderSingleton
	GameManager.current_store_id = &""

	_economy_system = EconomySystem.new()
	_economy_system.name = "EconomySystem"
	add_child_autofree(_economy_system)
	_economy_system.initialize()

	_inventory_system = InventorySystem.new()
	_inventory_system.name = "InventorySystem"
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(GameManager.data_loader)

	_reputation_system = ReputationSystem.new()
	_reputation_system.name = "ReputationSystem"
	add_child_autofree(_reputation_system)

	_progression_system = ProgressionSystem.new()
	_progression_system.name = "ProgressionSystem"
	add_child_autofree(_progression_system)
	_progression_system.initialize(_economy_system, _reputation_system)

	_order_system = OrderSystem.new()
	_order_system.name = "OrderSystem"
	add_child_autofree(_order_system)
	_order_system.initialize(
		_inventory_system, _reputation_system, _progression_system
	)


func after_each() -> void:
	GameManager.data_loader = _saved_data_loader
	GameManager.current_store_id = _saved_store_id


func test_tier_tabs_include_locked_badges_with_tooltips() -> void:
	var store_id: StringName = _find_store_with_basic_items()
	if store_id.is_empty():
		pending("Need a store with at least one basic-tier item")
		return
	var panel: OrderPanel = _open_panel(store_id)
	assert_eq(
		panel._tier_tabs.get_child_count(), 4,
		"Order panel should render all supplier tier badges"
	)
	var has_locked_badge: bool = false
	for child: Node in panel._tier_tabs.get_children():
		var button: Button = child as Button
		if button == null or not button.disabled:
			continue
		has_locked_badge = true
		assert_false(
			button.tooltip_text.is_empty(),
			"Locked supplier tiers should explain their requirement"
		)
		break
	assert_true(
		has_locked_badge,
		"Panel should show at least one locked supplier tier badge at baseline"
	)


func test_search_and_rarity_filter_update_catalog_in_real_time() -> void:
	var store_id: StringName = _find_store_with_basic_rarities(
		PackedStringArray(["common", "uncommon"])
	)
	if store_id.is_empty():
		pending("Need a store with both common and uncommon basic-tier items")
		return
	var panel: OrderPanel = _open_panel(store_id)
	var common_item: ItemDefinition = _find_basic_item(store_id, "common")
	var uncommon_item: ItemDefinition = _find_basic_item(
		store_id, "uncommon"
	)
	assert_not_null(common_item)
	assert_not_null(uncommon_item)
	var initial_count: int = panel._catalog_grid.get_child_count()
	panel._search_field.text = common_item.item_name
	panel._on_search_changed(common_item.item_name)
	await get_tree().process_frame
	assert_eq(
		panel._catalog_grid.get_child_count(), 1,
		"Search should narrow the catalog to the matching item"
	)
	panel._search_field.text = ""
	panel._on_search_changed("")
	panel._rarity_filter.selected = _rarity_filter_index("uncommon")
	panel._on_filter_changed(panel._rarity_filter.selected)
	await get_tree().process_frame
	var uncommon_count: int = _count_basic_items_by_rarity(
		store_id, "uncommon"
	)
	assert_eq(
		panel._catalog_grid.get_child_count(), uncommon_count,
		"Rarity filter should keep only uncommon supplier items"
	)
	assert_lt(
		panel._catalog_grid.get_child_count(), initial_count,
		"Rarity filter should reduce the visible catalog entries"
	)


func test_add_to_cart_updates_total_and_limit_progress() -> void:
	var store_id: StringName = _find_store_with_basic_items()
	if store_id.is_empty():
		pending("Need a store with at least one basic-tier item")
		return
	var panel: OrderPanel = _open_panel(store_id)
	var item_def: ItemDefinition = _find_basic_item(store_id)
	assert_not_null(item_def)
	panel._on_add_to_cart(item_def)
	panel._on_add_to_cart(item_def)
	await get_tree().process_frame
	assert_eq(panel._cart.size(), 1, "Cart should combine duplicate items")
	assert_eq(
		int(panel._cart[0]["quantity"]), 2,
		"Adding the same item twice should increment quantity"
	)
	assert_false(
		panel._submit_button.disabled,
		"Submit should enable once the cart has items"
	)
	assert_gt(
		panel._limit_bar.value, 0.0,
		"Daily limit progress should reflect cart spending"
	)
	assert_eq(
		panel._total_label.text,
		"Total: $%.2f" % (
			_order_system.get_order_cost(
				item_def, OrderSystem.SupplierTier.BASIC
			) * 2.0
		),
		"Cart total should show the aggregated line-item cost"
	)


func test_submit_order_clears_cart_and_refreshes_deliveries() -> void:
	var store_id: StringName = _find_store_with_basic_items()
	if store_id.is_empty():
		pending("Need a store with at least one basic-tier item")
		return
	var panel: OrderPanel = _open_panel(store_id)
	var item_def: ItemDefinition = _find_basic_item(store_id)
	assert_not_null(item_def)
	panel._on_add_to_cart(item_def)
	panel._on_submit_pressed()
	await get_tree().process_frame
	assert_eq(
		_order_system.get_pending_orders_for_store(store_id).size(), 1,
		"Successful submission should create a pending delivery"
	)
	assert_true(panel._cart.is_empty(), "Successful submission should clear the cart")
	assert_false(
		panel._error_label.visible,
		"Successful submission should not leave an inline error visible"
	)
	var delivery_row: Label = panel._deliveries_grid.get_child(0) as Label
	assert_not_null(delivery_row, "Deliveries list should show the new pending order")
	assert_string_contains(
		delivery_row.text, "arrives day",
		"Delivery row should include the estimated arrival day"
	)


func test_submit_order_shows_inline_error_when_cash_is_insufficient() -> void:
	var store_id: StringName = _find_store_with_basic_items()
	if store_id.is_empty():
		pending("Need a store with at least one basic-tier item")
		return
	var panel: OrderPanel = _open_panel(store_id)
	var item_def: ItemDefinition = _find_basic_item(store_id)
	assert_not_null(item_def)
	panel._on_add_to_cart(item_def)
	_economy_system.load_save_data({
		"player_cash": 0.0,
		"current_cash": 0.0,
	})
	panel._on_submit_pressed()
	await get_tree().process_frame
	assert_true(panel.is_open(), "Panel should remain open after submission failure")
	assert_true(
		panel._error_label.visible,
		"Insufficient cash should be surfaced inline"
	)
	assert_eq(
		panel._error_label.text, "Insufficient funds",
		"Failure reason should match the backend rejection"
	)
	assert_eq(
		_order_system.get_pending_orders_for_store(store_id).size(), 0,
		"Failed submissions must not create pending deliveries"
	)


func test_active_store_changed_reloads_the_catalog() -> void:
	var first_store: StringName = _find_store_with_basic_items()
	var second_store: StringName = _find_store_with_basic_items(first_store)
	if first_store.is_empty() or second_store.is_empty():
		pending("Need two stores with basic-tier supplier items")
		return
	var panel: OrderPanel = _open_panel(first_store)
	var expected_second_count: int = _get_basic_tier_items(second_store).size()
	assert_gt(
		expected_second_count, 0,
		"Second store should have supplier items to display"
	)
	EventBus.active_store_changed.emit(second_store)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(
		panel.store_type, String(second_store),
		"Panel should track the newly active store"
	)
	assert_eq(
		panel._catalog_grid.get_child_count(), expected_second_count,
		"Catalog should reload for the newly active store"
	)
	assert_true(panel._cart.is_empty(), "Store changes should clear the cart")


func _open_panel(store_id: StringName) -> OrderPanel:
	GameManager.current_store_id = store_id
	var panel: OrderPanel = _ORDER_PANEL_SCENE.instantiate() as OrderPanel
	panel.order_system = _order_system
	panel.economy_system = _economy_system
	add_child_autofree(panel)
	panel.open()
	return panel


func _find_store_with_basic_items(exclude_store: StringName = &"") -> StringName:
	for store_def: StoreDefinition in GameManager.data_loader.get_all_stores():
		var store_id: StringName = StringName(store_def.id)
		if store_id == exclude_store:
			continue
		if not _get_basic_tier_items(store_id).is_empty():
			return store_id
	return &""


func _find_store_with_basic_rarities(
	required_rarities: PackedStringArray,
) -> StringName:
	for store_def: StoreDefinition in GameManager.data_loader.get_all_stores():
		var store_id: StringName = StringName(store_def.id)
		var items: Array[ItemDefinition] = _get_basic_tier_items(store_id)
		if items.size() < required_rarities.size():
			continue
		var found_rarities: Dictionary = {}
		for item_def: ItemDefinition in items:
			found_rarities[item_def.rarity] = true
		var has_all_rarities: bool = true
		for rarity: String in required_rarities:
			if not found_rarities.has(rarity):
				has_all_rarities = false
				break
		if has_all_rarities:
			return store_id
	return &""


func _get_basic_tier_items(store_id: StringName) -> Array[ItemDefinition]:
	var items: Array[ItemDefinition] = []
	var store_items: Array[ItemDefinition] = GameManager.data_loader.get_items_by_store(
		String(store_id)
	)
	for item_def: ItemDefinition in store_items:
		if _order_system.is_item_in_tier_catalog(
			item_def, OrderSystem.SupplierTier.BASIC
		):
			items.append(item_def)
	return items


func _find_basic_item(
	store_id: StringName, rarity: String = ""
) -> ItemDefinition:
	for item_def: ItemDefinition in _get_basic_tier_items(store_id):
		if rarity.is_empty() or item_def.rarity == rarity:
			return item_def
	return null


func _count_basic_items_by_rarity(
	store_id: StringName, rarity: String
) -> int:
	var count: int = 0
	for item_def: ItemDefinition in _get_basic_tier_items(store_id):
		if item_def.rarity == rarity:
			count += 1
	return count


func _rarity_filter_index(rarity: String) -> int:
	return InventoryFilter.RARITIES.find(rarity) + 1
