## Pins the F8–F11 dev shortcuts on the debug overlay:
##   F8  — spawn customer (routes to MallCustomerSpawner.debug_spawn_customer)
##   F9  — add starter inventory items to the active store backroom
##   F10 — auto-stock first backroom item via StoreController.dev_force_place_test_item
##   F11 — force-complete the next pending sale via PlayerCheckout.dev_force_complete_sale
##
## All four are gated by OS.is_debug_build(); release builds queue_free in
## DebugOverlay._ready and the handlers never run. The overlay HUD label must
## advertise the four shortcuts alongside the existing Ctrl+ chord set.
extends GutTest


const _OverlayScene: PackedScene = preload(
	"res://game/scenes/debug/debug_overlay.tscn"
)


class _RecordingSpawner extends MallCustomerSpawner:
	var spawn_calls: int = 0

	func debug_spawn_customer() -> void:
		spawn_calls += 1


class _RecordingCheckout extends PlayerCheckout:
	var force_calls: int = 0
	var return_value: bool = true

	func dev_force_complete_sale() -> bool:
		force_calls += 1
		return return_value


func _make_overlay() -> CanvasLayer:
	var overlay: CanvasLayer = _OverlayScene.instantiate()
	add_child_autofree(overlay)
	return overlay


func _press(keycode: int) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	return ev


func test_f8_routes_to_mall_spawner_debug_spawn() -> void:
	var overlay: CanvasLayer = _make_overlay()
	var spawner: _RecordingSpawner = _RecordingSpawner.new()
	add_child_autofree(spawner)
	overlay.mall_customer_spawner = spawner
	overlay._input(_press(KEY_F8))
	assert_eq(
		spawner.spawn_calls, 1,
		"F8 must call MallCustomerSpawner.debug_spawn_customer exactly once"
	)


func test_f11_routes_to_checkout_dev_force_complete_sale() -> void:
	var overlay: CanvasLayer = _make_overlay()
	var checkout: _RecordingCheckout = _RecordingCheckout.new()
	add_child_autofree(checkout)
	overlay.checkout_system = checkout
	overlay._input(_press(KEY_F11))
	assert_eq(
		checkout.force_calls, 1,
		"F11 must call PlayerCheckout.dev_force_complete_sale exactly once"
	)


func test_f9_adds_starter_inventory_to_active_store_backroom() -> void:
	var loader: DataLoader = DataLoader.new()
	add_child_autofree(loader)
	loader.load_all_content()
	var prev_loader: DataLoader = GameManager.data_loader
	var prev_store_id: StringName = GameManager.current_store_id
	GameManager.data_loader = loader
	GameManager.current_store_id = &"retro_games"

	var inv: InventorySystem = InventorySystem.new()
	add_child_autofree(inv)
	inv.initialize(loader)

	var overlay: CanvasLayer = _make_overlay()
	overlay.inventory_system = inv

	var before: int = inv.get_backroom_items_for_store("retro_games").size()
	overlay._input(_press(KEY_F9))
	var after: int = inv.get_backroom_items_for_store("retro_games").size()

	assert_gt(
		after, before,
		"F9 must add at least one starter item to the active store's backroom"
	)

	GameManager.current_store_id = prev_store_id
	GameManager.data_loader = prev_loader


func test_f10_does_not_crash_without_store_controller() -> void:
	# F10 routes to StoreController.dev_force_place_test_item via the overlay
	# helper. With no StoreController in the scene tree the helper push_warns
	# and returns; this exercises the routing surface without exploding.
	var overlay: CanvasLayer = _make_overlay()
	overlay._input(_press(KEY_F10))
	pass_test("F10 route did not crash with no StoreController present")


func test_overlay_label_advertises_function_key_shortcuts() -> void:
	var overlay: CanvasLayer = _make_overlay()
	var text: String = overlay.call("_build_display_text") as String
	assert_string_contains(
		text, "F8: Spawn customer",
		"label must advertise F8 as the spawn-customer shortcut"
	)
	assert_string_contains(
		text, "F9: Add test inventory",
		"label must advertise F9 as the add-test-inventory shortcut"
	)
	assert_string_contains(
		text, "F10: Auto-stock first item",
		"label must advertise F10 as the auto-stock shortcut"
	)
	assert_string_contains(
		text, "F11: Force sale",
		"label must advertise F11 as the force-sale shortcut"
	)


# --- Direct unit tests for PlayerCheckout.dev_force_complete_sale ---


