class_name BetaDayOneController
extends Node

const EVENTS_PATH: String = "res://game/content/beta/events/customer_events.json"
const DAY_PATHS: Dictionary = {
	1: "res://game/content/beta/days/day_01.json",
	2: "res://game/content/beta/days/day_02.json",
}
const TARGET_BETA_DAYS: int = 2
const TARGET_EVENTS_PER_DAY: int = 3

## Linear Day-1 objective chain. One source of truth: every gating, prompt,
## time-advance, and close-day check reads from `_stage` and `_OBJECTIVES`.
## Adding a stage means appending an entry to `_OBJECTIVES` — gating,
## time-advance, and close-day eligibility all derive from this table.
##
## Tone rule: objective text is grounded retail-shift language only. No
## "odd" / "strange" / "mysterious" / "anomaly" / "secret" — the player
## decides what's weird; the UI doesn't announce it. The console stack
## (BetaHiddenClue) is ambient flavor: always interactable, never the
## active objective, doesn't advance the chain.
const STAGE_TALK_TO_CUSTOMER: StringName = &"talk_to_customer"
const STAGE_STOCK_SHELF: StringName = &"stock_shelf"
const STAGE_BACK_ROOM_INVENTORY: StringName = &"back_room_inventory"
const STAGE_END_DAY: StringName = &"end_day"
## Deprecated aliases — kept so external code that imported the old names
## still compiles. Not used in the live chain.
const STAGE_INSPECT_CLUE: StringName = &"back_room_inventory"
const STAGE_CHECK_SHELF: StringName = &"stock_shelf"
const STAGE_PICKUP_STOCK: StringName = &"back_room_inventory"
const STAGE_PLACE_STOCK: StringName = &"stock_shelf"

## In-game minute at which close-day's time gate unlocks. The chain's
## time costs are sized to land at or past this when the player completes
## every required objective, so the gate is rarely the limiting factor —
## it's a backstop against close-at-9-AM regressions.
const _CLOSE_TIME_MINUTES: float = 17.0 * 60.0  # 5:00 PM

## Day-1 objective table. Each entry drives gating, prompt, time advance,
## and the next-stage transition. `target_path` is the scene-relative path
## to the Interactable whose `enabled` flag the gating layer flips on for
## this stage; `time_cost_minutes` is added to TimeSystem when the player
## completes the step.
##
## Strings (not StringNames) inside the dict literals so the table parses
## as a plain Array literal — Godot's GDScript parser rejects nested
## `&"foo"` StringName literals inside typed Array[Dictionary] entries.
## `id` and `stage` are converted to StringName via `_chain_id` / `_chain_stage`
## helpers at lookup sites.
## Time costs land the chain at or past 5:00 PM by completion: 9:00 +
## 60 + 120 + 300 = 17:00 exactly. Even with TimeSystem absent (unit
## tests) the chain still flows because the time gate falls back to "ok"
## when there's no clock to consult.
## §F-I1 — Day-1 chain: customer → back room → stock → close. The order is
## doctrinal (per the latest beta-stabilization spec): the player can't stock
## meaningfully before knowing what's in the back room. Time costs (30/30/60)
## sum to 120 min so the chain finishes well before 5 PM; on transition to
## END_DAY, `_advance_to_next_stage` jumps the clock to 17:00 so the player
## isn't forced to idle from ~11 AM until close.
var _OBJECTIVES: Array[Dictionary] = [
	{
		"id": "talk_to_customer",
		"stage": "talk_to_customer",
		"label": "Day 1: Help the customer at the register.",
		"action": "Talk to the customer",
		"key": "E",
		"target_path": "BetaDayOneCustomer/Interactable",
		"time_cost_minutes": 30,
		"required": true,
	},
	{
		"id": "back_room_inventory",
		"stage": "back_room_inventory",
		"label": "Day 1: Check today's back room stock.",
		"action": "Check inventory",
		"key": "E",
		"target_path": "BetaBackroomPickup/Interactable",
		"time_cost_minutes": 30,
		"required": true,
	},
	{
		"id": "stock_shelf",
		"stage": "stock_shelf",
		"label": "Day 1: Put a few items on the shelves.",
		"action": "Stock the shelf",
		"key": "E",
		"target_path": "BetaRestockShelf/Interactable",
		"time_cost_minutes": 60,
		"required": true,
	},
	{
		"id": "close_day",
		"stage": "end_day",
		"label": "Day 1: Close the day at the register.",
		"action": "Close the day",
		"key": "E",
		"target_path": "BetaDayEndTrigger/Interactable",
		"time_cost_minutes": 0,
		"required": false,
	},
]

