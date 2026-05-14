## Debug autoload for headless interaction audit. Stripped to no-op in release builds.
## Connects to EventBus signals to auto-instrument the five required checkpoints.
## F3 toggles visibility; release builds queue_free in _ready, debug builds
## start hidden. No SubViewport or minimap is created here.
extends CanvasLayer

const CHECKPOINTS: Array[StringName] = [
	&"boot_complete",
	&"store_entered",
	&"inventory_open",
	&"shelf_stock",
	&"price_set",
	&"refurb_completed",
	&"transaction_completed",
	&"day_closed",
	&"customer_walked",
]

const _COLOR_TITLE := Color(1.0, 0.85, 0.2)
const _COLOR_PASS := Color(0.2, 0.9, 0.2)
const _COLOR_FAIL := Color(0.9, 0.2, 0.2)
const _COLOR_PENDING := Color(0.65, 0.65, 0.65)
const _PANEL_WIDTH := 320.0
const _ENTRY_ROWS: int = 10

const _PHASE_NAMES: Dictionary = {
	TimeSystem.DayPhase.PRE_OPEN: "PRE_OPEN",
	TimeSystem.DayPhase.MORNING_RAMP: "MORNING_RAMP",
	TimeSystem.DayPhase.MIDDAY_RUSH: "MIDDAY_RUSH",
	TimeSystem.DayPhase.AFTERNOON: "AFTERNOON",
	TimeSystem.DayPhase.EVENING: "EVENING",
	TimeSystem.DayPhase.LATE_EVENING: "LATE_EVENING",
}

var _results: Dictionary = {}
var _last_interactable: String = "none"
## Beta shelf/back-room counts mirror the values driven by
## `EventBus.beta_shelf_count_changed` / `beta_backroom_count_changed`. Read-only
## elsewhere — only the signal handlers write. Initialized to -1 so the HUD
## renders "—" before the first emit instead of a misleading 0.
var _beta_shelf_count: int = -1
var _beta_back_room_count: int = -1

var _label_scene_path: Label
var _label_controller_state: Label
var _label_focus_owner: Label
var _label_modal_depth: Label
var _label_interactable: Label
var _label_focused_target: Label
var _label_camera_path: Label
var _label_input_focus: Label
var _label_player_path: Label
var _label_store_id: Label
var _label_day: Label
var _label_time: Label
var _label_phase: Label
var _label_money: Label
var _label_customers: Label
var _label_sold_today: Label
var _label_on_shelves: Label
var _label_back_room: Label
var _label_active_objective: Label
var _label_open_modal: Label
var _label_queued_modals: Label
var _checkpoint_labels: Dictionary = {}
var _entry_labels: Array[Label] = []


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 128
	visible = false
	for key: StringName in CHECKPOINTS:
		_results[key] = null
	_build_hud()
	_wire_signals()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug"):
		toggle()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		_refresh_hud()


func toggle() -> void:
	visible = not visible


func pass_check(key: StringName) -> void:
	if _results.get(key) == true:
		return
	_results[key] = true
	print("[AUDIT] %s: PASS" % key)


func fail_check(key: StringName, reason: String = "") -> void:
	_results[key] = false
	var msg := "[AUDIT] %s: FAIL" % key
	if reason:
		msg += " (%s)" % reason
	push_warning(msg)


func all_passed() -> bool:
	for key: StringName in CHECKPOINTS:
		if _results.get(key) != true:
			return false
	return true


func get_results() -> Dictionary:
	return _results.duplicate()


## Called by interactable nodes to surface the last-hovered interactable.
func report_interactable(name: String) -> void:
	_last_interactable = name


