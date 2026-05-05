## Tests HoldList: id allocation, signal emission, duplicate detection,
## conflict resolution, expiry, and save/load round-trip.
extends GutTest


var _list: HoldList


func before_each() -> void:
	_list = HoldList.new()


func test_add_hold_assigns_sequential_ids() -> void:
	var first: HoldSlip = _list.add_hold(
		"A. One",
		"SER-1",
		&"item_a",
		"Item A",
		HoldSlip.RequestorTier.NORMAL,
		1,
	)
	var second: HoldSlip = _list.add_hold(
		"B. Two",
		"SER-2",
		&"item_b",
		"Item B",
		HoldSlip.RequestorTier.NORMAL,
		1,
	)
	assert_eq(first.id, "HOLD-0001")
	assert_eq(second.id, "HOLD-0002")


func test_add_hold_emits_hold_added_signal() -> void:
	var captured: Array[HoldSlip] = []
	_list.hold_added.connect(func(slip: HoldSlip) -> void:
		captured.append(slip)
	)
	_list.add_hold(
		"A. One",
		"SER-1",
		&"item_a",
		"Item A",
		HoldSlip.RequestorTier.NORMAL,
		1,
	)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0].customer_name, "A. One")


func test_add_hold_sets_expiry_day_from_duration() -> void:
	_list.hold_duration_days = 3
	var slip: HoldSlip = _list.add_hold(
		"A. One",
		"SER-1",
		&"item_a",
		"Item A",
		HoldSlip.RequestorTier.NORMAL,
		5,
	)
	assert_eq(slip.creation_day, 5)
	assert_eq(slip.expiry_day, 8)


func test_duplicate_same_serial_different_name_flagged() -> void:
	var captured: Array = []
	_list.duplicate_detected.connect(
		func(new_slip: HoldSlip, existing: HoldSlip, field: StringName) -> void:
			captured.append({
				"new": new_slip,
				"existing": existing,
				"field": field,
			})
	)
	var first: HoldSlip = _list.add_hold(
		"T. Morrow",
		"SFC-00412",
		&"item_a",
		"Cart A",
		HoldSlip.RequestorTier.NORMAL,
		2,
	)
	var second: HoldSlip = _list.add_hold(
		"R. Valdez",
		"SFC-00412",
		&"item_a",
		"Cart A",
		HoldSlip.RequestorTier.NORMAL,
		2,
	)
	assert_eq(captured.size(), 1, "duplicate_detected must fire once")
	assert_eq(captured[0]["field"], &"serial")
	assert_eq(second.status, HoldSlip.Status.FLAGGED, "new slip flagged")
	assert_eq(
		first.status,
		HoldSlip.Status.FLAGGED,
		"existing slip also flagged so the diff is symmetric",
	)


func test_duplicate_same_name_different_serial_same_day_flagged() -> void:
	var captured: Array = []
	_list.duplicate_detected.connect(
		func(_new_slip: HoldSlip, _existing: HoldSlip, field: StringName) -> void:
			captured.append(field)
	)
	_list.add_hold(
		"K. Niles",
		"SER-100",
		&"item_a",
		"Cart A",
		HoldSlip.RequestorTier.NORMAL,
		3,
	)
	var second: HoldSlip = _list.add_hold(
		"K. Niles",
		"SER-200",
		&"item_b",
		"Cart B",
		HoldSlip.RequestorTier.NORMAL,
		3,
	)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0], &"customer_name")
	assert_eq(second.status, HoldSlip.Status.FLAGGED)


func test_same_name_different_serial_different_day_no_conflict() -> void:
	var captured: Array = []
	_list.duplicate_detected.connect(
		func(_a: HoldSlip, _b: HoldSlip, _f: StringName) -> void:
			captured.append(true)
	)
	_list.add_hold(
		"K. Niles",
		"SER-1",
		&"item_a",
		"A",
		HoldSlip.RequestorTier.NORMAL,
		3,
	)
	var second: HoldSlip = _list.add_hold(
		"K. Niles",
		"SER-2",
		&"item_b",
		"B",
		HoldSlip.RequestorTier.NORMAL,
		5,
	)
	assert_eq(
		captured.size(), 0,
		"Different-day same-name does not trigger duplicate detection",
	)
	assert_eq(second.status, HoldSlip.Status.ACTIVE)


