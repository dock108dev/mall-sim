## Handles customer checkout transactions at the register.
class_name PlayerCheckout
extends Node

const OFFER_LOW: float = 0.85
const OFFER_HIGH: float = 1.15
const SENSITIVITY_FACTOR: float = 0.3
const PATIENCE_REP_PENALTY: float = -2.0
const ELECTRONICS_STORE_TYPE: String = "electronics"
const CHECKOUT_DURATION: float = 2.0
const GENEROUS_THRESHOLD: float = 0.75
const FAIR_THRESHOLD_HIGH: float = 1.25
## Minimum sale price for the bundle suggestion to surface. Below this the
## bundle ask reads as low-effort upsell rather than a meaningful add-on.
const BUNDLE_HIGH_VALUE_THRESHOLD: float = 30.0
const BUNDLE_UNLOCK_ID: StringName = &"employee_stocking_trained"
const ACCESSORY_CATEGORY: String = "accessories"
## Item conditions that flag a sale as defective. Selling a copy in this
## condition arms the angry-return spawn gate via
## EventBus.defective_sale_occurred.
const DEFECTIVE_CONDITIONS: Array[String] = ["poor", "damaged"]

var _economy_system: EconomySystem = null
var _inventory_system: InventorySystem = null
var _customer_system: CustomerSystem = null
var _reputation_system: ReputationSystem = null
var _checkout_panel: CheckoutPanel = null
var _haggle_system: HaggleSystem = null
var _haggle_panel: HagglePanel = null
var _register_queue: RegisterQueue = null
var _warranty_manager: WarrantyManager = null
var _warranty_dialog: WarrantyDialog = null
var _market_value_system: MarketValueSystem = null
var _rental_controller: VideoRentalStoreController = null

var _active_customer: Customer = null
var _active_item: ItemInstance = null
var _active_offer: float = 0.0
var _is_haggling: bool = false
var _is_processing: bool = false
var _checkout_timer: Timer = null
var _cashier: StaffDefinition = null


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
	_checkout_timer = Timer.new()
	_checkout_timer.one_shot = true
	_checkout_timer.wait_time = CHECKOUT_DURATION
	_checkout_timer.timeout.connect(_on_checkout_timer_timeout)
	add_child(_checkout_timer)
	EventBus.interactable_interacted.connect(
		_on_interactable_interacted
	)
	EventBus.customer_ready_to_purchase.connect(
		_on_customer_ready_to_purchase
	)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.checkout_queue_ready.connect(_on_checkout_queue_ready)
	EventBus.staff_hired.connect(_on_staff_hired)
	EventBus.staff_fired.connect(_on_staff_fired)
	EventBus.staff_quit.connect(_on_staff_quit)
	EventBus.staff_morale_changed.connect(_on_staff_morale_changed)
	EventBus.action_requested.connect(_on_action_requested)
	_refresh_cashier()


func setup_queue_positions(
	register_pos: Vector3, entry_pos: Vector3
) -> void:
	_register_queue.initialize(register_pos, entry_pos)


func set_checkout_panel(panel: CheckoutPanel) -> void:
	_checkout_panel = panel
	_checkout_panel.sale_accepted.connect(_on_sale_accepted)
	_checkout_panel.sale_declined.connect(_on_sale_declined)
	_checkout_panel.bundle_suggested.connect(_on_bundle_suggested)


func set_market_value_system(system: MarketValueSystem) -> void:
	_market_value_system = system


func set_haggle_system(system: HaggleSystem) -> void:
	_haggle_system = system
	_haggle_system.negotiation_accepted.connect(
		_on_haggle_accepted
	)
	_haggle_system.negotiation_failed.connect(
		_on_haggle_failed
	)


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


func set_warranty_manager(manager: WarrantyManager) -> void:
	_warranty_manager = manager


func set_warranty_dialog(dialog: WarrantyDialog) -> void:
	_warranty_dialog = dialog
	_warranty_dialog.warranty_accepted.connect(
		_on_warranty_accepted
	)
	_warranty_dialog.warranty_declined.connect(
		_on_warranty_declined
	)


func set_rental_controller(
	controller: VideoRentalStoreController,
) -> void:
	_rental_controller = controller


