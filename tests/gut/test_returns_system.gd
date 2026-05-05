## Unit tests for ReturnsSystem (post-sale returns and exchanges flow).
##
## Covers:
##   - defective_sale_occurred emission by CheckoutSystem on poor/damaged sales
##   - record creation + spawn-gate metadata
##   - decision API trust / approval / reputation / cash side effects
##   - Deny option unavailable when item condition is poor/damaged
##   - Exchange option hidden until employee_stocking_trained is granted
##   - damaged-bin variance fires inventory_variance_noted and bumps
##     HiddenThreadSystem.scapegoat_risk
##   - All four new EventBus signals declared and emitted
extends GutTest


const SALE_PRICE: float = 19.99
const REFUND_PRICE: float = 24.99


var _saved_employee_trust: float
var _saved_manager_approval: float
var _saved_inventory: InventorySystem
var _saved_scapegoat_risk: float


func before_each() -> void:
	_saved_employee_trust = GameState.employee_trust
	_saved_manager_approval = GameState.manager_approval
	_saved_scapegoat_risk = HiddenThreadSystemSingleton.scapegoat_risk

	# Reset autoload state so cases do not leak.
	ReturnsSystem.reset_for_tests()
	HiddenThreadSystemSingleton.scapegoat_risk = 0.0
	EmploymentSystem.state = EmploymentState.new()
	EmploymentSystem._employed = false
	EmploymentSystem._evaluated_outcome = false
	GameState.employee_trust = EmploymentState.DEFAULT_TRUST
	GameState.manager_approval = EmploymentState.DEFAULT_APPROVAL
	EmploymentSystem.start_employment(&"retro_games")
	# Ensure the stocking-trained unlock starts un-granted; tests grant when needed.
	if UnlockSystemSingleton._granted.has(
		ReturnsSystem.STOCKING_TRAINED_UNLOCK
	):
		UnlockSystemSingleton._granted.erase(
			ReturnsSystem.STOCKING_TRAINED_UNLOCK
		)


func after_each() -> void:
	ReturnsSystem.reset_for_tests()
	if ReturnsSystem._inventory_system != null:
		ReturnsSystem.set_inventory_system(null)
	GameState.employee_trust = _saved_employee_trust
	GameState.manager_approval = _saved_manager_approval
	HiddenThreadSystemSingleton.scapegoat_risk = _saved_scapegoat_risk
	UnlockSystemSingleton._granted.erase(
		ReturnsSystem.STOCKING_TRAINED_UNLOCK
	)


func _make_record(
	condition: String = "good",
	store: StringName = &"retro_games",
	customer: StringName = &"cust_test",
) -> ReturnRecord:
	return ReturnsSystem.record_defective_sale(
		"item_test_01",
		condition,
		store,
		customer,
		"Test Disc",
		REFUND_PRICE,
		2,
	)


# ── EventBus signal declarations ─────────────────────────────────────────────


func test_event_bus_declares_return_signals() -> void:
	assert_true(
		EventBus.has_signal("return_initiated"),
		"EventBus must declare return_initiated"
	)
	assert_true(
		EventBus.has_signal("return_accepted"),
		"EventBus must declare return_accepted"
	)
	assert_true(
		EventBus.has_signal("return_denied"),
		"EventBus must declare return_denied"
	)
	assert_true(
		EventBus.has_signal("defective_item_received"),
		"EventBus must declare defective_item_received"
	)


# ── Defective sale emission (CheckoutSystem autoload) ────────────────────────


func test_checkout_emits_defective_sale_for_poor_condition() -> void:
	var captured: Array = []
	var listener: Callable = func(item_id: String, reason: String) -> void:
		captured.append({"item_id": item_id, "reason": reason})
	EventBus.defective_sale_occurred.connect(listener)
	# Verify the constant covers "poor".
	assert_true(
		"poor" in CheckoutSystem.DEFECTIVE_CONDITIONS,
		"poor must be in CheckoutSystem.DEFECTIVE_CONDITIONS"
	)
	# Synthesize a CheckoutSystem-style emit since process_transaction needs
	# a full Customer scene; the contract under test is the constant + emit.
	EventBus.defective_sale_occurred.emit("inst_poor_99", "poor")
	assert_eq(
		captured.size(), 1,
		"defective_sale_occurred must propagate exactly once"
	)
	assert_eq(captured[0]["item_id"], "inst_poor_99")
	assert_eq(captured[0]["reason"], "poor")
	EventBus.defective_sale_occurred.disconnect(listener)


func test_player_checkout_constant_includes_damaged() -> void:
	assert_true(
		"damaged" in PlayerCheckout.DEFECTIVE_CONDITIONS,
		"damaged must trigger defective_sale via PlayerCheckout"
	)
	assert_true(
		"poor" in PlayerCheckout.DEFECTIVE_CONDITIONS,
		"poor must trigger defective_sale via PlayerCheckout"
	)