func _wire_signals() -> void:
	EventBus.boot_completed.connect(func(): pass_check(&"boot_complete"))
	EventBus.store_entered.connect(func(_sid: StringName): pass_check(&"store_entered"))
	EventBus.panel_opened.connect(func(panel_name: String) -> void:
		if panel_name == "inventory":
			pass_check(&"inventory_open")
	)
	EventBus.item_stocked.connect(
		func(_item_id: String, _shelf_id: String): pass_check(&"shelf_stock")
	)
	EventBus.price_set.connect(
		func(_item_id: String, _price: float): pass_check(&"price_set")
	)
	EventBus.refurbishment_completed.connect(
		func(_iid: String, _ok: bool, _nc: String): pass_check(&"refurb_completed")
	)
	EventBus.transaction_completed.connect(
		func(_amt: float, _ok: bool, _msg: String): pass_check(&"transaction_completed")
	)
	EventBus.day_closed.connect(func(_day: int, _sum: Dictionary): pass_check(&"day_closed"))
	EventBus.customer_left.connect(func(data: Dictionary) -> void:
		if not data.get("satisfied", true) and data.has("reason"):
			pass_check(&"customer_walked")
	)
	EventBus.storefront_zone_entered.connect(func(sid: String): _last_interactable = sid)
	EventBus.storefront_zone_exited.connect(func(_sid: String): _last_interactable = "none")
	EventBus.beta_shelf_count_changed.connect(func(c: int): _beta_shelf_count = c)
	EventBus.beta_backroom_count_changed.connect(func(c: int): _beta_back_room_count = c)


func _build_hud() -> void:
	var full_rect := Control.new()
	full_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	full_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(full_rect)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -(_PANEL_WIDTH + 8.0)
	panel.offset_right = -8.0
	panel.offset_top = 8.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.84)
	bg.set_corner_radius_all(4)
	bg.content_margin_left = 8.0
	bg.content_margin_right = 8.0
	bg.content_margin_top = 6.0
	bg.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override(&"panel", bg)
	full_rect.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vbox)

	var title := _make_label(vbox, "AUDIT OVERLAY  [F3]", 13)
	title.add_theme_color_override(&"font_color", _COLOR_TITLE)

	vbox.add_child(_hline())

	_label_scene_path = _make_label(vbox, "scene: —")
	_label_controller_state = _make_label(vbox, "state: —")
	_label_focus_owner = _make_label(vbox, "focus: —")
	_label_modal_depth = _make_label(vbox, "modal_depth: 0")
	_label_interactable = _make_label(vbox, "interactable: none")
	_label_focused_target = _make_label(vbox, "Focused: NONE")
	_label_camera_path = _make_label(vbox, "camera: —")
	_label_input_focus = _make_label(vbox, "input: gameplay")
	_label_player_path = _make_label(vbox, "player: <none>")
	_label_store_id = _make_label(vbox, "store: —")

	vbox.add_child(_hline())

	_label_day = _make_label(vbox, "Day: —")
	_label_time = _make_label(vbox, "Time: —")
	_label_phase = _make_label(vbox, "Phase: —")
	_label_money = _make_label(vbox, "Money: —")
	_label_customers = _make_label(vbox, "Customers: 0")
	_label_sold_today = _make_label(vbox, "SoldToday: $0")
	_label_on_shelves = _make_label(vbox, "OnShelves: —")
	_label_back_room = _make_label(vbox, "BackRoom: —")
	_label_active_objective = _make_label(vbox, "ActiveObjective: —")
	_label_open_modal = _make_label(vbox, "OpenModal: none")
	_label_queued_modals = _make_label(vbox, "QueuedModals: 0")

	vbox.add_child(_hline())

	for key: StringName in CHECKPOINTS:
		var lbl := _make_label(vbox, "%s: —" % key)
		_checkpoint_labels[key] = lbl

	vbox.add_child(_hline())
	var entries_title := _make_label(vbox, "RECENT AUDIT (last %d)" % _ENTRY_ROWS, 12)
	entries_title.add_theme_color_override(&"font_color", _COLOR_TITLE)
	for i in range(_ENTRY_ROWS):
		_entry_labels.append(_make_label(vbox, "—"))


func _make_label(parent: Control, text: String, font_size: int = 12) -> Label:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	lbl.text = text
	lbl.add_theme_font_size_override(&"font_size", font_size)
	lbl.add_theme_color_override(&"font_color", _COLOR_PENDING)
	parent.add_child(lbl)
	return lbl


func _hline() -> HSeparator:
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_PASS
	return sep


