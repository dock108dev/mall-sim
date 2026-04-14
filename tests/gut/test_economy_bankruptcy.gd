## Tests EconomySystem bankruptcy detection and guard flag behavior.
extends GutTest


var _economy: EconomySystem
var _bankruptcy_count: int = 0


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(100.0)
	_bankruptcy_count = 0
	EventBus.bankruptcy_declared.connect(_on_bankruptcy_declared)


func after_each() -> void:
	if EventBus.bankruptcy_declared.is_connected(
		_on_bankruptcy_declared
	):
		EventBus.bankruptcy_declared.disconnect(
			_on_bankruptcy_declared
		)


func _on_bankruptcy_declared() -> void:
	_bankruptcy_count += 1


func test_force_deduct_to_zero_emits_bankruptcy() -> void:
	_economy.force_deduct_cash(100.0, "rent")
	assert_eq(
		_bankruptcy_count, 1,
		"Deduction to exactly zero should emit bankruptcy_declared"
	)


func test_force_deduct_to_negative_emits_bankruptcy() -> void:
	_economy.force_deduct_cash(150.0, "rent")
	assert_eq(
		_bankruptcy_count, 1,
		"Deduction to negative should emit bankruptcy_declared"
	)


func test_double_deduction_does_not_double_emit() -> void:
	_economy.force_deduct_cash(80.0, "rent")
	_economy.force_deduct_cash(80.0, "more rent")
	assert_eq(
		_bankruptcy_count, 1,
		"Guard flag should prevent re-emission"
	)


func test_deduct_above_zero_does_not_emit() -> void:
	_economy.force_deduct_cash(50.0, "partial rent")
	assert_eq(
		_bankruptcy_count, 0,
		"Deduction that leaves positive balance should not emit"
	)


func test_emergency_cash_resets_flag() -> void:
	_economy.force_deduct_cash(150.0, "rent")
	assert_eq(_bankruptcy_count, 1)
	_economy.add_cash(200.0, "emergency injection")
	EventBus.emergency_cash_injected.emit(200.0, "Easy mode")
	_economy.force_deduct_cash(200.0, "more rent")
	assert_eq(
		_bankruptcy_count, 2,
		"After emergency cash restores positive balance, "
		+ "bankruptcy should be re-emittable"
	)


func test_emergency_cash_no_reset_if_still_negative() -> void:
	_economy.force_deduct_cash(200.0, "rent")
	assert_eq(_bankruptcy_count, 1)
	_economy.add_cash(50.0, "small injection")
	EventBus.emergency_cash_injected.emit(50.0, "Easy mode")
	_economy.force_deduct_cash(10.0, "fee")
	assert_eq(
		_bankruptcy_count, 1,
		"Flag should not reset if balance is still negative"
	)


func test_initialize_resets_bankruptcy_flag() -> void:
	_economy.force_deduct_cash(150.0, "rent")
	assert_eq(_bankruptcy_count, 1)
	_economy.initialize(500.0)
	_economy.force_deduct_cash(600.0, "big rent")
	assert_eq(
		_bankruptcy_count, 2,
		"initialize() should reset flag allowing new emission"
	)


func test_load_save_data_resets_bankruptcy_flag() -> void:
	_economy.force_deduct_cash(150.0, "rent")
	assert_eq(_bankruptcy_count, 1)
	_economy.load_save_data({"current_cash": 500.0})
	_economy.force_deduct_cash(600.0, "rent")
	assert_eq(
		_bankruptcy_count, 2,
		"load_save_data() should reset flag allowing new emission"
	)
