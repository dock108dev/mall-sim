## Tests StoreLeaseDialog multi-step flow: type selection, naming,
## confirmation, pending state, signal handling, and cancellation.
extends GutTest


var _dialog: StoreLeaseDialog
var _lease_requested_calls: Array[Dictionary] = []
var _panel_closed_calls: Array[String] = []
var _store_defs: Array[StoreDefinition] = []


func before_each() -> void:
	_lease_requested_calls = []
	_panel_closed_calls = []
	_store_defs = []
	ContentRegistry.clear_for_testing()
	_register_store_catalog()
	_store_defs = _build_store_defs()

	var scene: PackedScene = preload(
		"res://game/scenes/ui/store_lease_dialog.tscn"
	)
	_dialog = scene.instantiate() as StoreLeaseDialog
	add_child_autofree(_dialog)

	EventBus.lease_requested.connect(_capture_lease_requested)
	EventBus.panel_closed.connect(_capture_panel_closed)


func after_each() -> void:
	if EventBus.lease_requested.is_connected(
		_capture_lease_requested
	):
		EventBus.lease_requested.disconnect(
			_capture_lease_requested
		)
	if EventBus.panel_closed.is_connected(_capture_panel_closed):
		EventBus.panel_closed.disconnect(_capture_panel_closed)
	ContentRegistry.clear_for_testing()


func _capture_lease_requested(
	store_id: StringName,
	slot_index: int,
	store_name: String
) -> void:
	_lease_requested_calls.append({
		"store_id": store_id,
		"slot_index": slot_index,
		"store_name": store_name,
	})


func _capture_panel_closed(panel_name: String) -> void:
	_panel_closed_calls.append(panel_name)


func test_dialog_starts_hidden() -> void:
	assert_false(
		_dialog.visible,
		"Dialog should start hidden"
	)


func test_opens_on_type_selection_step() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	assert_true(
		_dialog._type_page.visible,
		"Type selection page should be visible"
	)
	assert_false(
		_dialog._naming_page.visible,
		"Naming page should be hidden"
	)
	assert_false(
		_dialog._confirm_page.visible,
		"Confirmation page should be hidden"
	)


func test_next_advances_to_naming() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()

	assert_false(
		_dialog._type_page.visible,
		"Type selection page should be hidden after next"
	)
	assert_true(
		_dialog._naming_page.visible,
		"Naming page should be visible"
	)
	assert_eq(
		_dialog._confirm_button.text, "Next",
		"Button should say Next on naming step"
	)


func test_naming_default_name() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()

	assert_false(
		_dialog._name_input.text.is_empty(),
		"Default name should be populated"
	)


func test_naming_empty_name_blocked() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()

	_dialog._name_input.text = ""
	_dialog._on_name_text_changed("")

	assert_true(
		_dialog._confirm_button.disabled,
		"Next should be disabled with empty name"
	)


func test_naming_advances_to_confirmation() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()

	_dialog._name_input.text = "Test Store"
	_dialog._on_confirm_pressed()

	assert_true(
		_dialog._confirm_page.visible,
		"Confirmation page should be visible"
	)
	assert_eq(
		_dialog._confirm_button.text, "Confirm",
		"Button should say Confirm on final step"
	)


func test_back_from_naming_returns_to_type_selection() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()

	_dialog._on_back_pressed()

	assert_true(
		_dialog._type_page.visible,
		"Type selection should be visible after back"
	)
	assert_false(
		_dialog._naming_page.visible,
		"Naming page should be hidden after back"
	)


func test_back_from_confirmation_returns_to_naming() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()
	_dialog._name_input.text = "Test Store"
	_dialog._on_confirm_pressed()

	_dialog._on_back_pressed()

	assert_true(
		_dialog._naming_page.visible,
		"Naming page should be visible after back"
	)
	assert_false(
		_dialog._confirm_page.visible,
		"Confirmation page should be hidden after back"
	)


