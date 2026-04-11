## Applies immediate effects for random events.
class_name RandomEventEffects
extends RefCounted


const HEALTH_INSPECTION_STOCK_THRESHOLD: float = 0.5
const HEALTH_INSPECTION_PASS_REP: float = 5.0
const HEALTH_INSPECTION_FAIL_REP: float = -10.0

var _inventory_system: InventorySystem
var _reputation_system: ReputationSystem


func initialize(
	inventory_system: InventorySystem,
	reputation_system: ReputationSystem
) -> void:
	_inventory_system = inventory_system
	_reputation_system = reputation_system


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


## Picks a random shelf item to receive 5x demand. Returns true if ongoing.
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
		item_name = chosen.definition.name
		active_event["target_item_id"] = chosen.definition.id
	else:
		item_name = "an item"
	var msg: String = def.notification_text % [
		item_name, def.duration_days
	]
	EventBus.notification_requested.emit(msg)


## Evaluates store stocking state. Returns true if passed.
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
			_reputation_system.modify_reputation(
				store_id, HEALTH_INSPECTION_PASS_REP
			)
	else:
		EventBus.notification_requested.emit(
			"Inspection failed! Shelves are understocked. (-10 rep)"
		)
		if _reputation_system:
			_reputation_system.modify_reputation(
				store_id, HEALTH_INSPECTION_FAIL_REP
			)
	return passes


## Removes 1 random item from shelves. Returns stolen item name.
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
		item_name = stolen.definition.name
	var msg: String = def.notification_text % item_name
	EventBus.notification_requested.emit(msg)
	EventBus.item_lost.emit(stolen.instance_id, "shoplifting")
	_inventory_system.remove_item(stolen.instance_id)
	return item_name
