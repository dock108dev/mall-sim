## Tests RegisterInteractable Day-1 manual checkout gate.
##
## Day-1 first sale should fire on a single E-press: the script reads the
## head-of-queue customer from `customer_ready_to_purchase`, surfaces a
## "Ring up customer" prompt only while the customer is parked at the
## register and `_awaiting_player_checkout` is true, and on `interact()`
## emits `item_sold` + `customer_purchased` and transitions the customer to
## LEAVING. After the first sale, the gate disengages and the script falls
## through to base-class behaviour.
extends GutTest


var _interactable: RegisterInteractable
var _purchased_payloads: Array[Dictionary] = []
var _item_sold_payloads: Array[Dictionary] = []


func before_each() -> void:
	_interactable = RegisterInteractable.new()
	add_child_autofree(_interactable)
	_purchased_payloads = []
	_item_sold_payloads = []
	GameState.set_flag(&"first_sale_complete", false)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.item_sold.connect(_on_item_sold)


func after_each() -> void:
	if EventBus.customer_purchased.is_connected(_on_customer_purchased):
		EventBus.customer_purchased.disconnect(_on_customer_purchased)
	if EventBus.item_sold.is_connected(_on_item_sold):
		EventBus.item_sold.disconnect(_on_item_sold)
	GameState.set_flag(&"first_sale_complete", false)


func _on_customer_purchased(
	store_id: StringName, item_id: StringName, price: float,
	customer_id: StringName,
) -> void:
	_purchased_payloads.append({
		"store_id": store_id,
		"item_id": item_id,
		"price": price,
		"customer_id": customer_id,
	})


func _on_item_sold(
	item_id: String, price: float, category: String,
) -> void:
	_item_sold_payloads.append({
		"item_id": item_id,
		"price": price,
		"category": category,
	})


func _build_customer() -> Customer:
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "test_customer"
	profile.customer_name = "Tester"
	profile.patience = 1.0
	profile.budget_range = [0.0, 100.0]
	profile.browse_time_range = [0.1, 0.2]
	profile.purchase_probability_base = 1.0

	var item_def: ItemDefinition = ItemDefinition.new()
	item_def.id = "test_item"
	item_def.item_name = "Test Cartridge"
	item_def.category = "cartridge"
	item_def.store_type = "retro_games"
	item_def.base_price = 25.0

	var item: ItemInstance = ItemInstance.create(item_def, "good", 0, 25.0)
	item.player_set_price = 30.0

	var customer: Customer = preload(
		"res://game/scenes/characters/customer.tscn"
	).instantiate() as Customer
	add_child_autofree(customer)
	customer.profile = profile
	customer.patience_timer = 100.0
	customer._desired_item = item
	return customer


func test_no_pending_customer_disables_interaction() -> void:
	assert_false(
		_interactable.can_interact(),
		"Without a pending customer the register must not be interactable"
	)
	assert_eq(
		_interactable.get_disabled_reason(),
		RegisterInteractable.PROMPT_NO_CUSTOMER,
		"Disabled reason must surface 'No customer waiting' to the HUD",
	)


func test_pending_customer_not_at_register_disables_interaction() -> void:
	var customer: Customer = _build_customer()
	customer._use_waypoint_fallback = true
	customer.advance_to_register()
	# Simulate "still walking" — re-arm the fallback target so
	# `_is_navigation_finished` reports false.
	customer._fallback_arrived = false
	EventBus.customer_ready_to_purchase.emit({
		"customer_id": customer.get_instance_id(),
	})
	assert_false(
		_interactable.can_interact(),
		"Customer mid-walk must not arm the prompt until they arrive"
	)


func test_day1_e_press_fires_sale_and_transitions_to_leaving() -> void:
	GameManager.set_current_day(1)
	var customer: Customer = _build_customer()
	customer._use_waypoint_fallback = true
	customer._fallback_arrived = true
	customer.advance_to_register()
	EventBus.customer_ready_to_purchase.emit({
		"customer_id": customer.get_instance_id(),
	})

	assert_true(
		customer.is_awaiting_player_checkout(),
		"Day-1 first-sale customer must arm the awaiting-checkout gate"
	)
	assert_true(
		_interactable.can_interact(),
		"Day-1 customer at register must surface the ring-up prompt"
	)

	_interactable.interact()

	assert_eq(
		_purchased_payloads.size(), 1,
		"interact() must emit exactly one customer_purchased event"
	)
	assert_eq(
		_item_sold_payloads.size(), 1,
		"interact() must emit item_sold so first_sale_complete latches"
	)
	assert_eq(
		customer.current_state, Customer.State.LEAVING,
		"Customer must transition to LEAVING after the sale fires"
	)
	assert_null(
		_interactable.get_pending_customer(),
		"Pending customer must clear after the sale fires"
	)


