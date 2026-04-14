## Unit tests for FixtureUpgradeHandler — eligibility check, cost deduction, and tier_advanced signal.
extends GutTest


var _handler: FixtureUpgradeHandler
var _economy: EconomySystem
var _reputation: ReputationSystem
var _data_loader: DataLoader
var _placed_fixtures: Dictionary

const FIXTURE_ID: String = "fixture_001"
const FIXTURE_TYPE: String = "test_shelf"
const FIXTURE_COST: float = 100.0


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_test_fixture()

	GameManager.current_store_id = &"test_store"
	_reputation._scores["test_store"] = 100.0

	_placed_fixtures = {
		FIXTURE_ID: {
			"tier": FixtureDefinition.TierLevel.BASIC,
			"fixture_type": FIXTURE_TYPE,
			"total_spent": 0.0,
		}
	}

	_handler = FixtureUpgradeHandler.new()
	_handler.initialize(
		_placed_fixtures, _data_loader, _economy, _reputation
	)


func after_each() -> void:
	GameManager.current_store_id = &""


func _register_test_fixture() -> void:
	var def := FixtureDefinition.new()
	def.id = FIXTURE_TYPE
	def.item_name = FIXTURE_TYPE
	def.cost = FIXTURE_COST
	_data_loader._fixtures[FIXTURE_TYPE] = def


func test_upgrade_rejected_when_insufficient_funds() -> void:
	_economy._current_cash = 0.0

	var result: bool = _handler.try_upgrade(FIXTURE_ID)

	assert_false(result, "Upgrade should be rejected when funds are insufficient")
	assert_almost_eq(
		_economy.get_cash(), 0.0, 0.01,
		"Balance should remain unchanged when upgrade is rejected due to insufficient funds"
	)


func test_upgrade_succeeds_and_deducts_cost() -> void:
	var cost: float = _handler.get_upgrade_cost(FIXTURE_ID)
	var balance_before: float = _economy.get_cash()

	var result: bool = _handler.try_upgrade(FIXTURE_ID)

	assert_true(result, "Upgrade should succeed with sufficient funds and valid reputation")
	assert_almost_eq(
		_economy.get_cash(), balance_before - cost, 0.01,
		"Balance should decrease by the exact upgrade cost"
	)


func test_tier_advanced_signal_emitted_on_success() -> void:
	watch_signals(EventBus)

	var result: bool = _handler.try_upgrade(FIXTURE_ID)

	assert_true(result, "Upgrade should succeed for signal emission test")
	assert_signal_emitted(
		EventBus, "fixture_upgraded",
		"fixture_upgraded signal should be emitted on successful upgrade"
	)
	var params: Array = get_signal_parameters(EventBus, "fixture_upgraded")
	assert_eq(
		params[0], FIXTURE_ID,
		"Signal fixture_id should match the upgraded fixture"
	)
	assert_eq(
		params[1], FixtureDefinition.TierLevel.IMPROVED,
		"Signal new_tier should be IMPROVED after upgrading from BASIC"
	)


func test_upgrade_rejected_at_max_tier() -> void:
	_placed_fixtures[FIXTURE_ID]["tier"] = FixtureDefinition.TierLevel.PREMIUM
	var balance_before: float = _economy.get_cash()
	watch_signals(EventBus)

	var result: bool = _handler.try_upgrade(FIXTURE_ID)

	assert_false(result, "Upgrade should be rejected when fixture is at maximum tier")
	assert_almost_eq(
		_economy.get_cash(), balance_before, 0.01,
		"Balance should be unchanged when upgrade is rejected at max tier"
	)
	assert_signal_not_emitted(
		EventBus, "fixture_upgraded",
		"fixture_upgraded signal should not be emitted when already at max tier"
	)


func test_upgrade_cost_scales_with_tier() -> void:
	var cost_basic_to_improved: float = _handler.get_upgrade_cost(FIXTURE_ID)

	_placed_fixtures[FIXTURE_ID]["tier"] = FixtureDefinition.TierLevel.IMPROVED
	var cost_improved_to_premium: float = _handler.get_upgrade_cost(FIXTURE_ID)

	assert_gt(
		cost_improved_to_premium, cost_basic_to_improved,
		"Upgrade cost to PREMIUM should be greater than upgrade cost to IMPROVED"
	)
