## Routes gameplay signals to EventBus.objective_changed with a three-slot payload.
## All text is sourced from objectives.json — zero hardcoded strings. Tutorial
## step text is rendered by `TutorialOverlay` (reading localization CSV via
## `tr()`), not by this director — the two-source overlap was removed per
## docs/audits/phase0-ui-integrity.md P1.3.
## Tracks the first full stock→sell→close loop to trigger auto-hide after day 3.
##
## Day 1 supports an optional `steps` array on the Day 1 entry. When present,
## the director walks the player through the chain in order, advancing on the
## matching gameplay signal for each step. Other days fall back to the legacy
## pre-sale / post-sale text swap.
extends Node

const CONTENT_PATH := "res://game/content/objectives.json"

## Day 1 step indices (must align with the order of `steps` in objectives.json).
const DAY1_STEP_TALK_TO_CUSTOMER: int = 0
const DAY1_STEP_BACK_ROOM_INVENTORY: int = 1
const DAY1_STEP_STOCK_SHELF: int = 2
const DAY1_STEP_CLOSE_DAY: int = 3
const DAY1_STEP_COUNT: int = 4

var _day_objectives: Dictionary = {}
var _defaults: Dictionary = {}

var _current_day: int = 0
var _stocked: bool = false
var _sold: bool = false
var _loop_completed: bool = false
## True after the player has completed one stock→sell loop on the active day.
## Reset on `day_started`; flips to true the moment both `_stocked` and `_sold`
## are set (typically inside `_on_item_sold` after a stocked shelf has sold).
## Drives the close-day confirmation gate via `can_close_day()` so the player
## is prompted to confirm before closing a day with no completed loop.
var _loop_completed_today: bool = false
## Active Day 1 step index, or -1 when the chain is not running. Set to 0 by
## day_started(1); incremented in lockstep with the chain's gameplay signals.
var _day1_step_index: int = -1
## True between day_started(1) and the first manager_note_dismissed of Day 1.
## While true the rail surfaces the pre-chain `pre_step` payload and the step
## chain itself is not yet armed (`_day1_step_index` stays -1).
var _waiting_for_note_dismiss: bool = false
## Hash of the most recently emitted payload (`textactionkeyhint`,
## or a fixed marker for the hidden auto-hide payload). `_emit_current()`
## returns early when the next computed payload hashes to the same value, so
## re-entering a scene or re-connecting a listener does not re-trigger the
## rail's 1-second flash tween for an unchanged objective. Reset to "" on
## every `day_started` so the first emit of a new day always fires.
var _last_payload_hash: String = ""
const _HIDDEN_PAYLOAD_HASH: String = "__hidden__"


func _ready() -> void:
	_load_content()
	EventBus.day_started.connect(_on_day_started)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.item_stocked.connect(_on_item_stocked)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.day_closed.connect(_on_day_closed)
	EventBus.preference_changed.connect(_on_preference_changed)
	EventBus.customer_interacted.connect(_on_customer_interacted)
	EventBus.placement_mode_entered.connect(_on_placement_mode_entered)
	EventBus.manager_note_dismissed.connect(_on_manager_note_dismissed)