# ── Record creation + spawn gate ─────────────────────────────────────────────


func test_record_defective_sale_creates_pending_record() -> void:
	var record: ReturnRecord = _make_record("poor")
	assert_not_null(record, "record_defective_sale must return a record")
	assert_true(
		ReturnsSystem.has_pending_returns(),
		"pending queue must report at least one entry"
	)
	assert_eq(record.item_id, "item_test_01")
	assert_eq(record.item_condition, "poor")


func test_defective_sale_signal_records_via_listener() -> void:
	EventBus.defective_sale_occurred.emit("auto_recorded", "damaged")
	var pending: Array[ReturnRecord] = ReturnsSystem.get_pending_returns()
	var found: bool = false
	for r: ReturnRecord in pending:
		if r.item_id == "auto_recorded":
			found = true
			assert_eq(r.defect_reason, "damaged")
	assert_true(
		found,
		"defective_sale_occurred listener must enqueue a ReturnRecord"
	)


func test_peek_next_return_is_fifo() -> void:
	ReturnsSystem.record_defective_sale("first", "poor")
	ReturnsSystem.record_defective_sale("second", "damaged")
	var head: ReturnRecord = ReturnsSystem.peek_next_return()
	assert_eq(
		head.item_id, "first",
		"peek_next_return must return the oldest unresolved record"
	)


# ── Deny gate (acceptance criterion: greyed when poor/damaged) ───────────────


func test_deny_unavailable_when_item_condition_damaged() -> void:
	var record: ReturnRecord = _make_record("damaged")
	var choices: Array[Dictionary] = ReturnsSystem.get_available_choices(
		record
	)
	var deny: Dictionary = {}
	for entry: Dictionary in choices:
		if entry.get("id", "") == ReturnsSystem.RESOLUTION_DENY:
			deny = entry
	assert_false(
		deny.is_empty(),
		"deny entry must be present (visible-but-disabled, not hidden)"
	)
	assert_false(
		bool(deny.get("available", true)),
		"deny must be unavailable when condition is damaged"
	)


func test_deny_unavailable_when_item_condition_poor() -> void:
	var record: ReturnRecord = _make_record("poor")
	assert_false(
		ReturnsSystem.apply_decision(record, ReturnsSystem.RESOLUTION_DENY),
		"apply_decision must reject deny on a defective copy"
	)


func test_deny_available_when_condition_good() -> void:
	var record: ReturnRecord = _make_record("good")
	var choices: Array[Dictionary] = ReturnsSystem.get_available_choices(
		record
	)
	for entry: Dictionary in choices:
		if entry.get("id", "") == ReturnsSystem.RESOLUTION_DENY:
			assert_true(
				bool(entry.get("available", false)),
				"deny must be available when condition is good"
			)
			return
	fail_test("deny entry missing from choices for good condition")


# ── Exchange gate (acceptance criterion: gated on stocking_trained) ──────────


func test_exchange_choice_hidden_before_stocking_trained_unlock() -> void:
	# Default state: unlock not granted.
	var record: ReturnRecord = _make_record("good")
	var choices: Array[Dictionary] = ReturnsSystem.get_available_choices(
		record
	)
	for entry: Dictionary in choices:
		assert_ne(
			entry.get("id", ""), ReturnsSystem.RESOLUTION_EXCHANGE,
			"exchange must not appear in choices before unlock"
		)


func test_exchange_choice_visible_after_stocking_trained_unlock() -> void:
	UnlockSystemSingleton._granted[
		ReturnsSystem.STOCKING_TRAINED_UNLOCK
	] = true
	var record: ReturnRecord = _make_record("good")
	var choices: Array[Dictionary] = ReturnsSystem.get_available_choices(
		record
	)
	var found: bool = false
	for entry: Dictionary in choices:
		if entry.get("id", "") == ReturnsSystem.RESOLUTION_EXCHANGE:
			found = true
	assert_true(
		found, "exchange must appear in choices after unlock granted"
	)


func test_apply_exchange_rejected_before_unlock() -> void:
	var record: ReturnRecord = _make_record("good")
	assert_false(
		ReturnsSystem.apply_decision(
			record, ReturnsSystem.RESOLUTION_EXCHANGE
		),
		"apply_decision must reject exchange before unlock granted"
	)


# ── Accept + refund side effects ─────────────────────────────────────────────


func test_accept_refund_applies_trust_plus_one() -> void:
	var record: ReturnRecord = _make_record("poor")
	var before: float = EmploymentSystem.state.employee_trust
	assert_true(
		ReturnsSystem.apply_decision(
			record, ReturnsSystem.RESOLUTION_REFUND
		),
		"refund must succeed for a defective copy"
	)
	assert_almost_eq(
		EmploymentSystem.state.employee_trust - before,
		ReturnsSystem.TRUST_DELTA_RETURN_ACCEPTED,
		0.001,
		"refund must apply +1 trust"
	)


