## Tests ProvenancePanel: open/close, suspicious detection, accept/reject flows.
extends GutTest


var _panel: ProvenancePanel


func _make_definition(
	base_price: float,
	suspicious: float = 0.0,
	store_type: String = "sports",
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = "test_provenance_item"
	def.item_name = "Test Provenance Item"
	def.store_type = store_type
	def.base_price = base_price
	def.rarity = "common"
	def.suspicious_chance = suspicious
	return def


func _make_item(
	def: ItemDefinition, condition: String = "good"
) -> ItemInstance:
	var item: ItemInstance = ItemInstance.create_from_definition(
		def, condition
	)
	return item


func before_each() -> void:
	_panel = preload(
		"res://game/scenes/ui/provenance_panel.tscn"
	).instantiate() as ProvenancePanel
	add_child_autofree(_panel)


# --- test_open_populates_labels ---


func test_open_populates_labels() -> void:
	var def: ItemDefinition = _make_definition(50.0)
	var item: ItemInstance = _make_item(def)
	var customer: Node = Node.new()
	add_child_autofree(customer)

	_panel.open(item, customer, 45.0)

	assert_true(_panel.is_open(), "Panel should be open")
	var name_label: Label = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/InfoVBox/ItemNameLabel"
		)
	)
	assert_eq(
		name_label.text, "Test Provenance Item",
		"Item name should be populated"
	)
	var price_label: Label = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/InfoVBox/AskingPriceLabel"
		)
	)
	assert_eq(
		price_label.text, "Asking Price: $45.00",
		"Asking price should be formatted correctly"
	)


# --- test_suspicious_indicator_visible ---


func test_suspicious_indicator_visible() -> void:
	var def: ItemDefinition = _make_definition(100.0, 1.0)
	var item: ItemInstance = _make_item(def)
	var customer: Node = Node.new()
	add_child_autofree(customer)

	_panel.open(item, customer, 90.0)

	assert_true(
		_panel.get_is_suspicious(),
		"Item with 100% suspicious chance should be suspicious"
	)
	var suspicious_label: Label = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/InfoVBox/SuspiciousLabel"
		)
	)
	assert_true(
		suspicious_label.visible,
		"Suspicious label should be visible"
	)


# --- test_non_suspicious_indicator_hidden ---


func test_non_suspicious_indicator_hidden() -> void:
	var def: ItemDefinition = _make_definition(100.0, 0.0)
	var item: ItemInstance = _make_item(def)
	var customer: Node = Node.new()
	add_child_autofree(customer)

	_panel.open(item, customer, 90.0)

	assert_false(
		_panel.get_is_suspicious(),
		"Item with 0% suspicious chance should not be suspicious"
	)
	var suspicious_label: Label = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/InfoVBox/SuspiciousLabel"
		)
	)
	assert_false(
		suspicious_label.visible,
		"Suspicious label should be hidden"
	)


# --- test_suspicious_applies_penalty ---


func test_suspicious_applies_penalty() -> void:
	var def: ItemDefinition = _make_definition(100.0, 1.0)
	var item: ItemInstance = _make_item(def)
	var customer: Node = Node.new()
	add_child_autofree(customer)

	_panel.open(item, customer, 90.0)

	var full_value: float = _panel.get_authenticated_value()
	var auth_label: Label = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/InfoVBox/AuthValueLabel"
		)
	)
	var expected_text: String = (
		"Authenticated Value: $%.2f"
		% (full_value * ProvenancePanel.SUSPICIOUS_PENALTY)
	)
	assert_eq(
		auth_label.text, expected_text,
		"Suspicious items should show 50%% penalty value"
	)


# --- test_accept_emits_signal ---


func test_accept_emits_signal() -> void:
	var def: ItemDefinition = _make_definition(50.0)
	var item: ItemInstance = _make_item(def)
	var customer: Node = Node.new()
	add_child_autofree(customer)

	_panel.open(item, customer, 45.0)

	var accepted_ids: Array[String] = []
	var capture: Callable = func(id: String) -> void:
		accepted_ids.append(id)
	EventBus.provenance_accepted.connect(capture)

	var accept_btn: Button = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/ButtonHBox/AcceptButton"
		)
	)
	accept_btn.pressed.emit()

	EventBus.provenance_accepted.disconnect(capture)
	assert_eq(
		accepted_ids.size(), 1,
		"provenance_accepted should fire once"
	)
	assert_eq(
		accepted_ids[0], item.instance_id,
		"Signal should carry the correct item ID"
	)


