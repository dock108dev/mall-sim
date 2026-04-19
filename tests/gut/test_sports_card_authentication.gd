## GUT tests for the Sports Cards authentication + grading mechanic (ISSUE-022).
## Covers: all six grade tiers, rejected-card signal path, authentic vs forged price.
extends GutTest


const STORE_ID: StringName = &"sports"
const FLOAT_TOLERANCE: float = 0.001

var _saved_data_loader: DataLoader
var _data_loader: DataLoader
var _inventory: InventorySystem
var _controller: SportsMemorabiliaController


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


func after_each() -> void:
	GameManager.data_loader = _saved_data_loader
	ContentRegistry.clear_for_testing()


## Creates an ItemDefinition with a specific provenance_score for unit testing.
func _make_def(provenance_score: float) -> ItemDefinition:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "test_card_%d" % randi()
	def.item_name = "Test Card"
	def.store_type = &"sports"
	def.category = &"trading_cards"
	def.base_price = 10.0
	def.provenance_score = provenance_score
	return def


func _make_item(provenance_score: float, condition: String = "good") -> ItemInstance:
	var def: ItemDefinition = _make_def(provenance_score)
	var item: ItemInstance = ItemInstance.create_from_definition(def, condition)
	_inventory.add_item(STORE_ID, item)
	return item


# ── Grade multiplier constants ────────────────────────────────────────────────

func test_grade_multipliers_cover_all_six_tiers() -> void:
	var tiers: Array[String] = ["F", "D", "C", "B", "A", "S"]
	for grade: String in tiers:
		assert_true(
			PriceResolver.GRADE_MULTIPLIERS.has(grade),
			"GRADE_MULTIPLIERS must include tier '%s'" % grade
		)
	assert_eq(
		PriceResolver.GRADE_MULTIPLIERS.size(), 6,
		"GRADE_MULTIPLIERS must have exactly six entries"
	)


func test_grade_multipliers_are_ordered() -> void:
	assert_gt(
		PriceResolver.GRADE_MULTIPLIERS["S"],
		PriceResolver.GRADE_MULTIPLIERS["A"],
		"S must exceed A"
	)
	assert_gt(
		PriceResolver.GRADE_MULTIPLIERS["A"],
		PriceResolver.GRADE_MULTIPLIERS["B"],
		"A must exceed B"
	)
	assert_gt(
		PriceResolver.GRADE_MULTIPLIERS["B"],
		PriceResolver.GRADE_MULTIPLIERS["C"],
		"B must exceed C"
	)
	assert_gt(
		PriceResolver.GRADE_MULTIPLIERS["C"],
		PriceResolver.GRADE_MULTIPLIERS["D"],
		"C must exceed D"
	)
	assert_gt(
		PriceResolver.GRADE_MULTIPLIERS["D"],
		PriceResolver.GRADE_MULTIPLIERS["F"],
		"D must exceed F"
	)


# ── Grade assignment via authenticate_card ────────────────────────────────────

func test_s_grade_assigned_for_score_095_plus() -> void:
	var item: ItemInstance = _make_item(0.96)
	_controller.authenticate_card(StringName(item.instance_id))
	assert_eq(item.card_grade, "S", "Score 0.96 should yield grade S")


func test_a_grade_assigned_for_score_085_to_094() -> void:
	var item: ItemInstance = _make_item(0.88)
	_controller.authenticate_card(StringName(item.instance_id))
	assert_eq(item.card_grade, "A", "Score 0.88 should yield grade A")


func test_b_grade_assigned_for_score_075_to_084() -> void:
	var item: ItemInstance = _make_item(0.79)
	_controller.authenticate_card(StringName(item.instance_id))
	assert_eq(item.card_grade, "B", "Score 0.79 should yield grade B")


func test_c_grade_assigned_for_score_065_to_074() -> void:
	var item: ItemInstance = _make_item(0.70)
	_controller.authenticate_card(StringName(item.instance_id))
	assert_eq(item.card_grade, "C", "Score 0.70 should yield grade C")


func test_d_grade_assigned_for_score_055_to_064() -> void:
	var item: ItemInstance = _make_item(0.58)
	_controller.authenticate_card(StringName(item.instance_id))
	assert_eq(item.card_grade, "D", "Score 0.58 should yield grade D")


func test_f_grade_assigned_for_score_050_to_054() -> void:
	var item: ItemInstance = _make_item(0.51)
	_controller.authenticate_card(StringName(item.instance_id))
	assert_eq(item.card_grade, "F", "Score 0.51 should yield grade F")


# ── Signal path: card_authenticated / card_rejected / card_graded ─────────────

func test_card_authenticated_emitted_on_pass() -> void:
	var item: ItemInstance = _make_item(0.80)
	var auth_ids: Array[StringName] = []
	var capture: Callable = func(iid: StringName) -> void:
		auth_ids.append(iid)
	EventBus.card_authenticated.connect(capture)
	_controller.authenticate_card(StringName(item.instance_id))
	EventBus.card_authenticated.disconnect(capture)
	assert_eq(auth_ids.size(), 1, "card_authenticated must fire once for an authentic card")
	assert_eq(auth_ids[0], StringName(item.instance_id), "card_authenticated item_id must match")


