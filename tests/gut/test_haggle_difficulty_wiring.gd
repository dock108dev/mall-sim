## Tests that HaggleSystem reads haggle_acceptance_base_rate and
## haggle_concession_ceiling from DifficultySystem at evaluation time.
extends GutTest


var _haggle: HaggleSystem
var _reputation: ReputationSystem
var _profile: CustomerTypeDefinition
var _definition: ItemDefinition
var _item: ItemInstance
var _customer_scene: PackedScene
var _original_tier: StringName


func before_all() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()


func before_each() -> void:
	_original_tier = DifficultySystemSingleton.get_current_tier_id()

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)

	_haggle = HaggleSystem.new()
	add_child_autofree(_haggle)
	_haggle.initialize(_reputation)

	_profile = CustomerTypeDefinition.new()
	_profile.id = "test_haggler"
	_profile.customer_name = "Test Haggler"
	_profile.budget_range = [5.0, 200.0]
	_profile.patience = 0.9
	_profile.price_sensitivity = 0.9
	_profile.preferred_categories = PackedStringArray(["cards"])
	_profile.preferred_tags = PackedStringArray([])
	_profile.condition_preference = "good"
	_profile.browse_time_range = [30.0, 60.0]
	_profile.purchase_probability_base = 0.8
	_profile.impulse_buy_chance = 0.1
	_profile.mood_tags = PackedStringArray([])

	_definition = ItemDefinition.new()
	_definition.id = "test_card"
	_definition.item_name = "Test Card"
	_definition.category = "cards"
	_definition.base_price = 50.0
	_definition.rarity = "common"
	_definition.tags = PackedStringArray([])
	_definition.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)

	_item = ItemInstance.create_from_definition(_definition, "good")
	_item.player_set_price = 90.0

	_customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)


func after_each() -> void:
	DifficultySystemSingleton.set_tier(_original_tier)


func _make_customer() -> Customer:
	var customer: Customer = _customer_scene.instantiate()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer


# --- Modifier lookups ---


func test_evaluate_offer_reads_acceptance_base_rate() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var rate: float = DifficultySystemSingleton.get_modifier(
		&"haggle_acceptance_base_rate"
	)
	assert_almost_eq(
		rate, 0.45, 0.001,
		"Normal tier haggle_acceptance_base_rate should be 0.45"
	)


func test_evaluate_offer_reads_concession_ceiling() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var ceiling: float = DifficultySystemSingleton.get_modifier(
		&"haggle_concession_ceiling"
	)
	assert_almost_eq(
		ceiling, 0.15, 0.001,
		"Normal tier haggle_concession_ceiling should be 0.15"
	)


func test_easy_tier_modifiers() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var rate: float = DifficultySystemSingleton.get_modifier(
		&"haggle_acceptance_base_rate"
	)
	var ceiling: float = DifficultySystemSingleton.get_modifier(
		&"haggle_concession_ceiling"
	)
	assert_almost_eq(rate, 0.60, 0.001, "Easy base rate = 0.60")
	assert_almost_eq(ceiling, 0.20, 0.001, "Easy ceiling = 0.20")


func test_hard_tier_modifiers() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var rate: float = DifficultySystemSingleton.get_modifier(
		&"haggle_acceptance_base_rate"
	)
	var ceiling: float = DifficultySystemSingleton.get_modifier(
		&"haggle_concession_ceiling"
	)
	assert_almost_eq(rate, 0.30, 0.001, "Hard base rate = 0.30")
	assert_almost_eq(ceiling, 0.08, 0.001, "Hard ceiling = 0.08")


# --- Hard tier ceiling rejection ---


func test_hard_tier_rejects_below_ceiling() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var below_ceiling: float = _item.player_set_price * 0.91
	var accepted_count: Array = [0]
	var trials: int = 200
	for i: int in range(trials):
		_haggle._sticker_price = _item.player_set_price
		var result: bool = _haggle._evaluate_offer(below_ceiling)
		if result:
			accepted_count[0] += 1
	assert_eq(
		accepted_count[0], 0,
		"Hard tier: offer at 91%% (below 92%% ceiling) must always reject"
	)