## Sub-fixture clutter that's hidden inside the beta scope so the room reads
## as a small store rather than a full retail environment. CartRackLeft /
## CartRackRight stay visible (added to `_BETA_KEEP_ROOT_NODES`) so the
## player has clear shelf landmarks; what stays here is loose-prop noise
## (atmosphere props, release wall, holds, testing stations) that doesn't
## contribute to Day-1 readability.
const _HIDDEN_NOISE_PATHS: Array[String] = [
	"new_console_display",
	"bargain_bin",
	"featured_display",
	"poster_slot",
	"delivery_manifest",
	"release_notes_clipboard",
	"employee_area",
	"StoreAtmosphereProps",
	"FrontLaneQueue",
	"crt_demo_area",
	"new_release_wall",
	"old_gen_shelf",
	"hold_shelf",
	"testing_station",
	"refurb_bench",
]

const _BETA_KEEP_ROOT_NODES: Array[StringName] = [
	&"PlayerController",
	&"PlayerEntrySpawn",
	&"FluorescentKeyLight",
	&"WarmNeonFill",
	&"GreenNeonFill",
	&"CRTDemoSpotlight",
	&"CheckoutLaneSpotlight",
	&"FrontLaneFill",
	&"CheckoutCounterPractical",
	&"BackroomUtilityLight",
	&"Floor",
	&"BackWallBody",
	&"LeftWallBody",
	&"RightWallBody",
	&"Ceiling",
	&"FrontWallLeftBody",
	&"FrontWallRightBody",
	&"EntranceDoor",
	&"NavigationRegion3D",
	&"EntryArea",
	&"RegisterArea",
	&"checkout_counter",
	# Authored fixtures — kept visible so the room reads as a used-game store
	# without a separate primitive-builder. Their slot Interactables are
	# disabled by `_apply_objective_gating`, so player E-presses still resolve
	# only against the beta day-1 critical-path targets.
	&"Checkout",
	&"CartRackLeft",
	&"CartRackRight",
	&"GlassCase",
	&"ConsoleShelf",
	&"AccessoriesBin",
	&"InteriorSignage",
	&"BetaDayOneController",
	&"BetaDayOneCustomer",
	&"BetaBackroomPickup",
	&"BetaRestockShelf",
	&"BetaDayEndTrigger",
	&"BetaHiddenClue",
	&"ZoneLabels",
	&"Storefront",
	&"EntranceInterior",
]

const BetaDebugOverlayScript: GDScript = preload(
	"res://game/scripts/beta/beta_debug_overlay.gd"
)
const BetaScreenshotHelperScript: GDScript = preload(
	"res://game/scripts/beta/beta_screenshot_helper.gd"
)

var _decision_panel: BetaDecisionCardPanel
var _summary_panel: BetaDaySummaryPanel
var _debug_overlay: CanvasLayer
var _screenshot_helper: CanvasLayer
var _events_by_day: Dictionary = {}
var _day_data_by_day: Dictionary = {}
var _day_events: Array[Dictionary] = []
var _current_event_index: int = 0
var _resolved_events_today: int = 0
var _stage: StringName = STAGE_TALK_TO_CUSTOMER
var _active_event: Dictionary = {}
## Track per-objective completion (one-shot guard). An objective fires
## `_advance_stage` exactly once even if its interactable's interact() is
## called twice (e.g. mid-fade scene churn) — the entry stays in this set
## and subsequent calls early-out.
var _completed_objectives: Dictionary = {}


