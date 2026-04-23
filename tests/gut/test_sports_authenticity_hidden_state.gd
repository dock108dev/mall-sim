## GUT tests for ISSUE-018 — hidden true_authenticity, probabilistic grading
## hints, and the fake-sold-as-authentic reputation penalty.
extends GutTest


const STORE_ID: StringName = &"sports"


var _saved_data_loader: DataLoader
var _data_loader: DataLoader
var _inventory: InventorySystem
var _economy: EconomySystem
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

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.add_cash(1000.0, "test seed")

	_controller = SportsMemorabiliaController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)
	_controller.set_economy_system(_economy)
	_controller.initialize(1)



func after_each() -> void:
	GameManager.data_loader = _saved_data_loader
	ContentRegistry.clear_for_testing()


func _make_item(provenance_score: float, condition: String = "good") -> ItemInstance:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "test_card_%d" % randi()
	def.item_name = "Test Card"
	def.store_type = &"sports"
	def.category = &"trading_cards"
	def.base_price = 10.0
	def.provenance_score = provenance_score
	var item: ItemInstance = ItemInstance.create_from_definition(def, condition)
	_inventory.add_item(STORE_ID, item)
	return item


# ── Hidden true_authenticity derivation ───────────────────────────────────────

func test_high_score_item_is_authentic() -> void:
	var item: ItemInstance = _make_item(0.90)
	assert_eq(item.true_authenticity, "authentic",
		"Score >= 0.75 should yield hidden 'authentic'")


func test_mid_score_item_is_questionable() -> void:
	var item: ItemInstance = _make_item(0.60)
	assert_eq(item.true_authenticity, "questionable",
		"Score in [0.5, 0.75) should yield hidden 'questionable'")


func test_low_score_item_is_fake() -> void:
	var item: ItemInstance = _make_item(0.20)
	assert_eq(item.true_authenticity, "fake",
		"Score < 0.5 should yield hidden 'fake'")


func test_revealed_authenticity_starts_unknown() -> void:
	var item: ItemInstance = _make_item(0.90)
	assert_eq(item.revealed_authenticity, "unknown",
		"Items start with revealed_authenticity = 'unknown'")


# ── Grading hint ──────────────────────────────────────────────────────────────

func test_grading_hint_deducts_fee_and_sets_revealed() -> void:
	var item: ItemInstance = _make_item(0.90)
	var start_cash: float = _economy.get_cash()
	var ok: bool = _controller.request_grading_hint(StringName(item.instance_id))
	assert_true(ok, "Grading hint must succeed with funds")
	assert_almost_eq(
		_economy.get_cash(),
		start_cash - SportsMemorabiliaController.GRADING_HINT_FEE,
		0.001, "Grading hint fee must be deducted"
	)
	assert_ne(item.revealed_authenticity, "unknown",
		"Hint must leave revealed_authenticity non-'unknown'")


func test_grading_hint_emits_signal() -> void:
	var item: ItemInstance = _make_item(0.30)
	var captured: Array = []
	var cb: Callable = func(iid: StringName, hint: String, fee: float) -> void:
		captured.append([iid, hint, fee])
	EventBus.grading_hint_revealed.connect(cb)
	_controller.request_grading_hint(StringName(item.instance_id))
	EventBus.grading_hint_revealed.disconnect(cb)
	assert_eq(captured.size(), 1, "grading_hint_revealed must fire once")
	assert_eq(captured[0][0], StringName(item.instance_id))


func test_grading_hint_never_reveals_raw_state_directly_on_item() -> void:
	# The hint is probabilistic — even calls against a known "fake" item may
	# occasionally report "questionable". The important invariant is that
	# true_authenticity is not copied verbatim into any player-facing field
	# other than revealed_authenticity, and revealed_authenticity is what the
	# UI reads. This test guards that invariant.
	var item: ItemInstance = _make_item(0.20)
	_controller.request_grading_hint(StringName(item.instance_id))
	assert_eq(item.true_authenticity, "fake",
		"true_authenticity remains the ground truth")
	assert_true(
		item.revealed_authenticity in ["authentic", "questionable", "fake"],
		"revealed_authenticity must be one of the three states"
	)


func test_grading_hint_fails_without_funds() -> void:
	var item: ItemInstance = _make_item(0.90)
	_economy.force_deduct_cash(_economy.get_cash(), "drain")
	var ok: bool = _controller.request_grading_hint(StringName(item.instance_id))
	assert_false(ok, "Grading hint must fail when player cannot afford fee")
	assert_eq(item.revealed_authenticity, "unknown",
		"Failed hint must not mutate revealed_authenticity")


# ── Fake-sold-as-authentic penalty ────────────────────────────────────────────

func test_fake_sold_as_authentic_emits_penalty_signal() -> void:
	var item: ItemInstance = _make_item(0.20)
	item.is_authenticated = true  # player declared it authentic
	var captured: Array = []
	var cb: Callable = func(
		iid: StringName, sid: StringName, price: float, delta: float
	) -> void:
		captured.append([iid, sid, price, delta])
	EventBus.fake_sold_as_authentic.connect(cb)
	EventBus.customer_purchased.emit(
		STORE_ID, StringName(item.instance_id), 50.0, &"cust_1"
	)
	EventBus.fake_sold_as_authentic.disconnect(cb)
	assert_eq(captured.size(), 1, "fake_sold_as_authentic must fire once")
	assert_lt(captured[0][3], 0.0, "reputation_delta must be negative")


func test_authentic_item_sold_as_authentic_does_not_penalize() -> void:
	var item: ItemInstance = _make_item(0.90)
	item.is_authenticated = true
	var captured: Array = []
	var cb: Callable = func(
		_iid: StringName, _sid: StringName, _price: float, _delta: float
	) -> void:
		captured.append(1)
	EventBus.fake_sold_as_authentic.connect(cb)
	EventBus.customer_purchased.emit(
		STORE_ID, StringName(item.instance_id), 50.0, &"cust_1"
	)
	EventBus.fake_sold_as_authentic.disconnect(cb)
	assert_eq(captured.size(), 0, "Authentic items must not trigger the penalty")


func test_fake_sold_without_declaring_authentic_does_not_penalize() -> void:
	var item: ItemInstance = _make_item(0.20)
	# is_authenticated remains false — player never certified it
	var captured: Array = []
	var cb: Callable = func(
		_iid: StringName, _sid: StringName, _price: float, _delta: float
	) -> void:
		captured.append(1)
	EventBus.fake_sold_as_authentic.connect(cb)
	EventBus.customer_purchased.emit(
		STORE_ID, StringName(item.instance_id), 50.0, &"cust_1"
	)
	EventBus.fake_sold_as_authentic.disconnect(cb)
	assert_eq(captured.size(), 0,
		"Selling a fake without declaring authentic must not penalize")
