## Tests TapeWearTracker: degradation rates, condition thresholds, and retirement trigger.
extends GutTest


var _tracker: TapeWearTracker


func before_each() -> void:
	_tracker = TapeWearTracker.new()


# --- initialize_item ---


func test_initialize_creates_zero_wear_for_mint_condition() -> void:
	_tracker.initialize_item("item_a", "mint")
	assert_almost_eq(
		_tracker.get_wear("item_a"), 0.0, 0.001,
		"Mint condition should start at 0.0 wear"
	)


func test_initialize_creates_entry_with_condition_wear() -> void:
	_tracker.initialize_item("item_b", "good")
	assert_almost_eq(
		_tracker.get_wear("item_b"),
		TapeWearTracker.CONDITION_TO_WEAR["good"],
		0.001,
		"Good condition should start at 0.4 wear"
	)


func test_initialize_all_conditions_map_correctly() -> void:
	var conditions: Array[String] = ["mint", "near_mint", "good", "fair", "poor"]
	for condition: String in conditions:
		var id: String = "item_" + condition
		_tracker.initialize_item(id, condition)
		assert_almost_eq(
			_tracker.get_wear(id),
			TapeWearTracker.CONDITION_TO_WEAR[condition],
			0.001,
			"Condition %s should map to wear %.2f" % [
				condition, TapeWearTracker.CONDITION_TO_WEAR[condition]
			]
		)


func test_initialize_duplicate_does_not_reset_wear() -> void:
	_tracker.initialize_item("dup_item", "mint")
	_tracker.apply_degradation("dup_item", "vhs_titles")
	var wear_after_one: float = _tracker.get_wear("dup_item")
	_tracker.initialize_item("dup_item", "mint")
	assert_almost_eq(
		_tracker.get_wear("dup_item"), wear_after_one, 0.001,
		"Re-initializing should not reset accumulated wear"
	)


# --- apply_degradation VHS ---


func test_vhs_degradation_increases_wear_by_rate() -> void:
	_tracker.initialize_item("vhs_1", "mint")
	_tracker.apply_degradation("vhs_1", "vhs_titles")
	assert_almost_eq(
		_tracker.get_wear("vhs_1"),
		TapeWearTracker.VHS_DEGRADATION_RATE,
		0.001,
		"VHS single degradation should increase wear by VHS_DEGRADATION_RATE"
	)


func test_vhs_degradation_accumulates() -> void:
	_tracker.initialize_item("vhs_2", "mint")
	for i: int in range(3):
		_tracker.apply_degradation("vhs_2", "vhs_titles")
	assert_almost_eq(
		_tracker.get_wear("vhs_2"),
		TapeWearTracker.VHS_DEGRADATION_RATE * 3.0,
		0.001,
		"VHS wear should accumulate correctly over multiple rentals"
	)


func test_vhs_degradation_returns_condition_string() -> void:
	_tracker.initialize_item("vhs_3", "mint")
	var condition: String = _tracker.apply_degradation("vhs_3", "vhs_titles")
	assert_eq(
		typeof(condition), TYPE_STRING,
		"apply_degradation should return a String condition"
	)


# --- apply_degradation DVD ---


func test_dvd_degradation_increases_wear_by_rate() -> void:
	_tracker.initialize_item("dvd_1", "mint")
	_tracker.apply_degradation("dvd_1", "dvd_titles")
	assert_almost_eq(
		_tracker.get_wear("dvd_1"),
		TapeWearTracker.DVD_DEGRADATION_RATE,
		0.001,
		"DVD single degradation should increase wear by DVD_DEGRADATION_RATE"
	)


func test_dvd_degradation_rate_is_half_vhs() -> void:
	assert_almost_eq(
		TapeWearTracker.DVD_DEGRADATION_RATE,
		TapeWearTracker.VHS_DEGRADATION_RATE * 0.5,
		0.001,
		"DVD_DEGRADATION_RATE should be half of VHS_DEGRADATION_RATE"
	)


func test_dvd_degradation_accumulates() -> void:
	_tracker.initialize_item("dvd_2", "mint")
	for i: int in range(5):
		_tracker.apply_degradation("dvd_2", "dvd_titles")
	assert_almost_eq(
		_tracker.get_wear("dvd_2"),
		TapeWearTracker.DVD_DEGRADATION_RATE * 5.0,
		0.001,
		"DVD wear should accumulate correctly over multiple rentals"
	)


# --- Condition threshold boundaries ---