func _load_content() -> void:
	var data: Variant = DataLoader.load_json(CONTENT_PATH)
	if not (data is Dictionary):
		push_error("ObjectiveDirector: failed to load %s as Dictionary" % CONTENT_PATH)
		return
	var d := data as Dictionary
	_defaults = {
		"text": str(d.get("default_text", "")),
		"action": str(d.get("default_action", "")),
		"key": str(d.get("default_key", "")),
	}
	for entry: Variant in d.get("objectives", []):
		if not (entry is Dictionary):
			continue
		var e := entry as Dictionary
		if not e.has("day"):
			continue
		var day_int: int = int(e["day"])
		var steps_raw: Variant = e.get("steps", [])
		var steps_typed: Array = []
		if steps_raw is Array:
			var steps_array: Array = steps_raw as Array
			for step_entry: Variant in steps_array:
				if step_entry is Dictionary:
					steps_typed.append(step_entry)
				else:
					# §F-93 / error-handling-report.md §1 — escalated from
					# push_warning to push_error: a non-Dictionary entry in
					# the Day-1 `steps` array is a content-authoring regression
					# on the critical tutorial path. The CI gut-tests job
					# scans stderr for push_error so the regression fails the
					# build instead of being a silent run-time degradation.
					push_error(
						(
							"ObjectiveDirector: day %d has non-Dictionary "
							+ "step entry (%s); skipped."
						)
						% [day_int, type_string(typeof(step_entry))]
					)
		elif e.has("steps"):
			# §F-93 / error-handling-report.md §1 — `steps` present but not
			# an Array is the same Day-1 critical-path regression as above.
			push_error(
				(
					"ObjectiveDirector: day %d has non-Array `steps` field "
					+ "(%s); ignored."
				)
				% [day_int, type_string(typeof(steps_raw))]
			)
		# §F-93 / error-handling-report.md §1 — Day 1 expects a steps array
		# of exactly DAY1_STEP_COUNT entries. A short / over-long chain
		# silently disables the tutorial; escalated to push_error so CI
		# fails on the regression instead of shipping a broken Day-1 rail.
		if day_int == 1 and steps_typed.size() != DAY1_STEP_COUNT:
			push_error(
				(
					"ObjectiveDirector: day 1 `steps` count is %d; "
					+ "expected %d. Day-1 step chain will be disabled "
					+ "and the rail will fall back to pre-sale / "
					+ "post-sale text."
				)
				% [steps_typed.size(), DAY1_STEP_COUNT]
			)
		var pre_step_raw: Variant = e.get("pre_step", {})
		var pre_step_dict: Dictionary = {}
		if pre_step_raw is Dictionary:
			pre_step_dict = pre_step_raw as Dictionary
		elif e.has("pre_step"):
			# §F-148 / error-handling-report.md §1 — `pre_step` is documented
			# as optional, so an absent key is fine. But if present and not
			# a Dictionary, Day 1 renders a blank rail between day_started
			# and the first manager_note_dismissed. Escalated to push_error
			# so CI catches the bad content payload at load time.
			push_error(
				(
					"ObjectiveDirector: day %d has non-Dictionary `pre_step` "
					+ "field (%s); ignored."
				)
				% [day_int, type_string(typeof(pre_step_raw))]
			)
		_day_objectives[day_int] = {
			"text": str(e.get("text", _defaults["text"])),
			"action": str(e.get("action", _defaults["action"])),
			"key": str(e.get("key", _defaults["key"])),
			"post_sale_text": str(e.get("post_sale_text", "")),
			"post_sale_action": str(e.get("post_sale_action", "")),
			"post_sale_key": str(e.get("post_sale_key", "")),
			"steps": steps_typed,
			"pre_step": pre_step_dict,
		}


func _on_day_started(day: int) -> void:
	_current_day = day
	_stocked = false
	_sold = false
	_loop_completed_today = false
	_day1_step_index = -1
	_waiting_for_note_dismiss = false
	# Reset so the first emit of a new day always fires, even when the day's
	# objective text matches the previous day's. Without this, a save+reload
	# into a day whose copy matches the last seen hash would be silently
	# deduped and the rail would never refresh.
	_last_payload_hash = ""
	if day == 1:
		# The chain-complete sentinel survives across days so the rail can
		# auto-hide once the player has finished a full loop. A fresh Day 1
		# is the only signal we have that the player has restarted the run
		# (`begin_new_run()` → scene swap → day_started(1)); without this
		# reset the auto-hide flag would persist into the replay and
		# trigger after Day 3 with the player's previous-run completion.
		_loop_completed = false
	if day == 1 and _day1_steps_available():
		# The Day 1 step chain is held until the player dismisses Vic's
		# morning note. _on_manager_note_dismissed advances _day1_step_index
		# to TALK_TO_CUSTOMER when the note clears.
		_waiting_for_note_dismiss = true
	_emit_current()


