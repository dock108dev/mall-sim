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
const DAY1_STEP_OPEN_INVENTORY: int = 0
const DAY1_STEP_SELECT_ITEM: int = 1
const DAY1_STEP_STOCK_ITEM: int = 2
const DAY1_STEP_WAIT_FOR_CUSTOMER: int = 3
const DAY1_STEP_CUSTOMER_BROWSING: int = 4
const DAY1_STEP_CUSTOMER_AT_CHECKOUT: int = 5
const DAY1_STEP_SALE_COMPLETE: int = 6
const DAY1_STEP_CLOSE_DAY: int = 7
const DAY1_STEP_COUNT: int = 8

## "Sale complete!" is shown briefly before the rail flips to the close-day
## prompt so the player registers the success beat before being asked to act.
const SALE_COMPLETE_DURATION: float = 2.0

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


func _ready() -> void:
	_load_content()
	EventBus.day_started.connect(_on_day_started)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.item_stocked.connect(_on_item_stocked)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.day_closed.connect(_on_day_closed)
	EventBus.preference_changed.connect(_on_preference_changed)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.placement_mode_entered.connect(_on_placement_mode_entered)
	EventBus.customer_state_changed.connect(_on_customer_state_changed)
	EventBus.customer_ready_to_purchase.connect(_on_customer_ready_to_purchase)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.checkout_declined.connect(_on_checkout_declined)
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
	if day == 1 and _day1_steps_available():
		# The Day 1 step chain is held until the player dismisses Vic's
		# morning note. _on_manager_note_dismissed advances _day1_step_index
		# to OPEN_INVENTORY when the note clears.
		_waiting_for_note_dismiss = true
	_emit_current()


func _on_manager_note_dismissed(_note_id: String) -> void:
	if _current_day != 1 or not _waiting_for_note_dismiss:
		return
	_waiting_for_note_dismiss = false
	if _day1_steps_available():
		_day1_step_index = DAY1_STEP_OPEN_INVENTORY
	_emit_current()


func _on_store_entered(_store_id: StringName) -> void:
	_emit_current()


func _on_item_stocked(_item_id: String, _shelf_id: String) -> void:
	_stocked = true
	if _sold:
		_loop_completed_today = true
	_advance_day1_step_if(DAY1_STEP_STOCK_ITEM)
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


func _on_panel_opened(panel_name: String) -> void:
	if panel_name == "inventory":
		_advance_day1_step_if(DAY1_STEP_OPEN_INVENTORY)


func _on_placement_mode_entered() -> void:
	_advance_day1_step_if(DAY1_STEP_SELECT_ITEM)


func _on_customer_state_changed(_customer: Node, new_state: int) -> void:
	if new_state == Customer.State.BROWSING:
		_advance_day1_step_if(DAY1_STEP_WAIT_FOR_CUSTOMER)


func _on_customer_ready_to_purchase(_customer_data: Dictionary) -> void:
	_advance_day1_step_if(DAY1_STEP_CUSTOMER_BROWSING)


func _on_customer_purchased(
	_store_id: StringName, _item_id: StringName,
	_price: float, _customer_id: StringName,
) -> void:
	_advance_day1_step_if(DAY1_STEP_CUSTOMER_AT_CHECKOUT)


## Day 1 only: when the player presses Pass at the register before the first
## sale, roll the rail back to "wait for a customer" so the prompt matches the
## actual game state. Without this the rail keeps showing "Customer at
## checkout" with no customer present until the next forced spawn arrives —
## the player has no signal that a new customer is coming.
func _on_checkout_declined(_customer: Node) -> void:
	if _current_day != 1 or _sold:
		return
	if not _day1_steps_available():
		return
	if (
		_day1_step_index < DAY1_STEP_CUSTOMER_BROWSING
		or _day1_step_index > DAY1_STEP_CUSTOMER_AT_CHECKOUT
	):
		return
	_day1_step_index = DAY1_STEP_WAIT_FOR_CUSTOMER
	_emit_current()


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
	if _day1_step_index == DAY1_STEP_SALE_COMPLETE:
		_schedule_close_day_step()


## Auto-advances from "Sale complete!" to "Close the day when ready" after a
## brief display window so the success beat lands before the next prompt.
## §F-99 — `tree == null` test-seam mirrors the §F-44 / §F-54 contract for
## autoload-test-seam patterns: production paths always have a SceneTree
## (autoload + scene); bare-Node unit-test fixtures hit the silent path and
## still terminate the chain by jumping directly to the advancer. The §F-98
## state-machine guard inside `_advance_to_close_day_step` defends against
## the timer firing after a day rollover.
func _schedule_close_day_step() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		_advance_to_close_day_step()
		return
	tree.create_timer(SALE_COMPLETE_DURATION).timeout.connect(
		_advance_to_close_day_step
	)


func _advance_to_close_day_step() -> void:
	# §F-98 — Same race-guard pattern as `_advance_day1_step_if`: a delayed
	# timer firing after the day rolled over (or after a duplicate trigger
	# already advanced past `DAY1_STEP_SALE_COMPLETE`) is a no-op by design.
	if _current_day != 1 or _day1_step_index != DAY1_STEP_SALE_COMPLETE:
		return
	_day1_step_index = DAY1_STEP_CLOSE_DAY
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
func _emit_current() -> void:
	var should_auto_hide: bool = _loop_completed and _current_day > 3
	if should_auto_hide and not Settings.show_objective_rail:
		var hidden: Dictionary = {"hidden": true}
		EventBus.objective_changed.emit(hidden)
		EventBus.objective_updated.emit(hidden)
		return
	if _current_day == 1 and _waiting_for_note_dismiss:
		var pre_entry: Dictionary = _day_objectives.get(1, {})
		var pre: Dictionary = pre_entry.get("pre_step", {}) as Dictionary
		_emit_objective_payload(
			str(pre.get("text", "")),
			str(pre.get("action", "")),
			str(pre.get("key", "")),
			"",
		)
		return
	var source: Dictionary = _day_objectives.get(_current_day, _defaults)
	var text_value: String = str(source.get("text", ""))
	var action_value: String = str(source.get("action", ""))
	var key_value: String = str(source.get("key", ""))
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
	_emit_objective_payload(
		text_value,
		action_value,
		key_value,
		str(source.get("optional_hint", "")),
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
