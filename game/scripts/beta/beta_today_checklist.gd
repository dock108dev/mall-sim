## Compact bottom-right "Today" checklist for the beta day-1 loop.
##
## Renders every day-1 chain objective simultaneously: pending items show
## as `• Label`, just-completed items briefly show as `✓ Label` for
## `COMPLETION_HOLD_SECONDS`, then collapse off the list. Distinct from
## ObjectiveRail (which surfaces the single active "do this now" beat
## with a key chip) — this panel is a glanceable progress tracker, not
## an instruction. The list is never empty before any objective is
## complete: every chain entry seeds as a pending bullet on `_ready` and
## on `EventBus.day_started`.
##
## Replaces the bleed-through corner footprint of the suppressed
## MomentsTray for beta runs. Owned by `BetaDayOneController` (spawned in
## `_ensure_panels`); not an autoload.
class_name BetaTodayChecklist
extends CanvasLayer

## Time the green ✓ stays on screen before the row collapses out of the list.
const COMPLETION_HOLD_SECONDS: float = 2.0

## CanvasLayer ordering — sits below ModalDimOverlay (49) so day-end /
## decision modals dim it, and below ObjectiveRail (40) so the rail's
## active-step chip always wins over a passive checklist row.
const LAYER_INDEX: int = 30

const _BULLET: String = "•"
const _CHECK: String = "✓"

const _HEADER_FONT_SIZE: int = 14
const _ITEM_FONT_SIZE: int = 13
const _HEADER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const _PENDING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.7)
const _COMPLETE_COLOR: Color = Color(0.65, 0.92, 0.65, 0.95)

var _container: VBoxContainer
var _header: Label
var _item_labels: Dictionary = {}
var _completed_ids: Dictionary = {}
var _objectives: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("beta_today_checklist")
	layer = LAYER_INDEX
	_build_panel()
	_rebuild_items()
	# §EH-13 — `beta_objective_completed` and `day_started` are declared in
	# `event_bus.gd`; the prior `has_signal` guards turned a signal-rename
	# regression into a silent unsubscribe. Connect unconditionally so a
	# rename fails at parse time on the EventBus.
	EventBus.beta_objective_completed.connect(_on_beta_objective_completed)
	EventBus.day_started.connect(_on_day_started)


## Sets the chain entries the checklist will display. Each entry is the
## same dict shape `BetaDayOneController._OBJECTIVES` uses — only `id`,
## `action`, and `label` are read here. Safe to call before or after
## `_ready`: the panel rebuilds on the next frame either way.
func set_objectives(objectives: Array[Dictionary]) -> void:
	_objectives = objectives.duplicate()
	if _container != null:
		_rebuild_items()


## Read-only count of currently-rendered item rows (excludes the header).
## Test seam — production callers don't need this.
func get_visible_item_count() -> int:
	var count: int = 0
	for label: Label in _item_labels.values():
		if is_instance_valid(label) and label.visible:
			count += 1
	return count


## Returns the bullet/check glyph currently rendered for the given id, or
## an empty string if the row is no longer present (collapsed). Test seam.
func get_item_glyph(objective_id: StringName) -> String:
	var label: Label = _item_labels.get(objective_id) as Label
	if label == null or not is_instance_valid(label):
		return ""
	var text: String = label.text
	if text.begins_with(_CHECK):
		return _CHECK
	if text.begins_with(_BULLET):
		return _BULLET
	return ""


func _build_panel() -> void:
	var anchor: Control = Control.new()
	anchor.name = "Anchor"
	anchor.anchor_left = 1.0
	anchor.anchor_top = 1.0
	anchor.anchor_right = 1.0
	anchor.anchor_bottom = 1.0
	anchor.offset_left = -260.0
	anchor.offset_top = -260.0
	anchor.offset_right = -16.0
	anchor.offset_bottom = -110.0
	anchor.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	_container = VBoxContainer.new()
	_container.name = "Container"
	_container.anchor_left = 0.0
	_container.anchor_top = 0.0
	_container.anchor_right = 1.0
	_container.anchor_bottom = 1.0
	_container.add_theme_constant_override("separation", 4)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_container)

	_header = Label.new()
	_header.name = "Header"
	_header.text = "Today"
	_header.add_theme_font_size_override("font_size", _HEADER_FONT_SIZE)
	_header.add_theme_color_override("font_color", _HEADER_COLOR)
	_container.add_child(_header)


func _rebuild_items() -> void:
	if _container == null:
		return
	for child: Node in _container.get_children():
		if child == _header:
			continue
		child.queue_free()
	_item_labels.clear()
	_completed_ids.clear()
	for entry: Dictionary in _objectives:
		var obj_id: StringName = StringName(str(entry.get("id", "")))
		if String(obj_id).is_empty():
			continue
		var label: Label = Label.new()
		label.name = "Item_%s" % String(obj_id)
		label.text = "%s %s" % [_BULLET, _short_label(entry)]
		label.add_theme_font_size_override("font_size", _ITEM_FONT_SIZE)
		label.add_theme_color_override("font_color", _PENDING_COLOR)
		_container.add_child(label)
		_item_labels[obj_id] = label


## Pulls the per-row copy from the chain entry. Prefers the short
## `action` verb ("Talk to the customer") over the long `label`
## ("Day 1: Help the customer at the register.") so the checklist reads
## as a tracker rather than a duplicate of the rail. Strips a leading
## "Day 1: " prefix from the label fallback so the header's "Today" is
## not echoed by every row.
func _short_label(entry: Dictionary) -> String:
	var action: String = str(entry.get("action", "")).strip_edges()
	if not action.is_empty():
		return action
	var raw: String = str(entry.get("label", "")).strip_edges()
	const _PREFIX: String = "Day 1: "
	if raw.begins_with(_PREFIX):
		raw = raw.substr(_PREFIX.length())
	return raw


func _on_beta_objective_completed(objective_id: StringName) -> void:
	if not _item_labels.has(objective_id):
		return
	if _completed_ids.has(objective_id):
		return
	var label: Label = _item_labels[objective_id] as Label
	if not is_instance_valid(label):
		return
	_completed_ids[objective_id] = true
	var entry: Dictionary = _entry_for(objective_id)
	label.text = "%s %s" % [_CHECK, _short_label(entry)]
	label.add_theme_color_override("font_color", _COMPLETE_COLOR)
	var timer: SceneTreeTimer = get_tree().create_timer(COMPLETION_HOLD_SECONDS)
	timer.timeout.connect(_collapse_item.bind(objective_id))


func _collapse_item(objective_id: StringName) -> void:
	var label: Label = _item_labels.get(objective_id) as Label
	if label != null and is_instance_valid(label):
		label.queue_free()
	_item_labels.erase(objective_id)


func _entry_for(objective_id: StringName) -> Dictionary:
	for entry: Dictionary in _objectives:
		if StringName(str(entry.get("id", ""))) == objective_id:
			return entry
	return {}


func _on_day_started(_day: int) -> void:
	_rebuild_items()