## Called by HaggleSystem on accepted deal or directly on non-haggled sale.
func initiate_sale(
	customer: Customer,
	item: ItemInstance,
	agreed_price: float
) -> void:
	if not customer or not item:
		push_warning("CheckoutSystem: null customer or item in initiate_sale")
		return
	if agreed_price <= 0.0:
		push_warning("CheckoutSystem: invalid agreed_price: %f" % agreed_price)
		return
	if not _inventory_system._items.has(item.instance_id):
		EventBus.notification_requested.emit(
			"Item no longer available"
		)
		customer.complete_purchase()
		_register_queue.remove(customer)
		EventBus.queue_advanced.emit(_register_queue.get_size())
		return
	_active_customer = customer
	_active_item = item
	_active_offer = agreed_price
	_is_processing = true
	_checkout_timer.wait_time = _get_checkout_duration()
	_checkout_timer.start()


func _on_checkout_timer_timeout() -> void:
	if not _active_customer or not _active_item:
		_is_processing = false
		return
	if not _inventory_system._items.has(_active_item.instance_id):
		EventBus.notification_requested.emit(
			"Item no longer available"
		)
		_finalize_checkout_no_sale()
		return
	_execute_sale()
	if _should_show_warranty() and _warranty_dialog:
		_show_warranty_dialog()
		return
	_complete_checkout()


func _on_interactable_interacted(
	_target: Interactable, type: int
) -> void:
	if type != Interactable.InteractionType.REGISTER:
		return
	if _is_processing:
		return
	if _checkout_panel and _checkout_panel.is_open():
		return
	if _haggle_panel and _haggle_panel.is_open():
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
		return
	EventBus.queue_advanced.emit(_register_queue.get_size())


func _on_customer_left(customer_data: Dictionary) -> void:
	var cust_id: int = customer_data.get("customer_id", 0)
	if not _register_queue.has_customer_id(cust_id):
		return
	_register_queue.remove_by_id(cust_id)
	EventBus.queue_advanced.emit(_register_queue.get_size())
	_reputation_system.add_reputation(
		"sports_memorabilia", PATIENCE_REP_PENALTY
	)
	if (
		_active_customer
		and _active_customer.get_instance_id() == cust_id
	):
		_cancel_active_checkout()


func _on_checkout_queue_ready(customer: Node) -> void:
	if not customer is Customer:
		EventBus.checkout_completed.emit(customer)
		return
	process_transaction(customer as Customer)


func process_transaction(customer: Customer) -> void:
	if not customer or not is_instance_valid(customer):
		push_error("CheckoutSystem: invalid customer in process_transaction")
		EventBus.checkout_completed.emit(customer)
		return
	_begin_checkout(customer)


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
	if not _inventory_system._items.has(_active_item.instance_id):
		EventBus.notification_requested.emit(
			"Item no longer available"
		)
		_finalize_checkout_no_sale()
		return
	if _haggle_system and _haggle_system.should_haggle(
		customer, _active_item
	):
		_is_haggling = true
		_haggle_system.begin_negotiation(
			customer, _active_item, _get_haggle_queue_count()
		)
		return
	if _is_rental_transaction():
		_active_offer = _active_item.definition.rental_fee
	else:
		_active_offer = _calculate_offer(
			_active_item, customer
		)
	_show_checkout_panel()


## Wraps the active checkout into a process_sale call via the panel.
func process_sale(
	items: Array[Dictionary], total_price: float
) -> void:
	if not _active_customer or items.is_empty():
		push_error("CheckoutSystem: invalid process_sale call")
		return
	initiate_sale(
		_active_customer, _active_item, total_price
	)


func _show_checkout_panel() -> void:
	if not _checkout_panel:
		push_warning(
			"CheckoutSystem: no checkout panel assigned"
		)
		return
	var item_name: String = _active_item.definition.item_name
	var item_cond: String = _active_item.condition.capitalize()
	var items: Array[Dictionary] = [{
		"item_name": item_name,
		"condition": item_cond,
		"price": _active_offer,
	}]
	EventBus.checkout_started.emit(
		items as Array, _active_customer
	)
	_populate_checkout_card(item_name)


