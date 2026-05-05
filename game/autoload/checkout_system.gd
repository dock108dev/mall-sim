## Processes NPC purchase transactions and emits results via EventBus.
extends Node

const DEFECTIVE_CONDITIONS: Array[String] = ["poor", "damaged"]

var _market_value_system: MarketValueSystem = null
var _inventory_system: InventorySystem = null
var _difficulty_system: DifficultySystem = null
var _processing_ids: Dictionary = {}


func initialize(
	market: MarketValueSystem, inventory: InventorySystem,
	difficulty: DifficultySystem = null
) -> void:
	_market_value_system = market
	_inventory_system = inventory
	_difficulty_system = difficulty


# gdlint:disable=max-returns
func process_transaction(npc: Customer) -> bool:
	if not npc or not is_instance_valid(npc):
		push_warning("CheckoutSystem: invalid npc in process_transaction")
		return false

	var customer_id: StringName = StringName(
		str(npc.get_instance_id())
	)
	if _processing_ids.has(customer_id):
		return false
	_processing_ids[customer_id] = true

	var desired_item: ItemInstance = npc.get_desired_item()
	if not desired_item or not desired_item.definition:
		push_warning(
			"CheckoutSystem: customer %s has no desired item or definition" % customer_id
		)
		_processing_ids.erase(customer_id)
		EventBus.customer_left_mall.emit(npc, false)
		return false

	var item_id: StringName = StringName(desired_item.instance_id)
	var store_id: StringName = ContentRegistry.resolve(
		desired_item.definition.store_type
	)

	if not _has_stock(store_id, item_id):
		_processing_ids.erase(customer_id)
		EventBus.customer_left_mall.emit(npc, false)
		return false

	var price: float = _get_item_price(store_id, desired_item)
	var budget: float = _get_budget(npc)

	if budget < price:
		_processing_ids.erase(customer_id)
		EventBus.customer_left_mall.emit(npc, false)
		return false

	if not _roll_purchase_probability(npc):
		_processing_ids.erase(customer_id)
		EventBus.customer_left_mall.emit(npc, false)
		return false

	EventBus.customer_purchased.emit(
		store_id, item_id, price, customer_id
	)
	if desired_item.condition in DEFECTIVE_CONDITIONS:
		EventBus.defective_sale_occurred.emit(
			String(item_id), desired_item.condition
		)
	_processing_ids.erase(customer_id)
	return true


# gdlint:enable=max-returns
func _has_stock(
	store_id: StringName, item_id: StringName
) -> bool:
	if not _inventory_system:
		push_error("CheckoutSystem: InventorySystem not initialized")
		return false
	var stock: Array[ItemInstance] = _inventory_system.get_stock(
		store_id
	)
	for item: ItemInstance in stock:
		if StringName(item.instance_id) == item_id:
			return true
	return false


func _get_item_price(
	_store_id: StringName, item: ItemInstance
) -> float:
	if not item.definition:
		return item.get_current_value()
	var base: float = item.definition.base_price
	var multipliers: Array = []
	if _market_value_system:
		multipliers.append_array(_market_value_system.get_item_multipliers(item))
	else:
		multipliers.append({
			"slot": "condition", "label": "Condition",
			"factor": ItemInstance.CONDITION_MULTIPLIERS.get(item.condition, 1.0),
			"detail": item.condition,
		})
		multipliers.append({
			"slot": "rarity", "label": "Rarity",
			"factor": ItemInstance.calculate_effective_rarity(base, item.definition.rarity),
			"detail": item.definition.rarity,
		})
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		StringName(item.instance_id), base, multipliers, false
	)
	return result.final_price


func _get_budget(npc: Customer) -> float:
	if not npc.profile:
		return 0.0
	var max_budget: float = npc.profile.budget_range[1]
	return max_budget


func _roll_purchase_probability(npc: Customer) -> bool:
	var base: float = 1.0
	if npc.profile:
		base = npc.profile.purchase_probability_base
	var diff: DifficultySystem = _difficulty_system
	if not diff:
		diff = DifficultySystemSingleton
	var modifier: float = diff.get_modifier(
		&"purchase_probability_multiplier"
	)
	var final_prob: float = clampf(base * modifier, 0.0, 1.0)
	return randf() < final_prob