func _ready() -> void:
	add_to_group("beta_day_one_controller")
	_apply_beta_only_strip()
	_apply_minimal_scope()
	_configure_beta_customer()
	_load_content()
	_ensure_panels()
	_connect_panel_signals()
	# Deferred so the parent StoreController._ready() runs first and connects
	# its EventBus.objective_changed listener before _start_day emits the
	# initial rail payload. Without this, StoreReadyContract invariant
	# objective_matches_action fails on store load (current_objective_text
	# stays empty because the emit happened before the connect).
	call_deferred("_start_day", BetaRunState.day)
	_print_interactable_debug_list()


func on_beta_customer_interacted() -> void:
	if _stage != STAGE_TALK_TO_CUSTOMER:
		EventBus.notification_requested.emit("Follow the current objective first.")
		return
	if _active_event.is_empty():
		EventBus.notification_requested.emit("No customer event is available right now.")
		return
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DECISION_CARD)
	_decision_panel.show_event(_active_event)


## Required back-room beat. Pressing E on the inventory pickup completes
## the back-room objective and advances the chain. Inspecting the
## console stack flavor object (BetaHiddenClue) is independent — it does
## not satisfy this beat.
func on_beta_backroom_pickup_interacted() -> void:
	if _stage != STAGE_BACK_ROOM_INVENTORY:
		EventBus.notification_requested.emit(_disabled_reason_for_stage(STAGE_BACK_ROOM_INVENTORY))
		return
	if _completed_objectives.has(&"back_room_inventory"):
		return
	EventBus.notification_requested.emit(
		"Counted the back room. Numbers match the manifest."
	)
	_complete_current_objective()


## Optional ambient flavor — the console stack is interactable any time
## the player notices it, but inspecting it does not advance the active
## objective. Per the tone rule: the player decides whether it's
## interesting; the UI never labels it as a quest. The hidden-thread
## signal still records the inspection so consequence pipelines (later
## days) can react.
func on_beta_hidden_clue_interacted() -> void:
	if _completed_objectives.has(&"_flavor_console_stack"):
		# Already inspected today — second press shows the same flavor
		# but we don't double-advance the clock or re-emit signals.
		EventBus.notification_requested.emit(
			"You've already taken a look. Nothing new to see."
		)
		return
	_completed_objectives[&"_flavor_console_stack"] = true
	BetaRunState.mark_hidden_thread_signal(&"day01_backroom_modded_console_hint")
	EventBus.notification_requested.emit(
		"A few old consoles are stacked beside the wall. One is warmer than it should be."
	)
	# Small ambient time tick — inspecting takes a moment but is not on
	# the critical path's time budget.
	var time_sys: TimeSystem = GameManager.get_time_system()
	if time_sys != null:
		time_sys.advance_by_minutes(5.0)


## Required stocking beat. Renamed from the old pickup/place-stock
## two-step into a single "stock the shelf" interaction so the chain
## stays simple and grounded.
func on_beta_restock_interacted() -> void:
	if _stage != STAGE_STOCK_SHELF:
		EventBus.notification_requested.emit(_disabled_reason_for_stage(STAGE_STOCK_SHELF))
		return
	if _completed_objectives.has(&"stock_shelf"):
		return
	EventBus.notification_requested.emit(
		"Used games shelf restocked from the trade-in pile."
	)
	_complete_current_objective()


func on_beta_day_end_requested() -> void:
	if _stage != STAGE_END_DAY:
		EventBus.notification_requested.emit(close_day_disabled_reason())
		return
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DAY_SUMMARY)
	var summary: Dictionary = BetaRunState.end_day()
	summary["events_completed"] = _resolved_events_today
	summary["events_target"] = _day_events.size()
	_summary_panel.show_summary(summary, BetaRunState.day >= TARGET_BETA_DAYS)


func _on_choice_selected(choice_id: StringName, effects: Dictionary) -> void:
	if _active_event.is_empty():
		BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)
		return
	var event_id: StringName = StringName(str(_active_event.get("id", "")))
	BetaRunState.apply_decision_effect(event_id, choice_id, effects)
	_resolved_events_today += 1
	if choice_id == &"refuse_return":
		BetaRunState.mark_hidden_thread_signal(&"parent_refused_return_risk")
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)
	# The customer step is the first link in the chain; resolving their
	# decision completes that objective and advances to INSPECT_CLUE. The
	# old "skip to END_DAY for last event" branch was the source of the
	# 9 AM close-day bug — every Day 1 has exactly one customer, so it
	# would short-circuit the rest of the loop.
	if _completed_objectives.has(&"talk_to_customer"):
		return
	_complete_current_objective()


