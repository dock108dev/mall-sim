## Right-anchored "Today" stats surface for the beta Day-1 loop.
##
## Renders a persistent header ("DAY N — PHASE") plus four live stat rows
## (On Shelves, Back Room, Customers, Sold Today) along the right edge of
## the screen. Wired to the same EventBus signals as `hud.gd` so the
## numbers stay in lockstep with the TopBar accounting, but presented as
## a single grouped panel instead of a flat HBox so the BRAINDUMP
## "Top Left: Money only" rule can be respected.
##
## Visible from Day 1 start: seeds its state from `BetaRunState.day` and
## `EventBus.day_started` at `_ready` so no player interaction is needed
## to bring it on screen.
##
## Hidden in FP mode — the HUD reparents the same stat labels into
## compact corner overlays for FP, so this panel would visually duplicate
## them. Dims under CTX_MODAL via the same alpha contract as `hud.gd`.
##
## Owned by `BetaDayOneController` (spawned in `_ensure_panels`); not an
## autoload.
class_name BetaTodayStatsPanel
extends CanvasLayer

## CanvasLayer ordering — same tier as `BetaTodayChecklist` (30), below
## ObjectiveRail (40) and ModalDimOverlay (49).
const LAYER_INDEX: int = 30

## Modal-fade contract — mirrors `hud.gd._MODAL_DIM_ALPHA`. Calibrated
## against `ModalDimOverlay.DIM_COLOR.a` so the composed visible opacity
## stays legible (0.65 × 0.6 ≈ 0.39).
const _MODAL_DIM_ALPHA: float = 0.65

## Visual contract (issue spec).
const _PANEL_BG: Color = Color(0.08, 0.08, 0.14, 0.88)
const _HEADER_FONT_SIZE: int = 16
const _ROW_FONT_SIZE: int = 13
const _HEADER_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const _ROW_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
const _ROW_MIN_HEIGHT: float = 24.0
const _PADDING: int = 12
const _PANEL_WIDTH: float = 240.0

## Maps `TimeSystem.DayPhase` to a short uppercase phase name for the
## header. Independent of `hud.gd`'s `_PHASE_KEYS` (which translate via
## the locale CSV) so the panel reads as a tight "DAY 1 — MORNING" tag
## even in locales that ship longer phase strings.
##
## §EH-40 — Must cover every value in `TimeSystem.DayPhase`. A missing
## entry combined with the prior `"MORNING"` fallback silently mis-rendered
## the header (e.g. a late-evening day shipped as "DAY N — MORNING"); the
## `_refresh_header` lookup now push_warns + falls back to a literal
## "UNKNOWN" so drift surfaces in QA logs instead.
const _PHASE_NAMES: Dictionary = {
	TimeSystem.DayPhase.PRE_OPEN: "OPENING",
	TimeSystem.DayPhase.MORNING_RAMP: "MORNING",
	TimeSystem.DayPhase.MIDDAY_RUSH: "MIDDAY",
	TimeSystem.DayPhase.AFTERNOON: "AFTERNOON",
	TimeSystem.DayPhase.EVENING: "EVENING",
	TimeSystem.DayPhase.LATE_EVENING: "LATE EVENING",
}

var _background: ColorRect
var _header: Label
var _on_shelves_value: Label
var _back_room_value: Label
var _customers_value: Label
var _sold_today_value: Label

var _current_day: int = 1
var _current_phase: TimeSystem.DayPhase = TimeSystem.DayPhase.PRE_OPEN
## Mirror of `hud.gd._customers_served_today_count` — increments on
## `customer_purchased`, resets on `day_started`. Distinct from active
## in-store customer count.
var _customers_served_today: int = 0
var _on_shelves_count: int = 0
var _back_room_count: int = 0
var _sold_today_count: int = 0


func _ready() -> void:
	add_to_group("beta_today_stats_panel")
	layer = LAYER_INDEX
	_build_panel()
	_seed_initial_state()
	_refresh_header()
	_refresh_all_values()
	# Live wiring — every signal is owner-declared on EventBus, so direct
	# typed connection mirrors the §EH-13 dead-guard avoidance pattern.
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.beta_shelf_count_changed.connect(_on_beta_shelf_count_changed)
	EventBus.beta_backroom_count_changed.connect(_on_beta_backroom_count_changed)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.fp_mode_changed.connect(_on_fp_mode_changed)
	InputFocus.context_changed.connect(_on_input_focus_changed)


