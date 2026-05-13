extends Node

signal input_mode_changed(new_mode: int)

const INPUT_MODE_GAMEPLAY: int = 0
const INPUT_MODE_DECISION_CARD: int = 1
const INPUT_MODE_PAUSE_MENU: int = 2
const INPUT_MODE_DAY_SUMMARY: int = 3
## Fixed daily rent for the beta loop. Surfaced on the day-summary panel
## under the Money section so the player sees today's sales offset by the
## day's operating cost. Constant for the beta — a future tuning pass can
## convert this into a per-day value loaded from `day_NN.json` without
## changing the panel-side contract.
const DAILY_RENT: int = 50

var day: int = 1
var cash: int = 0
var reputation: int = 0
## Per-day reputation delta accumulated by `apply_decision_effect`. Reset on
## `advance_day` / `reset_new_run`. Read by `end_day()` so the day-summary
## panel can render a single 'Reputation: +N / -N' line that reflects what
## happened *today*, not the cumulative run total.
var daily_reputation_delta: int = 0
## Per-day cash delta accumulated by `apply_decision_effect`. Reset on
## `advance_day` / `reset_new_run`. Read by `end_day()` so the day-summary
## panel can render Starting Cash / Sales Today / Ending Cash from a
## single source of truth without storing a separate starting-cash field.
var daily_cash_delta: int = 0
var manager_trust: int = 0
var hidden_thread_score: int = 0
var flags: Dictionary = {}
var completed_events: Array[StringName] = []
var daily_events_resolved: Array[StringName] = []
var hidden_thread_signals_seen: Array[StringName] = []
var input_mode: int = INPUT_MODE_GAMEPLAY
## True while the player is holding a stock box from the back room and has
## not yet placed it on the used games shelf. Read by ObjectiveRail to
## suppress the right-side action/hint chip when the player is carrying
## but not aimed at the restock shelf — preventing the prompt from
## appearing over unrelated nodes during navigation to the shelf.
var carrying_stock: bool = false


func reset_new_run() -> void:
	day = 1
	cash = 0
	reputation = 0
	daily_reputation_delta = 0
	daily_cash_delta = 0
	manager_trust = 0
	hidden_thread_score = 0
	flags.clear()
	completed_events.clear()
	daily_events_resolved.clear()
	hidden_thread_signals_seen.clear()
	carrying_stock = false
	set_input_mode(INPUT_MODE_GAMEPLAY)


## Bookkeeping label for the active modal phase. Cursor and gameplay-input
## gating are owned by `InputFocus` (push/pop via `ModalPanel.open()`/`close()`)
## so this method neither locks the cursor nor pushes context — it just records
## the label for the debug overlay and emits the change signal. The equality
## guard prevents redundant emissions when callers re-set the same mode.
func set_input_mode(mode: int) -> void:
	if input_mode == mode:
		return
	input_mode = mode
	input_mode_changed.emit(mode)


func apply_decision_effect(
	event_id: StringName,
	choice_id: StringName,
	effects: Dictionary
) -> void:
	var cash_delta: int = int(effects.get("cash", 0))
	cash += cash_delta
	daily_cash_delta += cash_delta
	# Mirror the cash delta into EconomySystem so the HUD's existing
	# get_cash() pipeline stays the single visible source of truth.
	# `economy == null` is a documented test seam (§EH-10 pattern):
	# `test_beta_run_state_cash_delta.gd` calls this directly on the
	# autoload without a GameWorld in the tree, so EconomySystem isn't
	# initialized. Production beta path always runs after Tier-1 init.
	# See §EH-25.
	if cash_delta != 0:
		var economy: EconomySystem = GameManager.get_economy_system()
		if economy != null:
			var reason: String = "Day %d: %s" % [day, choice_id]
			if cash_delta > 0:
				economy.add_cash(float(cash_delta), reason)
			else:
				economy.charge(float(-cash_delta), reason)
	var reputation_delta: int = int(effects.get("reputation", 0))
	reputation += reputation_delta
	daily_reputation_delta += reputation_delta
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


func end_day() -> Dictionary:
	return {
		"day": day,
		"cash": cash,
		"cash_delta": daily_cash_delta,
		"starting_cash": cash - daily_cash_delta,
		"reputation": reputation,
		"reputation_delta": daily_reputation_delta,
		"manager_trust": manager_trust,
		"hidden_thread_score": hidden_thread_score,
		"hidden_thread_note": _hidden_thread_note(),
	}


func advance_day() -> void:
	day += 1
	daily_events_resolved.clear()
	daily_reputation_delta = 0
	daily_cash_delta = 0
	set_input_mode(INPUT_MODE_GAMEPLAY)


func _hidden_thread_note() -> String:
	if hidden_thread_signals_seen.is_empty():
		return "No suspicious clues noticed."
	return "You noticed something off in the store."
