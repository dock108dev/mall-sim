## Tests CustomerStateIndicator debug-mode label updates and signal lifecycle.
extends GutTest

const IndicatorScene: PackedScene = preload(
	"res://game/scenes/characters/customer_state_indicator.tscn"
)
const CustomerScene: PackedScene = preload(
	"res://game/scenes/characters/customer.tscn"
)


func _make_customer(state: Customer.State = Customer.State.ENTERING) -> Customer:
	var customer: Customer = CustomerScene.instantiate()
	add_child_autofree(customer)
	customer.current_state = state
	return customer


func _make_indicator(customer: Customer) -> Node3D:
	var indicator: Node3D = IndicatorScene.instantiate()
	add_child_autofree(indicator)
	indicator.initialize(customer)
	return indicator


func before_each() -> void:
	Customer.reset_debug_id_counter()


func test_initialize_assigns_customer_reference() -> void:
	if not OS.is_debug_build():
		pass_test("non-debug build: indicator hidden, no signal connection")
		return
	var customer: Customer = _make_customer()
	customer.debug_id = 0
	var indicator: Node3D = _make_indicator(customer)
	assert_eq(indicator._customer, customer)


func test_label_shows_id_and_state_in_debug_build() -> void:
	if not OS.is_debug_build():
		pass_test("label suppressed in release builds")
		return
	var customer: Customer = _make_customer(Customer.State.BROWSING)
	customer.debug_id = 7
	var indicator: Node3D = _make_indicator(customer)
	var label: Label3D = indicator.get_node("Label3D")
	assert_eq(label.text, "#7\nBROWSING")


func test_label_updates_on_state_changed_signal() -> void:
	if not OS.is_debug_build():
		pass_test("signal not connected in release builds")
		return
	var customer: Customer = _make_customer(Customer.State.ENTERING)
	customer.debug_id = 2
	var indicator: Node3D = _make_indicator(customer)
	var label: Label3D = indicator.get_node("Label3D")
	customer.current_state = Customer.State.PURCHASING
	EventBus.customer_state_changed.emit(customer, int(Customer.State.PURCHASING))
	assert_eq(label.text, "#2\nPURCHASING")


func test_ignores_other_customer_signals() -> void:
	if not OS.is_debug_build():
		pass_test("signal not connected in release builds")
		return
	var customer: Customer = _make_customer(Customer.State.BROWSING)
	customer.debug_id = 1
	var indicator: Node3D = _make_indicator(customer)
	var label: Label3D = indicator.get_node("Label3D")
	var initial_text: String = label.text
	var other: Customer = _make_customer(Customer.State.LEAVING)
	other.debug_id = 9
	EventBus.customer_state_changed.emit(other, int(Customer.State.LEAVING))
	assert_eq(label.text, initial_text)


func test_signal_disconnects_on_exit_tree() -> void:
	if not OS.is_debug_build():
		pass_test("signal not connected in release builds")
		return
	var customer: Customer = _make_customer()
	customer.debug_id = 0
	var indicator: Node3D = _make_indicator(customer)
	var callable_ref: Callable = Callable(indicator, "_on_state_changed")
	assert_true(EventBus.customer_state_changed.is_connected(callable_ref))
	indicator.get_parent().remove_child(indicator)
	indicator.queue_free()
	await get_tree().process_frame
	assert_false(EventBus.customer_state_changed.is_connected(callable_ref))


func test_indicator_label_uses_billboard_mode() -> void:
	var customer: Customer = _make_customer()
	customer.debug_id = 0
	var indicator: Node3D = _make_indicator(customer)
	var label: Label3D = indicator.get_node("Label3D")
	assert_eq(label.billboard, BaseMaterial3D.BILLBOARD_ENABLED)


func test_customer_scene_contains_indicator_with_label() -> void:
	var customer: Node = CustomerScene.instantiate()
	add_child_autofree(customer)
	var indicator: Node = customer.get_node_or_null("CustomerStateIndicator")
	assert_not_null(indicator)
	assert_not_null(indicator.get_node_or_null("Label3D"))


func test_debug_id_is_short_sequential_integer() -> void:
	Customer.reset_debug_id_counter()
	var first: Customer = _make_customer()
	var second: Customer = _make_customer()
	var third: Customer = _make_customer()
	first.debug_id = -1
	second.debug_id = -1
	third.debug_id = -1
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.patience = 1.0
	profile.browse_time_range = [1.0, 1.0]
	first.initialize(profile, null, null)
	second.initialize(profile, null, null)
	third.initialize(profile, null, null)
	assert_eq(first.debug_id, 0)
	assert_eq(second.debug_id, 1)
	assert_eq(third.debug_id, 2)


func test_indicator_hidden_in_release_build() -> void:
	if OS.is_debug_build():
		pass_test("debug build: indicator stays visible by design")
		return
	var customer: Customer = _make_customer()
	customer.debug_id = 0
	var indicator: Node3D = _make_indicator(customer)
	assert_false(indicator.visible)
	var callable_ref: Callable = Callable(indicator, "_on_state_changed")
	assert_false(EventBus.customer_state_changed.is_connected(callable_ref))
