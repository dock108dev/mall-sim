class_name BetaDayOneController
extends Node

const EVENTS_PATH: String = "res://game/content/beta/events/customer_events.json"
const DAY_PATHS: Dictionary = {
	1: "res://game/content/beta/days/day_01.json",
	2: "res://game/content/beta/days/day_02.json",
}
const TARGET_BETA_DAYS: int = 2
const TARGET_EVENTS_PER_DAY: int = 3

const STAGE_TALK_TO_CUSTOMER: StringName = &"talk_to_customer"
const STAGE_PICKUP_STOCK: StringName = &"pickup_stock"
const STAGE_PLACE_STOCK: StringName = &"place_stock"
const STAGE_END_DAY: StringName = &"end_day"

const _HIDDEN_NOISE_NODES: Array[StringName] = [
	&"new_console_display",
	&"bargain_bin",
	&"featured_display",
	&"poster_slot",
	&"delivery_manifest",
	&"release_notes_clipboard",
	&"warranty_binder",
	&"employee_area",
	&"StoreAtmosphereProps",
	&"ZoneTransitions",
	&"InteriorSignage",
	&"ZoneLabels",
	&"FrontLaneQueue",
	&"Storefront",
	&"EntranceInterior",
]

var _decision_panel: BetaDecisionCardPanel
var _summary_panel: BetaDaySummaryPanel
var _events_by_day: Dictionary = {}
var _day_data_by_day: Dictionary = {}
var _day_events: Array[Dictionary] = []
var _current_event_index: int = 0
var _resolved_events_today: int = 0
var _stage: StringName = STAGE_TALK_TO_CUSTOMER
var _active_event: Dictionary = {}
var _carrying_box: bool = false
var _carry_item_label: String = "Used Game Box"


func _ready() -> void:
	add_to_group("beta_day_one_controller")
	_apply_minimal_scope()
	_load_content()
	_ensure_panels()
	_connect_panel_signals()
	_start_day(BetaRunState.day)
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


func on_beta_backroom_pickup_interacted() -> void:
	if _stage != STAGE_PICKUP_STOCK:
		EventBus.notification_requested.emit("You can pick stock after resolving a customer.")
		return
	_carrying_box = true
	_stage = STAGE_PLACE_STOCK
	EventBus.notification_requested.emit(
		"Carrying: %s. Place it on the shelf." % _carry_item_label
	)
	_update_objective_rail()
	_apply_objective_gating()
	_sync_stock_prop_visuals()


func on_beta_restock_interacted() -> void:
	if _stage != STAGE_PLACE_STOCK:
		EventBus.notification_requested.emit("Pick up stock from backroom first.")
		return
	if not _carrying_box:
		EventBus.notification_requested.emit("You are not carrying any stock box.")
		return
	_carrying_box = false
	_current_event_index += 1
	_prepare_next_objective()


func on_beta_day_end_requested() -> void:
	if _stage != STAGE_END_DAY:
		EventBus.notification_requested.emit(
			"Complete your open customer objective before ending the shift."
		)
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
	if choice_id == &"ignore_mismatch":
		BetaRunState.mark_hidden_thread_signal(&"parent_followup_complaint_risk")
	if _current_event_index >= _day_events.size() - 1:
		_stage = STAGE_END_DAY
		EventBus.notification_requested.emit(
			"Final customer resolved. End the day at the clock."
		)
	else:
		_stage = STAGE_PICKUP_STOCK
		EventBus.notification_requested.emit(
			"Customer resolved. Go to the backroom and pick up stock."
		)
	_update_objective_rail()
	_apply_objective_gating()
	_sync_stock_prop_visuals()
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)


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
	if _stage == STAGE_PICKUP_STOCK:
		return "Pick up a stock box from backroom first."
	if _stage == STAGE_PLACE_STOCK:
		return "Place the carried stock on the shelf first."
	if _stage == STAGE_END_DAY:
		return "Close the day at the shift clock."
	return "No customer event is active."


func can_interact_day_end() -> bool:
	return _stage == STAGE_END_DAY


func day_end_disabled_reason() -> String:
	if _stage == STAGE_TALK_TO_CUSTOMER:
		return "Resolve the active customer first."
	if _stage == STAGE_PICKUP_STOCK:
		return "Pick up stock first."
	if _stage == STAGE_PLACE_STOCK:
		return "Place the carried stock first."
	return "Day cannot be ended yet."


func can_interact_pickup() -> bool:
	return _stage == STAGE_PICKUP_STOCK and not _carrying_box


