## GUT tests for the Stadium Relics CARB multi-state authentication mechanic (ISSUE-009).
## Covers: fee deduction, 3-state reveal flow, partial-information reveal,
## grade multipliers, store_auth_started / store_auth_resolved signals,
## and the season modifier returning non-trivial values for boosted categories.
extends GutTest


const STORE_ID: StringName = &"sports"
const FLOAT_TOLERANCE: float = 0.001


## Minimal EconomySystem subclass for fee-deduction assertions.
class _EconomySpy extends EconomySystem:
	var total_deducted: float = 0.0
	var will_allow: bool = true

	func deduct_cash(amount: float, reason: String) -> bool:
		if will_allow:
			total_deducted += amount
		return will_allow if amount > 0.0 else super.deduct_cash(amount, reason)


var _saved_data_loader: DataLoader
var _data_loader: DataLoader
var _inventory: InventorySystem
var _controller: SportsMemorabiliaController
var _economy: _EconomySpy


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

	_economy = _EconomySpy.new()
	add_child_autofree(_economy)
	_economy.initialize(10000.0)

	_controller = SportsMemorabiliaController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)
	_controller.set_economy_system(_economy)
	_controller.initialize(1)


func after_each() -> void:
	GameManager.data_loader = _saved_data_loader
	ContentRegistry.clear_for_testing()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_item(condition: String = "good", provenance_score: float = 0.5) -> ItemInstance:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "test_carb_%d" % randi()
	def.item_name = "Test Item"
	def.store_type = &"sports"
	def.category = &"memorabilia"
	def.base_price = 1000.0
	def.provenance_score = provenance_score
	var item: ItemInstance = ItemInstance.create_from_definition(def, condition)
	_inventory.add_item(STORE_ID, item)
	return item


# ── CARB grade multiplier table ───────────────────────────────────────────────

func test_carb_grade_multipliers_cover_all_valid_grades() -> void:
	var expected_grades: Array = [0, 1, 2, 3, 4, 5, 7, 8, 9, 10]
	for grade: int in expected_grades:
		assert_true(
			SportsMemorabiliaController.CARB_GRADE_MULTIPLIERS.has(grade),
			"CARB_GRADE_MULTIPLIERS must include grade %d" % grade
		)


func test_carb_grade_multipliers_are_ordered() -> void:
	var mults := SportsMemorabiliaController.CARB_GRADE_MULTIPLIERS
	assert_eq(float(mults[0]), 0.0, "COUNTERFEIT must be 0.0x")
	assert_gt(float(mults[1]), 0.0, "AUTHENTIC_RAW must be > 0")
	assert_gt(float(mults[10]), float(mults[9]), "PRISTINE must exceed GEM_MINT")
	assert_gt(float(mults[9]), float(mults[8]), "GEM_MINT must exceed MINT")
	assert_gt(float(mults[8]), float(mults[7]), "MINT must exceed NEAR_MINT")
	assert_gt(float(mults[7]), float(mults[5]), "NEAR_MINT must exceed EXCELLENT")


func test_grade_6_is_absent() -> void:
	assert_false(
		SportsMemorabiliaController.CARB_GRADE_MULTIPLIERS.has(6),
		"Grade 6 must be absent — parodies real grading gap"
	)


# ── Fee deduction ─────────────────────────────────────────────────────────────

func test_submit_deducts_economy_fee() -> void:
	var item: ItemInstance = _make_item("good")
	var before: float = _economy.total_deducted
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 0)
	assert_gt(
		_economy.total_deducted, before,
		"A positive fee must be deducted from the economy on CARB submission"
	)


func test_economy_fee_respects_min_floor() -> void:
	var item: ItemInstance = _make_item("good")
	item.definition.base_price = 1.0  # would produce sub-floor fee without clamping
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 0)
	var cost: float = _economy.total_deducted
	assert_ge(
		cost,
		SportsMemorabiliaController.AUTH_MIN_FEE,
		"Fee must not fall below AUTH_MIN_FEE"
	)


func test_economy_denial_blocks_submission() -> void:
	_economy.will_allow = false
	var item: ItemInstance = _make_item("good")
	var started_ids: Array[StringName] = []
	var cap: Callable = func(iid: StringName, _t: int, _c: float) -> void:
		started_ids.append(iid)
	EventBus.store_auth_started.connect(cap)
	var ok: bool = _controller.submit_for_carb_authentication(
		StringName(item.instance_id), 0
	)
	EventBus.store_auth_started.disconnect(cap)
	assert_false(ok, "Submission must fail when economy denies the fee")
	assert_eq(started_ids.size(), 0, "store_auth_started must NOT emit on denied fee")


