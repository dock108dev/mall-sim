## Handles customer checkout transactions at the register.
class_name CheckoutSystem
extends Node

const OFFER_LOW: float = 0.85
const OFFER_HIGH: float = 1.15
const SENSITIVITY_FACTOR: float = 0.3
const PATIENCE_REP_PENALTY: float = -2.0
const HAGGLE_REP_BONUS: float = 1.0
const HAGGLE_FAIL_REP_PENALTY: float = -1.0
const ELECTRONICS_STORE_TYPE: String = "consumer_electronics"

var _economy_system: EconomySystem = null
var _inventory_system: InventorySystem = null
var _customer_system: CustomerSystem = null
var _reputation_system: ReputationSystem = null
var _checkout_panel: CheckoutPanel = null
var _haggle_system: HaggleSystem = null
var _haggle_panel: HagglePanel = null
var _register_queue: RegisterQueue = null
var _warranty_manager: WarrantyManager = null
var _trade_system: TradeSystem = null

## The customer currently being served at checkout.
var _active_customer: Customer = null
## The item being sold in the current checkout.
var _active_item: ItemInstance = null
## The offer price for the current checkout.
var _active_offer: float = 0.0
## Whether the current checkout is in haggling mode.
var _is_haggling: bool = false


func initialize(
	economy: EconomySystem,
	inventory: InventorySystem,
	customers: CustomerSystem,
	reputation: ReputationSystem
) -> void:
	_economy_system = economy
	_inventory_system = inventory
	_customer_system = customers
	_reputation_system = reputation
	_register_queue = RegisterQueue.new()
	EventBus.interactable_interacted.connect(
		_on_interactable_interacted
	)
	EventBus.customer_ready_to_purchase.connect(
		_on_customer_ready_to_purchase
	)
	EventBus.customer_left.connect(_on_customer_left)


## Initializes the register queue with store positions for queue spacing.
func setup_queue_positions(
	register_pos: Vector3, entry_pos: Vector3
) -> void:
	_register_queue.initialize(register_pos, entry_pos)


## Sets the checkout panel reference for UI display.
func set_checkout_panel(panel: CheckoutPanel) -> void:
	_checkout_panel = panel
	_checkout_panel.sale_accepted.connect(_on_sale_accepted)
	_checkout_panel.sale_declined.connect(_on_sale_declined)


## Sets the haggle system and panel references.
func set_haggle_system(system: HaggleSystem) -> void:
	_haggle_system = system
	_haggle_system.negotiation_accepted.connect(
		_on_haggle_accepted
	)
	_haggle_system.negotiation_failed.connect(
		_on_haggle_failed
	)


## Sets the haggle panel and wires its signals to the system.
func set_haggle_panel(panel: HagglePanel) -> void:
	_haggle_panel = panel
	_haggle_panel.offer_accepted.connect(
		_on_haggle_panel_accept
	)
	_haggle_panel.counter_submitted.connect(
		_on_haggle_panel_counter
	)
	_haggle_panel.offer_declined.connect(
		_on_haggle_panel_decline
	)
	_haggle_system.customer_countered.connect(
		_on_customer_countered
	)
	_haggle_system.negotiation_started.connect(
		_on_negotiation_started
	)


## Sets the warranty manager for electronics warranty upsell.
func set_warranty_manager(manager: WarrantyManager) -> void:
	_warranty_manager = manager


## Sets the trade system for PocketCreatures card trades.
func set_trade_system(system: TradeSystem) -> void:
	_trade_system = system


func _on_interactable_interacted(
	_target: Interactable, type: int
) -> void:
	if type != Interactable.InteractionType.REGISTER:
		return
	if _checkout_panel and _checkout_panel.is_open():
		return
	if _haggle_panel and _haggle_panel.is_open():
		return
	if _trade_system and _trade_system.is_active():
		return
	var customer: Customer = _find_waiting_customer()
	if not customer:
		EventBus.notification_requested.emit(
			"No customer waiting"
		)
		return
	_begin_checkout(customer)