func _on_summary_continue() -> void:
	if BetaRunState.day >= TARGET_BETA_DAYS:
		EventBus.notification_requested.emit("15-minute beta loop complete. Returning to main menu.")
		GameManager.go_to_main_menu()
		return
	BetaRunState.advance_day()
	GameManager.set_current_day(BetaRunState.day)
	EventBus.day_started.emit(BetaRunState.day)
	_start_day(BetaRunState.day)


func can_interact_customer() -> bool:
	return _stage == STAGE_TALK_TO_CUSTOMER and not _active_event.is_empty()


func customer_disabled_reason() -> String:
	return _disabled_reason_for_stage(STAGE_TALK_TO_CUSTOMER)


func can_interact_restock() -> bool:
	return _stage == STAGE_STOCK_SHELF


func restock_disabled_reason() -> String:
	return _disabled_reason_for_stage(STAGE_STOCK_SHELF)


func can_interact_pickup() -> bool:
	return _stage == STAGE_BACK_ROOM_INVENTORY


func pickup_disabled_reason() -> String:
	return _disabled_reason_for_stage(STAGE_BACK_ROOM_INVENTORY)


## Console stack is ambient flavor — always interactable when the player
## notices it. No stage gating; the prompt is muted post-inspection.
func can_interact_hidden_clue() -> bool:
	return not _completed_objectives.has(&"_flavor_console_stack")


func hidden_clue_disabled_reason() -> String:
	return ""


## Belt-and-suspenders: stage flag AND every required objective complete.
## Time-of-day is no longer a gate — once the chain is done the player
## should be able to close immediately. `_pause_time_for_end_day()` halts
## the clock the moment END_DAY is entered so the player isn't forced to
## race a moving 17:00 deadline while walking to the register.
func can_interact_day_end() -> bool:
	return _stage == STAGE_END_DAY and _all_required_objectives_completed()


func day_end_disabled_reason() -> String:
	return close_day_disabled_reason()


## Single source of truth for the close-day prompt's disabled message.
## Reads from the chain so when objectives are added/reordered, this
## message stays correct without per-stage maintenance. Phrased in
## grounded retail-shift language — never "you can't close the day yet,
## the mystery isn't solved."
func close_day_disabled_reason() -> String:
	for entry: Dictionary in _OBJECTIVES:
		var stage_name: StringName = StringName(str(entry.get("stage", "")))
		if stage_name == STAGE_END_DAY:
			continue
		if not bool(entry.get("required", false)):
			continue
		var entry_id: StringName = StringName(str(entry.get("id", "")))
		if not _completed_objectives.has(entry_id):
			return "You still have a few things to take care of before closing."
	return "Day cannot be ended yet."


func _disabled_reason_for_stage(target_stage: StringName) -> String:
	if _stage == target_stage:
		return ""
	for entry: Dictionary in _OBJECTIVES:
		if StringName(str(entry.get("stage", ""))) == _stage:
			return "Working on: %s" % str(entry.get("label", ""))
	return "Not available right now."


func _load_content() -> void:
	for day_key: Variant in DAY_PATHS.keys():
		var day: int = int(day_key)
		var day_json: Variant = _load_json(str(DAY_PATHS[day_key]))
		if day_json is Dictionary:
			_day_data_by_day[day] = day_json
	var events_json: Variant = _load_json(EVENTS_PATH)
	if events_json is Dictionary:
		var events: Array = (events_json as Dictionary).get("events", []) as Array
		for event_variant: Variant in events:
			if event_variant is Dictionary:
				var entry: Dictionary = event_variant as Dictionary
				var day: int = int(entry.get("day", 1))
				if not _events_by_day.has(day):
					_events_by_day[day] = []
				var bucket: Array = _events_by_day[day] as Array
				bucket.append(entry)
				_events_by_day[day] = bucket


