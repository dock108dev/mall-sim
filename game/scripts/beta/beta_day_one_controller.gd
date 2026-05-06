class_name BetaDayOneController
extends Node

const EVENTS_PATH: String = "res://game/content/beta/events/customer_events.json"
const DAY_PATH: String = "res://game/content/beta/days/day_01.json"
const DAY1_EVENT_ID: StringName = &"day01_wrong_console_parent"

var _decision_panel: BetaDecisionCardPanel
var _summary_panel: BetaDaySummaryPanel
var _event_data: Dictionary = {}
var _day_data: Dictionary = {}


func _ready() -> void:
	add_to_group("beta_day_one_controller")
	_load_content()
	_ensure_panels()
	_connect_panel_signals()
	_print_interactable_debug_list()
	if BetaRunState.day <= 1:
		EventBus.notification_requested.emit(
			"Day 1: Help the confused parent at the counter."
		)


func on_beta_customer_interacted() -> void:
	if BetaRunState.day != 1:
		EventBus.notification_requested.emit("Day 1 event is only available on Day 1.")
		return
	if BetaRunState.completed_events.has(DAY1_EVENT_ID):
		EventBus.notification_requested.emit("You already handled this customer.")
		return
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DECISION_CARD)
	_decision_panel.show_event(_event_data)


func on_beta_day_end_requested() -> void:
	if not BetaRunState.is_day1_completed():
		EventBus.notification_requested.emit(
			"Finish the Day 1 customer decision before ending the shift."
		)
		return
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DAY_SUMMARY)
	_summary_panel.show_summary(BetaRunState.end_day())


func _on_choice_selected(choice_id: StringName, effects: Dictionary) -> void:
	BetaRunState.apply_decision_effect(DAY1_EVENT_ID, choice_id, effects)
	if choice_id == &"ignore_mismatch":
		BetaRunState.mark_hidden_thread_signal(&"parent_followup_complaint_risk")
	EventBus.notification_requested.emit("Choice locked in. Shift can now be ended at the clock.")
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)


func _on_summary_continue() -> void:
	BetaRunState.advance_day()
	GameManager.set_current_day(BetaRunState.day)
	EventBus.day_started.emit(BetaRunState.day)
	EventBus.notification_requested.emit("Day 2 placeholder loaded.")


func _load_content() -> void:
	var day_json: Variant = _load_json(DAY_PATH)
	if day_json is Dictionary:
		_day_data = day_json as Dictionary
	var events_json: Variant = _load_json(EVENTS_PATH)
	if events_json is Dictionary:
		var events: Array = (events_json as Dictionary).get("events", []) as Array
		for event_variant: Variant in events:
			if event_variant is Dictionary:
				var entry: Dictionary = event_variant as Dictionary
				if StringName(str(entry.get("id", ""))) == DAY1_EVENT_ID:
					_event_data = entry
					break
	if _event_data.is_empty():
		_event_data = {
			"id": String(DAY1_EVENT_ID),
			"title": "Wrong Console Problem",
			"body": "A parent is asking for a game on the wrong platform.",
			"choices": [
				{
					"id": "honest_explain",
					"label": "Explain the mismatch and suggest the correct version.",
					"effects": {"cash": 20, "reputation": 2, "manager_trust": 1},
				},
			],
		}


func _ensure_panels() -> void:
	if _decision_panel == null:
		_decision_panel = BetaDecisionCardPanel.new()
		_ui_root().add_child(_decision_panel)
	if _summary_panel == null:
		_summary_panel = BetaDaySummaryPanel.new()
		_ui_root().add_child(_summary_panel)


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
