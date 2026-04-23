## Structured runtime checkpoint logger.
## Emits stable AUDIT lines parseable by tests/audit_run.sh and keeps a ring
## buffer of recent entries for the debug overlay. `pass` is a GDScript keyword,
## so the public methods are named `pass_check` / `fail_check`.
extends Node

signal checkpoint_passed(checkpoint: StringName, detail: String)
signal checkpoint_failed(checkpoint: StringName, reason: String)

const RING_CAPACITY: int = 256

var _ring: Array[Dictionary] = []
var _seen_pass: Dictionary = {}


func pass_check(checkpoint: StringName, detail: String = "") -> void:
	assert(checkpoint != &"", "AuditLog.pass_check: empty checkpoint")
	if _seen_pass.has(checkpoint):
		push_warning("AuditLog: duplicate PASS for checkpoint '%s'" % checkpoint)
	_seen_pass[checkpoint] = true
	var line: String = "AUDIT: PASS %s" % checkpoint
	if detail != "":
		line += " " + detail
	print(line)
	_record({
		"status": "PASS",
		"checkpoint": checkpoint,
		"detail": detail,
		"time_msec": Time.get_ticks_msec(),
	})
	checkpoint_passed.emit(checkpoint, detail)


func fail_check(checkpoint: StringName, reason: String) -> void:
	assert(checkpoint != &"", "AuditLog.fail_check: empty checkpoint")
	var line: String = "AUDIT: FAIL %s" % checkpoint
	if reason != "":
		line += " " + reason
	print(line)
	_record({
		"status": "FAIL",
		"checkpoint": checkpoint,
		"reason": reason,
		"time_msec": Time.get_ticks_msec(),
	})
	checkpoint_failed.emit(checkpoint, reason)


func recent(n: int) -> Array[Dictionary]:
	if n <= 0:
		return []
	var size: int = _ring.size()
	var start: int = max(0, size - n)
	var out: Array[Dictionary] = []
	for i in range(start, size):
		out.append(_ring[i])
	return out


func clear() -> void:
	_ring.clear()
	_seen_pass.clear()


func _record(entry: Dictionary) -> void:
	_ring.append(entry)
	if _ring.size() > RING_CAPACITY:
		_ring.remove_at(0)