func _build_panel() -> void:
	var anchor: Control = Control.new()
	anchor.name = "Anchor"
	anchor.anchor_left = 1.0
	anchor.anchor_top = 0.0
	anchor.anchor_right = 1.0
	anchor.anchor_bottom = 1.0
	anchor.offset_left = -_PANEL_WIDTH
	anchor.offset_top = 56.0
	anchor.offset_right = -16.0
	anchor.offset_bottom = -260.0
	anchor.grow_horizontal = Control.GROW_DIRECTION_BEGIN
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

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	_header = Label.new()
	_header.name = "Header"
	_header.custom_minimum_size = Vector2(0.0, _ROW_MIN_HEIGHT)
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_theme_font_size_override("font_size", _HEADER_FONT_SIZE)
	_header.add_theme_color_override("font_color", _HEADER_COLOR)
	column.add_child(_header)

	_on_shelves_value = _build_stat_row(column, "On Shelves")
	_back_room_value = _build_stat_row(column, "Back Room")
	_customers_value = _build_stat_row(column, "Customers")
	_sold_today_value = _build_stat_row(column, "Sold Today")


## Adds a `label : value` row to `column` and returns the value Label so
## the caller can hold a reference for live updates. Label sits flush
## left, value sits flush right (horizontal_alignment 2) with the HBox
## EXPAND fill so the gap between them always reaches the panel edge.
func _build_stat_row(column: VBoxContainer, label_text: String) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row_%s" % label_text.replace(" ", "")
	row.custom_minimum_size = Vector2(0.0, _ROW_MIN_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

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


## Reads the run-state day at boot so the panel can render the current
## day number before any `day_started` emission. Phase stays at PRE_OPEN
## (the class-level default) until the TimeSystem fires its first
## `day_phase_changed`.
func _seed_initial_state() -> void:
	_current_day = BetaRunState.day
	# Counters start at zero — wait for the real signals to overwrite.
	_customers_served_today = 0
	_on_shelves_count = 0
	_back_room_count = 0
	_sold_today_count = 0


func _refresh_header() -> void:
	if _header == null:
		return
	# §EH-40 — Drift surface for `TimeSystem.DayPhase`. Falling back silently
	# to a hard-coded phase string (the prior "MORNING" default) shipped the
	# late-evening case as "DAY N — MORNING" because `_PHASE_NAMES` was
	# missing the LATE_EVENING key. The push_warning + "UNKNOWN" fallback
	# now make any future drift loud in QA logs while keeping the panel
	# safe to render.
	var phase_name: String
	if _PHASE_NAMES.has(_current_phase):
		phase_name = str(_PHASE_NAMES[_current_phase])
	else:
		if OS.is_debug_build():
			push_warning(
				(
					"BetaTodayStatsPanel: unmapped TimeSystem.DayPhase '%d' "
					+ "— rendering as 'UNKNOWN'. Add the phase to "
					+ "`_PHASE_NAMES` in beta_today_stats_panel.gd."
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


func _on_day_started(day: int) -> void:
	_current_day = day
	_customers_served_today = 0
	_sold_today_count = 0
	# Shelf / back-room counts are not reset here — they are persistent
	# inventory state that the controller re-emits explicitly on day reset.
	_refresh_header()
	_refresh_all_values()


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


## Hide entirely in FP mode — `hud.gd` reparents the four base stat
## labels into corner overlays at that point, so this panel would visually
## duplicate them.
func _on_fp_mode_changed(enabled: bool) -> void:
	visible = not enabled


func _on_input_focus_changed(new_ctx: StringName, _old_ctx: StringName) -> void:
	var target: float = (
		_MODAL_DIM_ALPHA if new_ctx == InputFocus.CTX_MODAL else 1.0
	)
	for child: Node in get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = target


## Test seam — exposes the rendered header text for assertions without
## having to traverse the scene tree.
func get_header_text() -> String:
	if _header == null:
		return ""
	return _header.text


## Test seam — returns the current value-label text for `stat_name` (one
## of "On Shelves", "Back Room", "Customers", "Sold Today"). Empty
## string for any unknown name.
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