func _start_day(day: int) -> void:
	var all_day_events: Array = []
	if _events_by_day.has(day):
		all_day_events = (_events_by_day[day] as Array).duplicate()
	_day_events.clear()
	for event_variant: Variant in all_day_events:
		if event_variant is Dictionary:
			_day_events.append(event_variant as Dictionary)
	if _day_events.size() > TARGET_EVENTS_PER_DAY:
		_day_events = _day_events.slice(0, TARGET_EVENTS_PER_DAY)
	_current_event_index = 0
	_resolved_events_today = 0
	_completed_objectives.clear()
	# Start at the head of the chain.
	_stage = STAGE_TALK_TO_CUSTOMER
	if not _day_events.is_empty():
		_active_event = _day_events[0]
	else:
		_active_event = {}
	_apply_customer_profile(_active_event)
	_update_objective_rail()
	_apply_objective_gating()


## Marks the current stage's objective complete, advances the in-game
## clock by its `time_cost_minutes`, and transitions to the next stage in
## the chain. Idempotent — calling twice for the same objective is a
## no-op (the `_completed_objectives` guard at each call site already
## handles this; keeping the explicit check here too defends against
## external misuse).
func _complete_current_objective() -> void:
	var entry: Dictionary = _objective_for_stage(_stage)
	if entry.is_empty():
		return
	var objective_id: StringName = StringName(str(entry.get("id", "")))
	if objective_id == &"":
		return
	if _completed_objectives.has(objective_id):
		return
	_completed_objectives[objective_id] = true
	var time_cost: int = int(entry.get("time_cost_minutes", 0))
	if time_cost > 0:
		var time_sys: TimeSystem = GameManager.get_time_system()
		if time_sys != null:
			time_sys.advance_by_minutes(float(time_cost))
	_advance_stage_after(objective_id)


## Advances `_stage` to the entry that follows `completed_id` in
## `_OBJECTIVES`. Wrapping over the end of the array stays at END_DAY so
## the close-day prompt is the terminal state.
func _advance_stage_after(completed_id: StringName) -> void:
	var idx: int = -1
	for i: int in range(_OBJECTIVES.size()):
		if StringName(str(_OBJECTIVES[i].get("id", ""))) == completed_id:
			idx = i
			break
	if idx == -1 or idx + 1 >= _OBJECTIVES.size():
		_stage = STAGE_END_DAY
	else:
		_stage = StringName(str(_OBJECTIVES[idx + 1].get("stage", STAGE_END_DAY)))
	if _stage == STAGE_END_DAY:
		_pause_time_for_end_day()
	_update_objective_rail()
	_apply_objective_gating()


## §F-FIX1 — When the chain hits END_DAY, freeze the clock so the player
## can walk to the register at their own pace and close on their own E-press.
## Earlier auto-jump-to-17:00 was harmful: TimeSystem auto-`_end_day`s the
## moment `game_time_minutes >= 17:00`, which slammed the player straight
## to the day summary before they could interact with the close-day trigger.
## Spec: "the game intentionally jumps to closing time" — implemented as
## a soft pause; the player's E-press is what ends the day.
func _pause_time_for_end_day() -> void:
	var time_sys: TimeSystem = GameManager.get_time_system()
	if time_sys == null:
		return
	if time_sys.has_method("set_speed"):
		time_sys.call("set_speed", TimeSystem.SpeedTier.PAUSED)


## Returns the `_OBJECTIVES` row whose `stage` matches `target_stage`, or
## an empty dict for unknown stages.
func _objective_for_stage(target_stage: StringName) -> Dictionary:
	for entry: Dictionary in _OBJECTIVES:
		if StringName(str(entry.get("stage", ""))) == target_stage:
			return entry
	return {}


## Test seam — read-only access to the completion set so GUT tests can
## verify a stage actually flipped its objective complete without poking
## the private dictionary directly.
func is_objective_completed(objective_id: StringName) -> bool:
	return _completed_objectives.has(objective_id)