func test_shady_request_emits_signal() -> void:
	var shady_caught: Array[HoldSlip] = []
	_list.shady_request_received.connect(func(slip: HoldSlip) -> void:
		shady_caught.append(slip)
	)
	_list.add_hold(
		"Mystery",
		"SER-X",
		&"item_x",
		"Item X",
		HoldSlip.RequestorTier.SHADY,
		1,
	)
	assert_eq(shady_caught.size(), 1)
	assert_eq(shady_caught[0].requestor_tier, HoldSlip.RequestorTier.SHADY)


func test_anonymous_request_emits_shady_signal() -> void:
	var captured: Array[HoldSlip] = []
	_list.shady_request_received.connect(func(slip: HoldSlip) -> void:
		captured.append(slip)
	)
	_list.add_hold(
		"",
		"SER-Y",
		&"item_y",
		"Item Y",
		HoldSlip.RequestorTier.ANONYMOUS,
		1,
	)
	assert_eq(captured.size(), 1)
	if captured.size() == 1:
		assert_eq(captured[0].requestor_tier, HoldSlip.RequestorTier.ANONYMOUS)


func test_normal_request_does_not_emit_shady_signal() -> void:
	var captured: Array[HoldSlip] = []
	_list.shady_request_received.connect(func(slip: HoldSlip) -> void:
		captured.append(slip)
	)
	_list.add_hold(
		"Plain",
		"SER-1",
		&"item_a",
		"A",
		HoldSlip.RequestorTier.NORMAL,
		1,
	)
	assert_eq(captured.size(), 0)


func test_pending_holds_for_excludes_terminal_statuses() -> void:
	var slip_a: HoldSlip = _list.add_hold(
		"A", "SER-1", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1
	)
	_list.add_hold(
		"B", "SER-2", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1
	)
	# Same name + different serial + same day → flagged duplicate
	# but a different name + different serial keeps both ACTIVE
	assert_eq(_list.pending_holds_for(&"item_a").size(), 2)
	_list.fulfill(slip_a.id)
	assert_eq(
		_list.pending_holds_for(&"item_a").size(), 1,
		"Fulfilled slip drops out of pending_holds_for"
	)


func test_has_conflict_when_holds_exceed_stock() -> void:
	_list.add_hold("A", "SER-1", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1)
	_list.add_hold("B", "SER-2", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1)
	assert_true(_list.has_conflict(&"item_a", 1))
	assert_false(_list.has_conflict(&"item_a", 2))


func test_resolve_conflict_honor_earliest_fulfills_winner() -> void:
	var slip_a: HoldSlip = _list.add_hold(
		"A", "SER-1", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1
	)
	var slip_b: HoldSlip = _list.add_hold(
		"B", "SER-2", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1
	)
	# Make A expire earliest by overriding expiry days
	slip_a.expiry_day = 4
	slip_b.expiry_day = 7

	var fulfilled_payload: Array = []
	_list.hold_fulfilled.connect(
		func(s: HoldSlip, reason: String) -> void:
			fulfilled_payload.append({"slip": s, "reason": reason})
	)
	var result: Dictionary = _list.resolve_conflict(
		&"item_a", HoldList.ConflictChoice.HONOR_EARLIEST
	)
	assert_eq(result["fulfilled_slip_id"], slip_a.id)
	assert_eq(slip_a.status, HoldSlip.Status.FULFILLED)
	assert_eq(
		slip_b.status, HoldSlip.Status.ACTIVE,
		"competing slip remains ACTIVE until natural expiry"
	)
	assert_eq(fulfilled_payload.size(), 1)
	assert_eq(fulfilled_payload[0]["reason"], "earliest_expiry")


func test_resolve_conflict_escalate_uses_manager_reason() -> void:
	var slip_a: HoldSlip = _list.add_hold(
		"A", "SER-1", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1
	)
	var slip_b: HoldSlip = _list.add_hold(
		"B", "SER-2", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1
	)
	slip_a.expiry_day = 5
	slip_b.expiry_day = 9

	var reasons: Array = []
	_list.hold_fulfilled.connect(
		func(_s: HoldSlip, reason: String) -> void:
			reasons.append(reason)
	)
	var result: Dictionary = _list.resolve_conflict(
		&"item_a", HoldList.ConflictChoice.ESCALATE_TO_MANAGER
	)
	assert_eq(result["fulfilled_slip_id"], slip_a.id)
	assert_eq(slip_a.status, HoldSlip.Status.FULFILLED)
	assert_eq(slip_b.status, HoldSlip.Status.ACTIVE)
	assert_eq(reasons.size(), 1)
	assert_eq(reasons[0], "manager_escalation")


