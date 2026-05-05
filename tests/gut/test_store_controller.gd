## Tests StoreController base class: lifecycle signals, activation, and
## inventory/customer delegation.
extends GutTest


var _controller: StoreController
var _focus: Node


func before_each() -> void:
	_controller = StoreController.new()
	_controller.store_type = "test_store"
	add_child_autofree(_controller)
	_focus = get_tree().root.get_node_or_null("InputFocus")
	if _focus != null:
		_focus._reset_for_tests()


func after_each() -> void:
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func test_active_store_changed_activates() -> void:
	EventBus.active_store_changed.emit(&"test_store")
	assert_true(
		_controller.is_active(),
		"Controller should be active after matching store change"
	)


func test_active_store_changed_deactivates() -> void:
	EventBus.active_store_changed.emit(&"test_store")
	assert_true(_controller.is_active())
	EventBus.active_store_changed.emit(&"other_store")
	assert_false(
		_controller.is_active(),
		"Controller should deactivate on non-matching store change"
	)


func test_not_active_by_default() -> void:
	assert_false(
		_controller.is_active(),
		"Controller should not be active by default"
	)


func test_get_inventory_without_system() -> void:
	var result: Array[Dictionary] = _controller.get_inventory()
	assert_eq(
		result.size(), 0,
		"get_inventory should return empty without InventorySystem"
	)


func test_get_active_customers_without_system() -> void:
	var result: Array[Node] = _controller.get_active_customers()
	assert_eq(
		result.size(), 0,
		"get_active_customers should return empty without CustomerSystem"
	)


func test_emit_store_signal_invalid_signal() -> void:
	_controller.emit_store_signal(&"nonexistent_signal_xyz")
	assert_true(
		true,
		"emit_store_signal with invalid signal should not crash"
	)


func test_deactivation_only_fires_when_was_active() -> void:
	EventBus.active_store_changed.emit(&"other_store")
	assert_false(
		_controller.is_active(),
		"Should remain inactive without prior activation"
	)


# ── StoreReadyContract interface methods ─────────────────────────────────────

func test_is_controller_initialized_true_after_initialize_store() -> void:
	var fresh: StoreController = StoreController.new()
	add_child_autofree(fresh)
	assert_false(
		fresh.is_controller_initialized(),
		"is_controller_initialized() must be false before initialize_store()"
	)
	fresh.initialize_store(&"some_store")
	assert_true(
		fresh.is_controller_initialized(),
		"is_controller_initialized() must be true after initialize_store()"
	)


func test_get_input_context_returns_focus_current() -> void:
	if _focus == null:
		return
	_focus.push_context(_focus.CTX_STORE_GAMEPLAY)
	assert_eq(
		_controller.get_input_context(),
		_focus.CTX_STORE_GAMEPLAY,
		"get_input_context() must mirror InputFocus.current()"
	)


func test_has_blocking_modal_true_only_for_modal_context() -> void:
	if _focus == null:
		return
	_focus.push_context(_focus.CTX_STORE_GAMEPLAY)
	assert_false(
		_controller.has_blocking_modal(),
		"store_gameplay context must not be classified as a blocking modal"
	)
	_focus.push_context(_focus.CTX_MODAL)
	assert_true(
		_controller.has_blocking_modal(),
		"modal context must classify as a blocking modal"
	)


# ── store_entered/store_exited InputFocus push/pop ───────────────────────────

func test_store_entered_pushes_gameplay_context() -> void:
	if _focus == null:
		return
	_controller._ready()  # ensure lifecycle signals connected
	EventBus.store_entered.emit(StringName(_controller.store_type))
	# `_handle_store_entered` is queued via call_deferred; flush it.
	await get_tree().process_frame
	assert_eq(
		_focus.current(),
		_focus.CTX_STORE_GAMEPLAY,
		"store_entered for this controller must push CTX_STORE_GAMEPLAY"
	)


func test_store_entered_for_other_store_does_not_push() -> void:
	if _focus == null:
		return
	_controller._ready()
	EventBus.store_entered.emit(&"some_other_store")
	await get_tree().process_frame
	assert_ne(
		_focus.current(),
		_focus.CTX_STORE_GAMEPLAY,
		"store_entered for a different store_id must not push gameplay context"
	)


func test_store_exited_pops_gameplay_context() -> void:
	if _focus == null:
		return
	_controller._ready()
	EventBus.store_entered.emit(StringName(_controller.store_type))
	await get_tree().process_frame
	assert_eq(_focus.current(), _focus.CTX_STORE_GAMEPLAY)
	EventBus.store_exited.emit(StringName(_controller.store_type))
	assert_ne(
		_focus.current(),
		_focus.CTX_STORE_GAMEPLAY,
		"store_exited for this controller must pop the gameplay context"
	)


# ── current_objective_text wired from EventBus ───────────────────────────────

func test_objective_updated_sets_current_objective_text() -> void:
	_controller._ready()
	EventBus.objective_updated.emit({
		"current_objective": "Stock your first item and make a sale",
		"next_action": "Press I",
		"input_hint": "I",
		"optional_hint": "",
	})
	assert_eq(
		_controller.current_objective_text,
		"Stock your first item and make a sale",
		"objective_updated payload should populate current_objective_text"
	)


func test_objective_changed_sets_current_objective_text() -> void:
	_controller._ready()
	EventBus.objective_changed.emit({
		"text": "Find your pricing sweet spot",
		"action": "Right-click stocked items",
		"key": "",
	})
	assert_eq(
		_controller.current_objective_text,
		"Find your pricing sweet spot",
		"objective_changed payload should populate current_objective_text"
	)


func test_hidden_objective_payload_does_not_clear_text() -> void:
	_controller._ready()
	_controller.set_objective_text("existing text")
	EventBus.objective_updated.emit({"hidden": true})
	assert_eq(
		_controller.current_objective_text,
		"existing text",
		"hidden=true payload must not overwrite current_objective_text"
	)


func test_objective_matches_action_passes_when_key_present() -> void:
	_controller._ready()
	# Day 1 step 0 — text has no Interactable verb match ("open"+"inventory"
	# is not a registered Interactable in the bare controller fixture), but
	# key="I" makes it a valid actionable input.
	EventBus.objective_changed.emit({
		"text": "Open your inventory",
		"action": "Press I to open the inventory panel",
		"key": "I",
	})
	assert_true(
		_controller.objective_matches_action(),
		"keyboard-shortcut objectives must satisfy invariant 10 even when "
		+ "no on-stage Interactable verb matches"
	)


func test_objective_matches_action_fails_without_key_or_match() -> void:
	_controller._ready()
	EventBus.objective_changed.emit({
		"text": "Wait for a customer to arrive",
		"action": "Customers will spawn shortly",
		"key": "",
	})
	assert_false(
		_controller.objective_matches_action(),
		"objectives without a key and without a matching Interactable should "
		+ "still fail invariant 10"
	)