func test_confirm_emits_lease_requested_with_name() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()
	_dialog._name_input.text = "My Cool Shop"
	_dialog._on_confirm_pressed()
	_dialog._on_confirm_pressed()

	assert_eq(
		_lease_requested_calls.size(), 1,
		"Should emit lease_requested"
	)
	assert_eq(
		_lease_requested_calls[0]["store_name"], "My Cool Shop",
		"Should include custom store name"
	)
	assert_true(
		_dialog.visible,
		"Dialog must stay open while pending"
	)


func test_pending_state_disables_all_buttons() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()
	_dialog._name_input.text = "Test"
	_dialog._on_confirm_pressed()
	_dialog._on_confirm_pressed()

	assert_true(
		_dialog._confirm_button.disabled,
		"Confirm button should be disabled while pending"
	)
	assert_true(
		_dialog._cancel_button.disabled,
		"Cancel button should be disabled while pending"
	)
	assert_true(
		_dialog._back_button.disabled,
		"Back button should be disabled while pending"
	)
	assert_true(
		_dialog._pending_spinner.visible,
		"Pending spinner should be visible while pending"
	)


func test_lease_completed_success_closes_dialog() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()
	_dialog._name_input.text = "Test"
	_dialog._on_confirm_pressed()
	_dialog._on_confirm_pressed()

	var canonical: StringName = ContentRegistry.resolve("sports")
	EventBus.lease_completed.emit(canonical, true, "")

	assert_false(
		_dialog.visible,
		"Dialog should close on successful lease"
	)


func test_lease_completed_failure_shows_error() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()
	_dialog._name_input.text = "Test"
	_dialog._on_confirm_pressed()
	_dialog._on_confirm_pressed()

	var canonical: StringName = ContentRegistry.resolve("sports")
	EventBus.lease_completed.emit(
		canonical, false, "Insufficient funds."
	)

	assert_true(
		_dialog.visible,
		"Dialog should stay open on failure"
	)
	assert_string_contains(
		_dialog._error_label.text, "Insufficient funds."
	)
	assert_false(
		_dialog._confirm_button.disabled,
		"Confirm re-enabled after failure"
	)
	assert_false(
		_dialog._cancel_button.disabled,
		"Cancel re-enabled after failure"
	)


func test_cancel_blocked_while_pending() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()
	_dialog._name_input.text = "Test"
	_dialog._on_confirm_pressed()
	_dialog._on_confirm_pressed()

	_dialog._on_cancel_pressed()
	assert_true(
		_dialog.visible,
		"Cancel should not close dialog while pending"
	)


func test_close_dialog_blocked_while_pending() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()
	_dialog._name_input.text = "Test"
	_dialog._on_confirm_pressed()
	_dialog._on_confirm_pressed()

	_dialog.close_dialog()
	assert_true(
		_dialog.visible,
		"close_dialog should not hide while pending"
	)


func test_ignores_unrelated_lease_completed() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()
	_dialog._name_input.text = "Test"
	_dialog._on_confirm_pressed()
	_dialog._on_confirm_pressed()

	EventBus.lease_completed.emit(
		&"retro_games", true, ""
	)

	assert_true(
		_dialog.visible,
		"Should ignore lease_completed for different store"
	)
	assert_true(
		_dialog._is_pending,
		"Should still be pending"
	)


func test_status_label_shows_pending_text() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()
	_dialog._name_input.text = "Test"
	_dialog._on_confirm_pressed()
	_dialog._on_confirm_pressed()

	assert_eq(
		_dialog._status_label.text, "Processing lease...",
		"Status label should show pending text"
	)


func test_status_label_cleared_after_completion() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()
	_dialog._name_input.text = "Test"
	_dialog._on_confirm_pressed()
	_dialog._on_confirm_pressed()

	var canonical: StringName = ContentRegistry.resolve("sports")
	EventBus.lease_completed.emit(
		canonical, false, "Some error"
	)

	assert_eq(
		_dialog._status_label.text, "",
		"Status label should be cleared after completion"
	)
	assert_false(
		_dialog._pending_spinner.visible,
		"Pending spinner should hide after completion"
	)


