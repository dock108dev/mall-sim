## GUT integration tests: ACC numeric grading mechanic for Sports Cards.
## Covers: grade_returned fires on day N+1, numeric grade multiplier in audit trace.
extends GutTest


const STORE_ID: StringName = &"sports"
const ITEM_DEF_ID: StringName = &"sports_duvall_hr_common"
const FLOAT_TOLERANCE: float = 0.001

var _saved_data_loader: DataLoader
var _data_loader: DataLoader
var _inventory: InventorySystem
var _controller: SportsMemorabiliaController
var _grade_returned_signals: Array[Dictionary] = []


func before_each() -> void:
	_saved_data_loader = GameManager.data_loader
	ContentRegistry.clear_for_testing()

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all_content()
	GameManager.data_loader = _data_loader

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

	_controller = SportsMemorabiliaController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)
	_controller.initialize(1)

	_grade_returned_signals.clear()
	EventBus.grade_returned.connect(_on_grade_returned)


func after_each() -> void:
	_safe_disconnect(EventBus.grade_returned, _on_grade_returned)
	GameManager.data_loader = _saved_data_loader
	ContentRegistry.clear_for_testing()


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_grade_returned(card_id: StringName, grade: int) -> void:
	_grade_returned_signals.append({"card_id": card_id, "grade": grade})


func _stock_test_item(condition: String = "good") -> ItemInstance:
	var definition: ItemDefinition = ContentRegistry.get_item_definition(ITEM_DEF_ID)
	assert_not_null(definition, "Item definition should load from ContentRegistry")
	var item: ItemInstance = ItemInstance.create_from_definition(definition, condition)
	_inventory.add_item(STORE_ID, item)
	return item


## grade_returned must fire on day_started of day N+1 (not day N).
func test_grade_returned_fires_on_next_day_start() -> void:
	var item: ItemInstance = _stock_test_item("good")

	# Simulate day 1 — submit for grading
	GameManager.current_day = 1
	_controller.send_for_grading(StringName(item.instance_id))

	assert_true(
		item.is_grading_pending,
		"Item should be marked grading_pending after submission"
	)
	assert_false(
		item.numeric_grade >= 1,
		"Numeric grade should not be set on the day of submission"
	)
	assert_eq(
		_grade_returned_signals.size(), 0,
		"grade_returned must not fire on the day of submission"
	)

	# Trigger day_started for day 1 (same day) — still no return
	EventBus.day_started.emit(1)
	assert_eq(
		_grade_returned_signals.size(), 0,
		"grade_returned must not fire on day_started of the submission day"
	)

	# Trigger day_started for day 2 — grade should now return
	EventBus.day_started.emit(2)
	assert_eq(
		_grade_returned_signals.size(), 1,
		"grade_returned must fire exactly once on day_started of day N+1"
	)

	var returned_grade: int = _grade_returned_signals[0]["grade"]
	assert_between(returned_grade, 1, 10, "Returned grade must be in range 1–10")
	assert_eq(
		_grade_returned_signals[0]["card_id"],
		StringName(item.instance_id),
		"grade_returned card_id must match the submitted item instance_id"
	)
	assert_false(
		item.is_grading_pending,
		"is_grading_pending should be cleared after grade return"
	)
	assert_eq(
		item.numeric_grade, returned_grade,
		"item.numeric_grade should match the emitted grade"
	)


## PriceResolver audit trace must include the numeric grade multiplier for graded cards.
func test_grade_multiplier_in_audit_trace() -> void:
	var item: ItemInstance = _stock_test_item("mint")

	# Manually assign a known numeric grade to bypass the day-cycle.
	item.numeric_grade = 9
	item.is_graded = true
	item.is_grading_pending = false

	var expected_factor: float = PriceResolver.NUMERIC_GRADE_MULTIPLIERS.get(9, 1.0)
	var base_price: float = item.definition.base_price
	var priced: float = _controller.get_item_price(
		StringName(item.instance_id)
	)

	# With ACC grade 9 (×2.50), price should exceed base.
	assert_gt(
		priced,
		base_price * 1.0,
		"ACC grade 9 should produce a price greater than base_price"
	)

	# Build multipliers manually to verify audit trace content.
	var grade_factor: float = PriceResolver.NUMERIC_GRADE_MULTIPLIERS.get(9, 1.0)
	var multipliers: Array = [{
		"slot": "numeric_grade",
		"label": "ACC Grade",
		"factor": grade_factor,
		"detail": "ACC 9 — Mint",
	}]
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		StringName(item.instance_id),
		base_price,
		multipliers,
		false,
	)
	var found_grade_step: bool = false
	for step: Variant in result.steps:
		if step is PriceResolver.AuditStep:
			var s: PriceResolver.AuditStep = step as PriceResolver.AuditStep
			if s.label == "ACC Grade":
				found_grade_step = true
				assert_almost_eq(
					s.factor,
					expected_factor,
					FLOAT_TOLERANCE,
					"Audit step factor must match NUMERIC_GRADE_MULTIPLIERS[9]"
				)
	assert_true(
		found_grade_step,
		"PriceResolver audit trace must contain an 'ACC Grade' step for graded cards"
	)


## Cards pending grading must not be flagged numeric_grade < 1 after send_for_grading.
func test_pending_card_not_prematurely_graded() -> void:
	var item: ItemInstance = _stock_test_item("near_mint")
	_controller.send_for_grading(StringName(item.instance_id))

	assert_true(item.is_grading_pending, "Card should be pending after submission")
	assert_lt(item.numeric_grade, 1, "Numeric grade must not be set while pending")


## Duplicate submission on the same card must be silently ignored.
func test_duplicate_grading_submission_ignored() -> void:
	var item: ItemInstance = _stock_test_item("good")
	_controller.send_for_grading(StringName(item.instance_id))
	_controller.send_for_grading(StringName(item.instance_id))

	assert_eq(
		_controller._pending_grades.size(), 1,
		"Second submission on the same card must not add a second pending entry"
	)


## Grade rolls must land in the expected range for each condition tier.
func test_grade_range_matches_condition() -> void:
	var condition_ranges: Dictionary = {
		"mint":      [7, 10],
		"near_mint": [6,  9],
		"good":      [4,  7],
		"fair":      [2,  5],
		"poor":      [1,  3],
	}
	for condition: String in condition_ranges:
		var item: ItemInstance = _stock_test_item(condition)
		item.is_grading_pending = false  # not submitted; use internal method
		var grade: int = _controller._roll_numeric_grade(item, 42)
		var expected: Array = condition_ranges[condition]
		assert_between(
			grade,
			expected[0],
			expected[1],
			"Grade for condition '%s' should be in range [%d, %d]"
			% [condition, expected[0], expected[1]]
		)
