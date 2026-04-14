## Integration test: staff wages exhaust cash — day_ended → wages → bankruptcy → game_over chain.
extends GutTest

const STAFF_WAGE: float = 100.0
const STARTING_CASH_BELOW_WAGE: float = 90.0
const STORE_ID: String = "test_store"
const FLOAT_EPSILON: float = 0.01

var _economy: EconomySystem
var _staff: StaffSystem
var _reputation: ReputationSystem
var _data_loader: DataLoader
var _ending_evaluator: EndingEvaluatorSystem

var _saved_state: GameManager.GameState
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]
var _saved_difficulty: StringName


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_difficulty = DifficultySystem.get_current_tier_id()

	DifficultySystem.set_tier(&"normal")
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager.current_store_id = &"test_store"
	GameManager.owned_stores = []

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_test_staff_definition()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH_BELOW_WAGE)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_ID)
	_reputation.add_reputation(STORE_ID, 50.0)

	_staff = StaffSystem.new()
	add_child_autofree(_staff)
	_staff.initialize(_economy, _reputation, null, _data_loader)

	_ending_evaluator = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_evaluator)
	_ending_evaluator.initialize()


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	DifficultySystem.set_tier(_saved_difficulty)


## Wages exceed cash — bankruptcy_declared emitted and GameManager enters GAME_OVER.
func test_wages_exhaust_cash_triggers_bankruptcy_and_game_over() -> void:
	_staff.hire_staff("bankrupt_staff", STORE_ID)
	watch_signals(EventBus)

	_staff.process_daily_wages()

	assert_true(
		_economy.get_cash() <= 0.0,
		"Cash should be at or below zero after wages exceed starting balance"
	)
	assert_signal_emitted(
		EventBus, "bankruptcy_declared",
		"bankruptcy_declared should fire when wages exhaust player cash"
	)
	assert_eq(
		GameManager.current_state, GameManager.GameState.GAME_OVER,
		"GameManager should transition to GAME_OVER after bankruptcy"
	)


## Wages exactly equal cash — cash hits 0.0, bankruptcy_declared still fires.
func test_wages_equal_cash_still_triggers_bankruptcy() -> void:
	_economy.load_save_data({"current_cash": STAFF_WAGE})
	_staff.hire_staff("bankrupt_staff", STORE_ID)
	watch_signals(EventBus)

	_staff.process_daily_wages()

	assert_almost_eq(
		_economy.get_cash(), 0.0, FLOAT_EPSILON,
		"Cash should be exactly zero when wage equals starting cash"
	)
	assert_signal_emitted(
		EventBus, "bankruptcy_declared",
		"bankruptcy_declared should fire even when cash reaches exactly zero"
	)
	assert_eq(
		GameManager.current_state, GameManager.GameState.GAME_OVER,
		"GameManager should enter GAME_OVER when cash reaches exactly zero"
	)


## bankruptcy_declared guard flag — emitted at most once per run regardless of repeated deductions.
func test_bankruptcy_declared_emitted_exactly_once() -> void:
	_staff.hire_staff("bankrupt_staff", STORE_ID)
	watch_signals(EventBus)

	_staff.process_daily_wages()
	_staff.process_daily_wages()

	assert_signal_emit_count(
		EventBus, "bankruptcy_declared", 1,
		"bankruptcy_declared should be guarded and emitted at most once per run"
	)


## Easy mode injection restores cash above wages before deduction — bankruptcy_declared not emitted.
func test_easy_mode_injection_prevents_bankruptcy() -> void:
	DifficultySystem.set_tier(&"easy")
	_economy.load_save_data({
		"current_cash": STARTING_CASH_BELOW_WAGE,
		"daily_rent": 50.0,
		"last_injection_day": -1,
	})
	_staff.hire_staff("bankrupt_staff", STORE_ID)

	EventBus.day_ended.emit(1)

	assert_true(
		_economy.get_cash() > STAFF_WAGE,
		"Easy mode injection should raise cash well above the staff wage amount"
	)

	watch_signals(EventBus)
	_staff.process_daily_wages()

	assert_signal_not_emitted(
		EventBus, "bankruptcy_declared",
		"bankruptcy_declared should not fire when easy mode injection restores cash above wages"
	)
	assert_true(
		_economy.get_cash() > 0.0,
		"Cash should remain positive after wages when injection preceded deduction"
	)


func _register_test_staff_definition() -> void:
	var staff_def := StaffDefinition.new()
	staff_def.staff_id = "bankrupt_staff"
	staff_def.display_name = "Bankrupt Staff"
	staff_def.role = StaffDefinition.StaffRole.CASHIER
	staff_def.skill_level = 1
	staff_def.daily_wage = STAFF_WAGE
	_data_loader._staff_definitions["bankrupt_staff"] = staff_def