## Snapshot of the Day-1 FSM for the debug overlay and the F8 console
## dump. One source of truth: the overlay reads from this dict and the
## state dump prints it, so they can never disagree about what the FSM
## thinks is happening.
func get_state_snapshot() -> Dictionary:
	var current: Dictionary = _objective_for_stage(_stage)
	var completed_ids: Array[StringName] = []
	for key: Variant in _completed_objectives.keys():
		completed_ids.append(StringName(str(key)))
	var time_minutes: float = -1.0
	var time_sys: TimeSystem = GameManager.get_time_system()
	if time_sys != null:
		time_minutes = time_sys.game_time_minutes
	return {
		"day": BetaRunState.day,
		"stage": String(_stage),
		"active_objective_id": String(current.get("id", "")),
		"active_objective_label": String(current.get("label", "")),
		"completed_objectives": completed_ids,
		"can_close_day": _all_required_objectives_completed() and _stage == STAGE_END_DAY,
		"close_day_reason": close_day_disabled_reason() if _stage != STAGE_END_DAY else "ready",
		"time_minutes": time_minutes,
	}


func _apply_customer_profile(event_data: Dictionary) -> void:
	if event_data.is_empty():
		return
	var customer_name: String = str(event_data.get("customer_name", "Confused Parent"))
	var store: Node = _store_root()
	if store == null:
		return
	var node: Node = store.get_node_or_null("BetaDayOneCustomer/Interactable")
	if node is Interactable:
		(node as Interactable).display_name = customer_name


func _update_objective_rail() -> void:
	var entry: Dictionary = _objective_for_stage(_stage)
	if entry.is_empty():
		EventBus.objective_changed.emit({"hidden": true})
		return
	# Day-2 placeholder retains the existing "wrap the beta loop" copy when
	# we hit close_day on day 2. Lets us keep the scaffolding without
	# making the table itself day-aware (Day 2 is a placeholder slot).
	var label: String = str(entry.get("label", ""))
	if BetaRunState.day == 2 and StringName(str(entry.get("stage", ""))) == STAGE_END_DAY:
		label = "Day 2 (placeholder): Close at the register to wrap the beta loop."
	EventBus.objective_changed.emit({
		"text": label,
		"action": str(entry.get("action", "")),
		"key": str(entry.get("key", "E")),
	})


## Disables every Interactable under the store, then re-enables the
## current chain row's `target_path`. Two exceptions:
##   * Close-day requires `_stage == END_DAY` AND all required objectives
##     done — `_pause_time_for_end_day()` is what stops the world from
##     auto-ending at 17:00, so no time gate here.
##   * The console stack stays interactable any time the player notices
##     it (until they've inspected it once today). It is ambient flavor,
##     not a gated objective; gating it would make the mystery feel like
##     a checklist item.
func _apply_objective_gating() -> void:
	var store: Node = _store_root()
	if store == null:
		return
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable and _is_descendant_of(node, store):
			(node as Interactable).enabled = false
	_set_interactable_enabled(store, "EntranceDoor/Interactable", false)
	for entry: Dictionary in _OBJECTIVES:
		var entry_stage: StringName = StringName(str(entry.get("stage", "")))
		var path: String = str(entry.get("target_path", ""))
		if path.is_empty():
			continue
		var is_active: bool = (entry_stage == _stage)
		if entry_stage == STAGE_END_DAY:
			is_active = is_active and _all_required_objectives_completed()
		_set_interactable_enabled(store, path, is_active)
	# Console stack — ambient flavor, always interactable until inspected.
	_set_interactable_enabled(
		store,
		"BetaHiddenClue/Interactable",
		not _completed_objectives.has(&"_flavor_console_stack")
	)


func _all_required_objectives_completed() -> bool:
	for entry: Dictionary in _OBJECTIVES:
		if StringName(str(entry.get("stage", ""))) == STAGE_END_DAY:
			continue
		if not bool(entry.get("required", false)):
			continue
		var entry_id: StringName = StringName(str(entry.get("id", "")))
		if not _completed_objectives.has(entry_id):
			return false
	return true