func pickup_disabled_reason() -> String:
	if _stage == STAGE_TALK_TO_CUSTOMER:
		return "Handle the customer first."
	if _stage == STAGE_PLACE_STOCK:
		return "You already picked up stock. Place it on shelf."
	if _stage == STAGE_END_DAY:
		return "No pickup needed. End the day."
	return "Pickup unavailable right now."


func can_interact_restock() -> bool:
	return _stage == STAGE_PLACE_STOCK and _carrying_box


func restock_disabled_reason() -> String:
	if _stage == STAGE_TALK_TO_CUSTOMER:
		return "Help the customer at checkout first."
	if _stage == STAGE_PICKUP_STOCK:
		return "Pick up a stock box in backroom first."
	if _stage == STAGE_END_DAY:
		return "You're done restocking for today."
	return "Restock is not needed right now."


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
	_carrying_box = false
	_prepare_next_objective()


func _prepare_next_objective() -> void:
	if _current_event_index >= _day_events.size():
		_active_event = {}
		_stage = STAGE_END_DAY
		_update_objective_rail()
		_apply_objective_gating()
		_sync_stock_prop_visuals()
		return
	_active_event = _day_events[_current_event_index]
	_stage = STAGE_TALK_TO_CUSTOMER
	_carrying_box = false
	_apply_customer_profile(_active_event)
	_update_objective_rail()
	_apply_objective_gating()
	_sync_stock_prop_visuals()


func _apply_customer_profile(event_data: Dictionary) -> void:
	var customer_name: String = str(event_data.get("customer_name", "Confused Parent"))
	var node: Node = get_tree().current_scene.get_node_or_null("BetaDayOneCustomer/Interactable")
	if node is Interactable:
		(node as Interactable).display_name = customer_name


func _update_objective_rail() -> void:
	var payload: Dictionary = {}
	var day_text: String = "Day %d" % BetaRunState.day
	match _stage:
		STAGE_TALK_TO_CUSTOMER:
			payload = {
				"text": "%s: Help customer %d/%d at checkout." % [
					day_text,
					_current_event_index + 1,
					max(_day_events.size(), 1),
				],
				"action": "Talk to the customer",
				"key": "E",
			}
		STAGE_PICKUP_STOCK:
			payload = {
				"text": "%s: Go to backroom and pick up a stock box." % day_text,
				"action": "Pick up box",
				"key": "E",
			}
		STAGE_PLACE_STOCK:
			payload = {
				"text": "%s: Carry box to shelf and place it." % day_text,
				"action": "Place stock",
				"key": "E",
			}
		_:
			payload = {
				"text": "%s: Close the day at the shift clock." % day_text,
				"action": "End day",
				"key": "F4",
			}
	EventBus.objective_changed.emit(payload)


func _apply_objective_gating() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable:
			(node as Interactable).enabled = false
	_set_interactable_enabled(scene, "EntranceDoor/Interactable", true)
	_set_interactable_enabled(scene, "BetaHiddenClue/Interactable", true)
	_set_interactable_enabled(
		scene,
		"BetaDayOneCustomer/Interactable",
		_stage == STAGE_TALK_TO_CUSTOMER
	)
	_set_interactable_enabled(scene, "BetaBackroomPickup/Interactable", _stage == STAGE_PICKUP_STOCK)
	_set_interactable_enabled(scene, "BetaRestockShelf/Interactable", _stage == STAGE_PLACE_STOCK)
	_set_interactable_enabled(scene, "BetaDayEndTrigger/Interactable", _stage == STAGE_END_DAY)


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


func _apply_minimal_scope() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	for node_name: StringName in _HIDDEN_NOISE_NODES:
		var target: Node = scene.find_child(String(node_name), true, false)
		if target is Node3D:
			(target as Node3D).visible = false


func _set_interactable_enabled(scene: Node, path: String, enabled: bool) -> void:
	var node: Node = scene.get_node_or_null(path)
	if node is Interactable:
		(node as Interactable).enabled = enabled


func _sync_stock_prop_visuals() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_set_node3d_visible(
		scene,
		"BetaBackroomPickup/StockBox",
		_stage == STAGE_PICKUP_STOCK and not _carrying_box
	)
	_set_node3d_visible(
		scene,
		"BetaRestockShelf/RestockCrate",
		_stage == STAGE_PLACE_STOCK and _carrying_box
	)


func _set_node3d_visible(scene: Node, path: String, is_visible: bool) -> void:
	var node: Node = scene.get_node_or_null(path)
	if node is Node3D:
		(node as Node3D).visible = is_visible
