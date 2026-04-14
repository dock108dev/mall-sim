## Integration test: multi-day simulation verifying compound daily resets and accumulation.
extends GutTest

var _time: TimeSystem
var _economy: EconomySystem
var _staff: StaffSystem
var _trend: TrendSystem
var _reputation: ReputationSystem
var _perf_report: PerformanceReportSystem
var _data_loader: DataLoader

var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]
var _saved_day: int

const STARTING_CASH: float = 1000.0
const DAILY_WAGE: float = 50.0
const STORE_ID: String = "test_store"
const NUM_DAYS: int = 5
const TREND_CATEGORY: String = "electronics"
const TREND_MULTIPLIER: float = 1.8
const TREND_ACTIVE_DAY: int = 1
const TREND_END_DAY: int = 4
const TREND_FADE_END_DAY: int = 4
const INITIAL_REPUTATION: float = 55.0
const FLOAT_EPSILON: float = 0.01


func before_each() -> void:
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_day = GameManager.current_day

	GameManager.current_store_id = &"test_store"
	GameManager.owned_stores = []
	GameManager.current_day = 1

	_time = TimeSystem.new()
	add_child_autofree(_time)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_ID)
	_reputation._scores[STORE_ID] = INITIAL_REPUTATION

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_test_staff()

	_staff = StaffSystem.new()
	add_child_autofree(_staff)
	_staff.initialize(_economy, _reputation, null, _data_loader)
	_staff.hire_staff("test_worker", STORE_ID)

	_trend = TrendSystem.new()
	add_child_autofree(_trend)
	_trend.initialize(null)
	_trend._days_until_next_shift = 100
	_inject_test_trend()

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()


func after_each() -> void:
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	GameManager.current_day = _saved_day


func test_time_system_reaches_day_6_after_5_advances() -> void:
	_simulate_days(NUM_DAYS)

	assert_eq(
		_time.current_day, NUM_DAYS + 1,
		"TimeSystem.current_day should be 6 after 5 day cycles"
	)


func test_player_cash_decremented_by_cumulative_wages() -> void:
	_simulate_days(NUM_DAYS)

	var expected_cash: float = STARTING_CASH - (DAILY_WAGE * NUM_DAYS)
	assert_almost_eq(
		_economy.get_cash(), expected_cash, FLOAT_EPSILON,
		"Player cash should be 1000.0 - (50.0 × 5) = 750.0"
	)


func test_daily_revenue_resets_each_day() -> void:
	for day: int in range(1, NUM_DAYS + 1):
		_advance_day(day)

		var summary: Dictionary = _economy.get_daily_summary()
		assert_almost_eq(
			float(summary.get("total_revenue", -1.0)),
			0.0,
			FLOAT_EPSILON,
			"Daily revenue should reset to 0 on day %d" % day
		)

		_end_day(day)


func test_trend_expires_after_duration() -> void:
	assert_eq(
		_trend._active_trends.size(), 1,
		"One trend should be active at start"
	)

	for day: int in range(1, NUM_DAYS + 1):
		_advance_day(day)
		_end_day(day)

	assert_eq(
		_trend._active_trends.size(), 0,
		"Trend should be expired after 5 days (end_day = 4)"
	)


func test_trend_returns_neutral_multiplier_after_expiry() -> void:
	var item: ItemInstance = _create_electronics_item()

	var active_mult: float = _trend.get_trend_multiplier(item)
	assert_gt(
		active_mult, 1.0,
		"Trend multiplier should be above 1.0 while active"
	)

	for day: int in range(2, TREND_END_DAY + 1):
		GameManager.current_day = day
		_trend._on_day_started(day)

	var expired_mult: float = _trend.get_trend_multiplier(item)
	assert_almost_eq(
		expired_mult, 1.0, FLOAT_EPSILON,
		"Trend multiplier should return to 1.0 after expiry"
	)


func test_performance_report_generates_5_entries() -> void:
	_simulate_days(NUM_DAYS)

	var history: Array[PerformanceReport] = _perf_report.get_history()
	assert_eq(
		history.size(), NUM_DAYS,
		"PerformanceReportSystem should have 5 report entries"
	)


func test_reputation_decays_each_day() -> void:
	var score_before: float = _reputation.get_reputation(STORE_ID)

	_simulate_days(NUM_DAYS)

	var score_after: float = _reputation.get_reputation(STORE_ID)
	assert_true(
		score_after < score_before,
		"Reputation should decrease after 5 days of decay"
	)

	var expected_decay: float = ReputationSystemSingleton.DAILY_DECAY * NUM_DAYS
	assert_almost_eq(
		score_after,
		score_before - expected_decay,
		FLOAT_EPSILON,
		"Reputation should decay by DAILY_DECAY × 5 = %.1f" % expected_decay
	)


func test_cash_decrements_incrementally_per_day() -> void:
	for day: int in range(1, NUM_DAYS + 1):
		var expected: float = STARTING_CASH - (DAILY_WAGE * day)
		_advance_day(day)
		_end_day(day)

		assert_almost_eq(
			_economy.get_cash(), expected, FLOAT_EPSILON,
			"Cash should be %.2f after day %d wages" % [expected, day]
		)


# ── Helpers ──────────────────────────────────────────────────────────────────


func _advance_day(day: int) -> void:
	_time.current_day = day
	GameManager.current_day = day
	EventBus.day_started.emit(day)


func _end_day(day: int) -> void:
	EventBus.day_ended.emit(day)
	_staff.process_daily_wages()


func _simulate_days(count: int) -> void:
	for day: int in range(1, count + 1):
		_advance_day(day)
		_end_day(day)
	_time.current_day = count + 1
	GameManager.current_day = count + 1


func _register_test_staff() -> void:
	var staff_def := StaffDefinition.new()
	staff_def.staff_id = "test_worker"
	staff_def.display_name = "Test Worker"
	staff_def.role = StaffDefinition.StaffRole.CASHIER
	staff_def.skill_level = 1
	staff_def.daily_wage = DAILY_WAGE
	_data_loader._staff_definitions["test_worker"] = staff_def


func _inject_test_trend() -> void:
	var trend: Dictionary = {
		"target_type": "category",
		"target": TREND_CATEGORY,
		"trend_type": TrendSystem.TrendType.HOT,
		"multiplier": TREND_MULTIPLIER,
		"announced_day": TREND_ACTIVE_DAY,
		"active_day": TREND_ACTIVE_DAY,
		"end_day": TREND_END_DAY,
		"fade_end_day": TREND_FADE_END_DAY,
	}
	_trend._active_trends.append(trend)


func _create_electronics_item() -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_electronics_item"
	def.item_name = "Test Gadget"
	def.base_price = 20.0
	def.rarity = "common"
	def.condition_range = PackedStringArray(["good"])
	def.tags = PackedStringArray([])
	def.category = TREND_CATEGORY
	def.store_type = ""
	return ItemInstance.create_from_definition(def, "good")