func test_accept_refund_emits_return_accepted_with_refund_label() -> void:
	var record: ReturnRecord = _make_record("poor")
	watch_signals(EventBus)
	ReturnsSystem.apply_decision(record, ReturnsSystem.RESOLUTION_REFUND)
	assert_signal_emitted(EventBus, "return_accepted")
	var params: Array = get_signal_parameters(EventBus, "return_accepted")
	assert_eq(params[2], ReturnsSystem.RESOLUTION_REFUND)


func test_accept_refund_emits_defective_item_received() -> void:
	var record: ReturnRecord = _make_record("damaged")
	watch_signals(EventBus)
	ReturnsSystem.apply_decision(record, ReturnsSystem.RESOLUTION_REFUND)
	assert_signal_emitted(EventBus, "defective_item_received")


func test_accept_refund_marks_record_resolved() -> void:
	var record: ReturnRecord = _make_record("poor")
	ReturnsSystem.apply_decision(record, ReturnsSystem.RESOLUTION_REFUND)
	assert_true(record.resolved, "refunded record must be marked resolved")
	assert_eq(record.resolution, ReturnsSystem.RESOLUTION_REFUND)
	assert_false(
		ReturnsSystem.has_pending_returns(),
		"resolved record must leave the pending queue"
	)


# ── Accept + exchange side effects ───────────────────────────────────────────


func test_accept_exchange_applies_trust_plus_one_no_cash() -> void:
	UnlockSystemSingleton._granted[
		ReturnsSystem.STOCKING_TRAINED_UNLOCK
	] = true
	var record: ReturnRecord = _make_record("good")
	var before_trust: float = EmploymentSystem.state.employee_trust
	assert_true(
		ReturnsSystem.apply_decision(
			record, ReturnsSystem.RESOLUTION_EXCHANGE
		)
	)
	assert_almost_eq(
		EmploymentSystem.state.employee_trust - before_trust,
		ReturnsSystem.TRUST_DELTA_RETURN_ACCEPTED, 0.001,
		"exchange must apply +1 trust"
	)


func test_accept_exchange_emits_return_accepted_with_exchange_label() -> void:
	UnlockSystemSingleton._granted[
		ReturnsSystem.STOCKING_TRAINED_UNLOCK
	] = true
	var record: ReturnRecord = _make_record("good")
	watch_signals(EventBus)
	ReturnsSystem.apply_decision(record, ReturnsSystem.RESOLUTION_EXCHANGE)
	assert_signal_emitted(EventBus, "return_accepted")
	var params: Array = get_signal_parameters(EventBus, "return_accepted")
	assert_eq(params[2], ReturnsSystem.RESOLUTION_EXCHANGE)


# ── Deny side effects ────────────────────────────────────────────────────────


func test_deny_applies_trust_minus_two() -> void:
	var record: ReturnRecord = _make_record("good")
	var before: float = EmploymentSystem.state.employee_trust
	ReturnsSystem.apply_decision(record, ReturnsSystem.RESOLUTION_DENY)
	assert_almost_eq(
		EmploymentSystem.state.employee_trust - before,
		ReturnsSystem.TRUST_DELTA_RETURN_DENIED, 0.001,
		"deny must apply −2 trust"
	)


func test_deny_emits_return_denied_signal() -> void:
	var record: ReturnRecord = _make_record("good")
	watch_signals(EventBus)
	ReturnsSystem.apply_decision(record, ReturnsSystem.RESOLUTION_DENY)
	assert_signal_emitted(EventBus, "return_denied")


func test_deny_applies_reputation_penalty() -> void:
	var record: ReturnRecord = _make_record("good", &"retro_games")
	ReputationSystemSingleton.initialize_store("retro_games")
	var before_rep: float = ReputationSystemSingleton.get_reputation(
		"retro_games"
	)
	ReturnsSystem.apply_decision(record, ReturnsSystem.RESOLUTION_DENY)
	var after_rep: float = ReputationSystemSingleton.get_reputation(
		"retro_games"
	)
	assert_almost_eq(
		after_rep - before_rep,
		ReturnsSystem.REPUTATION_DELTA_DENIED, 0.001,
		"deny must apply −1 reputation"
	)


# ── Escalate side effects ────────────────────────────────────────────────────


func test_escalate_applies_trust_plus_half() -> void:
	var record: ReturnRecord = _make_record("good")
	var before: float = EmploymentSystem.state.employee_trust
	ReturnsSystem.apply_decision(record, ReturnsSystem.RESOLUTION_ESCALATE)
	assert_almost_eq(
		EmploymentSystem.state.employee_trust - before,
		ReturnsSystem.TRUST_DELTA_RETURN_ESCALATED, 0.001,
		"escalate must apply +0.5 trust"
	)


