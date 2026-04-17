## Applies immediate effects for random events.
class_name RandomEventEffects
extends RefCounted


const HEALTH_INSPECTION_STOCK_THRESHOLD: float = 0.5
const HEALTH_INSPECTION_PASS_REP: float = 5.0
const HEALTH_INSPECTION_FAIL_REP: float = -10.0
const SHOPLIFTING_REPUTATION_PENALTY: float = -2.0
const COMPETITOR_SALE_DEMAND_MODIFIER: float = -0.1
const RAINY_DAY_TRAFFIC_MODIFIER: float = 0.7

var _inventory_system: InventorySystem
var _reputation_system: ReputationSystem
var _economy_system: EconomySystem


func initialize(
	inventory_system: InventorySystem,
	reputation_system: ReputationSystem,
	economy_system: EconomySystem
) -> void:
	_inventory_system = inventory_system
	_reputation_system = reputation_system
	_economy_system = economy_system


## Picks a random category to block from suppliers.
func apply_supply_shortage(
	def: RandomEventDefinition, active_event: Dictionary
) -> void:
	var categories: PackedStringArray = [
		"trading_cards", "sealed_product", "autographs",
		"cartridges", "consoles", "accessories",
		"vhs", "dvd", "snacks",
		"singles", "sealed", "audio", "cameras",
	]
	var chosen_cat: String = categories[
		randi() % categories.size()
	]
	active_event["target_category"] = chosen_cat
	var msg: String = def.notification_text % [
		chosen_cat, def.duration_days
	]
	EventBus.notification_requested.emit(msg)


## Picks a random shelf item to receive 5x demand.
func apply_viral_trend(
	def: RandomEventDefinition, active_event: Dictionary
) -> void:
	var shelf_items: Array[ItemInstance] = (
		_inventory_system.get_shelf_items()
	)
	if shelf_items.is_empty():
		var msg: String = def.notification_text % [
			"an item", def.duration_days
		]
		EventBus.notification_requested.emit(msg)
		return
	var chosen: ItemInstance = shelf_items[
		randi() % shelf_items.size()
	]
	var item_name: String = ""
	if chosen.definition:
		item_name = chosen.definition.item_name
		active_event["target_item_id"] = chosen.definition.id
	else:
		item_name = "an item"
	var msg: String = def.notification_text % [
		item_name, def.duration_days
	]
	EventBus.notification_requested.emit(msg)


## Evaluates store stocking state.
func apply_health_inspection(
	def: RandomEventDefinition
) -> bool:
	EventBus.notification_requested.emit(def.notification_text)
	var shelf_items: Array[ItemInstance] = (
		_inventory_system.get_shelf_items()
	)
	var total_items: int = _inventory_system.get_item_count()
	var passes: bool = (
		total_items > 0
		and float(shelf_items.size()) / float(total_items)
			>= HEALTH_INSPECTION_STOCK_THRESHOLD
	)
	var store_id: String = GameManager.current_store_id
	if passes:
		EventBus.notification_requested.emit(
			"Inspection passed! Your store looks great. (+5 rep)"
		)
		if _reputation_system:
			_reputation_system.add_reputation(
				store_id, HEALTH_INSPECTION_PASS_REP
			)
	else:
		EventBus.notification_requested.emit(
			"Inspection failed! Shelves are understocked. (-10 rep)"
		)
		if _reputation_system:
			_reputation_system.add_reputation(
				store_id, HEALTH_INSPECTION_FAIL_REP
			)
	return passes


## Removes 1 random item from shelves.
func apply_shoplifting(
	def: RandomEventDefinition
) -> String:
	var shelf_items: Array[ItemInstance] = (
		_inventory_system.get_shelf_items()
	)
	if shelf_items.is_empty():
		EventBus.notification_requested.emit(
			"A shoplifter was spotted but found nothing to steal."
		)
		return ""
	var stolen: ItemInstance = shelf_items[
		randi() % shelf_items.size()
	]
	var item_name: String = "an item"
	if stolen.definition:
		item_name = stolen.definition.item_name
	var msg: String = def.notification_text % item_name
	EventBus.notification_requested.emit(msg)
	var store_id: StringName = StringName(
		GameManager.current_store_id
	)
	EventBus.inventory_item_removed.emit(
		StringName(stolen.instance_id),
		store_id,
		&"shoplifting"
	)
	EventBus.item_lost.emit(stolen.instance_id, "shoplifting")
	_inventory_system.remove_item(stolen.instance_id)
	if _reputation_system:
		_reputation_system.add_reputation(
			String(store_id), SHOPLIFTING_REPUTATION_PENALTY
		)
	return item_name


## Sells shelf items to a corporate bulk buyer at a premium price.
func apply_bulk_order(def: RandomEventDefinition) -> float:
	var shelf_items: Array[ItemInstance] = (
		_inventory_system.get_shelf_items()
	)
	if shelf_items.is_empty():
		push_warning(
			"RandomEventEffects: bulk order with no shelf stock"
		)
		EventBus.notification_requested.emit(
			"A corporate buyer visited but found nothing to buy."
		)
		return 0.0
	var quantity: int = def.bulk_order_quantity
	var multiplier: float = def.bulk_order_price_multiplier
	var fulfilled: int = mini(quantity, shelf_items.size())
	var first_item: ItemInstance = shelf_items[0]
	var sample_price: float = snappedf(
		first_item.get_current_value() * multiplier, 0.01
	)
	var total_revenue: float = 0.0
	for i: int in range(fulfilled):
		var item: ItemInstance = shelf_items[i]
		var unit_price: float = snappedf(
			item.get_current_value() * multiplier, 0.01
		)
		total_revenue += unit_price
		_inventory_system.remove_item(item.instance_id)
	if fulfilled > 0 and first_item.definition:
		EventBus.bulk_order_started.emit(
			StringName(first_item.definition.id),
			fulfilled,
			sample_price
		)
	if _economy_system and total_revenue > 0.0:
		_economy_system.credit(total_revenue, &"bulk_order")
	var msg: String = def.notification_text % total_revenue
	EventBus.notification_requested.emit(msg)
	return total_revenue


## Applies -10% demand modifier for the current day.
func apply_competitor_sale(
	def: RandomEventDefinition
) -> void:
	EventBus.notification_requested.emit(def.notification_text)


## Applies -30% foot traffic modifier for the current day.
func apply_rainy_day(def: RandomEventDefinition) -> void:
	EventBus.notification_requested.emit(def.notification_text)


## Adds a rare item to backroom inventory.
func apply_estate_sale(
	def: RandomEventDefinition
) -> String:
	var shelf_items: Array[ItemInstance] = (
		_inventory_system.get_shelf_items()
	)
	var item_name: String = "a rare find"
	if not shelf_items.is_empty():
		var template: ItemInstance = shelf_items[
			randi() % shelf_items.size()
		]
		if template.definition:
			item_name = template.definition.item_name
	var msg: String = def.notification_text % item_name
	EventBus.notification_requested.emit(msg)
	return item_name
