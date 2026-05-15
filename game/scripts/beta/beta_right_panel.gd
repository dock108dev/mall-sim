## Unified right-anchored "Today" panel for the beta Day-1 loop.
##
## Merges the previous `BetaTodayStatsPanel` (top-right stats) and
## `BetaTodayChecklist` (bottom-right objectives) into a single
## content-driven panel anchored to the top-right of the viewport. Internal
## column layout:
##
## 1. day-title label (`DAY N — PHASE`)
## 2. "STORE" section label
## 3. four stat rows (On Shelves, Back Room, Customers, Sold Today)
## 4. "TODAY" section label
## 5. objective checklist rows — full chain seeded at construction; each
##    row paints as ● (active, amber), ○ (future, ~0.5 alpha), or ✓
##    (completed, green) for the brief hold + collapse animation.
##
## By design the panel has no unlock-grant surface and no recent-events
## section — unlock toasts belong to `ToastNotificationUI`, not a
## persistent HUD panel. Per the beta UI contract: anything in this panel
## represents either current store state (STORE) or the active chain beat
## (TODAY); ephemeral notifications are not allowed to take up persistent
## screen real estate here.
##
## Visible from Day 1 start: seeds its header from `BetaRunState.day` and
## populates every chain row at `_ready` so the player sees the full
## tutorial outline up front. Stays visible across the FP-mode toggle —
## the HUD no longer reparents stat labels into corner overlays, so the
## panel is the sole stat surface in both modes. Dims under `CTX_MODAL`
## via the same alpha contract as `hud.gd`.
##
## Height is content-driven: a `PanelContainer` measures the inner
## `VBoxContainer`'s minimum size each `NOTIFICATION_SORT_CHILDREN` and
## resizes the background fill to match — no empty slab below the last
## visible row.
##
## Owned by the `BetaHUD` autoload (spawned in `BetaHUD._ready`); the day
## controller calls `BetaHUD.activate(day)` so the panel survives a
## controller teardown across day transitions.
class_name BetaRightPanel
extends CanvasLayer

## Time the green ✓ stays on screen before the checklist row collapses.
const COMPLETION_HOLD_SECONDS: float = 2.0

## Duration of the row-collapse tween that runs after the completion hold.
## Reduces the row's `custom_minimum_size.y` from natural height to 0 so the
## PanelContainer reflows smoothly instead of popping when the row is freed.
const COLLAPSE_DURATION_SECONDS: float = 0.3

## CanvasLayer ordering — sits below `ModalDimOverlay` (49) so day-end and
## decision modals dim it, and below `ObjectiveRail` (40) so the rail's
## active-step chip always wins over a passive panel row.
const LAYER_INDEX: int = 30

## Modal-fade contract — mirrors `hud.gd._MODAL_DIM_ALPHA`. Calibrated
## against `ModalDimOverlay.DIM_COLOR.a` so the composed visible opacity
## stays legible (0.65 × 0.6 ≈ 0.39).
const _MODAL_DIM_ALPHA: float = 0.65

## Glyphs for checklist row state — matches the rail's three-state model.
const _ACTIVE_GLYPH: String = "●"   # ●
const _FUTURE_GLYPH: String = "○"   # ○
const _CHECK: String = "✓"          # ✓

## Visual contract (shared across the beta HUD design family — same as
## `BetaEventLogPanel._PANEL_BG`).
const _PANEL_BG: Color = Color(0.08, 0.08, 0.14, 0.88)
const _HEADER_FONT_SIZE: int = 16
const _SECTION_FONT_SIZE: int = 12
const _ROW_FONT_SIZE: int = 13
const _ROW_MIN_HEIGHT: float = 24.0
const _SECTION_MIN_HEIGHT: float = 18.0
const _PADDING: int = 12
const _PANEL_WIDTH: float = 244.0
const _RIGHT_INSET: float = 16.0
const _TOP_INSET: float = 56.0