func test_patience_does_not_tick_while_awaiting_checkout() -> void:
	GameManager.set_current_day(1)
	var customer: Customer = _build_customer()
	customer._use_waypoint_fallback = true
	customer._fallback_arrived = true
	customer.advance_to_register()
	customer.patience_timer = 5.0

	customer._process_purchasing(2.0)

	assert_eq(
		customer.patience_timer, 5.0,
		"Patience must be paused while _awaiting_player_checkout is true"
	)


func test_patience_ticks_when_gate_disengaged() -> void:
	GameManager.set_current_day(2)
	var customer: Customer = _build_customer()
	customer._use_waypoint_fallback = true
	customer._fallback_arrived = true
	customer.advance_to_register()
	customer.patience_timer = 5.0

	assert_false(
		customer.is_awaiting_player_checkout(),
		"Day-2 customer must not arm the manual-checkout gate"
	)
	customer._process_purchasing(2.0)
	assert_almost_eq(
		customer.patience_timer, 3.0, 0.001,
		"Day-2 customer patience must tick normally"
	)


func test_first_sale_complete_disengages_gate_for_next_customer() -> void:
	GameManager.set_current_day(1)
	GameState.set_flag(&"first_sale_complete", true)
	var customer: Customer = _build_customer()
	customer._use_waypoint_fallback = true
	customer._fallback_arrived = true
	customer.advance_to_register()
	assert_false(
		customer.is_awaiting_player_checkout(),
		"After first_sale_complete, Day-1 customers must not gate on E-press"
	)


func test_complete_purchase_clears_awaiting_flag() -> void:
	GameManager.set_current_day(1)
	var customer: Customer = _build_customer()
	customer._use_waypoint_fallback = true
	customer._fallback_arrived = true
	customer.advance_to_register()
	assert_true(customer.is_awaiting_player_checkout())
	customer.complete_purchase()
	assert_false(
		customer.is_awaiting_player_checkout(),
		"complete_purchase must clear the manual-checkout gate"
	)


func test_leave_with_clears_awaiting_flag() -> void:
	GameManager.set_current_day(1)
	var customer: Customer = _build_customer()
	customer._use_waypoint_fallback = true
	customer._fallback_arrived = true
	customer.advance_to_register()
	assert_true(customer.is_awaiting_player_checkout())
	customer._leave_with(&"patience_expired")
	assert_false(
		customer.is_awaiting_player_checkout(),
		"_leave_with must clear the manual-checkout gate"
	)


func test_customer_leaving_clears_pending_reference() -> void:
	GameManager.set_current_day(1)
	var customer: Customer = _build_customer()
	customer._use_waypoint_fallback = true
	customer._fallback_arrived = true
	customer.advance_to_register()
	EventBus.customer_ready_to_purchase.emit({
		"customer_id": customer.get_instance_id(),
	})
	assert_not_null(_interactable.get_pending_customer())
	customer._leave_with(&"patience_expired")
	assert_null(
		_interactable.get_pending_customer(),
		"Pending reference must drop when the customer transitions to LEAVING"
	)


func test_day1_queue_patience_ticks_at_half_rate() -> void:
	GameManager.set_current_day(1)
	GameState.set_flag(&"first_sale_complete", false)
	var customer: Customer = _build_customer()
	customer._use_waypoint_fallback = true
	customer.enter_queue(Vector3(1.0, 0.0, 0.0))
	customer.patience_timer = 10.0
	customer._process_waiting_in_queue(2.0)
	assert_almost_eq(
		customer.patience_timer, 9.0, 0.001,
		"Day-1 queue customers tick at half rate while first sale is pending"
	)


func test_day2_queue_patience_ticks_at_full_rate() -> void:
	GameManager.set_current_day(2)
	var customer: Customer = _build_customer()
	customer._use_waypoint_fallback = true
	customer.enter_queue(Vector3(1.0, 0.0, 0.0))
	customer.patience_timer = 10.0
	customer._process_waiting_in_queue(2.0)
	assert_almost_eq(
		customer.patience_timer, 8.0, 0.001,
		"Day-2 queue customers tick at the normal rate"
	)