func _ensure_panels() -> void:
	if _decision_panel == null:
		_decision_panel = BetaDecisionCardPanel.new()
		_ui_root().add_child(_decision_panel)
	if _summary_panel == null:
		_summary_panel = BetaDaySummaryPanel.new()
		_ui_root().add_child(_summary_panel)
	if _debug_overlay == null:
		_debug_overlay = CanvasLayer.new()
		_debug_overlay.set_script(BetaDebugOverlayScript)
		_debug_overlay.name = "BetaDebugOverlay"
		_ui_root().add_child(_debug_overlay)
	if _screenshot_helper == null:
		_screenshot_helper = CanvasLayer.new()
		_screenshot_helper.set_script(BetaScreenshotHelperScript)
		_screenshot_helper.name = "BetaScreenshotHelper"
		_ui_root().add_child(_screenshot_helper)


func _connect_panel_signals() -> void:
	if not _decision_panel.choice_selected.is_connected(_on_choice_selected):
		_decision_panel.choice_selected.connect(_on_choice_selected)
	if not _summary_panel.continue_pressed.is_connected(_on_summary_continue):
		_summary_panel.continue_pressed.connect(_on_summary_continue)


func _ui_root() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return get_tree().root
	var ui_layer: Node = scene.find_child("UILayer", true, false)
	if ui_layer != null:
		return ui_layer
	return scene


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return {}
	return parsed


func _print_interactable_debug_list() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var rows: Array[String] = []
	for node: Node in tree.get_nodes_in_group("interactable"):
		if node is Interactable:
			var interactable: Interactable = node as Interactable
			rows.append("- %s" % interactable.resolve_interactable_id())
	rows.sort()
	print("[BetaInteractables]\n%s" % "\n".join(rows))


func _apply_minimal_scope() -> void:
	var store: Node = _store_root()
	if store == null:
		return
	for node_path: String in _HIDDEN_NOISE_PATHS:
		var target: Node = store.get_node_or_null(NodePath(node_path))
		if target is Node3D:
			(target as Node3D).visible = false


func _set_interactable_enabled(root: Node, path: String, enabled: bool) -> void:
	var node: Node = root.get_node_or_null(path)
	if node is Interactable:
		(node as Interactable).enabled = enabled


func _set_node3d_visible(root: Node, path: String, is_visible: bool) -> void:
	var node: Node = root.get_node_or_null(path)
	if node is Node3D:
		(node as Node3D).visible = is_visible


func _apply_beta_only_strip() -> void:
	var store: Node = _store_root()
	if store == null:
		return
	for child: Node in store.get_children():
		if _is_kept_root_node(child.name):
			continue
		_disable_interactables_in_subtree(child)
		if child is Node3D:
			(child as Node3D).visible = false


func _disable_interactables_in_subtree(node: Node) -> void:
	if node is Interactable:
		(node as Interactable).enabled = false
	for child: Node in node.get_children():
		_disable_interactables_in_subtree(child)


func _is_kept_root_node(node_name: StringName) -> bool:
	return _BETA_KEEP_ROOT_NODES.has(node_name)


