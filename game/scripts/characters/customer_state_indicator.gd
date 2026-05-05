## Floating billboard label that shows a customer's debug id and current state
## above their head. Visible only in debug builds — release builds hide the
## node and never connect the EventBus signal so there is no render or signal
## cost in shipped builds.
extends Node3D

var _customer: Customer = null

@onready var _label: Label3D = $Label3D


func initialize(customer: Customer) -> void:
	_customer = customer
	if not OS.is_debug_build():
		visible = false
		return
	visible = true
	_update_label()
	if not EventBus.customer_state_changed.is_connected(_on_state_changed):
		EventBus.customer_state_changed.connect(_on_state_changed)


func _on_state_changed(customer: Node, _new_state: int) -> void:
	if customer != _customer:
		return
	_update_label()


func _update_label() -> void:
	if _customer == null or _label == null:
		return
	var name: String = Customer.state_name(int(_customer.current_state))
	_label.text = "#%d\n%s" % [
		_customer.debug_id, name if not name.is_empty() else "?",
	]


func _exit_tree() -> void:
	if EventBus.customer_state_changed.is_connected(_on_state_changed):
		EventBus.customer_state_changed.disconnect(_on_state_changed)