# ── store_auth_started signal ─────────────────────────────────────────────────

func test_store_auth_started_emitted_on_valid_submission() -> void:
	var item: ItemInstance = _make_item("good")
	var started: Array[StringName] = []
	var cap: Callable = func(iid: StringName, _t: int, _c: float) -> void:
		started.append(iid)
	EventBus.store_auth_started.connect(cap)
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 0)
	EventBus.store_auth_started.disconnect(cap)
	assert_eq(started.size(), 1, "store_auth_started must fire exactly once on submission")
	assert_eq(
		started[0], StringName(item.instance_id),
		"store_auth_started must carry the submitted item_id"
	)


func test_duplicate_submission_blocked() -> void:
	var item: ItemInstance = _make_item("good")
	var ok1: bool = _controller.submit_for_carb_authentication(
		StringName(item.instance_id), 0
	)
	var ok2: bool = _controller.submit_for_carb_authentication(
		StringName(item.instance_id), 0
	)
	assert_true(ok1, "First submission must succeed")
	assert_false(ok2, "Duplicate submission must be rejected")


# ── Three-state reveal flow — Economy tier ────────────────────────────────────

func test_economy_has_binary_reveal_before_final() -> void:
	var item: ItemInstance = _make_item("good")
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 0)

	var notifications: Array[String] = []
	var cap: Callable = func(msg: String) -> void:
		notifications.append(msg)
	EventBus.notification_requested.connect(cap)

	# Day 1–2 after submission: no reveal yet (binary fires at day 3)
	EventBus.day_started.emit(2)
	var count_before: int = notifications.size()

	# Day 3 after submission: binary reveal fires
	EventBus.day_started.emit(4)
	EventBus.notification_requested.disconnect(cap)

	assert_gt(
		notifications.size(), count_before,
		"Binary reveal notification must fire at day 3 after submission"
	)


func test_economy_final_grade_fires_after_binary() -> void:
	var item: ItemInstance = _make_item("good")
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 0)

	var resolved: Array[int] = []
	var cap: Callable = func(iid: StringName, grade: int, _val: float) -> void:
		if iid == StringName(item.instance_id):
			resolved.append(grade)
	EventBus.store_auth_resolved.connect(cap)

	# Advance to day 6 (submission day=1, elapsed=5 ≥ offset=5)
	EventBus.day_started.emit(6)
	EventBus.store_auth_resolved.disconnect(cap)

	assert_eq(
		resolved.size(), 1,
		"store_auth_resolved must fire exactly once for Economy tier at day 5+"
	)


# ── Express tier: binary reveal at day 1, final at day 2 ─────────────────────

func test_express_binary_reveal_fires_at_day_1() -> void:
	var item: ItemInstance = _make_item("good")
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 1)

	var notifications: Array[String] = []
	var cap: Callable = func(msg: String) -> void:
		notifications.append(msg)
	EventBus.notification_requested.connect(cap)
	EventBus.day_started.emit(2)  # day 1 after submission
	EventBus.notification_requested.disconnect(cap)

	var has_binary: bool = false
	for msg: String in notifications:
		if "CARB update" in msg:
			has_binary = true
	assert_true(has_binary, "Express binary reveal must fire at day 1 after submission")


func test_express_resolved_at_day_2() -> void:
	var item: ItemInstance = _make_item("good")
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 1)

	var resolved: Array[int] = []
	var cap: Callable = func(iid: StringName, grade: int, _val: float) -> void:
		if iid == StringName(item.instance_id):
			resolved.append(grade)
	EventBus.store_auth_resolved.connect(cap)
	EventBus.day_started.emit(3)  # day 2 after submission
	EventBus.store_auth_resolved.disconnect(cap)

	assert_eq(resolved.size(), 1, "Express must resolve at day 2 after submission")


# ── Premium tier: bracket+binary at day 1, final at day 2 ────────────────────

func test_premium_bracket_reveal_fires_before_final() -> void:
	var item: ItemInstance = _make_item("good")
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 2)

	var notifications: Array[String] = []
	var cap: Callable = func(msg: String) -> void:
		notifications.append(msg)
	EventBus.notification_requested.connect(cap)
	EventBus.day_started.emit(2)  # day 1: bracket fires
	EventBus.notification_requested.disconnect(cap)

	var has_bracket: bool = false
	for msg: String in notifications:
		if "CARB assessment" in msg:
			has_bracket = true
	assert_true(
		has_bracket,
		"Premium tier must emit bracket (partial-info) reveal at day 1 before final grade"
	)