# --- test_reject_emits_signals ---


func test_reject_emits_signals() -> void:
	var def: ItemDefinition = _make_definition(50.0)
	var item: ItemInstance = _make_item(def)
	var customer: Node = Node.new()
	add_child_autofree(customer)

	_panel.open(item, customer, 45.0)

	var rejected_ids: Array[String] = []
	var left_nodes: Array[Node] = []
	var capture_reject: Callable = func(id: String) -> void:
		rejected_ids.append(id)
	var capture_left: Callable = func(
		c: Node, _satisfied: bool
	) -> void:
		left_nodes.append(c)
	EventBus.provenance_rejected.connect(capture_reject)
	EventBus.customer_left_mall.connect(capture_left)

	var reject_btn: Button = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/ButtonHBox/RejectButton"
		)
	)
	reject_btn.pressed.emit()

	EventBus.provenance_rejected.disconnect(capture_reject)
	EventBus.customer_left_mall.disconnect(capture_left)
	assert_eq(
		rejected_ids.size(), 1,
		"provenance_rejected should fire once"
	)
	assert_eq(
		left_nodes.size(), 1,
		"customer_left_mall should fire once"
	)
	assert_false(
		_panel.is_open(),
		"Panel should close after reject"
	)


# --- test_accept_disables_buttons_while_pending ---


func test_accept_disables_buttons_while_pending() -> void:
	var def: ItemDefinition = _make_definition(50.0)
	var item: ItemInstance = _make_item(def)
	var customer: Node = Node.new()
	add_child_autofree(customer)

	_panel.open(item, customer, 45.0)

	var accept_btn: Button = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/ButtonHBox/AcceptButton"
		)
	)
	var reject_btn: Button = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/ButtonHBox/RejectButton"
		)
	)
	accept_btn.pressed.emit()

	assert_true(
		accept_btn.disabled,
		"Accept button should be disabled while pending"
	)
	assert_true(
		reject_btn.disabled,
		"Reject button should be disabled while pending"
	)


# --- test_completed_success_closes_panel ---


func test_completed_success_closes_panel() -> void:
	var def: ItemDefinition = _make_definition(50.0)
	var item: ItemInstance = _make_item(def)
	var customer: Node = Node.new()
	add_child_autofree(customer)

	_panel.open(item, customer, 45.0)
	var item_id: String = item.instance_id

	var accept_btn: Button = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/ButtonHBox/AcceptButton"
		)
	)
	accept_btn.pressed.emit()

	EventBus.provenance_completed.emit(item_id, true, "")

	assert_false(
		_panel.is_open(),
		"Panel should close on successful completion"
	)


# --- test_completed_failure_shows_error ---


func test_completed_failure_shows_error() -> void:
	var def: ItemDefinition = _make_definition(50.0)
	var item: ItemInstance = _make_item(def)
	var customer: Node = Node.new()
	add_child_autofree(customer)

	_panel.open(item, customer, 45.0)
	var item_id: String = item.instance_id

	var accept_btn: Button = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/ButtonHBox/AcceptButton"
		)
	)
	accept_btn.pressed.emit()

	EventBus.provenance_completed.emit(
		item_id, false, "Verification failed"
	)

	assert_true(
		_panel.is_open(),
		"Panel should stay open on failure"
	)
	var error_label: Label = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/InfoVBox/ErrorLabel"
		)
	)
	assert_true(
		error_label.visible,
		"Error label should be visible"
	)
	assert_eq(
		error_label.text, "Verification failed",
		"Error label should show the failure message"
	)
	assert_false(
		accept_btn.disabled,
		"Buttons should be re-enabled after failure"
	)


# --- test_double_open_ignored ---


func test_double_open_ignored() -> void:
	var def: ItemDefinition = _make_definition(50.0)
	var item1: ItemInstance = _make_item(def)
	var item2: ItemInstance = _make_item(def)
	var customer: Node = Node.new()
	add_child_autofree(customer)

	_panel.open(item1, customer, 45.0)
	_panel.open(item2, customer, 55.0)

	var price_label: Label = (
		_panel.get_node(
			"PanelRoot/Margin/VBox/InfoVBox/AskingPriceLabel"
		)
	)
	assert_eq(
		price_label.text, "Asking Price: $45.00",
		"Should keep first item's data when already open"
	)
