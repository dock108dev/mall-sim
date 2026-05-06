extends Node

signal input_mode_changed(new_mode: int)

const DAY1_EVENT_ID: StringName = &"day01_wrong_console_parent"
const INPUT_MODE_GAMEPLAY: int = 0
const INPUT_MODE_DECISION_CARD: int = 1
const INPUT_MODE_PAUSE_MENU: int = 2
const INPUT_MODE_DAY_SUMMARY: int = 3

var day: int = 1
var cash: int = 0
var reputation: int = 0
var manager_trust: int = 0
var hidden_thread_score: int = 0
var flags: Dictionary = {}
var completed_events: Array[StringName] = []
var daily_events_resolved: Array[StringName] = []
var hidden_thread_signals_seen: Array[StringName] = []
var input_mode: int = INPUT_MODE_GAMEPLAY


func reset_new_run() -> void:
	day = 1
	cash = 0
	reputation = 0
	manager_trust = 0
	hidden_thread_score = 0
	flags.clear()
	completed_events.clear()
	daily_events_resolved.clear()
	hidden_thread_signals_seen.clear()
	set_input_mode(INPUT_MODE_GAMEPLAY)


func set_input_mode(mode: int) -> void:
	if input_mode == mode:
		return
	input_mode = mode
	if mode == INPUT_MODE_GAMEPLAY:
		InputHelper.lock_cursor()
	else:
		InputHelper.unlock_cursor()
	input_mode_changed.emit(mode)


func apply_decision_effect(
	event_id: StringName,
	choice_id: StringName,
	effects: Dictionary
) -> void:
	cash += int(effects.get("cash", 0))
	reputation += int(effects.get("reputation", 0))
	manager_trust += int(effects.get("manager_trust", 0))
	hidden_thread_score += int(effects.get("hidden_thread_score", 0))
	if effects.has("flags") and effects["flags"] is Dictionary:
		for key: Variant in (effects["flags"] as Dictionary):
			flags[StringName(String(key))] = bool(effects["flags"][key])
	if not completed_events.has(event_id):
		completed_events.append(event_id)
	if not daily_events_resolved.has(event_id):
		daily_events_resolved.append(event_id)
	flags[StringName("choice_%s" % choice_id)] = true


func mark_hidden_thread_signal(signal_id: StringName) -> void:
	if hidden_thread_signals_seen.has(signal_id):
		return
	hidden_thread_signals_seen.append(signal_id)
	hidden_thread_score += 1


func is_day1_completed() -> bool:
	return completed_events.has(DAY1_EVENT_ID)


func end_day() -> Dictionary:
	return {
		"day": day,
		"cash": cash,
		"reputation": reputation,
		"manager_trust": manager_trust,
		"hidden_thread_score": hidden_thread_score,
		"day1_event_completed": is_day1_completed(),
		"hidden_thread_note": _hidden_thread_note(),
	}


func advance_day() -> void:
	day += 1
	daily_events_resolved.clear()
	set_input_mode(INPUT_MODE_GAMEPLAY)


func _hidden_thread_note() -> String:
	if hidden_thread_signals_seen.is_empty():
		return "No suspicious clues noticed."
	return "You noticed something off in the store."