## Builds the customer's visible proxy (torso + head) and resizes the
## Interactable's CollisionShape3D so the visible mesh, the trigger volume,
## and the world position are anchored at the same Node3D origin. The .tscn
## drives BetaDayOneCustomer.position — this method does not move the node.
##
## Visible mesh, collision, and the optional Marker label are all children
## of `CustomerProxy`, which sits at local (0, 0, 0) under BetaDayOneCustomer.
## When the player walks within range of the visible torso/head, the
## InteractionRay hits the same volume, so the prompt and the visible target
## stay in lockstep.
func _configure_beta_customer() -> void:
	var store: Node = _store_root()
	if store == null:
		return
	var customer_node_ref: Node = store.get_node_or_null("BetaDayOneCustomer")
	if not (customer_node_ref is Node3D):
		return
	var customer_node: Node3D = customer_node_ref as Node3D

	var proxy_root_ref: Node = customer_node.get_node_or_null("CustomerProxy")
	var proxy_root: Node3D
	if proxy_root_ref is Node3D:
		proxy_root = proxy_root_ref as Node3D
	else:
		proxy_root = Node3D.new()
		proxy_root.name = "CustomerProxy"
		customer_node.add_child(proxy_root)

	var torso_ref: Node = proxy_root.get_node_or_null("Torso")
	if not (torso_ref is MeshInstance3D):
		var torso_mesh := MeshInstance3D.new()
		torso_mesh.name = "Torso"
		proxy_root.add_child(torso_mesh)
		torso_ref = torso_mesh
	var torso: MeshInstance3D = torso_ref as MeshInstance3D
	var torso_shape := CapsuleMesh.new()
	torso_shape.radius = 0.22
	torso_shape.height = 0.85
	torso.mesh = torso_shape
	torso.position = Vector3(0.0, 0.85, 0.0)
	var torso_mat := StandardMaterial3D.new()
	torso_mat.albedo_color = Color(0.34, 0.26, 0.20, 1.0)
	torso_mat.roughness = 0.82
	torso.material_override = torso_mat

	var head_ref: Node = proxy_root.get_node_or_null("Head")
	if not (head_ref is MeshInstance3D):
		var head_mesh := MeshInstance3D.new()
		head_mesh.name = "Head"
		proxy_root.add_child(head_mesh)
		head_ref = head_mesh
	var head: MeshInstance3D = head_ref as MeshInstance3D
	var head_shape := SphereMesh.new()
	head_shape.radius = 0.17
	head.mesh = head_shape
	head.position = Vector3(0.0, 1.45, 0.0)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.84, 0.71, 0.56, 1.0)
	head_mat.roughness = 0.88
	head.material_override = head_mat

	# Marker label suppressed for beta — the screen-anchored InteractionPrompt
	# already names the target ("Talk to Confused Parent"), so a floating
	# "CUSTOMER" billboard would just compete with it. Remove any leftover
	# Marker from a prior run so the proxy stays clean across reloads.
	var stale_marker: Node = proxy_root.get_node_or_null("Marker")
	if stale_marker != null:
		stale_marker.queue_free()

	# Resize the Interactable trigger so the screen-center ray hits it from
	# typical approach distances, not just nose-to-chest. The authored shape
	# in the .tscn is a 1.5 m box centered on the node origin (Y=-0.75 to
	# Y=+0.75 — floor + lower legs), which the player's eye-level ray
	# (camera at Y=1.7) flies over until the player is right on top of the
	# customer.
	#
	# The replacement capsule is intentionally LARGER than the visible
	# proxy: ±0.55 m horizontal, Y=0–2.0, so any aim near the customer's
	# silhouette registers a hit. The visible torso/head are still small
	# (matches the brief's "smaller scale, stands at counter") — the trigger
	# just doesn't have to be flattering.
	#
	# Deferred via `call_deferred` so it runs after `Interactable._ready`
	# has finished reparenting the CollisionShape3D into its generated
	# `InteractionArea` (game/scripts/components/interactable.gd:271).
	# Without the defer, our edit would race that reparent depending on
	# sibling tree order; deferring guarantees we touch the post-reparent
	# node and our shape sticks.
	call_deferred("_resize_customer_trigger", customer_node)


## Deferred companion to `_configure_beta_customer`. Runs after
## `Interactable._ready` has reparented the CollisionShape3D into the
## generated `InteractionArea`, so `find_child` resolves the same node
## regardless of sibling _ready ordering. The capsule is sized larger than
## the visible mesh so the screen-center ray reliably hits the trigger at
## the InteractionRay's full 2.5 m range, not just at zero distance.
func _resize_customer_trigger(customer_node: Node3D) -> void:
	if not is_instance_valid(customer_node):
		return
	var interactable_node: Node = customer_node.get_node_or_null("Interactable")
	if interactable_node == null:
		return
	var collision: CollisionShape3D = (
		interactable_node.find_child("CollisionShape3D", true, false)
		as CollisionShape3D
	)
	if collision == null:
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.0
	collision.shape = capsule
	collision.position = Vector3(0.0, 1.0, 0.0)


func _store_root() -> Node:
	var root: Node = get_parent()
	if root != null:
		return root
	return get_tree().current_scene


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	if node == null or ancestor == null:
		return false
	var current: Node = node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
