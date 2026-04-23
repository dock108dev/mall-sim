## Tests that rental wear state is persisted per-instance and that the customer
## appeal formula consumes wear at low/mid/high levels.
extends GutTest


var _tracker: TapeWearTracker


func before_each() -> void:
	_tracker = TapeWearTracker.new()


func test_compute_appeal_low_wear_returns_full_appeal() -> void:
	assert_almost_eq(
		TapeWearTracker.compute_appeal_factor(0.0),
		1.0,
		0.0001,
		"Pristine tape (0 wear) must have full appeal",
	)
	assert_almost_eq(
		TapeWearTracker.compute_appeal_factor(0.2),
		1.0,
		0.0001,
		"Low-wear tape at threshold should still have full appeal",
	)


func test_compute_appeal_mid_wear_erodes_appeal() -> void:
	var appeal: float = TapeWearTracker.compute_appeal_factor(0.6)
	assert_true(
		appeal < 1.0 and appeal > 0.5,
		"Mid-wear tape should sit strictly between 0.5 and 1.0 (got %f)" % appeal,
	)


func test_compute_appeal_high_wear_floor_is_half() -> void:
	assert_almost_eq(
		TapeWearTracker.compute_appeal_factor(1.0),
		0.5,
		0.0001,
		"Maximally worn tape appeal must equal the 0.5 floor",
	)


func test_classify_wear_maps_to_expected_buckets() -> void:
	assert_eq(TapeWearTracker.classify_wear(0.0), "pristine")
	assert_eq(TapeWearTracker.classify_wear(0.3), "light")
	assert_eq(TapeWearTracker.classify_wear(0.5), "moderate")
	assert_eq(TapeWearTracker.classify_wear(0.75), "heavy")
	assert_eq(TapeWearTracker.classify_wear(1.0), "worn_out")


func test_save_load_round_trip_preserves_wear_and_condition() -> void:
	var item_id: String = "vhs_save_roundtrip"
	_tracker.initialize_item(item_id, TapeWearTracker.MEDIA_TYPE_VHS)
	for _i: int in range(4):
		_tracker.apply_degradation(item_id)
	var original_wear: float = _tracker.get_wear(item_id)
	var original_condition: String = _tracker.get_condition(item_id)

	var snapshot: Dictionary = _tracker.get_save_data()
	var restored: TapeWearTracker = TapeWearTracker.new()
	restored.load_save_data(snapshot)

	assert_almost_eq(
		restored.get_wear(item_id),
		original_wear,
		0.0001,
		"Wear value must survive the save/load round trip",
	)
	assert_eq(
		restored.get_condition(item_id),
		original_condition,
		"Condition tier must survive the save/load round trip",
	)


func test_load_legacy_flat_play_count_format_still_works() -> void:
	# Legacy v1 payload: {instance_id: play_count}.
	var legacy: Dictionary = {"legacy_tape": 3}
	_tracker.load_save_data(legacy)
	assert_eq(
		_tracker.get_play_count("legacy_tape"),
		3,
		"Legacy save format must still populate play counts",
	)


func test_worn_out_tape_reports_non_rentable_reason_via_controller() -> void:
	var ctrl: VideoRentalStoreController = VideoRentalStoreController.new()
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "worn_tape"
	def.item_name = "Worn Tape"
	def.category = "vhs_classic"
	def.rarity = "common"
	var item: ItemInstance = ItemInstance.create_from_definition(def, "poor")
	# Drive wear to max via five returns from the poor tier.
	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP + 1):
		ctrl._wear_tracker.initialize_item(
			String(item.instance_id), "poor"
		)
		ctrl._wear_tracker.record_return(String(item.instance_id))
	assert_false(
		ctrl.is_rentable(item),
		"A maxed-out poor-condition tape must not be rentable",
	)
	var reason: String = ctrl.get_rentability_reason(item)
	assert_true(
		not reason.is_empty(),
		"Non-rentable tape must surface a player-facing reason",
	)
	ctrl.free()
