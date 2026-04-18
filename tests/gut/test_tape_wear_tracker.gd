## Tests TapeWearTracker wear rates, condition thresholds, and retirement boundary.
extends GutTest


var _tracker: TapeWearTracker


func before_each() -> void:
	_tracker = TapeWearTracker.new()


func test_initialize_item_registers_zero_wear_for_media_type() -> void:
	_tracker.initialize_item("vhs_item", TapeWearTracker.MEDIA_TYPE_VHS)

	assert_almost_eq(
		_tracker.get_wear("vhs_item"),
		0.0,
		0.0001,
		"Newly initialized media items should start with zero accumulated wear"
	)
	assert_eq(
		_tracker.get_tracked_item_count(),
		1,
		"Initializing a single item should create exactly one tracked entry"
	)


func test_apply_degradation_uses_vhs_rate() -> void:
	_tracker.initialize_item("vhs_item", TapeWearTracker.MEDIA_TYPE_VHS)

	var updated_wear: float = _tracker.apply_degradation("vhs_item")

	assert_almost_eq(
		updated_wear,
		TapeWearTracker.VHS_DEGRADATION_RATE,
		0.0001,
		"VHS items should gain the configured VHS degradation rate per rental"
	)
	assert_almost_eq(
		_tracker.get_wear("vhs_item"),
		TapeWearTracker.VHS_DEGRADATION_RATE,
		0.0001,
		"Stored wear should match the applied VHS degradation rate"
	)


func test_apply_degradation_uses_dvd_rate() -> void:
	_tracker.initialize_item("dvd_item", TapeWearTracker.MEDIA_TYPE_DVD)

	var updated_wear: float = _tracker.apply_degradation("dvd_item")

	assert_almost_eq(
		updated_wear,
		TapeWearTracker.DVD_DEGRADATION_RATE,
		0.0001,
		"DVD items should gain the configured DVD degradation rate per rental"
	)
	assert_almost_eq(
		_tracker.get_wear("dvd_item"),
		TapeWearTracker.DVD_DEGRADATION_RATE,
		0.0001,
		"Stored wear should match the applied DVD degradation rate"
	)


func test_condition_tier_changes_when_wear_crosses_threshold() -> void:
	_tracker.initialize_item("threshold_item", TapeWearTracker.MEDIA_TYPE_VHS)

	for _i: int in range(3):
		_tracker.apply_degradation("threshold_item")

	assert_eq(
		_tracker.get_condition("threshold_item"),
		"near_mint",
		"Crossing the first wear threshold should advance the item into the next condition tier"
	)


func test_condition_threshold_boundaries_match_condition_map() -> void:
	for condition: String in TapeWearTracker.CONDITION_WEAR_ORDER:
		var threshold: float = float(
			TapeWearTracker.CONDITION_TO_WEAR[condition]
		)
		assert_eq(
			_tracker.get_condition_for_wear(threshold),
			condition,
			"Wear exactly at %s threshold should resolve to %s" % [
				str(threshold), condition,
			]
		)


func test_vhs_item_reaches_poor_threshold_after_exact_rentals() -> void:
	var item_id: String = "vhs_retire"
	var target_wear: float = float(
		TapeWearTracker.CONDITION_TO_WEAR[TapeWearTracker.POOREST_CONDITION]
	)
	var expected_rentals: int = int(
		ceili(target_wear / TapeWearTracker.VHS_DEGRADATION_RATE)
	)
	_tracker.initialize_item(item_id, TapeWearTracker.MEDIA_TYPE_VHS)

	for _i: int in range(expected_rentals - 1):
		_tracker.apply_degradation(item_id)

	assert_true(
		_tracker.get_wear(item_id) < target_wear,
		"VHS items should stay below the retirement threshold until the final qualifying rental"
	)
	_tracker.apply_degradation(item_id)

	assert_almost_eq(
		_tracker.get_wear(item_id),
		target_wear,
		0.0001,
		"VHS items should hit the poor-condition threshold on the expected rental count"
	)
	assert_eq(
		_tracker.get_condition(item_id),
		TapeWearTracker.POOREST_CONDITION,
		"Reaching the threshold should mark the item as poor"
	)


func test_dvd_item_reaches_poor_threshold_after_exact_rentals() -> void:
	var item_id: String = "dvd_retire"
	var target_wear: float = float(
		TapeWearTracker.CONDITION_TO_WEAR[TapeWearTracker.POOREST_CONDITION]
	)
	var expected_rentals: int = int(
		ceili(target_wear / TapeWearTracker.DVD_DEGRADATION_RATE)
	)
	_tracker.initialize_item(item_id, TapeWearTracker.MEDIA_TYPE_DVD)

	for _i: int in range(expected_rentals - 1):
		_tracker.apply_degradation(item_id)

	assert_true(
		_tracker.get_wear(item_id) < target_wear,
		"DVD items should stay below the retirement threshold until the final qualifying rental"
	)
	_tracker.apply_degradation(item_id)

	assert_almost_eq(
		_tracker.get_wear(item_id),
		target_wear,
		0.0001,
		"DVD items should hit the poor-condition threshold on the expected rental count"
	)
	assert_eq(
		_tracker.get_condition(item_id),
		TapeWearTracker.POOREST_CONDITION,
		"Reaching the threshold should mark the item as poor"
	)


func test_reinitializing_same_item_does_not_duplicate_entry() -> void:
	_tracker.initialize_item("duplicate_item", TapeWearTracker.MEDIA_TYPE_VHS)
	_tracker.apply_degradation("duplicate_item")
	_tracker.initialize_item("duplicate_item", TapeWearTracker.MEDIA_TYPE_VHS)

	assert_eq(
		_tracker.get_tracked_item_count(),
		1,
		"Reinitializing an existing item_id should reuse the tracked entry instead of duplicating it"
	)
	assert_almost_eq(
		_tracker.get_wear("duplicate_item"),
		TapeWearTracker.VHS_DEGRADATION_RATE,
		0.0001,
		"Reinitializing should preserve the existing wear entry"
	)
