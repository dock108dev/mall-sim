## Tests RetroGames hold/reservation integration: signal forwarding onto
## EventBus, terminal access gating via the employee_holdlist_access unlock,
## Fulfillment Conflict resolution + trust deltas, and the persistence
## round-trip through get_save_data / load_save_data.
extends GutTest


const _ITEM_ID: StringName = &"retro_test_item"
const _UNLOCK_ID: StringName = &"employee_holdlist_access"

var _controller: RetroGames
# Tracks deltas applied during a test so the global ManagerRelationshipManager
# / EmploymentSystem state can be restored at after_each.
var _initial_manager_trust: float = 0.0
var _initial_employee_trust: float = 0.0


func before_each() -> void:
	_controller = RetroGames.new()
	add_child_autofree(_controller)
	_initial_manager_trust = ManagerRelationshipManager.manager_trust
	_initial_employee_trust = EmploymentSystem.state.employee_trust


func after_each() -> void:
	# Restore singleton state so cross-test ordering doesn't pollute results.
	ManagerRelationshipManager.manager_trust = _initial_manager_trust
	EmploymentSystem.state.employee_trust = _initial_employee_trust


func test_get_hold_list_returns_owned_instance() -> void:
	assert_not_null(_controller.holds.get_hold_list())
	assert_true(_controller.holds.get_hold_list() is HoldList)


func test_add_customer_hold_emits_event_bus_hold_added() -> void:
	var captured: Array = []
	var capture: Callable = func(
		store_id: StringName,
		slip_id: String,
		item_id: StringName,
		customer_name: String,
	) -> void:
		captured.append({
			"store_id": store_id,
			"slip_id": slip_id,
			"item_id": item_id,
			"customer_name": customer_name,
		})
	EventBus.hold_added.connect(capture)
	_controller.holds.add_customer_hold(
		"T. Morrow",
		"SER-1",
		_ITEM_ID,
		"Test Item",
		HoldSlip.RequestorTier.NORMAL,
	)
	EventBus.hold_added.disconnect(capture)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0]["store_id"], &"retro_games")
	assert_eq(captured[0]["customer_name"], "T. Morrow")


func test_shady_request_forwarded_onto_event_bus() -> void:
	var captured: Array = []
	var capture: Callable = func(
		store_id: StringName,
		slip_id: String,
		item_id: StringName,
		tier: int,
	) -> void:
		captured.append({
			"store_id": store_id,
			"slip_id": slip_id,
			"item_id": item_id,
			"tier": tier,
		})
	EventBus.hold_shady_request_received.connect(capture)
	_controller.holds.add_customer_hold(
		"Mystery",
		"SER-X",
		_ITEM_ID,
		"X",
		HoldSlip.RequestorTier.SHADY,
	)
	EventBus.hold_shady_request_received.disconnect(capture)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0]["tier"], HoldSlip.RequestorTier.SHADY)


func test_anonymous_tier_emits_shady_request_signal() -> void:
	var emitted: Array = []
	var capture: Callable = func(_a: StringName, _b: String, _c: StringName, d: int) -> void:
		emitted.append(d)
	EventBus.hold_shady_request_received.connect(capture)
	_controller.holds.add_customer_hold(
		"",
		"SER-Z",
		_ITEM_ID,
		"Z",
		HoldSlip.RequestorTier.ANONYMOUS,
	)
	EventBus.hold_shady_request_received.disconnect(capture)
	assert_eq(emitted.size(), 1)
	if emitted.size() == 1:
		assert_eq(emitted[0], HoldSlip.RequestorTier.ANONYMOUS)


func test_duplicate_serial_emits_event_bus_duplicate_detected() -> void:
	var captured: Array = []
	var capture: Callable = func(
		store_id: StringName,
		new_id: String,
		existing_id: String,
		field: StringName,
	) -> void:
		captured.append({
			"store_id": store_id,
			"new_id": new_id,
			"existing_id": existing_id,
			"field": field,
		})
	EventBus.hold_duplicate_detected.connect(capture)
	_controller.holds.add_customer_hold(
		"A", "SER-1", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	_controller.holds.add_customer_hold(
		"B", "SER-1", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	EventBus.hold_duplicate_detected.disconnect(capture)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0]["field"], &"serial")


func test_terminal_access_locked_by_default() -> void:
	# UnlockSystem starts with no granted unlocks at test boot.
	assert_false(_controller.holds.has_hold_terminal_access())


func test_terminal_access_granted_after_unlock() -> void:
	UnlockSystemSingleton._granted[_UNLOCK_ID] = true
	assert_true(_controller.holds.has_hold_terminal_access())
	UnlockSystemSingleton._granted.erase(_UNLOCK_ID)