func _on_customer_ready_to_purchase(
	customer_data: Dictionary
) -> void:
	var cust_id: int = customer_data.get("customer_id", 0)
	if cust_id == 0:
		return
	var node: Object = instance_from_id(cust_id)
	if not node is Customer:
		return
	var customer: Customer = node as Customer
	if not _register_queue.try_add(customer):
		customer.reject_from_queue()


func _on_customer_left(customer_data: Dictionary) -> void:
	var cust_id: int = customer_data.get("customer_id", 0)
	if not _register_queue.has_customer_id(cust_id):
		return
	_register_queue.remove_by_id(cust_id)
	_reputation_system.modify_reputation(
		"sports_memorabilia", PATIENCE_REP_PENALTY
	)
	if _active_customer and _active_customer.get_instance_id() == cust_id:
		_cancel_active_checkout()


## Returns the first customer in the queue who is at the register.
func _find_waiting_customer() -> Customer:
	var first: Customer = _register_queue.get_first()
	if not first:
		return null
	if first.current_state != Customer.State.PURCHASING:
		return null
	return first


func _begin_checkout(customer: Customer) -> void:
	_active_customer = customer
	_active_item = customer.get_desired_item()
	if not _active_item:
		EventBus.notification_requested.emit(
			"No customer waiting"
		)
		return
	if _trade_system and _trade_system.is_trader(customer):
		if _trade_system.begin_trade(customer):
			_register_queue.remove(customer)
			_active_customer = null
			_active_item = null
			return
	if _haggle_system and _haggle_system.should_haggle(
		customer, _active_item
	):
		_is_haggling = true
		_haggle_system.begin_negotiation(
			customer, _active_item
		)
		return
	_active_offer = _calculate_offer(
		_active_item, customer
	)
	_show_checkout_panel()


func _show_checkout_panel() -> void:
	if not _checkout_panel:
		push_warning(
			"CheckoutSystem: no checkout panel assigned"
		)
		return
	var item_name: String = _active_item.definition.name
	var item_cond: String = _active_item.condition.capitalize()
	var show_warranty: bool = _should_show_warranty()
	_checkout_panel.show_checkout(
		item_name, item_cond, _active_offer, show_warranty
	)
	EventBus.panel_opened.emit("checkout")


## Returns true if warranty upsell should be shown for the active item.
func _should_show_warranty() -> bool:
	if not _warranty_manager:
		return false
	if not _active_item or not _active_item.definition:
		return false
	if _active_item.definition.store_type != ELECTRONICS_STORE_TYPE:
		return false
	return WarrantyManager.is_eligible(_active_offer)


## Calculates the customer's offer price for an item.
func _calculate_offer(
	item: ItemInstance, customer: Customer
) -> float:
	var market_value: float = item.get_current_value()
	var random_mult: float = randf_range(OFFER_LOW, OFFER_HIGH)
	var sensitivity: float = 0.5
	if customer.profile:
		sensitivity = customer.profile.price_sensitivity
	var sensitivity_mult: float = (
		1.0 - sensitivity * SENSITIVITY_FACTOR
	)
	return market_value * random_mult * sensitivity_mult


func _on_sale_accepted() -> void:
	if not _active_customer or not _active_item:
		return
	_process_sale()
	_process_warranty_offer()
	_complete_checkout()


func _on_sale_declined() -> void:
	if not _active_customer:
		return
	_complete_checkout()


func _on_negotiation_started(
	item_name: String,
	item_condition: String,
	sticker_price: float,
	customer_offer: float,
	max_rounds: int,
) -> void:
	if not _haggle_panel:
		push_warning(
			"CheckoutSystem: no haggle panel assigned"
		)
		return
	_haggle_panel.show_negotiation(
		item_name, item_condition,
		sticker_price, customer_offer, max_rounds,
	)
	EventBus.panel_opened.emit("haggle")


