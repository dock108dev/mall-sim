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

## Modal-fade contract — mirrors hud.gd `_MODAL_DIM_ALPHA`. When CTX_MODAL
## is on top of the InputFocus stack the checklist alpha drops so the
## active modal owns the foreground. Calibrated against
## `ModalDimOverlay.DIM_COLOR.a` so the composed visible opacity stays
## legible (0.65 × 0.6 ≈ 0.39).
const _MODAL_DIM_ALPHA: float = 0.65

const _BULLET: String = "•"
const _CHECK: String = "✓"

const _HEADER_FONT_SIZE: int = 16
const _ITEM_FONT_SIZE: int = 13
const _ROW_MIN_HEIGHT: float = 24.0
const _PADDING: int = 12

## Header row — full white, matches HUD FP primary tier.
const _HEADER_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
## Pending row — 60% white, matches HUD FP secondary tier.
const _PENDING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
## Completed row glyph — neon green, mirrors retro `sign_backing_mat`.
const _COMPLETED_COLOR: Color = Color(0.3, 1.0, 0.5)
## Semi-transparent dark-indigo backing — same swatch as BetaTodayStatsPanel.
const _PANEL_BG: Color = Color(0.08, 0.08, 0.14, 0.88)

var _container: VBoxContainer
var _header: Label
var _background: ColorRect
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
	# Mirror hud.gd's modal-dim pattern so the day-end / decision modals dim
	# the passive checklist while the foreground modal owns CTX_MODAL.
	InputFocus.context_changed.connect(_on_input_focus_changed)
	EventBus.fp_mode_changed.connect(_on_fp_mode_changed)


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

	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = _PANEL_BG
	_background.anchor_left = 0.0
	_background.anchor_top = 0.0
	_background.anchor_right = 1.0
	_background.anchor_bottom = 1.0
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_background)

	# 12 px inner padding on all sides so content never sits flush against
	# the panel edge — matches BetaTodayStatsPanel padding.
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.anchor_left = 0.0
	margin.anchor_top = 0.0
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", _PADDING)
	margin.add_theme_constant_override("margin_top", _PADDING)
	margin.add_theme_constant_override("margin_right", _PADDING)
	margin.add_theme_constant_override("margin_bottom", _PADDING)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(margin)

	_container = VBoxContainer.new()
	_container.name = "Container"
	_container.add_theme_constant_override("separation", 4)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_container)

	_header = Label.new()
	_header.name = "Header"
	_header.text = "Today"
	_header.custom_minimum_size = Vector2(0.0, _ROW_MIN_HEIGHT)
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
	label.custom_minimum_size = Vector2(0.0, _ROW_MIN_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	label.add_theme_color_override("font_color", _COMPLETED_COLOR)
	var timer: SceneTreeTimer = get_tree().create_timer(COMPLETION_HOLD_SECONDS)
	timer.timeout.connect(_collapse_item.bind(objective_id))


## Tracks the rail's `steps` payload so a chain advance lifts the next
## row out of hidden-future state without re-seeding the whole list.
## Walks the steps array and surfaces every entry whose state is `active`
## or `completed`. Pure-future payloads (e.g. STAGE_VIC_NOTE before the
## chain starts) leave the panel showing only the seeded first row, so
## the player never sees the full Day-1 chain at once.
##
## Matching is by `step.id` — `BetaDayOneController._build_steps_payload`
## is the only emitter of `objective_changed` payloads that include a
## `steps` array, and it always sets `id` on every entry.
##
## §EH-40 — A non-future step that arrives with no `id`, or with an `id`
## that does not match any seeded `_objectives` entry, is a contract drift
## between the rail-payload emitter and the checklist's `set_objectives`
## seed. Silently dropping those rows shipped a broken Today panel with no
## diagnostic; the debug-build `push_warning` calls below surface the
## drift in QA logs while the production path keeps the panel safe to
## render.
func _on_objective_changed(payload: Dictionary) -> void:
	var steps: Array = payload.get("steps", []) as Array
	if steps.is_empty():
		return
	for step: Dictionary in steps:
		var state: String = str(step.get("state", "future"))
		if state == "future":
			continue
		var entry_id: StringName = StringName(str(step.get("id", "")))
		if String(entry_id).is_empty():
			if OS.is_debug_build():
				push_warning(
					(
						"BetaTodayChecklist: dropped non-future step with "
						+ "empty 'id' (state=%s, text=%s). The emitter "
						+ "must set `id` on every step in "
						+ "`_build_steps_payload`."
					) % [state, str(step.get("text", ""))]
				)
			continue
		if not _has_entry(entry_id):
			if OS.is_debug_build():
				push_warning(
					(
						"BetaTodayChecklist: step id '%s' not present in "
						+ "seeded `_objectives`; row dropped. Verify "
						+ "`set_objectives()` was called with a list "
						+ "containing this id before the rail emit."
					) % String(entry_id)
				)
			continue
		_surface_row(entry_id)


func _has_entry(objective_id: StringName) -> bool:
	for entry: Dictionary in _objectives:
		if StringName(str(entry.get("id", ""))) == objective_id:
			return true
	return false


func _on_input_focus_changed(new_ctx: StringName, _old_ctx: StringName) -> void:
	var target: float = (
		_MODAL_DIM_ALPHA if new_ctx == InputFocus.CTX_MODAL else 1.0
	)
	for child: Node in get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = target


## Hide the entire checklist while the player is in first-person mode —
## the FP corner overlays in hud.gd already surface the relevant
## glanceable info, and the checklist would visually compete with the
## ObjectiveRail step preview.
func _on_fp_mode_changed(enabled: bool) -> void:
	visible = not enabled


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