func test_resolve_conflict_honor_earliest_applies_manager_trust() -> void:
	var slip_a: HoldSlip = _controller.holds.add_customer_hold(
		"A", "SER-1", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	_controller.holds.add_customer_hold(
		"B", "SER-2", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	slip_a.expiry_day = slip_a.creation_day + 1  # earliest

	var before_trust: float = ManagerRelationshipManager.manager_trust
	_controller.holds.resolve_fulfillment_conflict(
		_ITEM_ID, HoldList.ConflictChoice.HONOR_EARLIEST
	)
	var delta: float = ManagerRelationshipManager.manager_trust - before_trust
	assert_almost_eq(delta, 0.02, 0.0001)


func test_resolve_conflict_escalate_applies_higher_manager_trust() -> void:
	var slip_a: HoldSlip = _controller.holds.add_customer_hold(
		"A", "SER-1", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	_controller.holds.add_customer_hold(
		"B", "SER-2", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	slip_a.expiry_day = slip_a.creation_day + 1

	var before_trust: float = ManagerRelationshipManager.manager_trust
	var result: Dictionary = _controller.holds.resolve_fulfillment_conflict(
		_ITEM_ID, HoldList.ConflictChoice.ESCALATE_TO_MANAGER
	)
	var delta: float = ManagerRelationshipManager.manager_trust - before_trust
	assert_almost_eq(delta, 0.03, 0.0001)
	# Earliest-expiry slip is always honored; escalation just changes the
	# trust outcome, not the fulfilled slip.
	assert_eq(result["fulfilled_slip_id"], slip_a.id)


func test_resolve_conflict_walk_in_emits_bypass_signal() -> void:
	_controller.holds.add_customer_hold(
		"A", "SER-1", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	_controller.holds.add_customer_hold(
		"B", "SER-2", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)

	var emitted: Array = []
	var capture: Callable = func(
		store_id: StringName, item_id: StringName, disputed: Array
	) -> void:
		emitted.append({
			"store_id": store_id,
			"item_id": item_id,
			"disputed": disputed,
		})
	EventBus.hold_conflict_bypassed.connect(capture)
	_controller.holds.resolve_fulfillment_conflict(
		_ITEM_ID, HoldList.ConflictChoice.GIVE_TO_WALK_IN
	)
	EventBus.hold_conflict_bypassed.disconnect(capture)

	assert_eq(emitted.size(), 1)
	assert_eq(emitted[0]["store_id"], &"retro_games")
	assert_eq(emitted[0]["item_id"], _ITEM_ID)
	assert_eq((emitted[0]["disputed"] as Array).size(), 2)


func test_resolve_conflict_walk_in_applies_negative_trust_deltas() -> void:
	_controller.holds.add_customer_hold(
		"A", "SER-1", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	_controller.holds.add_customer_hold(
		"B", "SER-2", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)

	var manager_before: float = ManagerRelationshipManager.manager_trust
	# EmploymentSystem.apply_trust_delta no-ops when not _employed; arm it.
	EmploymentSystem._employed = true
	var employee_before: float = EmploymentSystem.state.employee_trust

	_controller.holds.resolve_fulfillment_conflict(
		_ITEM_ID, HoldList.ConflictChoice.GIVE_TO_WALK_IN
	)

	var manager_delta: float = (
		ManagerRelationshipManager.manager_trust - manager_before
	)
	var employee_delta: float = (
		EmploymentSystem.state.employee_trust - employee_before
	)
	assert_almost_eq(manager_delta, -0.05, 0.0001)
	assert_almost_eq(employee_delta, -3.0, 0.0001)
	EmploymentSystem._employed = false


func test_units_in_stock_zero_without_inventory_system() -> void:
	assert_eq(_controller.holds.units_in_stock(_ITEM_ID), 0)


func test_save_load_round_trip_restores_holds() -> void:
	_controller.holds.add_customer_hold(
		"A", "SER-1", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	_controller.holds.add_customer_hold(
		"B", "SER-2", _ITEM_ID, "X", HoldSlip.RequestorTier.SHADY
	)
	var snapshot: Dictionary = _controller.get_save_data()
	assert_true(snapshot.has("hold_list"))

	var fresh := RetroGames.new()
	add_child_autofree(fresh)
	fresh.load_save_data(snapshot)
	assert_eq(fresh.get_hold_list().get_all_slips().size(), 2)


func test_pending_holds_drop_off_after_fulfill() -> void:
	var slip_a: HoldSlip = _controller.holds.add_customer_hold(
		"A", "SER-1", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	_controller.holds.add_customer_hold(
		"B", "SER-2", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	assert_eq(_controller.holds.get_hold_list().pending_holds_for(_ITEM_ID).size(), 2)
	_controller.holds.get_hold_list().fulfill(slip_a.id)
	assert_eq(_controller.holds.get_hold_list().pending_holds_for(_ITEM_ID).size(), 1)


func test_day_started_expires_stale_slips() -> void:
	var slip: HoldSlip = _controller.holds.add_customer_hold(
		"A", "SER-1", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	slip.expiry_day = 1
	# Forwarded EventBus.hold_expired on day rollover
	var expired_payload: Array = []
	var capture: Callable = func(
		store_id: StringName, slip_id: String, item_id: StringName
	) -> void:
		expired_payload.append({
			"store_id": store_id,
			"slip_id": slip_id,
			"item_id": item_id,
		})
	EventBus.hold_expired.connect(capture)
	EventBus.day_started.emit(5)
	EventBus.hold_expired.disconnect(capture)

	assert_eq(slip.status, HoldSlip.Status.EXPIRED)
	assert_eq(expired_payload.size(), 1)
	assert_eq(expired_payload[0]["slip_id"], slip.id)


func test_has_fulfillment_conflict_false_without_supply_constraint() -> void:
	# Without an inventory system or platform shortage, the supply-constraint
	# branch returns false and the conflict panel is suppressed.
	_controller.holds.add_customer_hold(
		"A", "SER-1", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	_controller.holds.add_customer_hold(
		"B", "SER-2", _ITEM_ID, "X", HoldSlip.RequestorTier.NORMAL
	)
	assert_false(_controller.holds.has_fulfillment_conflict(_ITEM_ID))
