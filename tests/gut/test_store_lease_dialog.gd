## Tests StoreLeaseDialog multi-step flow: type selection, naming,
## confirmation, pending state, signal handling, and cancellation.
extends GutTest


var _dialog: StoreLeaseDialog
var _lease_requested_calls: Array[Dictionary] = []
var _panel_closed_calls: Array[String] = []


func before_each() -> void:
	_lease_requested_calls = []
	_panel_closed_calls = []

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


func test_owned_stores_grayed_out() -> void:
	var store_defs: Array[StoreDefinition] = []
	if GameManager.data_loader:
		store_defs = GameManager.data_loader.get_all_stores()

	var canonical: StringName = ContentRegistry.resolve("sports")
	var owned: Array[StringName] = [canonical]
	_dialog.show_for_slot(1, store_defs, owned, 1000.0, 50.0)

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
	var store_defs: Array[StoreDefinition] = []
	if GameManager.data_loader:
		store_defs = GameManager.data_loader.get_all_stores()
	_dialog.show_for_slot(
		0, store_defs, [], cash, reputation
	)


func _select_store_type(store_type: String) -> void:
	var canonical: StringName = ContentRegistry.resolve(
		store_type
	)
	_dialog._selected_store_type = (
		String(canonical) if not canonical.is_empty()
		else store_type
	)
	if GameManager.data_loader:
		_dialog._selected_store_def = (
			GameManager.data_loader.get_store(store_type)
		)
	_dialog._update_confirm_button()
