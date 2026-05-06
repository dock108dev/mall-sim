## Register Interactable — fires the Day-1 first sale on a single E-press.
##
## When the head-of-queue customer parks at the register on Day 1 (before the
## first-sale flag is set), the Customer FSM pauses patience and arms the
## `_awaiting_player_checkout` gate. Pressing E here resolves the sale
## directly: it removes the item from the shelf slot, emits `item_sold` and
## `customer_purchased` (so the inventory, economy, reputation, performance,
## and ObjectiveDirector subscribers all run), and transitions the customer
## to LEAVING. After the first sale, `first_sale_complete` is set on Day 1's
## `item_sold` handler in ObjectiveDirector and subsequent customers fall
## through to the existing PlayerCheckout E-press flow.
class_name RegisterInteractable
extends Interactable

const PROMPT_NO_CUSTOMER: String = "No customer waiting"
const PROMPT_DEFAULT_VERB: String = "Ring up customer"

var _pending_customer: Customer = null


func _ready() -> void:
	interaction_type = InteractionType.REGISTER
	# Default copy when authored without explicit overrides — the HUD
	# composes `prompt_text` + `display_name` into "Press E to <verb>".
	if prompt_text.is_empty() or prompt_text == "Use":
		prompt_text = PROMPT_DEFAULT_VERB
	if display_name == "Item":
		display_name = ""
	super._ready()
	EventBus.customer_ready_to_purchase.connect(
		_on_customer_ready_to_purchase
	)
	EventBus.customer_state_changed.connect(_on_customer_state_changed)


## Returns the currently-pending head-of-queue customer, or null. Exposed for
## tests and the debug overlay so they can observe the wired customer without
## reaching into private fields.
func get_pending_customer() -> Customer:
	if _pending_customer != null and not is_instance_valid(_pending_customer):
		_pending_customer = null
	return _pending_customer


func can_interact(_actor: Node = null) -> bool:
	var customer: Customer = get_pending_customer()
	if customer == null:
		return false
	return customer.is_at_register()


func get_disabled_reason(_actor: Node = null) -> String:
	if get_pending_customer() == null:
		return PROMPT_NO_CUSTOMER
	return ""


## Single-press resolution path. When the Day-1 manual-checkout gate is armed,
## the sale fires directly. Otherwise the call falls through to the base
## Interactable so PlayerCheckout's existing `interactable_interacted` handler
## opens the panel for Day 2+ checkouts.
func interact(by: Node = null) -> void:
	if not enabled:
		return
	if not can_interact(by):
		return
	var customer: Customer = _pending_customer
	if customer.is_awaiting_player_checkout():
		_pending_customer = null
		_fire_quick_sale(customer)
		return
	super.interact(by)


func _fire_quick_sale(customer: Customer) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	var item: ItemInstance = customer.get_desired_item()
	if item == null or item.definition == null:
		# error-handling-report.md §4 — A customer parked at the register
		# without a desired item / definition violates the Customer FSM
		# invariant: `_pending_customer` only flips on
		# `customer_ready_to_purchase`, which is gated on a resolved
		# desired item. Escalated to push_error so the broken FSM path
		# fails CI's stderr scan instead of being silently downgraded to
		# a queue rejection in production.
		push_error(
			"RegisterInteractable: customer %d has no desired item"
			% customer.get_instance_id()
		)
		customer.reject_from_queue()
		return
	var slot: Node = customer.get_desired_item_slot()
	var item_instance_id: String = item.instance_id
	var category: String = item.definition.category
	var price: float = item.player_set_price
	if price <= 0.0:
		price = item.get_current_value()
	var store_id: StringName = ContentRegistry.resolve(
		item.definition.store_type
	)
	var customer_id: StringName = StringName(
		str(customer.get_instance_id())
	)
	# Clearing the visual slot before subscribers run mirrors
	# PlayerCheckout._execute_sale, where `slot.remove_item()` precedes the
	# inventory deduction so the placeholder mesh disappears in the same
	# frame as the cash hit.
	if slot != null and slot.has_method("remove_item"):
		slot.remove_item()
	# `item_sold` is the canonical signal that drives ObjectiveDirector to
	# set `first_sale_complete`; `customer_purchased` drives inventory
	# deduction, economy cash, reputation, performance reports, and the
	# Day-1 step advance. Both must fire to keep the autoresolved Day-2+
	# path in parity with the manual Day-1 path.
	EventBus.item_sold.emit(item_instance_id, price, category)
	EventBus.customer_purchased.emit(
		store_id, StringName(item_instance_id), price, customer_id
	)
	customer.complete_purchase()


func _on_customer_ready_to_purchase(customer_data: Dictionary) -> void:
	var cust_id: int = int(customer_data.get("customer_id", 0))
	if cust_id == 0:
		return
	var node: Object = instance_from_id(cust_id)
	if node == null or not (node is Customer):
		return
	_pending_customer = node as Customer


func _on_customer_state_changed(customer: Node, new_state: int) -> void:
	if customer == null:
		return
	if customer != _pending_customer:
		return
	if new_state == Customer.State.LEAVING:
		_pending_customer = null
