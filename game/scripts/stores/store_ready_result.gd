## Result of a StoreReadyContract.check(...) call.
##
## Binary outcome, fail-hard: `ok == true` iff every invariant passed.
## `failures` lists the StringName of *every* invariant that failed (not just
## the first), so the caller can surface a complete diagnostic instead of
## re-checking after fixing one cause at a time. `reason` is a human-readable
## summary suitable for an on-screen failure banner.
class_name StoreReadyResult
extends RefCounted

var ok: bool = false
var failures: Array[StringName] = []
var reason: String = ""


func _init(p_ok: bool = false, p_failures: Array[StringName] = [], p_reason: String = "") -> void:
	ok = p_ok
	failures = p_failures.duplicate()
	reason = p_reason


## First failing invariant name, or &"" if ok. Used by FailCard (ISSUE-018) to
## headline one invariant; `failures` still carries the full list.
func failed_invariant() -> StringName:
	if failures.is_empty():
		return &""
	return failures[0]