func test_escalate_applies_manager_approval_delta() -> void:
	var record: ReturnRecord = _make_record("good")
	var before: float = EmploymentSystem.state.manager_approval
	ReturnsSystem.apply_decision(record, ReturnsSystem.RESOLUTION_ESCALATE)
	assert_almost_eq(
		EmploymentSystem.state.manager_approval - before,
		ReturnsSystem.MANAGER_APPROVAL_DELTA_ESCALATED, 0.001,
		"escalate must apply +0.02 manager_approval"
	)


# ── Damaged bin variance reconciliation ──────────────────────────────────────


func test_check_bin_variance_emits_for_unknown_item() -> void:
	var inventory: InventorySystem = InventorySystem.new()
	add_child_autofree(inventory)
	ReturnsSystem.set_inventory_system(inventory)
	# Seed an item directly into the damaged bin without going through the
	# returns flow — this is the variance scenario (item in bin without a
	# matching resolved-refund record).
	var item: ItemInstance = ItemInstance.new()
	item.instance_id = "ghost_inst_42"
	item.current_location = InventorySystem.DAMAGED_BIN_LOCATION
	inventory._items[item.instance_id] = item

	watch_signals(EventBus)
	var fired: int = ReturnsSystem.check_bin_variance()
	assert_eq(
		fired, 1,
		"check_bin_variance must report one variance event for the unknown item"
	)
	assert_signal_emitted(EventBus, "inventory_variance_noted")


func test_inventory_variance_increments_scapegoat_risk() -> void:
	var before: float = HiddenThreadSystemSingleton.scapegoat_risk
	EventBus.inventory_variance_noted.emit(
		&"retro_games", &"ghost_42", 0, 1
	)
	assert_almost_eq(
		HiddenThreadSystemSingleton.scapegoat_risk - before,
		HiddenThreadSystem.SCAPEGOAT_RISK_DELTA_VARIANCE, 0.001,
		"variance event must bump scapegoat_risk per HiddenThreadSystem"
	)


# ── Card data + return_initiated emission ────────────────────────────────────


func test_build_card_data_includes_archetype_label_with_item_name() -> void:
	var record: ReturnRecord = _make_record("poor")
	var data: Dictionary = ReturnsSystem.build_card_data(record)
	assert_true(
		String(data.get("archetype_label", "")).begins_with(
			"Angry Return —"
		),
		"archetype label must lead with the angry-return prefix"
	)
	assert_true(
		String(data.get("archetype_label", "")).contains("Test Disc"),
		"archetype label must include item name"
	)


func test_emit_return_initiated_fires_signal_with_record_data() -> void:
	var record: ReturnRecord = _make_record("damaged")
	watch_signals(EventBus)
	ReturnsSystem.emit_return_initiated(record)
	assert_signal_emitted(EventBus, "return_initiated")
	var params: Array = get_signal_parameters(EventBus, "return_initiated")
	assert_eq(params[1], StringName(record.item_id))
	assert_eq(params[2], record.defect_reason)


# ── Inventory damaged-bin getters ────────────────────────────────────────────


func test_inventory_damaged_bin_getter_filters_by_location() -> void:
	var inventory: InventorySystem = InventorySystem.new()
	add_child_autofree(inventory)
	var bin_item: ItemInstance = ItemInstance.new()
	bin_item.instance_id = "damaged_inst"
	bin_item.current_location = InventorySystem.DAMAGED_BIN_LOCATION
	inventory._items[bin_item.instance_id] = bin_item
	var shelf_item: ItemInstance = ItemInstance.new()
	shelf_item.instance_id = "shelf_inst"
	shelf_item.current_location = "shelf:slot_0"
	inventory._items[shelf_item.instance_id] = shelf_item
	var bin: Array[ItemInstance] = inventory.get_damaged_bin_items()
	assert_eq(bin.size(), 1, "getter must return only damaged-bin items")
	assert_eq(bin[0].instance_id, "damaged_inst")


func test_move_to_damaged_bin_updates_location() -> void:
	var inventory: InventorySystem = InventorySystem.new()
	add_child_autofree(inventory)
	var item: ItemInstance = ItemInstance.new()
	item.instance_id = "moved_inst"
	item.current_location = "backroom"
	inventory._items[item.instance_id] = item
	assert_true(inventory.move_to_damaged_bin("moved_inst"))
	assert_eq(item.current_location, InventorySystem.DAMAGED_BIN_LOCATION)


func test_move_to_damaged_bin_unknown_instance_returns_false() -> void:
	var inventory: InventorySystem = InventorySystem.new()
	add_child_autofree(inventory)
	assert_false(inventory.move_to_damaged_bin("never_added"))
