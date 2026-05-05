## Tests HoldSlip resource serialization, status checks, and round-trip
## fidelity through to_dict / from_dict.
extends GutTest


func test_default_status_is_active() -> void:
	var slip := HoldSlip.new()
	assert_eq(slip.status, HoldSlip.Status.ACTIVE)
	assert_true(slip.is_active())
	assert_false(slip.is_flagged())
	assert_false(slip.is_terminal_status())


func test_flagged_status_helpers() -> void:
	var slip := HoldSlip.new()
	slip.status = HoldSlip.Status.FLAGGED
	assert_false(slip.is_active())
	assert_true(slip.is_flagged())
	assert_false(slip.is_terminal_status())


func test_terminal_statuses() -> void:
	for status in [
		HoldSlip.Status.FULFILLED,
		HoldSlip.Status.EXPIRED,
		HoldSlip.Status.DISPUTED,
	]:
		var slip := HoldSlip.new()
		slip.status = status
		assert_true(
			slip.is_terminal_status(),
			"Status %d must report as terminal" % status,
		)


func test_to_dict_round_trip() -> void:
	var original := HoldSlip.new()
	original.id = "HOLD-0042"
	original.customer_name = "T. Morrow"
	original.serial = "SFC-00412"
	original.item_id = &"retro_blasteroids"
	original.item_label = "Cartridge — Blasteroids"
	original.creation_day = 4
	original.expiry_day = 7
	original.status = HoldSlip.Status.FLAGGED
	original.requestor_tier = HoldSlip.RequestorTier.SHADY
	original.thread_id = "thread_fence_circuit"

	var data: Dictionary = original.to_dict()
	var restored: HoldSlip = HoldSlip.from_dict(data)

	assert_eq(restored.id, original.id)
	assert_eq(restored.customer_name, original.customer_name)
	assert_eq(restored.serial, original.serial)
	assert_eq(restored.item_id, original.item_id)
	assert_eq(restored.item_label, original.item_label)
	assert_eq(restored.creation_day, original.creation_day)
	assert_eq(restored.expiry_day, original.expiry_day)
	assert_eq(restored.status, original.status)
	assert_eq(restored.requestor_tier, original.requestor_tier)
	assert_eq(restored.thread_id, original.thread_id)


func test_from_dict_handles_missing_keys() -> void:
	var slip: HoldSlip = HoldSlip.from_dict({})
	assert_eq(slip.id, "")
	assert_eq(slip.customer_name, "")
	assert_eq(slip.creation_day, 0)
	assert_eq(slip.status, HoldSlip.Status.ACTIVE)
	assert_eq(slip.requestor_tier, HoldSlip.RequestorTier.NORMAL)
