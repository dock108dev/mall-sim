## Tests that active_store_changed signal propagates to all UI panels.
extends GutTest

const _INVENTORY_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/inventory_panel.tscn"
)
const _ORDER_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/order_panel.tscn"
)
const _STAFF_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/staff_panel.tscn"
)
const _TRENDS_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/trends_panel.tscn"
)


var _signals_received: Array[Dictionary] = []
var _saved_store_id: StringName = &""
var _saved_data_loader: DataLoader
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _reputation_system: ReputationSystem
var _progression_system: ProgressionSystem
var _order_system: OrderSystem
var _trend_system: TrendSystem


func before_each() -> void:
	_signals_received.clear()
	_saved_store_id = GameManager.current_store_id
	_saved_data_loader = GameManager.data_loader
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()
	GameManager.data_loader = DataLoaderSingleton
	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(GameManager.data_loader)
	_economy_system = EconomySystem.new()
	add_child_autofree(_economy_system)
	_economy_system.initialize()
	_reputation_system = ReputationSystem.new()
	add_child_autofree(_reputation_system)
	_progression_system = ProgressionSystem.new()
	add_child_autofree(_progression_system)
	_progression_system.initialize(_economy_system, _reputation_system)
	_order_system = OrderSystem.new()
	add_child_autofree(_order_system)
	_order_system.initialize(
		_inventory_system, _reputation_system, _progression_system
	)
	_trend_system = TrendSystem.new()
	add_child_autofree(_trend_system)
	_trend_system.initialize(GameManager.data_loader)


func after_each() -> void:
	GameManager.current_store_id = _saved_store_id
	GameManager.data_loader = _saved_data_loader


func test_active_store_changed_signal_exists() -> void:
	assert_true(
		EventBus.has_signal("active_store_changed"),
		"EventBus should have active_store_changed signal"
	)


func test_active_store_changed_emits_on_connect() -> void:
	EventBus.active_store_changed.connect(_on_store_changed)
	EventBus.active_store_changed.emit(&"retro_games")
	assert_eq(
		_signals_received.size(), 1,
		"Should receive one signal emission"
	)
	assert_eq(
		_signals_received[0]["store_id"], &"retro_games",
		"Should receive correct store_id"
	)
	EventBus.active_store_changed.disconnect(_on_store_changed)


func test_active_store_changed_empty_on_exit() -> void:
	EventBus.active_store_changed.connect(_on_store_changed)
	EventBus.active_store_changed.emit(&"")
	assert_eq(
		_signals_received.size(), 1,
		"Should receive signal on hallway exit"
	)
	assert_eq(
		_signals_received[0]["store_id"], &"",
		"Store ID should be empty on hallway exit"
	)
	EventBus.active_store_changed.disconnect(_on_store_changed)


func test_multiple_store_switches() -> void:
	EventBus.active_store_changed.connect(_on_store_changed)
	EventBus.active_store_changed.emit(&"retro_games")
	EventBus.active_store_changed.emit(&"")
	EventBus.active_store_changed.emit(&"electronics")
	assert_eq(
		_signals_received.size(), 3,
		"Should receive three signal emissions"
	)
	assert_eq(
		_signals_received[0]["store_id"], &"retro_games",
		"First switch to retro_games"
	)
	assert_eq(
		_signals_received[1]["store_id"], &"",
		"Second switch to hallway"
	)
	assert_eq(
		_signals_received[2]["store_id"], &"electronics",
		"Third switch to electronics"
	)
	EventBus.active_store_changed.disconnect(_on_store_changed)


func test_inventory_panel_refreshes_when_store_changes() -> void:
	if not _store_has_items("retro_games") or not _store_has_items("electronics"):
		pass_test("Required store content unavailable")
		return
	GameManager.current_store_id = &"retro_games"
	var panel: InventoryPanel = (
		_INVENTORY_PANEL_SCENE.instantiate() as InventoryPanel
	)
	panel.inventory_system = _inventory_system
	add_child_autofree(panel)
	_register_item("retro_games", "backroom")
	_register_item("electronics", "backroom")
	panel.open()
	assert_eq(panel.store_id, "retro_games")
	assert_eq(panel._grid.get_child_count(), 1)
	EventBus.active_store_changed.emit(&"electronics")
	await get_tree().process_frame
	assert_eq(panel.store_id, "electronics")
	assert_eq(panel._grid.get_child_count(), 1)
	EventBus.active_store_changed.emit(&"")
	await get_tree().process_frame
	assert_true(panel.is_open(), "Inventory panel should stay open in hallway")
	assert_true(panel._empty_label.visible)
	assert_eq(panel._footer_count.text, "No active store")