## Builds the customer-decision-card payload from the active customer / item
## and pushes it into the checkout panel. The panel is responsible for the
## visual presentation; this is the data binding boundary.
func _populate_checkout_card(item_name: String) -> void:
	if _checkout_panel == null:
		return
	if _active_customer == null or _active_customer.profile == null:
		return
	var profile: CustomerTypeDefinition = _active_customer.profile
	var archetype: Dictionary = CheckoutPanel.derive_archetype_label(profile)
	var sticker: float = _active_item.get_current_value()
	if _market_value_system:
		sticker = _market_value_system.calculate_item_value(_active_item)
	var data: Dictionary = {
		"archetype_id": archetype.get("archetype_id", &""),
		"archetype_label": archetype.get("label", ""),
		"want": _build_want_text(item_name, profile),
		"context": _build_context_text(profile),
		"reasoning": "",
		"offer_price": _active_offer,
		"sticker_price": sticker,
		"rep_delta": "+1 Rep",
		"decline_label": "Customer leaves, −Rep",
	}
	var bundle: Dictionary = _build_bundle_data()
	if not bundle.is_empty():
		data["bundle"] = bundle
	_checkout_panel.populate_customer_card(data)


func _build_want_text(
	item_name: String, profile: CustomerTypeDefinition
) -> String:
	if profile.customer_name.is_empty():
		return "Wants the %s." % item_name
	return "%s wants the %s." % [profile.customer_name, item_name]


func _build_context_text(profile: CustomerTypeDefinition) -> String:
	if profile.mood_tags.is_empty():
		return ""
	var primary_mood: String = String(profile.mood_tags[0]).replace("_", " ")
	var budget: Array[float] = profile.budget_range
	if budget.size() >= 2 and budget[1] > 0.0:
		return "Mood: %s — budget around $%.0f–$%.0f." % [
			primary_mood, budget[0], budget[1],
		]
	return "Mood: %s." % primary_mood


## Builds the bundle-suggestion dict shown on the customer card. Returns empty
## when the unlock is not granted, the active item is below the high-value
## threshold, or no eligible accessory exists in inventory.
func _build_bundle_data() -> Dictionary:
	if _active_item == null or _active_item.definition == null:
		return {}
	if _active_offer < BUNDLE_HIGH_VALUE_THRESHOLD:
		return {}
	if not UnlockSystemSingleton.is_unlocked(BUNDLE_UNLOCK_ID):
		return {}
	var accessory: ItemInstance = _find_eligible_bundle_accessory()
	if accessory == null or accessory.definition == null:
		return {}
	var accessory_price: float = accessory.get_current_value()
	if _market_value_system:
		accessory_price = _market_value_system.calculate_item_value(accessory)
	return {
		"id": accessory.instance_id,
		"label": "Suggest Bundle: +%s" % accessory.definition.item_name,
		"consequence": "+$%.2f if accepted | −0.5 Rep if declined" % accessory_price,
		"price": accessory_price,
	}


func _find_eligible_bundle_accessory() -> ItemInstance:
	if _inventory_system == null or _active_item == null \
			or _active_item.definition == null:
		return null
	var store_type: String = _active_item.definition.store_type
	var best: ItemInstance = null
	var best_margin: float = -INF
	for instance: ItemInstance in _inventory_system._items.values():
		if instance == null or instance.definition == null:
			continue
		if instance.instance_id == _active_item.instance_id:
			continue
		if instance.definition.store_type != store_type:
			continue
		if instance.definition.category != ACCESSORY_CATEGORY:
			continue
		var price: float = instance.get_current_value()
		var wholesale: float = instance.definition.base_price
		var margin: float = price - wholesale
		if margin > best_margin:
			best_margin = margin
			best = instance
	return best


func _should_show_warranty() -> bool:
	if not _warranty_manager:
		return false
	if not _active_item or not _active_item.definition:
		return false
	if _active_item.definition.store_type != ELECTRONICS_STORE_TYPE:
		return false
	return WarrantyManager.is_eligible(_active_offer)


