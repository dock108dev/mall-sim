## Tests Easy-mode emergency cash injection behavior in EconomySystem.
extends GutTest


var _economy: EconomySystem
var _injections: Array[Dictionary] = []


func before_each() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_injections = []
	if EventBus.emergency_cash_injected.is_connected(_on_injected):
		EventBus.emergency_cash_injected.disconnect(_on_injected)
	EventBus.emergency_cash_injected.connect(_on_injected)


func after_each() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	if EventBus.emergency_cash_injected.is_connected(_on_injected):
		EventBus.emergency_cash_injected.disconnect(_on_injected)


func _on_injected(amount: float, reason: String) -> void:
	_injections.append({"amount": amount, "reason": reason})


## Helper: set up easy mode with cash below the injection threshold.
func _setup_easy_below_threshold(
	rent: float, starting_cash: float
) -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	# On easy, initialize multiplies cash by 1.5 — pass raw amount so final
	# cash equals starting_cash.
	_economy.initialize(starting_cash / 1.5)
	_economy.set_daily_rent(rent)


# ── Trigger conditions ────────────────────────────────────────────────────────

func test_injection_fires_on_easy_when_cash_below_threshold() -> void:
	# daily_rent = 100 → threshold = 200; start cash = 150 < 200 → inject
	_setup_easy_below_threshold(100.0, 150.0)
	_economy._check_emergency_injection(1)
	assert_eq(_injections.size(), 1, "Injection should fire once")


func test_injection_amount_equals_threshold_times_three() -> void:
	_setup_easy_below_threshold(100.0, 150.0)
	var before: float = _economy.get_cash()
	_economy._check_emergency_injection(1)
	var expected_amount: float = 100.0 * 2.0 * 3.0  # threshold * 3
	assert_almost_eq(
		_economy.get_cash() - before,
		expected_amount,
		0.01,
		"Injected amount should be daily_rent × 2 × 3"
	)
	assert_almost_eq(
		_injections[0]["amount"],
		expected_amount,
		0.01,
		"Signal amount should match injection amount"
	)


func test_injection_does_not_fire_when_cash_at_threshold() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	_economy.initialize(200.0 / 1.5)  # exactly at threshold after mult
	_economy.set_daily_rent(100.0)
	_economy._check_emergency_injection(1)
	assert_eq(_injections.size(), 0, "No injection when cash equals threshold")


func test_injection_does_not_fire_on_normal() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	_economy.initialize(10.0)
	_economy.set_daily_rent(100.0)
	_economy._check_emergency_injection(1)
	assert_eq(_injections.size(), 0, "Injection must not fire on Normal")


func test_injection_does_not_fire_on_hard() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_economy.initialize(10.0)
	_economy.set_daily_rent(100.0)
	_economy._check_emergency_injection(1)
	assert_eq(_injections.size(), 0, "Injection must not fire on Hard")


# ── 7-day cooldown ────────────────────────────────────────────────────────────

func test_second_injection_blocked_within_7_days() -> void:
	_setup_easy_below_threshold(100.0, 50.0)
	_economy._check_emergency_injection(1)
	assert_eq(_injections.size(), 1)
	# Force cash below threshold again by draining it.
	_economy.force_deduct_cash(_economy.get_cash() - 50.0, "drain")
	_economy._check_emergency_injection(7)  # day 7 — only 6 days elapsed
	assert_eq(_injections.size(), 1, "Cooldown not expired at 6 days elapsed")


func test_injection_allowed_after_7_days() -> void:
	_setup_easy_below_threshold(100.0, 50.0)
	_economy._check_emergency_injection(1)
	assert_eq(_injections.size(), 1)
	_economy.force_deduct_cash(_economy.get_cash() - 50.0, "drain")
	_economy._check_emergency_injection(8)  # day 8 — 7 days elapsed
	assert_eq(_injections.size(), 2, "Injection should fire after 7 days")


func test_injection_fires_on_first_day_without_prior_history() -> void:
	_setup_easy_below_threshold(100.0, 50.0)
	_economy._check_emergency_injection(1)
	assert_eq(_injections.size(), 1, "Should fire on day 1 with no history")


# ── Signal integrity ──────────────────────────────────────────────────────────

func test_signal_emitted_with_reason_string() -> void:
	_setup_easy_below_threshold(100.0, 50.0)
	_economy._check_emergency_injection(1)
	assert_eq(_injections.size(), 1)
	assert_false(
		_injections[0]["reason"].is_empty(),
		"Reason string must not be empty"
	)


# ── Save / load ───────────────────────────────────────────────────────────────

func test_last_injection_day_persisted_in_save_data() -> void:
	_setup_easy_below_threshold(100.0, 50.0)
	_economy._check_emergency_injection(5)
	var saved: Dictionary = _economy.get_save_data()
	assert_eq(
		saved.get("last_injection_day", -99),
		5,
		"last_injection_day must be serialized"
	)


func test_last_injection_day_restored_from_save_data() -> void:
	_setup_easy_below_threshold(100.0, 50.0)
	_economy.load_save_data({"current_cash": 50.0, "last_injection_day": 5})
	# Day 11 → 6 days elapsed → still blocked
	_economy._check_emergency_injection(11)
	assert_eq(_injections.size(), 0, "Cooldown should be restored from save")
	# Day 12 → 7 days elapsed → allowed
	_economy._check_emergency_injection(12)
	assert_eq(_injections.size(), 1, "Injection should fire after restored cooldown expires")


func test_load_save_data_without_injection_day_defaults_to_never() -> void:
	_setup_easy_below_threshold(100.0, 50.0)
	_economy.load_save_data({"current_cash": 50.0})
	_economy._check_emergency_injection(1)
	assert_eq(
		_injections.size(), 1,
		"Missing last_injection_day should default to never-injected"
	)