func test_order_panel_refreshes_and_inactivates_on_store_change() -> void:
	if GameManager.data_loader == null:
		pass_test("GameManager.data_loader unavailable")
		return
	GameManager.current_store_id = &"retro_games"
	var panel: OrderPanel = _ORDER_PANEL_SCENE.instantiate() as OrderPanel
	panel.order_system = _order_system
	panel.economy_system = _economy_system
	add_child_autofree(panel)
	panel.open()
	assert_eq(panel.store_type, "retro_games")
	assert_gt(panel._tier_tabs.get_child_count(), 0)
	EventBus.active_store_changed.emit(&"")
	await get_tree().process_frame
	assert_true(panel.is_open(), "Order panel should stay open in hallway")
	assert_true(panel._empty_label.visible)
	assert_eq(panel._empty_label.text, "No active store selected")
	assert_eq(panel._title_label.text, "Stock Orders (No active store)")


func test_staff_panel_shows_inactive_state_in_hallway() -> void:
	GameManager.current_store_id = &"retro_games"
	var panel: StaffPanel = _STAFF_PANEL_SCENE.instantiate() as StaffPanel
	add_child_autofree(panel)
	panel.open()
	assert_true(panel._is_open)
	EventBus.active_store_changed.emit(&"")
	await get_tree().process_frame
	assert_true(panel._is_open, "Staff panel should stay open in hallway")
	assert_eq(panel._capacity_label.text, "No active store")
	assert_eq(panel._current_staff_list.get_child_count(), 1)
	assert_eq(panel._hire_list.get_child_count(), 1)


func test_trends_panel_filters_to_active_store_and_clears_in_hallway() -> void:
	if GameManager.data_loader == null:
		pass_test("GameManager.data_loader unavailable")
		return
	GameManager.current_store_id = &"retro_games"
	var panel: TrendsPanel = (
		_TRENDS_PANEL_SCENE.instantiate() as TrendsPanel
	)
	panel.trend_system = _trend_system
	add_child_autofree(panel)
	_inject_category_trend("cartridges")
	_inject_category_trend("portable_audio")
	panel.open_panel()
	assert_eq(panel._trend_list.get_child_count(), 1)
	EventBus.active_store_changed.emit(&"electronics")
	await get_tree().process_frame
	assert_eq(panel._trend_list.get_child_count(), 1)
	var row: HBoxContainer = panel._trend_list.get_child(0) as HBoxContainer
	var label: Label = row.get_child(1) as Label
	assert_eq(label.text, "portable_audio")
	EventBus.active_store_changed.emit(&"")
	await get_tree().process_frame
	assert_true(panel._empty_state.visible)


func _on_store_changed(store_id: StringName) -> void:
	_signals_received.append({"store_id": store_id})


func _register_item(store_id: String, location: String) -> void:
	var items: Array[ItemDefinition] = GameManager.data_loader.get_items_by_store(
		store_id
	)
	var item: ItemInstance = ItemInstance.create(
		items[0], "good", 0, items[0].base_price
	)
	item.current_location = location
	_inventory_system.register_item(item)


func _inject_category_trend(category: String) -> void:
	var current_day: int = GameManager.current_day
	_trend_system._active_trends.append({
		"target_type": "category",
		"target": category,
		"trend_type": TrendSystem.TrendType.HOT,
		"multiplier": 1.5,
		"announced_day": current_day - 1,
		"active_day": current_day - 1,
		"end_day": current_day + 2,
		"fade_end_day": current_day + 4,
	})


func _store_has_items(store_id: String) -> bool:
	if GameManager.data_loader == null:
		return false
	return not GameManager.data_loader.get_items_by_store(store_id).is_empty()
