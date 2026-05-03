## Tests for the customer_item_spotted EventBus signal — emission from
## Customer._evaluate_current_shelf, AmbientMomentsSystem toast + dedup
## handling, and TutorialSystem WAIT_FOR_CUSTOMER advance wiring.
extends GutTest


class FakeInventory extends InventorySystem:
	var items_by_location: Dictionary = {}

	func get_items_at_location(location: String) -> Array[ItemInstance]:
		var typed: Array[ItemInstance] = []
		for entry: ItemInstance in items_by_location.get(location, []):
			typed.append(entry)
		return typed


class FakeShelfSlot extends Node3D:
	var slot_id: String = "shelf_a"


var _profile: CustomerTypeDefinition
var _saved_tutorial_active: bool


func before_each() -> void:
	_saved_tutorial_active = GameManager.is_tutorial_active
	_profile = _make_profile()


func after_each() -> void:
	GameManager.is_tutorial_active = _saved_tutorial_active


# ── Customer emission ────────────────────────────────────────────────────────


func test_first_desirable_item_emits_customer_item_spotted() -> void:
	var inv := FakeInventory.new()
	add_child_autofree(inv)
	var slot := FakeShelfSlot.new()
	add_child_autofree(slot)
	var item: ItemInstance = _make_item("retro_a", 12.0)
	inv.items_by_location["shelf:%s" % slot.slot_id] = [item]

	var customer: Customer = _make_customer(inv)
	customer._current_target_slot = slot

	var emissions: Array = []
	var cb: Callable = func(c: Customer, i: ItemInstance) -> void:
		emissions.append({"customer": c, "item": i})
	EventBus.customer_item_spotted.connect(cb)

	customer._evaluate_current_shelf()
	EventBus.customer_item_spotted.disconnect(cb)

	assert_eq(emissions.size(), 1, "First desirable item must emit once")
	assert_eq(
		emissions[0]["customer"], customer,
		"Emission should carry the spotting customer"
	)
	assert_eq(
		emissions[0]["item"], item,
		"Emission should carry the desired item"
	)


func test_upgrade_to_better_item_emits_again() -> void:
	var inv := FakeInventory.new()
	add_child_autofree(inv)
	var slot_a := FakeShelfSlot.new()
	slot_a.slot_id = "shelf_a"
	add_child_autofree(slot_a)
	var slot_b := FakeShelfSlot.new()
	slot_b.slot_id = "shelf_b"
	add_child_autofree(slot_b)

	var cheap_item: ItemInstance = _make_item("retro_cheap", 12.0)
	var pricier_item: ItemInstance = _make_item("retro_pricey", 80.0)
	inv.items_by_location["shelf:%s" % slot_a.slot_id] = [cheap_item]
	inv.items_by_location["shelf:%s" % slot_b.slot_id] = [pricier_item]

	var customer: Customer = _make_customer(inv)

	var emissions: Array[ItemInstance] = []
	var cb: Callable = func(_c: Customer, i: ItemInstance) -> void:
		emissions.append(i)
	EventBus.customer_item_spotted.connect(cb)

	customer._current_target_slot = slot_a
	customer._evaluate_current_shelf()
	customer._current_target_slot = slot_b
	customer._evaluate_current_shelf()
	EventBus.customer_item_spotted.disconnect(cb)

	assert_eq(emissions.size(), 2, "Site A then Site B must emit twice")
	assert_eq(emissions[0], cheap_item, "First emission is the initial item")
	assert_eq(
		emissions[1], pricier_item,
		"Second emission is the higher-scored upgrade"
	)


# ── AmbientMomentsSystem toast + dedup ───────────────────────────────────────


func test_toast_posted_on_first_customer_item_spotted() -> void:
	var sys := AmbientMomentsSystem.new()
	add_child_autofree(sys)
	sys._connect_signals()

	var customer: Customer = _make_customer(null)
	var item: ItemInstance = _make_item("retro_a", 12.0)
	item.definition.item_name = "Used Cartridge Game"

	var toasts: Array = []
	var cb: Callable = func(message: String, category: StringName, duration: float) -> void:
		toasts.append({
			"message": message,
			"category": category,
			"duration": duration,
		})
	EventBus.toast_requested.connect(cb)

	EventBus.customer_item_spotted.emit(customer, item)
	EventBus.toast_requested.disconnect(cb)

	assert_eq(toasts.size(), 1, "First spot should emit exactly one toast")
	assert_eq(
		toasts[0]["message"],
		"Customer browsing: Used Cartridge Game",
		"Toast text must follow the 'Customer browsing: <name>' format"
	)
	assert_eq(
		toasts[0]["category"], &"customer",
		"Customer-browsing toasts use the 'customer' category"
	)
	assert_gt(
		float(toasts[0]["duration"]), 0.0,
		"Toast duration must be positive"
	)


