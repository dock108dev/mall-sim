## Integration test: Easy mode emergency cash injection — cash floor trigger,
## EconomySystem balance update, signal emission, and cooldown enforcement.
extends GutTest


const BASE_DAILY_RENT: float = 50.0
const EASY_RENT_MULTIPLIER: float = 0.70
## 50.0 × 0.70
const EFFECTIVE_DAILY_RENT: float = BASE_DAILY_RENT * EASY_RENT_MULTIPLIER
## EFFECTIVE_DAILY_RENT × 2.0
const INJECTION_THRESHOLD: float = EFFECTIVE_DAILY_RENT * 2.0
## INJECTION_THRESHOLD × 3.0
const INJECTION_AMOUNT: float = INJECTION_THRESHOLD * 3.0
const CASH_BELOW_THRESHOLD: float = 60.0
const INJECTION_DAY: int = 1

var _economy: EconomySystem
var _injection_count: int = 0
var _last_injection_amount: float = 0.0
var _saved_tier: StringName


func before_each() -> void:
	_saved_tier = DifficultySystemSingleton.get_current_tier_id()
	DifficultySystemSingleton.set_tier(&"easy")
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(100.0)
	_injection_count = 0
	_last_injection_amount = 0.0
	EventBus.emergency_cash_injected.connect(_on_emergency_cash_injected)


func after_each() -> void:
	if EventBus.emergency_cash_injected.is_connected(
		_on_emergency_cash_injected
	):
		EventBus.emergency_cash_injected.disconnect(
			_on_emergency_cash_injected
		)
	DifficultySystemSingleton.set_tier(_saved_tier)


func _on_emergency_cash_injected(amount: float, _reason: String) -> void:
	_injection_count += 1
	_last_injection_amount = amount


func _set_economy_state(
	cash: float, rent: float, last_injection_day: int
) -> void:
	_economy.load_save_data({
		"current_cash": cash,
		"daily_rent": rent,
		"last_injection_day": last_injection_day,
	})


func test_injection_triggers_when_cash_below_threshold() -> void:
	_set_economy_state(CASH_BELOW_THRESHOLD, EFFECTIVE_DAILY_RENT, -1)
	EventBus.day_ended.emit(INJECTION_DAY)
	assert_eq(
		_injection_count, 1,
		"emergency_cash_injected should fire once when cash < threshold"
	)
	assert_almost_eq(
		_last_injection_amount, INJECTION_AMOUNT, 0.01,
		"Injected amount should equal threshold × 3.0 = %.2f" % INJECTION_AMOUNT
	)
	assert_almost_eq(
		_economy.get_cash(),
		CASH_BELOW_THRESHOLD + INJECTION_AMOUNT,
		0.01,
		"Cash should increase by injection amount"
	)


func test_injection_does_not_trigger_when_cash_above_threshold() -> void:
	_set_economy_state(INJECTION_THRESHOLD + 1.0, EFFECTIVE_DAILY_RENT, -1)
	EventBus.day_ended.emit(INJECTION_DAY)
	assert_eq(
		_injection_count, 0,
		"emergency_cash_injected should not fire when cash >= threshold"
	)


func test_cooldown_prevents_injection_within_7_days() -> void:
	_set_economy_state(CASH_BELOW_THRESHOLD, EFFECTIVE_DAILY_RENT, INJECTION_DAY)
	var cash_before: float = _economy.get_cash()
	EventBus.day_ended.emit(INJECTION_DAY + 6)
	assert_eq(
		_injection_count, 0,
		"Injection should not fire within 7-day cooldown window"
	)
	assert_almost_eq(
		_economy.get_cash(), cash_before, 0.01,
		"Cash should not increase during cooldown"
	)


func test_injection_fires_again_after_cooldown_expires() -> void:
	_set_economy_state(CASH_BELOW_THRESHOLD, EFFECTIVE_DAILY_RENT, INJECTION_DAY)
	EventBus.day_ended.emit(INJECTION_DAY + 7)
	assert_eq(
		_injection_count, 1,
		"Injection should fire once the 7-day cooldown has elapsed"
	)
	assert_almost_eq(
		_last_injection_amount, INJECTION_AMOUNT, 0.01,
		"Injected amount should equal threshold × 3.0 after cooldown"
	)
	assert_almost_eq(
		_economy.get_cash(),
		CASH_BELOW_THRESHOLD + INJECTION_AMOUNT,
		0.01,
		"Cash should increase by injection amount after cooldown expires"
	)


func test_normal_tier_never_triggers_injection() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var normal_economy: EconomySystem = EconomySystem.new()
	add_child_autofree(normal_economy)
	normal_economy.initialize(100.0)
	normal_economy.load_save_data({
		"current_cash": CASH_BELOW_THRESHOLD,
		"daily_rent": EFFECTIVE_DAILY_RENT,
		"last_injection_day": -1,
	})
	var cash_before: float = normal_economy.get_cash()
	EventBus.day_ended.emit(INJECTION_DAY)
	assert_eq(
		_injection_count, 0,
		"Normal tier should never emit emergency_cash_injected"
	)
	assert_almost_eq(
		normal_economy.get_cash(), cash_before, 0.01,
		"Normal tier cash should not change due to injection"
	)