func _refresh_hud() -> void:
	var scene_path := "none"
	if get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path
	_label_scene_path.text = "scene: %s" % scene_path

	_label_controller_state.text = "state: %s" % str(GameManager.current_state)

	var focus := get_viewport().gui_get_focus_owner()
	_label_focus_owner.text = "focus: %s" % (focus.name if focus else "none")

	# Canonical reads from ModalQueue. ModalQueue.active_panel() is the
	# single source of truth for what modal owns the foreground; the
	# overlay reads it directly rather than maintaining a shadow stack.
	var active_panel_name: String = _active_modal_name()
	var queued_count: int = ModalQueue.pending_count()
	var open_count: int = (1 if active_panel_name != "none" else 0) + queued_count
	_label_modal_depth.text = "modal_depth: %d" % open_count
	_label_interactable.text = "interactable: %s" % _last_interactable
	_label_focused_target.text = _build_focused_readout()

	var cam_path: String = "<none>"
	var cam3d: Camera3D = get_viewport().get_camera_3d()
	if cam3d:
		cam_path = str(cam3d.get_path())
	else:
		var cam2d: Camera2D = get_viewport().get_camera_2d()
		if cam2d:
			cam_path = str(cam2d.get_path())
	_label_camera_path.text = "camera: %s" % cam_path

	var input_top: String = "gameplay"
	if active_panel_name != "none":
		input_top = "modal:%s" % active_panel_name
	_label_input_focus.text = "input: %s" % input_top

	var player: Node = get_tree().get_first_node_in_group("player")
	_label_player_path.text = "player: %s" % (str(player.get_path()) if player else "<none>")

	var sid: StringName = GameManager.get_active_store_id()
	_label_store_id.text = "store: %s" % (String(sid) if sid != &"" else "<none>")

	_refresh_braindump_fields(active_panel_name, queued_count)
	_refresh_entries()

	for key: StringName in CHECKPOINTS:
		var lbl: Label = _checkpoint_labels.get(key)
		if not lbl:
			continue
		var result: Variant = _results.get(key)
		if result == true:
			lbl.text = "%s: PASS" % key
			lbl.add_theme_color_override(&"font_color", _COLOR_PASS)
		elif result == false:
			lbl.text = "%s: FAIL" % key
			lbl.add_theme_color_override(&"font_color", _COLOR_FAIL)
		else:
			lbl.text = "%s: —" % key
			lbl.add_theme_color_override(&"font_color", _COLOR_PENDING)


## Refreshes the 11 BRAINDUMP debug-panel fields: Day, Time, Phase, Money,
## Customers, SoldToday, OnShelves, BackRoom, ActiveObjective, OpenModal,
## QueuedModals. Each field gracefully degrades to "—" when its source
## singleton or scene-tree controller is not present (e.g. unit-test
## fixtures), so the overlay is always safe to display.
func _refresh_braindump_fields(active_panel_name: String, queued_count: int) -> void:
	_label_day.text = "Day: %d" % BetaRunState.day

	var time_sys: TimeSystem = GameManager.get_time_system()
	if time_sys != null:
		var minutes: int = int(time_sys.game_time_minutes)
		var hh: int = (minutes / 60) % 24
		var mm: int = minutes % 60
		_label_time.text = "Time: %02d:%02d" % [hh, mm]
		_label_phase.text = "Phase: %s" % _phase_name(time_sys.current_phase)
	else:
		_label_time.text = "Time: —"
		_label_phase.text = "Phase: —"

	var economy: EconomySystem = GameManager.get_economy_system()
	var money: int
	if economy != null:
		money = int(economy.get_cash())
	else:
		money = BetaRunState.cash
	_label_money.text = "Money: $%d" % money

	var ctrl: BetaDayOneController = _beta_controller()
	if ctrl != null:
		var snap: Dictionary = ctrl.get_state_snapshot()
		_label_customers.text = "Customers: %d" % int(snap.get("customers_helped", 0))
		_label_sold_today.text = "SoldToday: $%d" % int(snap.get("sales_today", 0))
		var obj_id: String = String(snap.get("active_objective_id", ""))
		var stage: String = String(snap.get("stage", ""))
		var active_label: String
		if obj_id != "":
			active_label = obj_id
		elif stage != "":
			active_label = stage
		else:
			active_label = "—"
		_label_active_objective.text = "ActiveObjective: %s" % active_label
	else:
		_label_customers.text = "Customers: —"
		_label_sold_today.text = "SoldToday: —"
		_label_active_objective.text = "ActiveObjective: —"

	_label_on_shelves.text = (
		"OnShelves: %d" % _beta_shelf_count
		if _beta_shelf_count >= 0
		else "OnShelves: —"
	)
	_label_back_room.text = (
		"BackRoom: %d" % _beta_back_room_count
		if _beta_back_room_count >= 0
		else "BackRoom: —"
	)

	_label_open_modal.text = "OpenModal: %s" % active_panel_name
	_label_queued_modals.text = "QueuedModals: %d" % queued_count