func test_card_rejected_emitted_on_fail() -> void:
	var item: ItemInstance = _make_item(0.30)
	var rejected_ids: Array[StringName] = []
	var capture: Callable = func(iid: StringName) -> void:
		rejected_ids.append(iid)
	EventBus.card_rejected.connect(capture)
	_controller.authenticate_card(StringName(item.instance_id))
	EventBus.card_rejected.disconnect(capture)
	assert_eq(rejected_ids.size(), 1, "card_rejected must fire once for a forged card")
	assert_eq(rejected_ids[0], StringName(item.instance_id), "card_rejected item_id must match")


func test_card_graded_emitted_after_authentication() -> void:
	var item: ItemInstance = _make_item(0.87)
	var grades: Array[String] = []
	var capture: Callable = func(iid: StringName, grade: String) -> void:
		if iid == StringName(item.instance_id):
			grades.append(grade)
	EventBus.card_graded.connect(capture)
	_controller.authenticate_card(StringName(item.instance_id))
	EventBus.card_graded.disconnect(capture)
	assert_eq(grades.size(), 1, "card_graded must fire once after successful authentication")
	assert_eq(grades[0], "A", "Grade A expected for provenance_score 0.87")


func test_rejected_card_does_not_emit_card_graded() -> void:
	var item: ItemInstance = _make_item(0.20)
	var grades: Array[String] = []
	var capture: Callable = func(_iid: StringName, grade: String) -> void:
		grades.append(grade)
	EventBus.card_graded.connect(capture)
	_controller.authenticate_card(StringName(item.instance_id))
	EventBus.card_graded.disconnect(capture)
	assert_eq(grades.size(), 0, "card_graded must NOT fire when card is rejected")


func test_rejected_card_authentication_status_is_rejected() -> void:
	var item: ItemInstance = _make_item(0.10)
	_controller.authenticate_card(StringName(item.instance_id))
	assert_eq(item.authentication_status, "rejected", "Rejected card must have authentication_status 'rejected'")


func test_authenticated_card_is_flagged_as_graded() -> void:
	var item: ItemInstance = _make_item(0.90)
	_controller.authenticate_card(StringName(item.instance_id))
	assert_true(item.is_graded, "Item must have is_graded = true after authentication")
	assert_true(item.is_authenticated, "Item must have is_authenticated = true after authentication")


# ── Price calculation: grade multiplier applied via PriceResolver ─────────────

func test_authentic_card_price_uses_grade_multiplier() -> void:
	# Score 0.91 → grade A (3.0×), base_price = 10.0
	var item: ItemInstance = _make_item(0.91)
	_controller.authenticate_card(StringName(item.instance_id))
	assert_eq(item.card_grade, "A", "Pre-check: grade must be A for score 0.91")
	var price: float = _controller.get_item_price(StringName(item.instance_id))
	assert_almost_eq(
		price, 10.0 * PriceResolver.GRADE_MULTIPLIERS["A"], FLOAT_TOLERANCE,
		"Graded A card must price at base × 3.0"
	)


func test_forged_card_price_uses_condition_multiplier_not_grade() -> void:
	# Forged card (score 0.2) → rejected, no grade → falls back to condition
	var item: ItemInstance = _make_item(0.20, "good")
	_controller.authenticate_card(StringName(item.instance_id))
	assert_false(item.is_graded, "Rejected card must not be graded")
	var price: float = _controller.get_item_price(StringName(item.instance_id))
	var expected: float = 10.0 * ItemInstance.CONDITION_MULTIPLIERS.get("good", 1.0)
	assert_almost_eq(
		price, expected, FLOAT_TOLERANCE,
		"Forged card must price at base × condition multiplier, not grade"
	)


func test_graded_card_price_exceeds_ungraded_for_high_score() -> void:
	var ungraded: ItemInstance = _make_item(0.95, "good")
	var graded: ItemInstance = _make_item(0.95, "good")
	_controller.authenticate_card(StringName(graded.instance_id))
	var ungraded_price: float = _controller.get_item_price(StringName(ungraded.instance_id))
	var graded_price: float = _controller.get_item_price(StringName(graded.instance_id))
	assert_gt(graded_price, ungraded_price, "S-grade card must price above ungraded equivalent")


# ── grade_value numeric index ─────────────────────────────────────────────────

func test_grade_value_matches_grade_order_index() -> void:
	var pairs: Array = [["F", 0], ["D", 1], ["C", 2], ["B", 3], ["A", 4], ["S", 5]]
	for pair: Array in pairs:
		var grade: String = pair[0]
		var expected_idx: int = pair[1]
		assert_eq(
			PriceResolver.GRADE_ORDER.find(grade), expected_idx,
			"GRADE_ORDER index for %s must be %d" % [grade, expected_idx]
		)