const _HEADER_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const _ROW_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
const _SECTION_COLOR: Color = Color(1.0, 1.0, 1.0, 0.45)
const _COMPLETED_COLOR: Color = Color(0.3, 1.0, 0.5)
## Future steps render at ~0.5 alpha so the active row is the unambiguous
## focal point. The active step uses `UIThemeConstants.ACCENT_COLOR_AMBER`
## directly at the call site — single source of truth for the amber tone.
const _FUTURE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.5)

## Maps `TimeSystem.DayPhase` to a short uppercase phase tag for the
## header. Independent of the locale CSV so the panel reads as a tight
## "DAY 1 — MORNING" tag even in locales that ship longer phase strings.
##
## §EH-40 — Must cover every value in `TimeSystem.DayPhase`; a missing
## entry falls through to "UNKNOWN" with a debug-build warning so drift
## surfaces in QA logs instead of silently rendering the wrong phase.
const _PHASE_NAMES: Dictionary = {
	TimeSystem.DayPhase.PRE_OPEN: "OPENING",
	TimeSystem.DayPhase.MORNING_RAMP: "MORNING",
	TimeSystem.DayPhase.MIDDAY_RUSH: "MIDDAY",
	TimeSystem.DayPhase.AFTERNOON: "AFTERNOON",
	TimeSystem.DayPhase.EVENING: "EVENING",
	TimeSystem.DayPhase.LATE_EVENING: "LATE EVENING",
}

var _column: VBoxContainer
var _header: Label
var _on_shelves_value: Label
var _back_room_value: Label
var _customers_value: Label
var _sold_today_value: Label

## Checklist rows live as direct children of `_column` after the "TODAY"
## section label. Tracked separately from the stats rows so day-reset and
## row-collapse logic only touches the objective rows.
var _checklist_anchor: Label
var _item_labels: Dictionary = {}
## Per-row visual state, keyed by objective id: "future", "active", or
## "completed". `_apply_row_state` is the single writer.
var _row_states: Dictionary = {}
var _completed_ids: Dictionary = {}
## Active collapse tweens, keyed by objective id. Tracked so a freed panel
## or a re-seed can kill in-flight tweens before their callbacks fire.
var _collapse_tweens: Dictionary = {}
var _objectives: Array[Dictionary] = []

var _current_day: int = 1
var _current_phase: TimeSystem.DayPhase = TimeSystem.DayPhase.PRE_OPEN
## Mirror of `hud.gd._customers_served_today_count` — increments on
## `customer_purchased`, resets on `day_started`.
var _customers_served_today: int = 0
var _on_shelves_count: int = 0
var _back_room_count: int = 0
var _sold_today_count: int = 0


func _ready() -> void:
	add_to_group("beta_right_panel")
	layer = LAYER_INDEX
	_build_panel()
	_seed_initial_state()
	_refresh_header()
	_refresh_all_values()
	_rebuild_items()
	# §EH-13 — every signal is owner-declared on EventBus, so direct typed
	# connection mirrors the dead-guard avoidance pattern and turns a
	# rename into a parse-time failure.
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.beta_shelf_count_changed.connect(_on_beta_shelf_count_changed)
	EventBus.beta_backroom_count_changed.connect(_on_beta_backroom_count_changed)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.beta_objective_completed.connect(_on_beta_objective_completed)
	EventBus.objective_changed.connect(_on_objective_changed)
	InputFocus.context_changed.connect(_on_input_focus_changed)


