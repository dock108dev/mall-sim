## Debug autoload for headless interaction audit. Stripped to no-op in release builds.
## Connects to EventBus signals to auto-instrument the five required checkpoints.
## F3 (toggle_debug action) toggles visibility; overlay never eats gameplay input.
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

var _results: Dictionary = {}
var _modal_stack: Array[String] = []
var _last_interactable: String = "none"

var _label_scene_path: Label
var _label_controller_state: Label
var _label_focus_owner: Label
var _label_modal_depth: Label
var _label_interactable: Label
var _checkpoint_labels: Dictionary = {}


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


## Called by modal-presenting systems so the depth counter stays accurate.
func push_modal(name: String) -> void:
	_modal_stack.push_back(name)


func pop_modal() -> void:
	if not _modal_stack.is_empty():
		_modal_stack.pop_back()


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

	vbox.add_child(_hline())

	for key: StringName in CHECKPOINTS:
		var lbl := _make_label(vbox, "%s: —" % key)
		_checkpoint_labels[key] = lbl


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

	_label_modal_depth.text = "modal_depth: %d" % _modal_stack.size()
	_label_interactable.text = "interactable: %s" % _last_interactable

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