func test_resolve_conflict_walk_in_disputes_all() -> void:
	var slip_a: HoldSlip = _list.add_hold(
		"A", "SER-1", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1
	)
	var slip_b: HoldSlip = _list.add_hold(
		"B", "SER-2", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1
	)

	var bypass_emitted: Array = []
	_list.hold_conflict_bypassed.connect(
		func(item_id: StringName, disputed: Array) -> void:
			bypass_emitted.append({"item_id": item_id, "disputed": disputed})
	)
	var result: Dictionary = _list.resolve_conflict(
		&"item_a", HoldList.ConflictChoice.GIVE_TO_WALK_IN
	)
	assert_eq(slip_a.status, HoldSlip.Status.DISPUTED)
	assert_eq(slip_b.status, HoldSlip.Status.DISPUTED)
	var disputed_ids: Array = result["disputed_slip_ids"]
	assert_eq(disputed_ids.size(), 2)
	assert_eq(bypass_emitted.size(), 1)
	assert_eq(bypass_emitted[0]["item_id"], &"item_a")
	assert_eq((bypass_emitted[0]["disputed"] as Array).size(), 2)


func test_expire_stale_marks_old_slips() -> void:
	var slip: HoldSlip = _list.add_hold(
		"A", "SER-1", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1
	)
	slip.expiry_day = 3
	var expired_caught: Array[HoldSlip] = []
	_list.hold_expired.connect(func(s: HoldSlip) -> void:
		expired_caught.append(s)
	)
	var newly_expired: Array[HoldSlip] = _list.expire_stale(4)
	assert_eq(newly_expired.size(), 1)
	assert_eq(slip.status, HoldSlip.Status.EXPIRED)
	assert_eq(expired_caught.size(), 1)


func test_expire_stale_skips_terminal_statuses() -> void:
	var slip_a: HoldSlip = _list.add_hold(
		"A", "SER-1", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1
	)
	_list.fulfill(slip_a.id)
	slip_a.expiry_day = 3
	var newly_expired: Array[HoldSlip] = _list.expire_stale(99)
	assert_eq(newly_expired.size(), 0)


func test_save_load_round_trip() -> void:
	var slip_a: HoldSlip = _list.add_hold(
		"A", "SER-1", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1
	)
	_list.add_hold(
		"B", "SER-2", &"item_b", "B", HoldSlip.RequestorTier.SHADY, 2
	)
	_list.fulfill(slip_a.id)

	var saved: Dictionary = _list.get_save_data()

	var restored := HoldList.new()
	restored.load_save_data(saved)

	var all_slips: Array[HoldSlip] = restored.get_all_slips()
	assert_eq(all_slips.size(), 2)
	# Allocator continues from saved state — next id should not collide
	var third: HoldSlip = restored.add_hold(
		"C", "SER-3", &"item_c", "C", HoldSlip.RequestorTier.NORMAL, 3
	)
	assert_eq(third.id, "HOLD-0003")


func test_fulfill_unknown_slip_returns_false() -> void:
	assert_false(_list.fulfill("HOLD-9999"))


func test_flag_promotes_active_to_flagged() -> void:
	var slip: HoldSlip = _list.add_hold(
		"A", "SER-1", &"item_a", "A", HoldSlip.RequestorTier.NORMAL, 1
	)
	assert_true(_list.flag(slip.id))
	assert_eq(slip.status, HoldSlip.Status.FLAGGED)
	assert_false(_list.flag(slip.id), "Re-flagging a flagged slip is no-op")


func test_get_conflict_holds_sorted_by_expiry() -> void:
	var slip_a: HoldSlip = _list.add_hold(
		"A", "SER-1", &"item_x", "X", HoldSlip.RequestorTier.NORMAL, 1
	)
	var slip_b: HoldSlip = _list.add_hold(
		"B", "SER-2", &"item_x", "X", HoldSlip.RequestorTier.NORMAL, 1
	)
	var slip_c: HoldSlip = _list.add_hold(
		"C", "SER-3", &"item_x", "X", HoldSlip.RequestorTier.NORMAL, 1
	)
	slip_a.expiry_day = 9
	slip_b.expiry_day = 4
	slip_c.expiry_day = 6

	var sorted: Array[HoldSlip] = _list.get_conflict_holds(&"item_x")
	assert_eq(sorted.size(), 3)
	assert_eq(sorted[0].id, slip_b.id)
	assert_eq(sorted[1].id, slip_c.id)
	assert_eq(sorted[2].id, slip_a.id)
