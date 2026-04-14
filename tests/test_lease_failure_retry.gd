## Integration test verifying the transactional lease dialog: failure keeps
## dialog open with an error message, and retry with sufficient funds closes it.
extends GutTest


const STORE_TYPE: StringName = &"sports"
const TEST_SLOT: int = 1
## Matches StoreLeaseDialog.UNLOCK_REQUIREMENTS[1].cost for slot index 1.
const LEASE_COST: float = 500.0

var _dialog: StoreLeaseDialog
var _economy: EconomySystem
var _store_state: StoreStateManager
var _lease_requested_calls: Array[Dictionary] = []
var _lease_completed_calls: Array[Dictionary] = []


func before_each() -> void:
	_lease_requested_calls = []
	_lease_completed_calls = []

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(0.0)

	_store_state = StoreStateManager.new()
	add_child_autofree(_store_state)
	_store_state.initialize(null, _economy)

	var scene: PackedScene = preload(
		"res://game/scenes/ui/store_lease_dialog.tscn"
	)
	_dialog = scene.instantiate() as StoreLeaseDialog
	add_child_autofree(_dialog)

	EventBus.lease_requested.connect(_on_lease_requested)
	EventBus.lease_completed.connect(_capture_lease_completed)


func after_each() -> void:
	if EventBus.lease_requested.is_connected(_on_lease_requested):
		EventBus.lease_requested.disconnect(_on_lease_requested)
	if EventBus.lease_completed.is_connected(_capture_lease_completed):
		EventBus.lease_completed.disconnect(_capture_lease_completed)


func _on_lease_requested(
	store_id: StringName,
	slot_index: int,
	_store_name: String
) -> void:
	_lease_requested_calls.append({
		"store_id": store_id,
		"slot_index": slot_index,
	})
	if _economy.get_cash() < LEASE_COST:
		EventBus.lease_completed.emit(
			store_id, false, "Insufficient funds."
		)
		return
	var success: bool = _economy.deduct_cash(
		LEASE_COST, "Store setup fee: %s" % store_id
	)
	if not success:
		EventBus.lease_completed.emit(
			store_id, false, "Insufficient funds."
		)
		return
	_store_state.lease_store(slot_index, store_id)


func _capture_lease_completed(
	store_id: StringName, success: bool, message: String
) -> void:
	_lease_completed_calls.append({
		"store_id": store_id,
		"success": success,
		"message": message,
	})


func test_lease_requested_fires_on_confirm() -> void:
	_open_dialog()
	_advance_to_confirmation()
	_dialog._on_confirm_pressed()

	assert_eq(
		_lease_requested_calls.size(), 1,
		"lease_requested must fire once when confirm is pressed"
	)


func test_dialog_remains_visible_after_failure() -> void:
	_open_dialog()
	_advance_to_confirmation()
	_dialog._on_confirm_pressed()

	assert_true(
		_dialog.visible,
		"Dialog must remain visible after lease failure"
	)


func test_error_label_shows_failure_reason() -> void:
	_open_dialog()
	_advance_to_confirmation()
	_dialog._on_confirm_pressed()

	assert_string_contains(
		_dialog._error_label.text,
		"Insufficient funds.",
		"Error label must display the failure reason from the signal"
	)


func test_confirm_button_reenabled_after_failure() -> void:
	_open_dialog()
	_advance_to_confirmation()
	_dialog._on_confirm_pressed()

	assert_false(
		_dialog._confirm_button.disabled,
		"Confirm button must be re-enabled after a failed attempt"
	)
	assert_false(
		_dialog._cancel_button.disabled,
		"Cancel button must be re-enabled after a failed attempt"
	)


func test_retry_closes_dialog_on_success() -> void:
	_open_dialog()
	_advance_to_confirmation()

	_dialog._on_confirm_pressed()
	assert_true(
		_dialog.visible,
		"Dialog stays open after first failure"
	)

	_economy.add_cash(1000.0, "test grant")
	_dialog._on_confirm_pressed()

	assert_false(
		_dialog.visible,
		"Dialog must close after successful retry"
	)


func test_owned_slot_registered_after_successful_retry() -> void:
	_open_dialog()
	_advance_to_confirmation()

	_dialog._on_confirm_pressed()
	_economy.add_cash(1000.0, "test grant")
	_dialog._on_confirm_pressed()

	assert_true(
		_store_state.owned_slots.has(TEST_SLOT),
		"StoreStateSystem.owned_slots must include the leased slot"
	)


func test_lease_completed_success_signal_on_retry() -> void:
	_open_dialog()
	_advance_to_confirmation()

	_dialog._on_confirm_pressed()

	assert_eq(
		_lease_completed_calls.size(), 1,
		"One lease_completed emitted on failed attempt"
	)
	assert_false(
		_lease_completed_calls[0]["success"] as bool,
		"First lease_completed must be a failure"
	)

	_economy.add_cash(1000.0, "test grant")
	_dialog._on_confirm_pressed()

	assert_eq(
		_lease_requested_calls.size(), 2,
		"lease_requested must fire on both the failed and retry attempts"
	)
	var last_completed: Dictionary = (
		_lease_completed_calls[_lease_completed_calls.size() - 1]
	)
	assert_true(
		last_completed["success"] as bool,
		"Final lease_completed must be a success"
	)
	assert_eq(
		last_completed["message"] as String, "",
		"Successful lease_completed must carry an empty message"
	)


func _open_dialog() -> void:
	var owned: Array[StringName] = []
	var canonical: StringName = ContentRegistry.resolve("retro_games")
	if not canonical.is_empty():
		owned.append(canonical)
	else:
		owned.append(&"retro_games")

	var store_defs: Array[StoreDefinition] = []
	if GameManager.data_loader:
		store_defs = GameManager.data_loader.get_all_stores()

	_dialog.show_for_slot(TEST_SLOT, store_defs, owned, 1000.0, 100.0)


func _advance_to_confirmation() -> void:
	var canonical: StringName = ContentRegistry.resolve("sports")
	_dialog._selected_store_type = (
		String(canonical) if not canonical.is_empty() else "sports"
	)
	if GameManager.data_loader:
		_dialog._selected_store_def = (
			GameManager.data_loader.get_store("sports")
		)
	_dialog._update_confirm_button()
	_dialog._on_confirm_pressed()
	_dialog._on_confirm_pressed()