func test_cancel_at_any_step_closes_without_side_effects() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()

	_dialog._on_cancel_pressed()

	assert_false(
		_dialog.visible,
		"Dialog should close on cancel from naming step"
	)
	assert_eq(
		_lease_requested_calls.size(), 0,
		"No lease request should be emitted on cancel"
	)


func test_escape_is_ignored_while_pending() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()
	_dialog._name_input.text = "Test"
	_dialog._on_confirm_pressed()
	_dialog._on_confirm_pressed()

	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true
	_dialog._unhandled_input(escape_event)

	assert_true(
		_dialog.visible,
		"Escape should not close the dialog while pending"
	)


func test_dialog_uses_modal_overlay_to_block_background_clicks() -> void:
	assert_eq(
		_dialog.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"Dialog root should block background clicks"
	)
	assert_eq(
		_dialog._overlay.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"Overlay should block pointer input behind the dialog"
	)


func test_owned_stores_grayed_out() -> void:
	var canonical: StringName = ContentRegistry.resolve("sports")
	var owned: Array[StringName] = [canonical]
	_dialog.show_for_slot(1, _store_defs, owned, 1000.0, 50.0)

	var sports_btn: Button = _dialog._store_buttons.get(
		"sports", null
	) as Button
	if sports_btn:
		assert_true(
			sports_btn.disabled,
			"Owned store should be disabled"
		)


func test_name_max_length_enforced() -> void:
	_open_dialog_with_funds(1000.0, 50.0)
	_select_store_type("sports")
	_dialog._on_confirm_pressed()

	assert_eq(
		_dialog._name_input.max_length,
		StoreLeaseDialog.MAX_STORE_NAME_LENGTH,
		"LineEdit should enforce max length"
	)


func _open_dialog_with_funds(
	cash: float, reputation: float
) -> void:
	_dialog.show_for_slot(
		0, _store_defs, [], cash, reputation
	)


func _select_store_type(store_type: String) -> void:
	var canonical: StringName = ContentRegistry.resolve(
		store_type
	)
	_dialog._selected_store_type = (
		String(canonical) if not canonical.is_empty()
		else store_type
	)
	_dialog._selected_store_def = _get_store_def(store_type)
	_dialog._update_confirm_button()


func _get_store_def(store_type: String) -> StoreDefinition:
	for store_def: StoreDefinition in _store_defs:
		var canonical: StringName = ContentRegistry.resolve(store_def.id)
		if canonical == ContentRegistry.resolve(store_type):
			return store_def
	return null


func _build_store_defs() -> Array[StoreDefinition]:
	return [
		_make_store_def(
			"sports",
			"Sports Memorabilia",
			"Authentic jerseys and rare collectibles.",
			120.0,
			8,
			4
		),
		_make_store_def(
			"retro_games",
			"Retro Games",
			"Classic consoles, carts, and repairs.",
			140.0,
			10,
			5
		),
	]


func _make_store_def(
	store_id: String,
	store_name: String,
	description: String,
	daily_rent: float,
	shelf_capacity: int,
	backroom_capacity: int
) -> StoreDefinition:
	var store_def := StoreDefinition.new()
	store_def.id = store_id
	store_def.store_name = store_name
	store_def.description = description
	store_def.size_category = "small"
	store_def.daily_rent = daily_rent
	store_def.shelf_capacity = shelf_capacity
	store_def.backroom_capacity = backroom_capacity
	return store_def


func _register_store_catalog() -> void:
	ContentRegistry.register_entry(
		{
			"id": "sports",
			"aliases": ["sports_memorabilia"],
			"name": "Sports Memorabilia",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "retro_games",
			"name": "Retro Games",
		},
		"store"
	)
