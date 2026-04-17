## Tests TapeWearTracker play-count thresholds, condition drops, and write-off state.
extends GutTest


var _tracker: TapeWearTracker


func before_each() -> void:
	_tracker = TapeWearTracker.new()


func test_initialize_item_starts_play_count_at_zero() -> void:
	_tracker.initialize_item("item_a", "good")

	assert_eq(
		_tracker.get_play_count("item_a"),
		0,
		"Newly tracked items should start at zero plays in their current tier"
	)
	assert_eq(
		_tracker.get_condition("item_a"),
		"good",
		"Tracker should cache the item's current condition"
	)


func test_record_return_increments_play_count_without_changing_condition() -> void:
	_tracker.initialize_item("item_b", "near_mint")

	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1):
		var result: Dictionary = _tracker.record_return("item_b")
		assert_false(
			bool(result.get("condition_changed", false)),
			"Condition should not drop before the threshold is reached"
		)

	assert_eq(
		_tracker.get_play_count("item_b"),
		TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1,
		"Play count should reflect progress within the current condition tier"
	)
	assert_eq(
		_tracker.get_condition("item_b"),
		"near_mint",
		"Condition should stay unchanged before the threshold"
	)


func test_record_return_degrades_condition_and_resets_progress() -> void:
	_tracker.initialize_item("item_c", "good")

	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1):
		_tracker.record_return("item_c")
	var result: Dictionary = _tracker.record_return("item_c")

	assert_true(
		bool(result.get("condition_changed", false)),
		"Crossing the threshold should report a condition change"
	)
	assert_eq(
		str(result.get("new_condition", "")),
		"fair",
		"Good tapes should degrade to fair at the threshold"
	)
	assert_eq(
		_tracker.get_play_count("item_c"),
		0,
		"Progress should reset after dropping a condition tier"
	)


func test_poor_tape_becomes_unrentable_after_next_threshold() -> void:
	_tracker.initialize_item("item_d", "poor")

	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1):
		_tracker.record_return("item_d")
	var result: Dictionary = _tracker.record_return("item_d")

	assert_true(
		bool(result.get("became_unrentable", false)),
		"Poor tapes should transition into write-off state at the threshold"
	)
	assert_false(
		_tracker.is_rentable("item_d"),
		"Written-off tapes should no longer be rentable"
	)
	assert_eq(
		_tracker.get_play_count("item_d"),
		TapeWearTracker.RENTALS_PER_CONDITION_DROP,
		"Written-off tapes should keep a full threshold count for save/load restoration"
	)


func test_initialize_from_inventory_restores_written_off_state() -> void:
	var item: ItemInstance = ItemInstance.new()
	item.instance_id = "item_e"
	item.condition = "poor"
	_tracker.load_save_data({
		"item_e": TapeWearTracker.RENTALS_PER_CONDITION_DROP,
	})

	_tracker.initialize([item])

	assert_false(
		_tracker.is_rentable("item_e"),
		"Initializing from inventory should infer written-off state from poor condition plus full play count"
	)


func test_save_load_preserves_partial_progress() -> void:
	_tracker.initialize_item("item_f", "fair")
	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1):
		_tracker.record_return("item_f")
	var saved: Dictionary = _tracker.get_save_data()

	_tracker = TapeWearTracker.new()
	_tracker.load_save_data(saved)
	_tracker.initialize_item("item_f", "fair")

	assert_eq(
		_tracker.get_play_count("item_f"),
		TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1,
		"Saved play progress should restore exactly"
	)
	assert_true(
		_tracker.is_rentable("item_f"),
		"Partial-progress tapes should remain rentable after reload"
	)
