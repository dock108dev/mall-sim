## Manages the 30-day game arc: phase classification, unlock triggers, win/loss.
##
## Arc phases (from arc_unlocks.json):
##   slow_open    days  1–7
##   main_stretch days  8–21
##   crunch       days 22–30
##
## Unlock thresholds (arc_unlocks.json) fire arc_unlock_triggered exactly once
## per run when the matching day is first reached.
##
## Win: day 30 reached with cash >= win_condition.min_cash.
## Loss: end-of-day cash < 0 (checked every day).
## game_ended fires at most once; call evaluate_day_end() from DayCycleController.
class_name DayManager
extends Node

const ARC_UNLOCKS_PATH := "res://game/content/progression/arc_unlocks.json"

var _economy_system: EconomySystem = null
var _ending_evaluator: EndingEvaluatorSystem = null
var _arc_phases: Array = []
var _arc_unlocks: Array = []
var _win_condition: Dictionary = {}
var _fired_unlocks: Dictionary = {}
var _game_ended_emitted: bool = false


func initialize(
	economy_system: EconomySystem,
	ending_evaluator: EndingEvaluatorSystem = null,
) -> void:
	_economy_system = economy_system
	_ending_evaluator = ending_evaluator
	_load_arc_config()
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.first_sale_completed.is_connected(_on_first_sale_completed):
		EventBus.first_sale_completed.connect(_on_first_sale_completed)


## Returns the arc phase label for the current day.
func current_arc_phase() -> String:
	return _phase_for_day(GameManager.get_current_day())


## Called by DayCycleController after wages and milestone evaluation.
## Emits game_ended(outcome, stats) when win or loss conditions are met.
func evaluate_day_end(day: int, current_cash: float) -> void:
	if _game_ended_emitted:
		return
	if current_cash < 0.0:
		_emit_game_ended("loss", day, current_cash)
		return
	var target_day: int = int(_win_condition.get("target_day", 30))
	var min_cash: float = float(_win_condition.get("min_cash", 5000.0))
	if day >= target_day and current_cash >= min_cash:
		_emit_game_ended("win", day, current_cash)


func get_save_data() -> Dictionary:
	return {"fired_unlocks": _fired_unlocks.duplicate()}


func load_save_data(data: Dictionary) -> void:
	var fired: Variant = data.get("fired_unlocks", {})
	if fired is Dictionary:
		_fired_unlocks = (fired as Dictionary).duplicate()
	_game_ended_emitted = false


# ── Internal ──────────────────────────────────────────────────────────────────

func _phase_for_day(day: int) -> String:
	for phase: Variant in _arc_phases:
		if not (phase is Dictionary):
			continue
		var p: Dictionary = phase as Dictionary
		if day >= int(p.get("day_start", 1)) and day <= int(p.get("day_end", 30)):
			return str(p.get("id", "main_stretch"))
	return "crunch"


func _load_arc_config() -> void:
	var data: Variant = DataLoader.load_json(ARC_UNLOCKS_PATH)
	if not (data is Dictionary):
		push_error(
			"DayManager: failed to load %s as Dictionary" % ARC_UNLOCKS_PATH
		)
		return
	var d: Dictionary = data as Dictionary
	_arc_phases = d.get("arc_phases", []) as Array
	_arc_unlocks = d.get("arc_unlocks", []) as Array
	_win_condition = d.get("win_condition", {"target_day": 30, "min_cash": 5000.0}) as Dictionary


func _on_day_started(day: int) -> void:
	_check_arc_unlocks(day)
	if day == 1:
		_seed_day_one_inventory()


## Day 1 safety net for backroom inventory. The deterministic bootstrap path
## (`GameWorld.bootstrap_new_game_state` → `DataLoader.create_starting_inventory`)
## seeds before this fires, so `seed_starting_items` typically no-ops on top-up.
## When `active_store_id` is still empty (Day 1 fires before `set_active_store`
## runs in the hub-mode async crossfade), fall back to the first owned store so
## the safety net targets the right inventory rather than skipping silently.
func _seed_day_one_inventory() -> void:
	var inv: InventorySystem = GameManager.get_inventory_system()
	if not inv:
		return
	var store_id: StringName = GameManager.get_active_store_id()
	if store_id.is_empty():
		store_id = GameManager.current_store_id
	if store_id.is_empty():
		var owned: Array[StringName] = GameManager.get_owned_store_ids()
		if not owned.is_empty():
			store_id = owned[0]
	if store_id.is_empty():
		push_warning("DayManager: no active store — skipping Day 1 inventory seed")
		return
	inv.seed_starting_items(store_id, 7)


func _on_first_sale_completed(
	_store_id: StringName, _item_id: String, _price: float
) -> void:
	if GameManager.get_current_day() == 1:
		GameState.set_flag(&"first_sale_complete", true)


func _check_arc_unlocks(day: int) -> void:
	for unlock: Variant in _arc_unlocks:
		if not (unlock is Dictionary):
			continue
		var u: Dictionary = unlock as Dictionary
		var uid: String = str(u.get("unlock_id", ""))
		var threshold: int = int(u.get("day", 0))
		if uid.is_empty() or threshold <= 0:
			continue
		if day >= threshold and not _fired_unlocks.get(uid, false):
			_fired_unlocks[uid] = true
			EventBus.arc_unlock_triggered.emit(uid, day)


func _emit_game_ended(outcome: String, day: int, final_cash: float) -> void:
	_game_ended_emitted = true
	var endings_unlocked: Array = []
	if _ending_evaluator:
		var rid: StringName = _ending_evaluator.get_resolved_ending_id()
		if not rid.is_empty():
			endings_unlocked.append(String(rid))
	var stats: Dictionary = {
		"outcome": outcome,
		"final_cash": final_cash,
		"days_survived": day,
		"items_sold_per_store": {},
		"endings_unlocked": endings_unlocked,
	}
	EventBus.game_ended.emit(outcome, stats)
