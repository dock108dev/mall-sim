## Debug autoload for headless interaction audit. Stripped to no-op in release builds.
## Connects to EventBus signals to auto-instrument the five required checkpoints.
extends Node

const CHECKPOINTS: Array[StringName] = [
	&"boot_complete",
	&"store_entered",
	&"refurb_completed",
	&"transaction_completed",
	&"day_closed",
]

var _results: Dictionary = {}


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	for key: StringName in CHECKPOINTS:
		_results[key] = null  # null = pending, true = pass, false = fail
	_wire_signals()


func _wire_signals() -> void:
	EventBus.boot_completed.connect(func(): pass_check(&"boot_complete"))
	EventBus.store_entered.connect(func(_sid: StringName): pass_check(&"store_entered"))
	EventBus.refurbishment_completed.connect(
		func(_iid: String, _ok: bool, _nc: String): pass_check(&"refurb_completed")
	)
	EventBus.transaction_completed.connect(
		func(_amt: float, _ok: bool, _msg: String): pass_check(&"transaction_completed")
	)
	EventBus.day_closed.connect(func(_day: int, _sum: Dictionary): pass_check(&"day_closed"))


func pass_check(key: StringName) -> void:
	if _results.get(key) == true:
		return  # already passed; don't double-log
	_results[key] = true
	_log_result(key, true)


func fail_check(key: StringName, reason: String = "") -> void:
	_results[key] = false
	_log_result(key, false, reason)


func _log_result(key: StringName, passed: bool, reason: String = "") -> void:
	var status := "PASS" if passed else "FAIL"
	var msg := "[AUDIT] %s: %s" % [key, status]
	if reason:
		msg += " (%s)" % reason
	print(msg)


func all_passed() -> bool:
	for key: StringName in CHECKPOINTS:
		if _results.get(key) != true:
			return false
	return true


func get_results() -> Dictionary:
	return _results.duplicate()
