## Unit tests for ElectronicsStoreController — depreciation schedule,
## demo unit flag behavior, and warranty offer trigger.
extends GutTest

const BASE_PRICE: float = 100.0
# A min_value_ratio higher than CLEARANCE_MULT_MIN (0.3) so the floor activates
# before the lifecycle reaches its lowest multiplier, letting us test clamping.
const MIN_VALUE_RATIO: float = 0.5

var _controller: ElectronicsStoreController
var _inventory: InventorySystem
var _warranty_offer_ids: Array[String] = []


func _make_definition(
	price: float = BASE_PRICE,
	min_ratio: float = MIN_VALUE_RATIO,
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = "test_elec_%d" % randi()
	def.item_name = "Test Electronics"
	def.store_type = "electronics"
	def.category = "gadgets"
	def.base_price = price
	def.rarity = "common"
	def.product_line = "test_gadget_line"
	def.generation = 1
	def.launch_day = 1
	def.min_value_ratio = min_ratio
	def.depreciation_rate = 0.02
	def.condition_range = PackedStringArray(["good"])
	return def


func _make_item(def: ItemDefinition) -> ItemInstance:
	var item: ItemInstance = ItemInstance.create_from_definition(def, "good")
	_inventory._items[item.instance_id] = item
	return item


func _on_warranty_offer_presented(item_id: String) -> void:
	_warranty_offer_ids.append(item_id)


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_controller = ElectronicsStoreController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)
	_warranty_offer_ids.clear()
	EventBus.warranty_offer_presented.connect(_on_warranty_offer_presented)


func after_each() -> void:
	if EventBus.warranty_offer_presented.is_connected(_on_warranty_offer_presented):
		EventBus.warranty_offer_presented.disconnect(_on_warranty_offer_presented)


func test_depreciation_reduces_price_over_days() -> void:
	var def: ItemDefinition = _make_definition()
	var item: ItemInstance = _make_item(def)
	var floor_price: float = def.base_price * def.min_value_ratio

	# Day 1 = launch day; lifecycle multiplier is at its peak (~1.5).
	EventBus.day_started.emit(1)
	var price_at_launch: float = _controller.get_current_price(item.instance_id)

	# Day 11 = peak phase (past launch spike); multiplier drops to 1.0.
	EventBus.day_started.emit(11)
	var price_after_ten_days: float = _controller.get_current_price(item.instance_id)

	assert_lt(
		price_after_ten_days,
		price_at_launch,
		"Price should decrease after leaving launch phase"
	)
	assert_ge(
		price_after_ten_days,
		floor_price,
		"Price must remain at or above floor_price after 10 days"
	)


func test_demo_unit_not_sellable() -> void:
	var def: ItemDefinition = _make_definition()
	var item: ItemInstance = _make_item(def)
	item.is_demo = true

	var result: bool = _controller.attempt_purchase(item.instance_id)

	assert_false(result, "attempt_purchase must return false for a demo unit")


func test_warranty_offer_triggers_on_eligible_item() -> void:
	# A sale price >= WarrantyManager.MIN_ITEM_PRICE ($50) is warranty-eligible.
	var def: ItemDefinition = _make_definition(100.0)
	var item: ItemInstance = _make_item(def)

	_controller.present_warranty_offer(item.instance_id, 100.0)

	assert_eq(
		_warranty_offer_ids.size(),
		1,
		"warranty_offer_presented should fire once for an eligible item"
	)
	assert_eq(
		_warranty_offer_ids[0],
		item.instance_id,
		"Signal should carry the correct item_id"
	)


func test_warranty_offer_not_triggered_for_ineligible() -> void:
	# A sale price below $50 does not qualify for a warranty offer.
	var def: ItemDefinition = _make_definition(20.0)
	var item: ItemInstance = _make_item(def)

	_controller.present_warranty_offer(item.instance_id, 20.0)

	assert_eq(
		_warranty_offer_ids.size(),
		0,
		"warranty_offer_presented must not fire for items below the price threshold"
	)


func test_depreciation_floor_respected() -> void:
	# MIN_VALUE_RATIO (0.5) > CLEARANCE_MULT_MIN (0.3), so after deep depreciation
	# the floor clamp activates and the returned price equals exactly floor_price.
	var def: ItemDefinition = _make_definition(BASE_PRICE, MIN_VALUE_RATIO)
	var item: ItemInstance = _make_item(def)
	var floor_price: float = def.base_price * def.min_value_ratio

	EventBus.day_started.emit(365)
	var price: float = _controller.get_current_price(item.instance_id)

	assert_almost_eq(
		price,
		floor_price,
		0.001,
		"After 365 days price should equal floor_price exactly — not lower"
	)