func _calculate_offer(
	item: ItemInstance, customer: Customer
) -> float:
	if not item.definition:
		return item.get_current_value()
	var base: float = item.definition.base_price
	var multipliers: Array = []
	if _market_value_system:
		multipliers.append_array(_market_value_system.get_item_multipliers(item))
	else:
		var cond: float = ItemInstance.CONDITION_MULTIPLIERS.get(item.condition, 1.0)
		var rarity: float = ItemInstance.calculate_effective_rarity(
			base, item.definition.rarity
		)
		multipliers.append({
			"slot": "condition", "label": "Condition",
			"factor": cond, "detail": item.condition,
		})
		multipliers.append({
			"slot": "rarity", "label": "Rarity",
			"factor": rarity, "detail": item.definition.rarity,
		})
	var random_mult: float = randf_range(OFFER_LOW, OFFER_HIGH)
	var sensitivity: float = 0.5
	if customer.profile:
		sensitivity = customer.profile.price_sensitivity
	var sensitivity_mult: float = 1.0 - sensitivity * SENSITIVITY_FACTOR
	multipliers.append({
		"slot": "random", "label": "Offer Variance",
		"factor": random_mult, "detail": "±15% market noise",
	})
	multipliers.append({
		"slot": "sensitivity", "label": "Price Sensitivity",
		"factor": sensitivity_mult,
		"detail": "sensitivity=%.2f" % sensitivity,
	})
	# Suppress auto-injection: checkout offers use intrinsic value, not reputation-adjusted price.
	multipliers.append({
		"slot": "reputation", "label": "Reputation",
		"factor": 1.0, "detail": "n/a for customer offer",
	})
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		StringName(item.instance_id), base, multipliers, true
	)
	return result.final_price


func _get_perceived_value(item: ItemInstance) -> float:
	if _market_value_system:
		return _market_value_system.calculate_item_value(item)
	return item.get_current_value()


func _on_sale_accepted() -> void:
	if not _active_customer or not _active_item:
		return
	initiate_sale(_active_customer, _active_item, _active_offer)


func _on_sale_declined() -> void:
	if not _active_customer:
		return
	_complete_checkout()


## Bundle press: treat as accept with the bundle accessory's price added on
## top, and remove the accessory from inventory so the upsell is real.
func _on_bundle_suggested() -> void:
	if _checkout_panel == null:
		return
	if not _active_customer or not _active_item:
		return
	var bundle: Dictionary = _checkout_panel.get_active_bundle()
	if bundle.is_empty():
		return
	var bundle_id: String = str(bundle.get("id", ""))
	var bundle_price: float = float(bundle.get("price", 0.0))
	if bundle_id.is_empty() or bundle_price <= 0.0:
		return
	if _inventory_system != null and _inventory_system._items.has(bundle_id):
		_inventory_system.remove_item(bundle_id)
	_active_offer += bundle_price
	initiate_sale(_active_customer, _active_item, _active_offer)


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
	var cust_name: String = "Customer"
	if _active_customer and _active_customer.profile:
		cust_name = _active_customer.profile.customer_name
	var turn_time: float = 10.0
	if _haggle_system:
		turn_time = _haggle_system.time_per_turn
	_haggle_panel.show_negotiation(
		item_name, item_condition,
		sticker_price, customer_offer, max_rounds,
		turn_time, cust_name,
	)
	_populate_haggle_card(sticker_price, customer_offer)


func _populate_haggle_card(
	sticker_price: float, customer_offer: float
) -> void:
	if _haggle_panel == null:
		return
	if _active_customer == null or _active_customer.profile == null:
		return
	var profile: CustomerTypeDefinition = _active_customer.profile
	var archetype: Dictionary = CheckoutPanel.derive_archetype_label(profile)
	var data: Dictionary = {
		"archetype_id": archetype.get("archetype_id", &""),
		"archetype_label": archetype.get("label", ""),
		"context": _build_context_text(profile),
		"reasoning": "",
		"accept_consequence": "Take $%.2f — close the sale." % customer_offer,
		"counter_consequence": (
			"Push back — they may walk if you go above $%.2f." % sticker_price
		),
		"reject_consequence": "Walk away — −2 Rep.",
	}
	_haggle_panel.populate_customer_card(data)


func _on_haggle_panel_accept() -> void:
	if _haggle_system and _haggle_system.is_active():
		_haggle_system.accept_offer()


func _on_haggle_panel_counter(price: float) -> void:
	if _haggle_system and _haggle_system.is_active():
		_haggle_system.player_counter(price)


func _on_haggle_panel_decline() -> void:
	if _haggle_system and _haggle_system.is_active():
		_haggle_system.decline_offer()


func _get_haggle_queue_count() -> int:
	if _register_queue == null:
		return 0
	return maxi(_register_queue.get_size() - 1, 0)