func _build_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	# Top-right anchor only — `anchor_bottom = 0.0` plus `grow_vertical =
	# GROW_DIRECTION_END` lets the PanelContainer's combined minimum size
	# drive the rendered height. No empty slab below the last row.
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -(_PANEL_WIDTH + _RIGHT_INSET)
	panel.offset_top = _TOP_INSET
	panel.offset_right = -_RIGHT_INSET
	panel.offset_bottom = _TOP_INSET
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = _PANEL_BG
	style.content_margin_left = float(_PADDING)
	style.content_margin_top = float(_PADDING)
	style.content_margin_right = float(_PADDING)
	style.content_margin_bottom = float(_PADDING)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.add_theme_constant_override("separation", 4)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_column)

	_header = Label.new()
	_header.name = "Header"
	_header.custom_minimum_size = Vector2(0.0, _ROW_MIN_HEIGHT)
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_theme_font_size_override("font_size", _HEADER_FONT_SIZE)
	_header.add_theme_color_override("font_color", _HEADER_COLOR)
	_column.add_child(_header)

	_build_section_label("StoreSection", "STORE")
	_on_shelves_value = _build_stat_row("On Shelves")
	_back_room_value = _build_stat_row("Back Room")
	_customers_value = _build_stat_row("Customers")
	_sold_today_value = _build_stat_row("Sold Today")

	_checklist_anchor = _build_section_label("TodaySection", "TODAY")