func test_wear_below_0_2_returns_mint() -> void:
	assert_eq(
		TapeWearTracker.wear_to_condition(0.0), "mint",
		"wear 0.0 should be mint"
	)
	assert_eq(
		TapeWearTracker.wear_to_condition(0.19), "mint",
		"wear 0.19 should be mint"
	)


func test_wear_at_0_2_returns_near_mint() -> void:
	assert_eq(
		TapeWearTracker.wear_to_condition(0.2), "near_mint",
		"wear 0.2 should be near_mint"
	)
	assert_eq(
		TapeWearTracker.wear_to_condition(0.39), "near_mint",
		"wear 0.39 should be near_mint"
	)


func test_wear_at_0_4_returns_good() -> void:
	assert_eq(
		TapeWearTracker.wear_to_condition(0.4), "good",
		"wear 0.4 should be good"
	)
	assert_eq(
		TapeWearTracker.wear_to_condition(0.59), "good",
		"wear 0.59 should be good"
	)


func test_wear_at_0_6_returns_fair() -> void:
	assert_eq(
		TapeWearTracker.wear_to_condition(0.6), "fair",
		"wear 0.6 should be fair"
	)
	assert_eq(
		TapeWearTracker.wear_to_condition(0.79), "fair",
		"wear 0.79 should be fair"
	)


func test_wear_at_0_8_returns_poor() -> void:
	assert_eq(
		TapeWearTracker.wear_to_condition(0.8), "poor",
		"wear 0.8 should be poor"
	)
	assert_eq(
		TapeWearTracker.wear_to_condition(1.0), "poor",
		"wear 1.0 should be poor"
	)


# --- Retirement threshold via degradation ---


func test_vhs_reaches_poor_after_exactly_10_rentals() -> void:
	_tracker.initialize_item("vhs_retire", "mint")
	var expected_rentals: int = ceili(0.8 / TapeWearTracker.VHS_DEGRADATION_RATE)
	assert_eq(expected_rentals, 10, "VHS should need exactly 10 rentals to reach poor")

	var condition: Array = ["mint"]
	var rentals: Array = [0]
	for i: int in range(expected_rentals - 1):
		condition[0] = _tracker.apply_degradation("vhs_retire", "vhs_titles")
		rentals[0] += 1
	assert_ne(
		condition[0], "poor",
		"VHS should not be poor before %d rentals (was at %d)" % [expected_rentals, rentals]
	)

	condition[0] = _tracker.apply_degradation("vhs_retire", "vhs_titles")
	rentals[0] += 1
	assert_eq(
		condition[0], "poor",
		"VHS should reach poor after exactly %d rentals" % expected_rentals
	)


func test_dvd_reaches_poor_after_exactly_20_rentals() -> void:
	_tracker.initialize_item("dvd_retire", "mint")
	var expected_rentals: int = ceili(0.8 / TapeWearTracker.DVD_DEGRADATION_RATE)
	assert_eq(expected_rentals, 20, "DVD should need exactly 20 rentals to reach poor")

	var condition: Array = ["mint"]
	var rentals: Array = [0]
	for i: int in range(expected_rentals - 1):
		condition[0] = _tracker.apply_degradation("dvd_retire", "dvd_titles")
		rentals[0] += 1
	assert_ne(
		condition[0], "poor",
		"DVD should not be poor before %d rentals (was at %d)" % [expected_rentals, rentals]
	)

	condition[0] = _tracker.apply_degradation("dvd_retire", "dvd_titles")
	rentals[0] += 1
	assert_eq(
		condition[0], "poor",
		"DVD should reach poor after exactly %d rentals" % expected_rentals
	)


# --- apply_degradation condition return matches get_wear ---


func test_returned_condition_matches_wear_to_condition() -> void:
	_tracker.initialize_item("consistency", "mint")
	for i: int in range(5):
		var returned: String = _tracker.apply_degradation("consistency", "vhs_titles")
		var computed: String = TapeWearTracker.wear_to_condition(
			_tracker.get_wear("consistency")
		)
		assert_eq(
			returned, computed,
			"apply_degradation return must match wear_to_condition(get_wear())"
		)


# --- Constants ---


func test_vhs_degradation_rate_constant() -> void:
	assert_almost_eq(
		TapeWearTracker.VHS_DEGRADATION_RATE, 0.08, 0.0001,
		"VHS_DEGRADATION_RATE should be 0.08"
	)


func test_dvd_degradation_rate_constant() -> void:
	assert_almost_eq(
		TapeWearTracker.DVD_DEGRADATION_RATE, 0.04, 0.0001,
		"DVD_DEGRADATION_RATE should be 0.04"
	)