func _on_action_requested(action_id: StringName, _store_id: StringName) -> void:
	if action_id != &"haggle":
		return
	if not _active_customer or not _active_item:
		return
	if _is_haggling or not _haggle_system:
		return
	if _haggle_system.is_active():
		return
	_is_haggling = true
	_haggle_system.begin_negotiation(
		_active_customer, _active_item, _get_haggle_queue_count()
	)


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
	_is_haggling = false
	if _haggle_panel and _haggle_panel.is_open():
		if _haggle_panel.is_card_populated():
			_haggle_panel.show_result(
				"Deal closed at $%.2f — handshake delivered." % final_price
			)
		else:
			_haggle_panel.show_outcome(true)
	initiate_sale(_active_customer, _active_item, _active_offer)


func _on_haggle_failed() -> void:
	_finish_haggle()


func _finish_haggle() -> void:
	_is_haggling = false
	if _haggle_panel and _haggle_panel.is_open():
		if _haggle_panel.is_card_populated():
			_haggle_panel.show_result(
				"They walked away. Reputation took a hit."
			)
		else:
			_haggle_panel.show_outcome(false)
	_complete_checkout()


func _execute_sale() -> void:
	if _is_rental_transaction():
		_execute_rental()
		return
	var item_id: String = _active_item.instance_id
	var market_value: float = _get_perceived_value(_active_item)
	var slot: Node = _active_customer.get_desired_item_slot()
	if slot and slot.has_method("remove_item"):
		slot.remove_item()
	var category: String = ""
	var item_name: String = ""
	if _active_item.definition:
		category = _active_item.definition.category
		item_name = _active_item.definition.item_name
	_inventory_system.remove_item(item_id)
	_apply_sale_reputation(market_value)
	EventBus.item_sold.emit(item_id, _active_offer, category)
	EventBus.transaction_completed.emit(_active_offer, true, "")
	var store_id: StringName = &""
	if _active_item.definition:
		store_id = ContentRegistry.resolve(
			_active_item.definition.store_type
		)
	var cust_id: StringName = &""
	if _active_customer:
		cust_id = StringName(str(_active_customer.get_instance_id()))
	_emit_sale_toast(item_name, _active_offer)
	EventBus.customer_purchased.emit(
		store_id, StringName(item_id), _active_offer, cust_id
	)
	if _active_item.condition in DEFECTIVE_CONDITIONS:
		EventBus.defective_sale_occurred.emit(
			item_id, _active_item.condition
		)


func _is_rental_transaction() -> bool:
	if not _rental_controller or not _active_item:
		return false
	if not _active_item.definition:
		return false
	return _rental_controller.is_rental_item(
		_active_item.definition.category
	)


func _execute_rental() -> void:
	var item_id: String = _active_item.instance_id
	var slot: Node = _active_customer.get_desired_item_slot()
	if slot and slot.has_method("remove_item"):
		slot.remove_item()
	var category: String = _active_item.definition.category
	var rental_fee: float = _active_item.definition.rental_fee
	var rental_tier: String = _active_item.definition.rental_tier
	if rental_tier.is_empty():
		rental_tier = "three_day"
	if rental_fee <= 0.0:
		rental_fee = _active_offer
	if rental_fee <= 0.0:
		push_error("CheckoutSystem: rental has no valid fee, aborting")
		return
	var cust_id: String = ""
	if _active_customer:
		cust_id = str(_active_customer.get_instance_id())
	_rental_controller.process_rental(
		item_id,
		category,
		rental_tier,
		rental_fee,
		GameManager.current_day,
		cust_id,
	)
	_apply_sale_reputation(rental_fee)
	var store_id: StringName = ContentRegistry.resolve(
		_active_item.definition.store_type
	)
	_emit_sale_toast(_active_item.definition.item_name, rental_fee)
	EventBus.customer_purchased.emit(
		store_id, StringName(item_id), rental_fee,
		StringName(cust_id),
	)