func _on_manager_note_dismissed(_note_id: String) -> void:
	if _current_day != 1 or not _waiting_for_note_dismiss:
		return
	_waiting_for_note_dismiss = false
	if _day1_steps_available():
		_day1_step_index = DAY1_STEP_TALK_TO_CUSTOMER
	_emit_current()


func _on_store_entered(_store_id: StringName) -> void:
	_emit_current()


func _on_item_stocked(_item_id: String, _shelf_id: String) -> void:
	_stocked = true
	if _sold:
		_loop_completed_today = true
	_advance_day1_step_if(DAY1_STEP_STOCK_SHELF)
	_emit_current()


func _on_item_sold(item_id: String, price: float, _category: String) -> void:
	if not _sold:
		_sold = true
		# §F-55 — set the flag before emitting so listeners that read
		# `GameState.get_flag(&"first_sale_complete")` from inside the
		# `first_sale_completed` handler see the already-true value.
		GameState.set_flag(&"first_sale_complete", true)
		EventBus.first_sale_completed.emit(&"", item_id, price)
	if _stocked:
		_loop_completed_today = true
	_emit_current()


func _on_day_closed(_day: int, _summary: Dictionary) -> void:
	if _stocked and _sold:
		_loop_completed = true
		_loop_completed_today = true


## Returns true when the player may close the current day without confirmation.
## Used by `DayCycleController` to gate the player-initiated close path. The
## clock-triggered close path in `DayCycleController._on_day_ended` does NOT
## consult this method — the day clock always closes regardless of loop state.
##
## Fail-open in non-gameplay states (DAY_SUMMARY, MALL_OVERVIEW, BUILD, …) and
## when no day has started (`_current_day <= 0`). Production gameplay reaches
## the `_loop_completed_today` branch only after a real `day_started` while
## the GameManager FSM sits in GAMEPLAY / STORE_VIEW.
func can_close_day() -> bool:
	if _current_day <= 0:
		return true
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return true
	var state: int = int(gm.current_state)
	if (
		state != int(GameManager.State.GAMEPLAY)
		and state != int(GameManager.State.STORE_VIEW)
		and state != int(GameManager.State.MALL_OVERVIEW)
	):
		return true
	return _loop_completed_today


## Returns the human-readable copy that explains why the loop is incomplete.
## Distinguishes "shelves empty" (player hasn't stocked yet) from "no sale yet"
## (shelves are stocked but no customer has purchased) so the confirmation
## modal can give actionable advice. Returns an empty string when the loop is
## already complete (caller should not need the copy in that case).
func get_close_blocked_reason() -> String:
	if _loop_completed_today:
		return ""
	if not _stocked:
		return "The shelves are empty — stock some items before closing."
	return "You haven't made a sale yet. Close the day anyway?"


func _on_preference_changed(key: String, _value: Variant) -> void:
	if key == "show_objective_rail":
		_emit_current()


func _on_customer_interacted(_customer: Node) -> void:
	_advance_day1_step_if(DAY1_STEP_TALK_TO_CUSTOMER)


func _on_placement_mode_entered() -> void:
	_advance_day1_step_if(DAY1_STEP_BACK_ROOM_INVENTORY)


## Advances the Day 1 chain when the player is sitting on `expected_step`.
## Out-of-order signals (a duplicate trigger, a customer arriving before the
## player has stocked, etc.) are no-ops by design.
## §F-98 — The two silent returns are state-machine race-guards. Wrong-day /
## wrong-step is the documented out-of-order contract above; the
## `_day1_steps_available()` false-arm is a downstream consequence of the
## §F-93 content-authoring warning that already fired at load time, so adding
## a per-emit warning here would only echo the load-time diagnostic on every
## signal received.
func _advance_day1_step_if(expected_step: int) -> void:
	if _current_day != 1 or _day1_step_index != expected_step:
		return
	if not _day1_steps_available():
		return
	_day1_step_index = expected_step + 1
	_emit_current()


func _day1_steps_available() -> bool:
	var entry: Dictionary = _day_objectives.get(1, {})
	var steps_variant: Variant = entry.get("steps", [])
	if not (steps_variant is Array):
		return false
	return (steps_variant as Array).size() == DAY1_STEP_COUNT