func _phase_name(phase: int) -> String:
	if _PHASE_NAMES.has(phase):
		return String(_PHASE_NAMES[phase])
	# §EH-40 — Drift surface, mirrors EventLog._format_message
	# default arm. A new TimeSystem.DayPhase value reaching this
	# function is a wiring drift the audit overlay should surface
	# instead of silently swallowing as "UNKNOWN".
	if OS.is_debug_build():
		push_warning(
			(
				"AuditOverlay._phase_name: unmapped DayPhase '%d' "
				+ "— rendering as 'UNKNOWN'. Add the phase to the "
				+ "match in audit_overlay.gd."
			) % phase
		)
	return "UNKNOWN"


## Locates the Day-1 controller via its `beta_day_one_controller` group
## registration. Returns null in unit-test fixtures where the controller is
## not in the scene tree — callers degrade to "—" for the affected fields.
func _beta_controller() -> BetaDayOneController:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var node: Node = tree.get_first_node_in_group("beta_day_one_controller")
	if node is BetaDayOneController:
		return node as BetaDayOneController
	return null


## Reads the currently-active panel name from `ModalQueue` — canonical
## singleton source for the "OpenModal" debug field. Returns "none" when
## no modal is active.
func _active_modal_name() -> String:
	var active: ModalPanel = ModalQueue.active_panel()
	if active != null and is_instance_valid(active):
		return String(active.name)
	return "none"


## Reads the cursor-driven hover state from any InteractionRay registered in
## the `interaction_ray` group and formats the audit readout. Returns
## "Focused: NONE" when no ray is present or no target is hovered.
func _build_focused_readout() -> String:
	var ray: Node = get_tree().get_first_node_in_group(&"interaction_ray")
	if ray == null:
		return "Focused: NONE"
	var target: Interactable = ray.get_hovered_target()
	if target == null or not is_instance_valid(target):
		return "Focused: NONE"
	var target_name: String = target.display_name.strip_edges()
	if target_name.is_empty():
		target_name = String(target.name)
	var distance: float = ray.get_hovered_camera_distance()
	var distance_text: String = "?"
	if distance >= 0.0:
		distance_text = "%.1f" % distance
	var action_label: String = ray.get_hovered_action_label()
	if action_label.is_empty():
		action_label = "—"
	return "Focused: %s (%sm) / %s" % [target_name, distance_text, action_label]


func _refresh_entries() -> void:
	var entries: Array[Dictionary] = AuditLog.recent(_ENTRY_ROWS)
	var n: int = entries.size()
	for i in range(_ENTRY_ROWS):
		var lbl: Label = _entry_labels[i]
		if i >= n:
			lbl.text = "—"
			lbl.add_theme_color_override(&"font_color", _COLOR_PENDING)
			continue
		var entry: Dictionary = entries[n - 1 - i]
		var status: String = String(entry.get("status", ""))
		var checkpoint: StringName = entry.get("checkpoint", &"")
		if status == "PASS":
			var detail: String = String(entry.get("detail", ""))
			lbl.text = "PASS %s%s" % [checkpoint, (" " + detail) if detail != "" else ""]
			lbl.add_theme_color_override(&"font_color", _COLOR_PASS)
		else:
			var reason: String = String(entry.get("reason", ""))
			lbl.text = "FAIL %s%s" % [checkpoint, (" " + reason) if reason != "" else ""]
			lbl.add_theme_color_override(&"font_color", _COLOR_FAIL)