## Posts the "Sold <item> for $<price>" feedback toast for the BRAINDUMP Day-1
## "see the sale happen" loop. Emitted from `_execute_sale` / `_execute_rental`
## (rather than from a `customer_purchased` listener elsewhere) because those
## are the only call sites that still hold the live `ItemDefinition` — by the
## time `customer_purchased` fires, `inventory.remove_item` has already wiped
## the instance from the lookup, so a downstream listener cannot recover the
## display name from the instance_id alone.
##
## §F-89 — Pass 13: empty `item_name` is a content-authoring hole (the
## ItemDefinition lacked `item_name`). Skipping the toast rather than emitting
## "Sold  for $X.XX" is the documented fallback (mirrors
## `ambient_moments_system._on_customer_item_spotted`); the surrounding sale
## still completes — only the cosmetic toast is suppressed. The wider
## ItemDefinition validator runs in `tests/validate_*.sh` and CI surfaces the
## missing display name there rather than at runtime.
func _emit_sale_toast(item_name: String, price: float) -> void:
	if item_name.is_empty():
		return
	EventBus.toast_requested.emit(
		"Sold %s for $%.2f" % [item_name, price],
		&"system",
		0.0,
	)


func _apply_sale_reputation(market_value: float) -> void:
	if market_value <= 0.0:
		return
	var ratio: float = _active_offer / market_value
	if ratio > FAIR_THRESHOLD_HIGH:
		return
	var rep_delta: float = ReputationSystemSingleton.REP_FAIR_SALE
	if ratio < GENEROUS_THRESHOLD:
		rep_delta = ReputationSystemSingleton.REP_FAIR_SALE * 1.5
	_reputation_system.add_reputation("", rep_delta)


func _show_warranty_dialog() -> void:
	var item_name: String = _active_item.definition.item_name
	var wholesale: float = _active_item.definition.base_price
	if _economy_system:
		wholesale = _economy_system.get_wholesale_price(
			_active_item.definition
		)
	var tiers: Array = []
	if _active_item.definition.warranty_tiers.size() > 0:
		tiers = _active_item.definition.warranty_tiers
	_warranty_dialog.open(
		_active_item.instance_id,
		item_name,
		_active_offer,
		wholesale,
		WarrantyDialog.DEFAULT_WARRANTY_PERCENT,
		tiers,
	)


func _on_warranty_accepted(
	item_id: String, fee: float
) -> void:
	if _warranty_manager:
		var wholesale: float = 0.0
		if _active_item and _active_item.definition:
			wholesale = _active_item.definition.base_price
			if _economy_system:
				wholesale = _economy_system.get_wholesale_price(
					_active_item.definition
				)
		var tier_id: String = ""
		if _warranty_dialog:
			tier_id = _warranty_dialog.get_selected_tier_id()
		_warranty_manager.add_warranty(
			item_id,
			_active_offer,
			fee,
			wholesale,
			GameManager.current_day,
			tier_id,
		)
	if _economy_system:
		_economy_system.add_cash(fee, "Warranty: %s" % item_id)
	_emit_warranty_price_audit(item_id, fee)
	EventBus.warranty_purchased.emit(item_id, fee)
	EventBus.notification_requested.emit(
		"Warranty sold for $%.2f" % fee
	)
	_complete_checkout()


func _emit_warranty_price_audit(item_id: String, fee: float) -> void:
	if _active_offer <= 0.0:
		return
	var tier_id: String = ""
	if _warranty_dialog:
		tier_id = _warranty_dialog.get_selected_tier_id()
	var tier_label: String = (
		"Warranty (%s)" % tier_id.capitalize()
		if not tier_id.is_empty()
		else "Warranty Add-on"
	)
	var factor: float = 1.0 + fee / _active_offer
	PriceResolver.resolve_for_item(
		StringName(item_id),
		_active_offer,
		[{
			"slot": "warranty",
			"label": tier_label,
			"factor": factor,
			"detail": "Extended warranty fee: $%.2f" % fee,
		}],
		true,
	)


func _on_warranty_declined() -> void:
	_complete_checkout()


func _complete_checkout() -> void:
	var completed_customer: Customer = _active_customer
	if _active_customer and is_instance_valid(_active_customer):
		_register_queue.remove(_active_customer)
		_active_customer.complete_purchase()
	_active_customer = null
	_active_item = null
	_active_offer = 0.0
	_is_processing = false
	if (
		_checkout_panel
		and _checkout_panel.is_open()
		and not _checkout_panel.is_showing_receipt()
		and not _checkout_panel.is_showing_result()
	):
		_checkout_panel.hide_checkout()
		EventBus.panel_closed.emit("checkout")
	if (
		_haggle_panel
		and _haggle_panel.is_open()
		and not _haggle_panel.is_showing_result()
	):
		_haggle_panel.hide_negotiation()
		EventBus.panel_closed.emit("haggle")
	EventBus.queue_advanced.emit(_register_queue.get_size())
	if completed_customer:
		EventBus.checkout_completed.emit(completed_customer)