func test_hard_tier_allows_above_ceiling() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var above_ceiling: float = _item.player_set_price * 0.93
	var accepted_count: Array = [0]
	var trials: int = 500
	for i: int in range(trials):
		var result: bool = _haggle._evaluate_offer(above_ceiling)
		if result:
			accepted_count[0] += 1
	assert_gt(
		accepted_count[0], 0,
		"Hard tier: offer at 93%% (above 92%% ceiling) should sometimes accept"
	)


# --- Normal tier probability ---


func test_normal_tier_acceptance_probability() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var offer_price: float = _item.player_set_price * 0.867
	var expected_prob: float = 0.45 * 0.867
	var accepted_count: Array = [0]
	var trials: int = 5000
	for i: int in range(trials):
		var result: bool = _haggle._evaluate_offer(offer_price)
		if result:
			accepted_count[0] += 1
	var actual_rate: float = float(accepted_count[0]) / float(trials)
	assert_almost_eq(
		actual_rate, expected_prob, 0.05,
		"Normal tier 86.7%% offer should accept ~%.1f%% of the time"
		% [expected_prob * 100.0]
	)


# --- Easy tier probability ---


func test_easy_tier_acceptance_probability() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var offer_price: float = _item.player_set_price * 0.867
	# base_rate=0.60, offer_ratio=0.867, success_rate_mult=1.30
	var expected_prob: float = 0.60 * 0.867 * 1.30
	var accepted_count: Array = [0]
	var trials: int = 5000
	for i: int in range(trials):
		var result: bool = _haggle._evaluate_offer(offer_price)
		if result:
			accepted_count[0] += 1
	var actual_rate: float = float(accepted_count[0]) / float(trials)
	assert_almost_eq(
		actual_rate, expected_prob, 0.05,
		"Easy tier 86.7%% offer should accept ~%.1f%% of the time"
		% [expected_prob * 100.0]
	)


# --- haggle_success_rate_multiplier ---


func test_easy_success_rate_multiplier_is_1_30() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var mult: float = DifficultySystemSingleton.get_modifier(
		&"haggle_success_rate_multiplier"
	)
	assert_almost_eq(mult, 1.30, 0.001, "Easy haggle_success_rate_multiplier should be 1.30")


func test_hard_success_rate_multiplier_is_0_65() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var mult: float = DifficultySystemSingleton.get_modifier(
		&"haggle_success_rate_multiplier"
	)
	assert_almost_eq(mult, 0.65, 0.001, "Hard haggle_success_rate_multiplier should be 0.65")


func test_normal_success_rate_multiplier_is_1_00() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var mult: float = DifficultySystemSingleton.get_modifier(
		&"haggle_success_rate_multiplier"
	)
	assert_almost_eq(mult, 1.00, 0.001, "Normal haggle_success_rate_multiplier should be 1.00")


func test_hard_tier_acceptance_probability() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var offer_price: float = _item.player_set_price * 0.95
	# above hard ceiling (1 - 0.08 = 0.92), offer_ratio=0.95
	# base_rate=0.30, success_rate_mult=0.65
	var expected_prob: float = 0.30 * 0.95 * 0.65
	var accepted_count: Array = [0]
	var trials: int = 5000
	for i: int in range(trials):
		var result: bool = _haggle._evaluate_offer(offer_price)
		if result:
			accepted_count[0] += 1
	var actual_rate: float = float(accepted_count[0]) / float(trials)
	assert_almost_eq(
		actual_rate, expected_prob, 0.05,
		"Hard tier 95%% offer should accept ~%.1f%% of the time"
		% [expected_prob * 100.0]
	)


# --- No DifficultySystem call in _ready or _init ---


func test_no_difficulty_call_in_init() -> void:
	var system: HaggleSystem = HaggleSystem.new()
	add_child_autofree(system)
	assert_true(
		true,
		"HaggleSystem construction must not call DifficultySystem"
	)