## Builds and emits the current payload from the day objective for the active
## day. Sends {hidden: true} when the auto-hide condition is met. Tutorial
## text is owned by `TutorialOverlay` and does not flow through this payload.
##
## Beta deferral: when the active scene contains a node in the
## "beta_day_one_controller" group, that controller is the authority for
## objective text and gating. ObjectiveDirector skips emission so the rail
## doesn't ping-pong between two sources.
func _emit_current() -> void:
	if _beta_controller_active():
		return
	var should_auto_hide: bool = _loop_completed and _current_day > 3
	if should_auto_hide and not Settings.show_objective_rail:
		# Dedup the hidden auto-hide payload too — a `preference_changed`
		# tick that keeps `show_objective_rail` false should not re-emit the
		# hidden dictionary and force a tween/visibility recalc in the rail.
		if _last_payload_hash == _HIDDEN_PAYLOAD_HASH:
			return
		_last_payload_hash = _HIDDEN_PAYLOAD_HASH
		var hidden: Dictionary = {"hidden": true}
		EventBus.objective_changed.emit(hidden)
		EventBus.objective_updated.emit(hidden)
		return
	var text_value: String = ""
	var action_value: String = ""
	var key_value: String = ""
	var optional_hint: String = ""
	if _current_day == 1 and _waiting_for_note_dismiss:
		var pre_entry: Dictionary = _day_objectives.get(1, {})
		var pre: Dictionary = pre_entry.get("pre_step", {}) as Dictionary
		text_value = str(pre.get("text", ""))
		action_value = str(pre.get("action", ""))
		key_value = str(pre.get("key", ""))
	else:
		var source: Dictionary = _day_objectives.get(_current_day, _defaults)
		text_value = str(source.get("text", ""))
		action_value = str(source.get("action", ""))
		key_value = str(source.get("key", ""))
		optional_hint = str(source.get("optional_hint", ""))
		if (
			_current_day == 1
			and _day1_step_index >= 0
			and _day1_steps_available()
		):
			var steps: Array = source.get("steps", []) as Array
			var step: Dictionary = steps[_day1_step_index] as Dictionary
			text_value = str(step.get("text", text_value))
			action_value = str(step.get("action", action_value))
			key_value = str(step.get("key", key_value))
		elif _sold:
			# Once the first sale completes, advance the rail to the day's
			# post-sale copy when the day entry authors one. Day 1 reaches its
			# close-day prompt through the steps chain instead, so this branch
			# only kicks in for days without a steps array.
			var post_text: String = str(source.get("post_sale_text", ""))
			if not post_text.is_empty():
				text_value = post_text
				action_value = str(source.get("post_sale_action", ""))
				key_value = str(source.get("post_sale_key", ""))
	# Re-entering a scene or re-connecting a listener can drive _emit_current
	# multiple times in a frame with identical content; without this gate the
	# rail's 1-second flash tween restarts on every redundant emission. Hash
	# the final payload fields and bail when unchanged. Reset on day_started
	# so the first emit of a new day always fires.
	var payload_hash: String = (
		"%s%s%s%s"
		% [text_value, action_value, key_value, optional_hint]
	)
	if _last_payload_hash == payload_hash:
		return
	_last_payload_hash = payload_hash
	_emit_objective_payload(
		text_value,
		action_value,
		key_value,
		optional_hint,
	)


## Single emit point for the rail's `objective_changed` + `objective_updated`
## payload pair so the pre-step path and the main step/post-sale path cannot
## drift in shape.
func _emit_objective_payload(
	text_value: String,
	action_value: String,
	key_value: String,
	optional_hint: String,
) -> void:
	EventBus.objective_changed.emit({
		"objective": text_value,
		"text": text_value,
		"action": action_value,
		"key": key_value,
	})
	EventBus.objective_updated.emit({
		"current_objective": text_value,
		"next_action": action_value,
		"input_hint": key_value,
		"optional_hint": optional_hint,
	})


func _beta_controller_active() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	return not tree.get_nodes_in_group("beta_day_one_controller").is_empty()