func test_dedup_same_customer_same_item_suppresses_repeat() -> void:
	var sys := AmbientMomentsSystem.new()
	add_child_autofree(sys)
	sys._connect_signals()

	var customer: Customer = _make_customer(null)
	var item: ItemInstance = _make_item("retro_a", 12.0)

	var count: Array = [0]
	var cb: Callable = func(_m: String, _c: StringName, _d: float) -> void:
		count[0] += 1
	EventBus.toast_requested.connect(cb)

	EventBus.customer_item_spotted.emit(customer, item)
	EventBus.customer_item_spotted.emit(customer, item)
	EventBus.toast_requested.disconnect(cb)

	assert_eq(
		count[0], 1,
		"Repeat (customer, item) pair must not produce a second toast"
	)


func test_upgrade_to_different_item_posts_new_toast() -> void:
	var sys := AmbientMomentsSystem.new()
	add_child_autofree(sys)
	sys._connect_signals()

	var customer: Customer = _make_customer(null)
	var first_item: ItemInstance = _make_item("retro_a", 12.0)
	first_item.definition.item_name = "Used Cartridge Game"
	var upgraded_item: ItemInstance = _make_item("retro_b", 80.0)
	upgraded_item.definition.item_name = "Strategy Guide"

	var messages: Array[String] = []
	var cb: Callable = func(m: String, _c: StringName, _d: float) -> void:
		messages.append(m)
	EventBus.toast_requested.connect(cb)

	EventBus.customer_item_spotted.emit(customer, first_item)
	EventBus.customer_item_spotted.emit(customer, upgraded_item)
	EventBus.toast_requested.disconnect(cb)

	assert_eq(messages.size(), 2, "Upgrade to a different item must post again")
	assert_eq(messages[0], "Customer browsing: Used Cartridge Game")
	assert_eq(messages[1], "Customer browsing: Strategy Guide")


func test_dedup_clears_when_customer_left() -> void:
	var sys := AmbientMomentsSystem.new()
	add_child_autofree(sys)
	sys._connect_signals()

	var customer: Customer = _make_customer(null)
	var item: ItemInstance = _make_item("retro_a", 12.0)

	var count: Array = [0]
	var cb: Callable = func(_m: String, _c: StringName, _d: float) -> void:
		count[0] += 1
	EventBus.toast_requested.connect(cb)

	EventBus.customer_item_spotted.emit(customer, item)
	EventBus.customer_left.emit({"customer_id": customer.get_instance_id()})
	EventBus.customer_item_spotted.emit(customer, item)
	EventBus.toast_requested.disconnect(cb)

	assert_eq(
		count[0], 2,
		"After customer_left clears dedup, the same item should toast again"
	)


# ── Tutorial wiring ──────────────────────────────────────────────────────────


func test_tutorial_customer_browsing_advances_on_item_spotted() -> void:
	var tutorial := TutorialSystem.new()
	add_child_autofree(tutorial)
	tutorial.initialize(true)
	tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	tutorial._process(0.01)
	# Drive WELCOME → … → CUSTOMER_BROWSING so customer_item_spotted is the
	# next legitimate trigger.
	EventBus.panel_opened.emit("inventory")
	EventBus.placement_mode_entered.emit()
	EventBus.item_stocked.emit("item_1", "shelf_1")
	EventBus.customer_entered.emit({"customer_id": "c1"})
	assert_eq(
		tutorial.current_step,
		TutorialSystem.TutorialStep.CUSTOMER_BROWSING,
		"Pre-condition: tutorial must be on CUSTOMER_BROWSING"
	)

	var customer: Customer = _make_customer(null)
	var item: ItemInstance = _make_item("retro_a", 12.0)
	EventBus.customer_item_spotted.emit(customer, item)

	assert_eq(
		tutorial.current_step,
		TutorialSystem.TutorialStep.CUSTOMER_AT_CHECKOUT,
		"customer_item_spotted should advance CUSTOMER_BROWSING → CUSTOMER_AT_CHECKOUT"
	)


# ── Helpers ──────────────────────────────────────────────────────────────────


func _make_profile() -> CustomerTypeDefinition:
	var p := CustomerTypeDefinition.new()
	p.id = "spot_test_customer"
	p.customer_name = "Spot Tester"
	p.budget_range = [5.0, 200.0]
	p.patience = 1.0
	p.price_sensitivity = 0.5
	p.preferred_categories = PackedStringArray(["games"])
	p.preferred_tags = PackedStringArray([])
	p.condition_preference = "good"
	p.browse_time_range = [10.0, 20.0]
	p.purchase_probability_base = 0.5
	p.impulse_buy_chance = 0.0
	p.max_price_to_market_ratio = 1.0
	return p


func _make_item(item_id: String, price: float) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = item_id
	def.item_name = "Test Item %s" % item_id
	def.category = "games"
	def.base_price = price
	def.rarity = "common"
	def.tags = PackedStringArray([])
	def.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)
	var item: ItemInstance = ItemInstance.create_from_definition(def, "good")
	item.player_set_price = price
	return item


func _make_customer(inv: InventorySystem) -> Customer:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.profile = _profile
	customer._budget_multiplier = 1.0
	customer._inventory_system = inv
	return customer
