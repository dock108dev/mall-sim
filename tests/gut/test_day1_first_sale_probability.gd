## Day 1 first-sale guarantee: the BRAINDUMP Priority 6 contract that the
## tutorial customer must purchase the placed item with ≥80% probability,
## bypassing the normal demand-model multipliers so a low-base profile or weak
## match cannot randomly bounce the player out of the loop. After
## `GameState.first_sale_complete` flips, the standard model resumes.
extends GutTest


const SAMPLE_SIZE: int = 1000
const MIN_REQUIRED_RATE: float = 0.80

var _profile: CustomerTypeDefinition
var _definition: ItemDefinition
var _item: ItemInstance
var _saved_day: int


func before_each() -> void:
	_saved_day = GameManager.get_current_day()
	GameState.reset_new_game()
	GameManager.set_current_day(1)

	# A deliberately weak profile: low base probability, no category match,
	# minimal impulse. Under the normal model this would convert ~20-30%; the
	# Day 1 guarantee must lift it to DAY1_PURCHASE_PROBABILITY.
	_profile = CustomerTypeDefinition.new()
	_profile.id = "test_day1_customer"
	_profile.customer_name = "Tutorial Customer"
	_profile.budget_range = [5.0, 200.0]
	_profile.patience = 0.5
	_profile.price_sensitivity = 0.75
	_profile.preferred_categories = PackedStringArray(["never_match"])
	_profile.preferred_tags = PackedStringArray([])
	_profile.condition_preference = "good"
	_profile.browse_time_range = [30.0, 60.0]
	_profile.purchase_probability_base = 0.3
	_profile.impulse_buy_chance = 1.0
	_profile.max_price_to_market_ratio = 5.0

	_definition = ItemDefinition.new()
	_definition.id = "test_cart"
	_definition.item_name = "Test Cartridge"
	_definition.category = "cartridges"
	_definition.base_price = 40.0
	_definition.rarity = "common"
	_definition.tags = PackedStringArray([])
	_definition.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)

	_item = ItemInstance.create_from_definition(_definition, "good")
	_item.player_set_price = 40.0


func after_each() -> void:
	GameManager.set_current_day(_saved_day)
	GameState.reset_new_game()
	# Restore non-determinism so probabilistic tests in other files don't
	# inherit the seed set by the conversion-rate sweeps below.
	randomize()


func test_constant_meets_minimum_braindump_threshold() -> void:
	assert_gte(
		Constants.DAY1_PURCHASE_PROBABILITY,
		MIN_REQUIRED_RATE,
		"DAY1_PURCHASE_PROBABILITY must satisfy the BRAINDUMP ≥80% contract"
	)


func test_day1_first_sale_overrides_weak_profile_to_guaranteed_purchase() -> void:
	GameState.set_flag(&"first_sale_complete", false)
	var customer: Customer = _make_customer()
	var purchases: int = 0

	seed(54321)
	for _i: int in range(SAMPLE_SIZE):
		customer.current_state = Customer.State.DECIDING
		customer._desired_item = _item
		customer._process_deciding()
		if customer.current_state == Customer.State.PURCHASING:
			purchases += 1

	var rate: float = float(purchases) / float(SAMPLE_SIZE)
	assert_gte(
		rate,
		MIN_REQUIRED_RATE,
		"Day 1 first-sale guarantee must yield ≥80%% conversion (got %.2f)" % rate
	)


func test_after_first_sale_flag_set_normal_model_resumes() -> void:
	GameState.set_flag(&"first_sale_complete", true)
	var customer: Customer = _make_customer()
	var purchases: int = 0

	seed(54321)
	for _i: int in range(SAMPLE_SIZE):
		customer.current_state = Customer.State.DECIDING
		customer._desired_item = _item
		customer._process_deciding()
		if customer.current_state == Customer.State.PURCHASING:
			purchases += 1

	var rate: float = float(purchases) / float(SAMPLE_SIZE)
	# Standard model with base 0.3 and no category match yields well under
	# the guarantee threshold; the assertion proves the override is gated on
	# the flag rather than always-on for Day 1.
	assert_lt(
		rate,
		MIN_REQUIRED_RATE,
		"With first_sale_complete=true the standard model must drop below 80%% (got %.2f)" % rate
	)


func test_override_inactive_outside_day_1() -> void:
	GameManager.set_current_day(2)
	GameState.set_flag(&"first_sale_complete", false)
	var customer: Customer = _make_customer()
	assert_false(
		customer._is_first_sale_guarantee_active(),
		"Guarantee must not apply when current day is not 1"
	)


func test_override_inactive_when_first_sale_flag_set() -> void:
	GameState.set_flag(&"first_sale_complete", true)
	var customer: Customer = _make_customer()
	assert_false(
		customer._is_first_sale_guarantee_active(),
		"Guarantee must not apply once first_sale_complete is true"
	)


func test_price_ceiling_still_applies_under_guarantee() -> void:
	# An absurd markup must still lose the sale — the override is for the
	# decision roll, not a willingness-to-pay bypass.
	GameState.set_flag(&"first_sale_complete", false)
	_item.player_set_price = 999_999.0
	var customer: Customer = _make_customer()
	customer._desired_item = _item
	customer._process_deciding()
	assert_eq(
		customer.current_state,
		Customer.State.LEAVING,
		"Day 1 guarantee must not bypass the price-too-high guard"
	)


func _make_customer() -> Customer:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.profile = _profile
	customer._budget_multiplier = 1.0
	return customer
