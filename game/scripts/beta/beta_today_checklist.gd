## Compact bottom-right "Today" checklist for the beta day-1 loop.
##
## Renders only the *active* and *recently-completed* day-1 chain
## objectives — future steps are hidden until the chain advances to them,
## so the checklist mirrors the ObjectiveRail step-state model
## (completed / active / future) instead of front-loading the whole chain
## at Day 1 start. Distinct from ObjectiveRail (which surfaces the single
## active "do this now" beat with a key chip + the full step preview as
## small slots) — this panel is the bottom-right glanceable tracker that
## never shows future work.
##
## Active rows render as `• Label`; just-completed rows briefly show as
## `✓ Label` for `COMPLETION_HOLD_SECONDS`, then collapse off the list.
## On `_ready` and `EventBus.day_started` the panel seeds the active
## row only; subsequent rows appear as the chain advances via
## `EventBus.objective_changed` (which carries the multi-step `steps`
## payload from BetaDayOneController).
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
	# Lifts a row out of "future" hidden state when its objective becomes
	# the active beat. The payload's `steps` array is the SSOT for which
	# row owns the `active` slot — see BetaDayOneController._build_steps_payload.
	EventBus.objective_changed.connect(_on_objective_changed)


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
	# Day starts with only the first chain entry surfaced — every later row
	# stays hidden until ObjectiveDirector / BetaDayOneController flips it
	# to "active" via the objective_changed steps payload. Using the first
	# `_OBJECTIVES` row as the seed mirrors the chain's authoritative order
	# and keeps the no-rebuild fallback (set_objectives outside the beta
	# loop) showing a sensible single starting beat.
	if _objectives.is_empty():
		return
	var first_entry: Dictionary = _objectives[0]
	var first_id: StringName = StringName(str(first_entry.get("id", "")))
	if String(first_id).is_empty():
		return
	_surface_row(first_id)


## Adds the row for `objective_id` to the visible list as a pending bullet
## if it is not already present. Idempotent — re-surfacing a row that is
## already visible (or already completed) is a no-op so the active step
## staying active across multiple objective_changed emissions does not
## flicker the UI.
func _surface_row(objective_id: StringName) -> void:
	if String(objective_id).is_empty():
		return
	if _container == null:
		return
	if _item_labels.has(objective_id):
		return
	var entry: Dictionary = _entry_for(objective_id)
	if entry.is_empty():
		return
	var label: Label = Label.new()
	label.name = "Item_%s" % String(objective_id)
	label.text = "%s %s" % [_BULLET, _short_label(entry)]
	label.add_theme_font_size_override("font_size", _ITEM_FONT_SIZE)
	label.add_theme_color_override("font_color", _PENDING_COLOR)
	_container.add_child(label)
	_item_labels[objective_id] = label


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
	label.add_theme_color_override("font_color", BetaModalTheme.COLOR_ACCENT)
	var timer: SceneTreeTimer = get_tree().create_timer(COMPLETION_HOLD_SECONDS)
	timer.timeout.connect(_collapse_item.bind(objective_id))


## Tracks the rail's `steps` payload so a chain advance lifts the next
## row out of hidden-future state without re-seeding the whole list.
## Walks the steps array and surfaces every entry whose state is `active`
## or `completed`. Pure-future payloads (e.g. STAGE_VIC_NOTE before the
## chain starts) leave the panel showing only the seeded first row, so
## the player never sees the full Day-1 chain at once.
func _on_objective_changed(payload: Dictionary) -> void:
	var steps: Array = payload.get("steps", []) as Array
	if steps.is_empty():
		return
	for step: Dictionary in steps:
		var state: String = str(step.get("state", "future"))
		if state == "future":
			continue
		var step_text: String = str(step.get("text", ""))
		var entry_id: StringName = _objective_id_for_text(step_text)
		if String(entry_id).is_empty():
			continue
		_surface_row(entry_id)


## Reverse-lookup helper — `steps` payload entries carry `text` only, so
## we resolve back to the `_OBJECTIVES` row id by matching the label.
## Returns an empty StringName when no row matches (e.g. a payload from
## outside the beta chain).
func _objective_id_for_text(step_text: String) -> StringName:
	for entry: Dictionary in _objectives:
		if String(entry.get("label", "")) == step_text:
			return StringName(str(entry.get("id", "")))
	return StringName("")


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
