## Handles PocketCreatures card trade offers from Trader customers.
class_name TradeSystem
extends RefCounted

const TRADER_PROFILE_ID: String = "pc_trader"
const VALUE_TOLERANCE: float = 0.20
const TRADE_REP_BONUS: float = 1.0
const VALID_CONDITIONS: Array[String] = [
	"fair", "good", "near_mint",
]

var _data_loader: DataLoader = null
var _inventory_system: InventorySystem = null
var _economy_system: EconomySystem = null
var _reputation_system: ReputationSystem = null
var _trade_panel: TradePanel = null

var _active_customer: Customer = null
var _wanted_item: ItemInstance = null
var _wanted_item_slot: Node = null
var _offered_item: ItemInstance = null
var _trades_today: int = 0


## Sets up the trade system with required references.
func initialize(
	data_loader: DataLoader,
	inventory_system: InventorySystem,
	economy_system: EconomySystem,
	reputation_system: ReputationSystem,
) -> void:
	_data_loader = data_loader
	_inventory_system = inventory_system
	_economy_system = economy_system
	_reputation_system = reputation_system
	EventBus.day_started.connect(_on_day_started)


## Connects the trade panel and wires its signals.
func set_trade_panel(panel: TradePanel) -> void:
	_trade_panel = panel
	_trade_panel.trade_accepted.connect(_on_trade_accepted)
	_trade_panel.trade_declined.connect(_on_trade_declined)


## Returns true if the customer should enter the trade flow.
func is_trader(customer: Customer) -> bool:
	if not customer or not customer.profile:
		return false
	return customer.profile.id == TRADER_PROFILE_ID


## Begins a trade offer for the given customer.
## Returns true if the trade flow was initiated.
func begin_trade(customer: Customer) -> bool:
	var item: ItemInstance = customer.get_desired_item()
	if not item:
		return false
	_active_customer = customer
	_wanted_item = item
	_wanted_item_slot = customer.get_desired_item_slot()
	_offered_item = _generate_offer(item)
	if not _offered_item:
		_clear_state()
		return false
	_show_trade_panel()
	return true


## Returns the number of trades completed today.
func get_trades_today() -> int:
	return _trades_today


## Returns true if a trade is currently in progress.
func is_active() -> bool:
	return _active_customer != null


func _generate_offer(wanted: ItemInstance) -> ItemInstance:
	if not _data_loader or not _economy_system:
		return null
	var wanted_value: float = _economy_system.calculate_market_value(
		wanted
	)
	if wanted_value <= 0.0:
		return null
	var min_value: float = wanted_value * (1.0 - VALUE_TOLERANCE)
	var max_value: float = wanted_value * (1.0 + VALUE_TOLERANCE)
	var candidates: Array[ItemDefinition] = (
		_data_loader.get_items_by_store("pocket_creatures")
	)
	candidates.shuffle()
	for def: ItemDefinition in candidates:
		if def.id == wanted.definition.id:
			continue
		var condition: String = _pick_random_condition()
		var test_item: ItemInstance = ItemInstance.create(
			def, condition, GameManager.current_day, 0.0
		)
		var test_value: float = (
			_economy_system.calculate_market_value(test_item)
		)
		if test_value >= min_value and test_value <= max_value:
			return test_item
	return null


func _pick_random_condition() -> String:
	return VALID_CONDITIONS[randi() % VALID_CONDITIONS.size()]


func _show_trade_panel() -> void:
	if not _trade_panel:
		push_warning("TradeSystem: no trade panel assigned")
		return
	var wanted_name: String = _wanted_item.definition.item_name
	var wanted_cond: String = _wanted_item.condition.capitalize()
	var wanted_val: float = _economy_system.calculate_market_value(
		_wanted_item
	)
	var offered_name: String = _offered_item.definition.item_name
	var offered_cond: String = _offered_item.condition.capitalize()
	var offered_val: float = _economy_system.calculate_market_value(
		_offered_item
	)
	_trade_panel.show_trade(
		wanted_name, wanted_cond, wanted_val,
		offered_name, offered_cond, offered_val,
	)
	EventBus.panel_opened.emit("trade")
	EventBus.trade_offered.emit(
		_active_customer.get_instance_id(),
		_wanted_item.instance_id,
		_offered_item.instance_id,
	)


func _on_trade_accepted() -> void:
	if not _active_customer or not _wanted_item or not _offered_item:
		return
	_process_trade()
	_finish_trade()


func _on_trade_declined() -> void:
	EventBus.trade_declined.emit(
		_active_customer.get_instance_id()
		if _active_customer else 0
	)
	_finish_trade()


func _process_trade() -> void:
	var slot: Node = _wanted_item_slot
	if slot and slot.has_method("remove_item"):
		slot.remove_item()
	_inventory_system.remove_item(_wanted_item.instance_id)
	_offered_item.current_location = "backroom"
	_offered_item.acquired_day = GameManager.current_day
	_inventory_system.register_item(_offered_item)
	_trades_today += 1
	_reputation_system.modify_reputation(
		"pocket_creatures", TRADE_REP_BONUS
	)
	EventBus.trade_accepted.emit(
		_wanted_item.instance_id,
		_offered_item.instance_id,
	)
	EventBus.notification_requested.emit(
		"Trade completed! Received %s" % _offered_item.definition.item_name
	)


func _finish_trade() -> void:
	if _trade_panel and _trade_panel.is_open():
		_trade_panel.hide_trade()
		EventBus.panel_closed.emit("trade")
	var customer: Customer = _active_customer
	_clear_state()
	if customer:
		customer.complete_purchase()


func _clear_state() -> void:
	_active_customer = null
	_wanted_item = null
	_wanted_item_slot = null
	_offered_item = null


func _on_day_started(_day: int) -> void:
	_trades_today = 0