func _on_haggle_panel_accept() -> void:
	if _haggle_system and _haggle_system.is_active():
		_haggle_system.accept_offer()


func _on_haggle_panel_counter(price: float) -> void:
	if _haggle_system and _haggle_system.is_active():
		_haggle_system.player_counter(price)


func _on_haggle_panel_decline() -> void:
	if _haggle_system and _haggle_system.is_active():
		_haggle_system.decline_offer()


func _on_customer_countered(
	new_offer: float, round_number: int
) -> void:
	if not _haggle_panel:
		return
	_haggle_panel.show_customer_counter(
		new_offer,
		round_number,
		_haggle_system._max_rounds_for_customer,
	)


func _on_haggle_accepted(final_price: float) -> void:
	_active_offer = final_price
	_process_sale()
	_process_warranty_offer()
	_reputation_system.modify_reputation(
		"sports_memorabilia", HAGGLE_REP_BONUS
	)
	_finish_haggle()


func _on_haggle_failed() -> void:
	_reputation_system.modify_reputation(
		"sports_memorabilia", HAGGLE_FAIL_REP_PENALTY
	)
	_finish_haggle()


func _finish_haggle() -> void:
	_is_haggling = false
	if _haggle_panel and _haggle_panel.is_open():
		_haggle_panel.hide_negotiation()
	_complete_checkout()


func _process_sale() -> void:
	var item_id: String = _active_item.instance_id
	_economy_system.add_cash(
		_active_offer, "Item sale: %s" % item_id
	)
	var slot: Node = _active_customer.get_desired_item_slot()
	if slot and slot.has_method("remove_item"):
		slot.remove_item()
	var category: String = ""
	if _active_item.definition:
		category = _active_item.definition.category
	_inventory_system.remove_item(item_id)
	EventBus.item_sold.emit(item_id, _active_offer, category)


## Processes warranty offer if applicable after a sale.
func _process_warranty_offer() -> void:
	if not _checkout_panel or not _checkout_panel.is_warranty_offered():
		return
	if not _warranty_manager:
		return
	if not _active_item or not _active_item.definition:
		return
	var fee: float = _checkout_panel.get_warranty_fee()
	if fee <= 0.0:
		return
	if not WarrantyManager.roll_acceptance(_active_offer):
		EventBus.notification_requested.emit(
			"Customer declined the warranty"
		)
		return
	var wholesale: float = _active_item.definition.base_price
	if _economy_system:
		wholesale = _economy_system.get_wholesale_price(
			_active_item.definition
		)
	var item_id: String = _active_item.instance_id
	_warranty_manager.add_warranty(
		item_id,
		_active_offer,
		fee,
		wholesale,
		GameManager.current_day,
	)
	_economy_system.add_cash(fee, "Warranty: %s" % item_id)
	EventBus.warranty_purchased.emit(item_id, fee)
	EventBus.notification_requested.emit(
		"Warranty sold for $%.2f" % fee
	)


func _complete_checkout() -> void:
	_register_queue.remove(_active_customer)
	_active_customer.complete_purchase()
	_active_customer = null
	_active_item = null
	_active_offer = 0.0
	if _checkout_panel and _checkout_panel.is_open():
		_checkout_panel.hide_checkout()
		EventBus.panel_closed.emit("checkout")
	if _haggle_panel and _haggle_panel.is_open():
		_haggle_panel.hide_negotiation()
		EventBus.panel_closed.emit("haggle")


func _cancel_active_checkout() -> void:
	if _is_haggling and _haggle_system and _haggle_system.is_active():
		_haggle_system.decline_offer()
		return
	_active_customer = null
	_active_item = null
	_active_offer = 0.0
	if _checkout_panel and _checkout_panel.is_open():
		_checkout_panel.hide_checkout()
		EventBus.panel_closed.emit("checkout")
