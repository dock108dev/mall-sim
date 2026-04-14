## Tests that every EventBus.signal.connect/emit call in the codebase references a declared signal.
extends GutTest


const GAME_SCRIPTS_DIR: String = "res://game/"
const TEST_SCRIPTS_DIR: String = "res://tests/"

var _declared_signals: Array[String] = []


func before_all() -> void:
	_declared_signals = _get_declared_signal_names()


func test_eventbus_has_declared_signals() -> void:
	assert_gt(
		_declared_signals.size(), 0,
		"EventBus should declare at least one signal"
	)


func test_all_declared_signals_exist_on_eventbus() -> void:
	for sig_name: String in _declared_signals:
		assert_true(
			EventBus.has_signal(sig_name),
			"EventBus should have signal '%s'" % sig_name
		)


func test_reputation_changed_signature() -> void:
	var info: Array[Dictionary] = EventBus.get_signal_list()
	for sig: Dictionary in info:
		if sig["name"] != "reputation_changed":
			continue
		var args: Array = sig["args"]
		assert_eq(args.size(), 2, "reputation_changed should have 2 params")
		assert_eq(
			args[0]["name"], "store_id",
			"First param should be store_id"
		)
		assert_eq(
			args[1]["name"], "new_score",
			"Second param should be new_score"
		)
		return
	fail_test("reputation_changed signal not found in EventBus")


func test_checkout_started_signature() -> void:
	var info: Array[Dictionary] = EventBus.get_signal_list()
	for sig: Dictionary in info:
		if sig["name"] != "checkout_started":
			continue
		var args: Array = sig["args"]
		assert_eq(args.size(), 2, "checkout_started should have 2 params")
		return
	fail_test("checkout_started signal not found in EventBus")


func test_money_changed_signature() -> void:
	var info: Array[Dictionary] = EventBus.get_signal_list()
	for sig: Dictionary in info:
		if sig["name"] != "money_changed":
			continue
		var args: Array = sig["args"]
		assert_eq(args.size(), 2, "money_changed should have 2 params")
		assert_eq(
			args[0]["name"], "old_amount",
			"First param should be old_amount"
		)
		assert_eq(
			args[1]["name"], "new_amount",
			"Second param should be new_amount"
		)
		return
	fail_test("money_changed signal not found in EventBus")


func test_transaction_completed_signature() -> void:
	var info: Array[Dictionary] = EventBus.get_signal_list()
	for sig: Dictionary in info:
		if sig["name"] != "transaction_completed":
			continue
		var args: Array = sig["args"]
		assert_eq(
			args.size(), 3,
			"transaction_completed should have 3 params"
		)
		return
	fail_test("transaction_completed signal not found in EventBus")


func test_inventory_updated_has_store_id_param() -> void:
	var info: Array[Dictionary] = EventBus.get_signal_list()
	for sig: Dictionary in info:
		if sig["name"] != "inventory_updated":
			continue
		var args: Array = sig["args"]
		assert_eq(
			args.size(), 1,
			"inventory_updated should have 1 param (store_id)"
		)
		assert_eq(
			args[0]["name"], "store_id",
			"Param should be store_id"
		)
		return
	fail_test("inventory_updated signal not found in EventBus")


func _get_declared_signal_names() -> Array[String]:
	var names: Array[String] = []
	var info: Array[Dictionary] = EventBus.get_signal_list()
	for sig: Dictionary in info:
		var sig_name: String = sig["name"]
		if sig_name.begins_with("script_") or sig_name.begins_with("property_"):
			continue
		names.append(sig_name)
	return names