func _finalize_checkout_no_sale() -> void:
	var completed_customer: Customer = _active_customer
	if _active_customer and is_instance_valid(_active_customer):
		_register_queue.remove(_active_customer)
		_active_customer.complete_purchase()
	_active_customer = null
	_active_item = null
	_active_offer = 0.0
	_is_processing = false
	EventBus.queue_advanced.emit(_register_queue.get_size())
	if completed_customer:
		EventBus.checkout_completed.emit(completed_customer)


func _refresh_cashier() -> void:
	_cashier = null
	var store_id: String = String(GameManager.get_active_store_id())
	if store_id.is_empty():
		return
	var staff: Array[StaffDefinition] = StaffManager.get_staff_for_store(store_id)
	for member: StaffDefinition in staff:
		if member.role == StaffDefinition.StaffRole.CASHIER:
			_cashier = member
			return


func _get_checkout_duration() -> float:
	if _cashier and is_instance_valid(_cashier):
		return CHECKOUT_DURATION / _cashier.performance_multiplier()
	return CHECKOUT_DURATION


func _on_staff_hired(_staff_id: String, _store_id: String) -> void:
	_refresh_cashier()


func _on_staff_fired(_staff_id: String, _store_id: String) -> void:
	_refresh_cashier()


func _on_staff_quit(_staff_id: String) -> void:
	_refresh_cashier()


func _on_staff_morale_changed(_staff_id: String, _new_morale: float) -> void:
	_refresh_cashier()


## §F-112 — Dev-only fallback that completes the next pending checkout
## immediately, bypassing the panel/haggle wait and the checkout timer.
## Routes through the normal `_execute_sale` / `_complete_checkout` path so
## item_sold, transaction_completed, customer_purchased and checkout_completed
## fire exactly as they would for a player-driven accept. Returns true on
## success.
##
## Guarded by `OS.is_debug_build()` — release builds short-circuit and return
## false. Intended to unblock the Day-1 checkout loop when the panel UI is
## not surfacing or the customer is stalled at the register. The cascade of
## silent `return false` paths inside (no inventory system, no waiting
## customer, no desired item, item not in inventory) are precondition checks
## for a dev shortcut; warning at every branch would spam the console for
## harmless rejections (e.g. F11 pressed before any customer arrives). The
## single diagnostic surface is the caller's `push_warning` in
## `debug_overlay._debug_force_complete_sale` ("no pending sale to
## force-complete"), see §F-100.
func dev_force_complete_sale() -> bool:
	if not OS.is_debug_build():
		return false
	if _try_force_complete_active():
		return true
	return _try_force_complete_pending()


func _try_force_complete_active() -> bool:
	if not (_active_customer and is_instance_valid(_active_customer) and _active_item):
		return false
	if _is_processing:
		_checkout_timer.stop()
		_on_checkout_timer_timeout()
		return true
	if _active_offer > 0.0:
		initiate_sale(_active_customer, _active_item, _active_offer)
		_checkout_timer.stop()
		_on_checkout_timer_timeout()
		return true
	return false


func _try_force_complete_pending() -> bool:
	if _inventory_system == null:
		return false
	var customer: Customer = _find_waiting_customer()
	if customer == null:
		return false
	var item: ItemInstance = customer.get_desired_item()
	if item == null or item.definition == null:
		return false
	if not _inventory_system._items.has(item.instance_id):
		return false
	var price: float = _calculate_offer(item, customer)
	initiate_sale(customer, item, price)
	if _is_processing:
		_checkout_timer.stop()
		_on_checkout_timer_timeout()
	return true


func _cancel_active_checkout() -> void:
	if _is_haggling and _haggle_system and _haggle_system.is_active():
		_haggle_system.decline_offer()
		return
	_checkout_timer.stop()
	_active_customer = null
	_active_item = null
	_active_offer = 0.0
	_is_processing = false
	if _checkout_panel and _checkout_panel.is_open():
		_checkout_panel.hide_checkout()
		EventBus.panel_closed.emit("checkout")