func _build_section_label(node_name: String, text: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.custom_minimum_size = Vector2(0.0, _SECTION_MIN_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _SECTION_FONT_SIZE)
	label.add_theme_color_override("font_color", _SECTION_COLOR)
	_column.add_child(label)
	return label


## Adds a `label : value` row to the column and returns the value Label so
## the caller can hold a reference for live updates.
func _build_stat_row(label_text: String) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row_%s" % label_text.replace(" ", "")
	row.custom_minimum_size = Vector2(0.0, _ROW_MIN_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(row)

	var label: Label = Label.new()
	label.name = "Label"
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _ROW_FONT_SIZE)
	label.add_theme_color_override("font_color", _ROW_COLOR)
	row.add_child(label)

	var value: Label = Label.new()
	value.name = "Value"
	value.text = "0"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", _ROW_FONT_SIZE)
	value.add_theme_color_override("font_color", _ROW_COLOR)
	row.add_child(value)
	return value


## Sets the chain entries the checklist section will display. Each entry
## matches the dict shape `BetaDayOneController._objectives` uses — only
## `id`, `action`, and `label` are read here. Safe to call before or after
## `_ready`: the panel rebuilds when the column is constructed.
func set_objectives(objectives: Array[Dictionary]) -> void:
	_objectives = objectives.duplicate()
	if _column != null:
		_rebuild_items()


## Public reseed entry point for `BetaHUD.activate(day)`. Resets the
## per-day stat counters to the same baseline `_on_day_started` would
## install, refreshes the header, pulls a fresh objective chain from the
## active `BetaDayOneController` (group `beta_day_one_controller`), and
## rebuilds the checklist rows. Idempotent — repeated calls with the same
## `day` and the same active controller produce the same rendered state.
##
## Persistent inventory counters (on-shelves / back-room) are deliberately
## not reset: they are run-wide state that the controller re-emits across
## a day transition via `beta_shelf_count_changed` / `beta_backroom_count_changed`.
func seed_for_day(day: int) -> void:
	_current_day = day
	_customers_served_today = 0
	_sold_today_count = 0
	var controller: Node = get_tree().get_first_node_in_group(
		"beta_day_one_controller"
	)
	if controller != null:
		var objs: Variant = controller.get("_objectives")
		if objs is Array:
			var typed: Array[Dictionary] = []
			for entry: Variant in objs as Array:
				if entry is Dictionary:
					typed.append(entry as Dictionary)
			_objectives = typed
	_refresh_header()
	_refresh_all_values()
	_rebuild_items()


func _seed_initial_state() -> void:
	_current_day = BetaRunState.day
	_customers_served_today = 0
	_on_shelves_count = 0
	_back_room_count = 0
	_sold_today_count = 0


func _refresh_header() -> void:
	if _header == null:
		return
	# §EH-40 — Drift surface for `TimeSystem.DayPhase`. A missing entry
	# previously shipped the late-evening case as "DAY N — MORNING"
	# because `_PHASE_NAMES` was missing the LATE_EVENING key. The
	# push_warning + "UNKNOWN" fallback makes any future drift loud in
	# QA logs while keeping the panel safe to render.
	var phase_name: String
	if _PHASE_NAMES.has(_current_phase):
		phase_name = str(_PHASE_NAMES[_current_phase])
	else:
		if OS.is_debug_build():
			push_warning(
				(
					"BetaRightPanel: unmapped TimeSystem.DayPhase '%d' "
					+ "— rendering as 'UNKNOWN'. Add the phase to "
					+ "`_PHASE_NAMES` in beta_right_panel.gd."
				) % int(_current_phase)
			)
		phase_name = "UNKNOWN"
	_header.text = "DAY %d — %s" % [_current_day, phase_name]


func _refresh_all_values() -> void:
	if _on_shelves_value != null:
		_on_shelves_value.text = str(_on_shelves_count)
	if _back_room_value != null:
		_back_room_value.text = str(_back_room_count)
	if _customers_value != null:
		_customers_value.text = str(_customers_served_today)
	if _sold_today_value != null:
		_sold_today_value.text = str(_sold_today_count)


# ── Checklist section ──────────────────────────────────────────────────────


## Clears any existing item rows and seeds the full chain — every entry
## becomes a row at construction. The first row paints as active (●,
## amber), the rest as future (○, muted, ~0.5 alpha). Subsequent
## `objective_changed` payloads reshuffle which row is active; explicit
## completion goes through `_on_beta_objective_completed`.
func _rebuild_items() -> void:
	if _column == null:
		return
	for tween: Tween in _collapse_tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()
	_collapse_tweens.clear()
	for objective_id: StringName in _item_labels.keys():
		var label: Label = _item_labels[objective_id] as Label
		if is_instance_valid(label):
			label.queue_free()
	_item_labels.clear()
	_completed_ids.clear()
	_row_states.clear()
	if _objectives.is_empty():
		return
	for index: int in range(_objectives.size()):
		var entry: Dictionary = _objectives[index]
		var entry_id: StringName = StringName(str(entry.get("id", "")))
		if String(entry_id).is_empty():
			continue
		var initial_state: String = "active" if index == 0 else "future"
		_create_row(entry_id, initial_state)


## Creates the row Label for `objective_id` and stamps the requested
## state. Idempotent — re-creating an existing row is a no-op.
func _create_row(objective_id: StringName, state: String) -> void:
	if String(objective_id).is_empty():
		return
	if _column == null:
		return
	if _item_labels.has(objective_id):
		return
	var entry: Dictionary = _entry_for(objective_id)
	if entry.is_empty():
		return
	var label: Label = Label.new()
	label.name = "Item_%s" % String(objective_id)
	label.custom_minimum_size = Vector2(0.0, _ROW_MIN_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _ROW_FONT_SIZE)
	# Clip during the collapse tween so shrinking row height does not
	# bleed text into the row above.
	label.clip_text = true
	_column.add_child(label)
	_item_labels[objective_id] = label
	_apply_row_state(objective_id, state)


## Single writer for row glyph + color. State is one of
## "future" / "active" / "completed". Skips rows whose collapse tween is
## already in flight so the post-completion shrink is not interrupted.
func _apply_row_state(objective_id: StringName, state: String) -> void:
	var label: Label = _item_labels.get(objective_id) as Label
	if not is_instance_valid(label):
		return
	var entry: Dictionary = _entry_for(objective_id)
	var short: String = _short_label(entry)
	_row_states[objective_id] = state
	match state:
		"active":
			label.text = "%s %s" % [_ACTIVE_GLYPH, short]
			label.add_theme_color_override(
				"font_color", UIThemeConstants.ACCENT_COLOR_AMBER
			)
		"completed":
			label.text = "%s %s" % [_CHECK, short]
			label.add_theme_color_override("font_color", _COMPLETED_COLOR)
		_:
			label.text = "%s %s" % [_FUTURE_GLYPH, short]
			label.add_theme_color_override("font_color", _FUTURE_COLOR)


## Pulls the per-row copy from the chain entry. Prefers the short
## `action` verb ("Talk to the customer") over the long `label` so the
## checklist reads as a tracker.
func _short_label(entry: Dictionary) -> String:
	var action: String = str(entry.get("action", "")).strip_edges()
	if not action.is_empty():
		return action
	return str(entry.get("label", "")).strip_edges()


func _entry_for(objective_id: StringName) -> Dictionary:
	for entry: Dictionary in _objectives:
		if StringName(str(entry.get("id", ""))) == objective_id:
			return entry
	return {}


func _has_entry(objective_id: StringName) -> bool:
	for entry: Dictionary in _objectives:
		if StringName(str(entry.get("id", ""))) == objective_id:
			return true
	return false


# ── Signal handlers ────────────────────────────────────────────────────────


func _on_day_started(day: int) -> void:
	_current_day = day
	_customers_served_today = 0
	_sold_today_count = 0
	# Shelf / back-room counts are not reset here — they are persistent
	# inventory state that the controller re-emits explicitly on day reset.
	_refresh_header()
	_refresh_all_values()
	_rebuild_items()


func _on_day_phase_changed(new_phase: int) -> void:
	_current_phase = new_phase as TimeSystem.DayPhase
	_refresh_header()


func _on_beta_shelf_count_changed(count: int) -> void:
	_on_shelves_count = count
	if _on_shelves_value != null:
		_on_shelves_value.text = str(count)


func _on_beta_backroom_count_changed(count: int) -> void:
	_back_room_count = count
	if _back_room_value != null:
		_back_room_value.text = str(count)


func _on_customer_purchased(
	_store_id: StringName, _item_id: StringName,
	_price: float, _customer_id: StringName,
) -> void:
	_customers_served_today += 1
	if _customers_value != null:
		_customers_value.text = str(_customers_served_today)


func _on_item_sold(_item_id: String, _price: float, _category: String) -> void:
	_sold_today_count += 1
	if _sold_today_value != null:
		_sold_today_value.text = str(_sold_today_count)


func _on_beta_objective_completed(objective_id: StringName) -> void:
	if not _item_labels.has(objective_id):
		return
	if _completed_ids.has(objective_id):
		return
	var label: Label = _item_labels[objective_id] as Label
	if not is_instance_valid(label):
		return
	_completed_ids[objective_id] = true
	_apply_row_state(objective_id, "completed")
	var timer: SceneTreeTimer = get_tree().create_timer(COMPLETION_HOLD_SECONDS)
	timer.timeout.connect(_collapse_item.bind(objective_id))


## Tracks the rail's `steps` payload so a chain advance updates the
## active/future visual state without rebuilding rows. All rows are
## seeded at construction; this handler only restamps state.
##
## "completed" states from the payload are deliberately ignored — the
## explicit `beta_objective_completed` signal owns the green ✓ + hold +
## collapse flow, and the matching `_completed_ids` entry guards against
## double-handling when both signals arrive.
##
## §EH-40 — A step that arrives with no `id`, or with an `id` that does
## not match any seeded `_objectives` entry, is a contract drift between
## the rail-payload emitter and the panel's `set_objectives` seed. The
## debug-build `push_warning` calls surface the drift while the
## production path keeps the panel safe to render.
func _on_objective_changed(payload: Dictionary) -> void:
	var steps: Array = payload.get("steps", []) as Array
	if steps.is_empty():
		return
	for step: Dictionary in steps:
		var state: String = str(step.get("state", "future"))
		var entry_id: StringName = StringName(str(step.get("id", "")))
		if String(entry_id).is_empty():
			if OS.is_debug_build():
				push_warning(
					(
						"BetaRightPanel: dropped step with empty 'id' "
						+ "(state=%s, text=%s). The emitter must set `id` "
						+ "on every step in `_build_steps_payload`."
					) % [state, str(step.get("text", ""))]
				)
			continue
		if not _has_entry(entry_id):
			if OS.is_debug_build():
				push_warning(
					(
						"BetaRightPanel: step id '%s' not present in seeded "
						+ "`_objectives`; row dropped. Verify "
						+ "`set_objectives()` was called with a list "
						+ "containing this id before the rail emit."
					) % String(entry_id)
				)
			continue
		# `beta_objective_completed` owns the completion flow; skip both
		# the explicit "completed" payload state and any row already mid-
		# collapse so the green ✓ → tween → free chain runs to completion.
		if state == "completed":
			continue
		if _completed_ids.has(entry_id):
			continue
		_apply_row_state(entry_id, state)


func _on_input_focus_changed(new_ctx: StringName, _old_ctx: StringName) -> void:
	var target: float = (
		_MODAL_DIM_ALPHA if new_ctx == InputFocus.CTX_MODAL else 1.0
	)
	for child: Node in get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = target


## Starts the row-collapse tween so the PanelContainer reflows smoothly
## as the row shrinks to zero height. Held until the tween finishes, then
## hands off to `_finalize_collapse` for queue_free + bookkeeping.
func _collapse_item(objective_id: StringName) -> void:
	var label: Label = _item_labels.get(objective_id) as Label
	if label == null or not is_instance_valid(label):
		_finalize_collapse(objective_id)
		return
	var tween: Tween = create_tween()
	_collapse_tweens[objective_id] = tween
	tween.tween_property(
		label, "custom_minimum_size:y", 0.0, COLLAPSE_DURATION_SECONDS
	)
	tween.tween_callback(Callable(self, "_finalize_collapse").bind(objective_id))


func _finalize_collapse(objective_id: StringName) -> void:
	var label: Label = _item_labels.get(objective_id) as Label
	if label != null and is_instance_valid(label):
		label.queue_free()
	_item_labels.erase(objective_id)
	_completed_ids.erase(objective_id)
	_row_states.erase(objective_id)
	_collapse_tweens.erase(objective_id)


# ── Test seams ─────────────────────────────────────────────────────────────


## Returns the rendered header text for assertions without scene-tree
## traversal.
func get_header_text() -> String:
	if _header == null:
		return ""
	return _header.text


## Returns the current value-label text for `stat_name` (one of
## "On Shelves", "Back Room", "Customers", "Sold Today"). Empty string
## for any unknown name.
func get_stat_value(stat_name: String) -> String:
	var label: Label = null
	match stat_name:
		"On Shelves":
			label = _on_shelves_value
		"Back Room":
			label = _back_room_value
		"Customers":
			label = _customers_value
		"Sold Today":
			label = _sold_today_value
	if label == null:
		return ""
	return label.text


## Read-only count of currently-rendered objective rows (excludes the
## stats rows and section labels).
func get_visible_item_count() -> int:
	var count: int = 0
	for label: Label in _item_labels.values():
		if is_instance_valid(label) and label.visible:
			count += 1
	return count


## Returns the leading state glyph rendered for `objective_id`:
## `●` (active), `○` (future), `✓` (completed), or empty string if the
## row has collapsed. Mirrors the three-state model in `_apply_row_state`.
func get_item_glyph(objective_id: StringName) -> String:
	var label: Label = _item_labels.get(objective_id) as Label
	if label == null or not is_instance_valid(label):
		return ""
	var text: String = label.text
	if text.begins_with(_CHECK):
		return _CHECK
	if text.begins_with(_ACTIVE_GLYPH):
		return _ACTIVE_GLYPH
	if text.begins_with(_FUTURE_GLYPH):
		return _FUTURE_GLYPH
	return ""


## Returns the recorded row state ("future", "active", "completed") for
## `objective_id`, or an empty string if no row exists for that id.
func get_row_state(objective_id: StringName) -> String:
	if not _row_states.has(objective_id):
		return ""
	return str(_row_states[objective_id])