var _direct_checkout: PlayerCheckout
var _direct_economy: EconomySystem
var _direct_inventory: InventorySystem
var _direct_reputation: ReputationSystem
var _direct_customer_system: CustomerSystem
var _direct_definition: ItemDefinition
var _direct_item: ItemInstance
var _direct_profile: CustomerTypeDefinition
var _direct_sold: Array[Dictionary] = []


func _direct_before() -> void:
	_direct_economy = EconomySystem.new()
	add_child_autofree(_direct_economy)
	_direct_economy.initialize(1000.0)

	_direct_inventory = InventorySystem.new()
	add_child_autofree(_direct_inventory)

	_direct_reputation = ReputationSystem.new()
	add_child_autofree(_direct_reputation)

	_direct_customer_system = CustomerSystem.new()
	add_child_autofree(_direct_customer_system)

	_direct_checkout = PlayerCheckout.new()
	add_child_autofree(_direct_checkout)
	_direct_checkout.initialize(
		_direct_economy, _direct_inventory,
		_direct_customer_system, _direct_reputation
	)

	_direct_profile = CustomerTypeDefinition.new()
	_direct_profile.id = "test_buyer"
	_direct_profile.customer_name = "Test Buyer"
	_direct_profile.budget_range = [5.0, 500.0]
	_direct_profile.patience = 0.8
	_direct_profile.price_sensitivity = 0.5
	_direct_profile.preferred_categories = PackedStringArray([])
	_direct_profile.preferred_tags = PackedStringArray([])
	_direct_profile.condition_preference = "good"
	_direct_profile.browse_time_range = [30.0, 60.0]
	_direct_profile.purchase_probability_base = 0.9
	_direct_profile.impulse_buy_chance = 0.1
	_direct_profile.mood_tags = PackedStringArray([])

	_direct_definition = ItemDefinition.new()
	_direct_definition.id = "test_item"
	_direct_definition.item_name = "Test Item"
	_direct_definition.category = "cards"
	_direct_definition.base_price = 100.0
	_direct_definition.rarity = "common"
	_direct_definition.tags = PackedStringArray([])
	_direct_definition.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)
	_direct_definition.store_type = "pocket_creatures"

	_direct_item = ItemInstance.create_from_definition(
		_direct_definition, "good"
	)
	_direct_item.player_set_price = 100.0
	_direct_inventory._items[_direct_item.instance_id] = _direct_item

	_direct_sold = []
	EventBus.item_sold.connect(_on_direct_sold)


func _direct_after() -> void:
	if EventBus.item_sold.is_connected(_on_direct_sold):
		EventBus.item_sold.disconnect(_on_direct_sold)


func _on_direct_sold(
	item_id: String, price: float, category: String
) -> void:
	_direct_sold.append({
		"item_id": item_id, "price": price, "category": category
	})


func _make_direct_customer() -> Customer:
	var scene: PackedScene = preload(
		"res://game/scenes/characters/customer.tscn"
	)
	var customer: Customer = scene.instantiate()
	add_child_autofree(customer)
	customer.profile = _direct_profile
	return customer


func test_dev_force_complete_sale_finalizes_in_flight_sale() -> void:
	_direct_before()
	var customer: Customer = _make_direct_customer()
	var initial_cash: float = _direct_economy.get_cash()
	var sale_price: float = 80.0
	# initiate_sale puts the checkout into _is_processing with the timer
	# ticking; dev_force_complete_sale must short-circuit the wait and run
	# _execute_sale → _complete_checkout right away.
	_direct_checkout.initiate_sale(customer, _direct_item, sale_price)
	assert_true(
		_direct_checkout._is_processing,
		"sanity: initiate_sale must set _is_processing"
	)
	var ok: bool = _direct_checkout.dev_force_complete_sale()
	assert_true(ok, "dev_force_complete_sale must return true on in-flight sale")
	assert_almost_eq(
		_direct_economy.get_cash(), initial_cash + sale_price, 0.01,
		"cash must increase by the agreed price after force-complete"
	)
	assert_false(
		_direct_inventory._items.has(_direct_item.instance_id),
		"item must be removed from inventory after force-complete"
	)
	assert_eq(
		_direct_sold.size(), 1,
		"item_sold must fire exactly once on force-complete"
	)
	_direct_after()


func test_dev_force_complete_sale_returns_false_when_idle() -> void:
	_direct_before()
	# No active customer, no waiting customer in queue → nothing to complete.
	var ok: bool = _direct_checkout.dev_force_complete_sale()
	assert_false(
		ok,
		"dev_force_complete_sale must return false when there is no pending sale"
	)
	_direct_after()