func test_premium_resolved_at_day_2() -> void:
	var item: ItemInstance = _make_item("good")
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 2)

	var resolved: Array[int] = []
	var cap: Callable = func(iid: StringName, grade: int, _val: float) -> void:
		if iid == StringName(item.instance_id):
			resolved.append(grade)
	EventBus.store_auth_resolved.connect(cap)
	EventBus.day_started.emit(3)  # day 2: final grade
	EventBus.store_auth_resolved.disconnect(cap)

	assert_eq(resolved.size(), 1, "Premium must resolve at day 2 after submission")


# ── Grade applied persistently to item ───────────────────────────────────────

func test_carb_grade_applied_to_item_after_resolution() -> void:
	var item: ItemInstance = _make_item("good")
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 1)
	EventBus.day_started.emit(3)  # Express resolves at day 2

	assert_eq(
		item.authentication_status, "carb_graded",
		"Item authentication_status must be 'carb_graded' after resolution"
	)
	assert_true(item.is_graded, "Item must be marked is_graded after CARB resolution")
	assert_true(
		SportsMemorabiliaController.CARB_GRADE_MULTIPLIERS.has(item.numeric_grade),
		"Item.numeric_grade must be a valid AuthGrade value after resolution"
	)


func test_carb_graded_item_price_uses_carb_multipliers() -> void:
	var item: ItemInstance = _make_item("mint")
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 1)
	EventBus.day_started.emit(3)  # resolve

	assert_eq(item.authentication_status, "carb_graded", "Pre-check: must be carb_graded")
	var grade: int = item.numeric_grade
	var expected_factor: float = float(
		SportsMemorabiliaController.CARB_GRADE_MULTIPLIERS.get(grade, 0.0)
	)
	var price: float = _controller.get_item_price(StringName(item.instance_id))
	var base: float = item.definition.base_price
	assert_almost_eq(
		price, base * expected_factor, FLOAT_TOLERANCE,
		"CARB-graded item price must be base_price × CARB_GRADE_MULTIPLIERS[grade]"
	)


func test_carb_removed_from_pending_after_resolution() -> void:
	var item: ItemInstance = _make_item("good")
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 1)
	assert_true(
		_controller._pending_carb_auths.has(String(item.instance_id)),
		"Item must be in _pending_carb_auths after submission"
	)
	EventBus.day_started.emit(3)
	assert_false(
		_controller._pending_carb_auths.has(String(item.instance_id)),
		"Item must be removed from _pending_carb_auths after resolution"
	)


# ── season modifier non-trivial return ───────────────────────────────────────

func test_season_modifier_returns_non_trivial_for_memorabilia() -> void:
	# Force day 1 → month 1 → modifier 1.40 for memorabilia category
	GameManager.set_current_day(1)
	var modifier: float = _controller._get_season_modifier(&"memorabilia")
	assert_ne(
		modifier, 1.0,
		"_get_season_modifier must return a non-trivial value for boosted categories"
	)


func test_season_modifier_varies_across_months() -> void:
	GameManager.set_current_day(1)    # month 1: draft season
	var m1: float = _controller._get_season_modifier(&"memorabilia")
	GameManager.set_current_day(121)  # day 121 → month 5: off-season
	var m5: float = _controller._get_season_modifier(&"memorabilia")
	assert_ne(m1, m5, "Season modifier must differ between month 1 and month 5")


func test_season_modifier_unchanged_for_non_boosted_category() -> void:
	GameManager.set_current_day(1)
	var modifier: float = _controller._get_season_modifier(&"trading_cards")
	assert_eq(
		modifier, 1.0,
		"Non-boosted categories (trading_cards) must always return 1.0"
	)


# ── save / load round-trip ────────────────────────────────────────────────────

func test_save_data_includes_pending_carb_auths() -> void:
	var item: ItemInstance = _make_item("good")
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 0)
	var save: Dictionary = _controller.get_save_data()
	assert_true(
		save.has("pending_carb_auths"),
		"get_save_data must include pending_carb_auths key"
	)
	assert_eq(
		(save["pending_carb_auths"] as Dictionary).size(), 1,
		"Saved pending_carb_auths must contain the submitted item"
	)


func test_save_load_round_trip_preserves_carb_auths() -> void:
	var item: ItemInstance = _make_item("good")
	_controller.submit_for_carb_authentication(StringName(item.instance_id), 0)
	var save: Dictionary = _controller.get_save_data()
	_controller.load_save_data(save)
	assert_true(
		_controller._pending_carb_auths.has(String(item.instance_id)),
		"load_save_data must restore in-flight CARB authentication entries"
	)
