## Bottom-left on-screen event log surface for the beta Day-1 loop.
##
## Subscribes to `EventBus.event_logged(tag, message)` and renders the
## most-recent entries as a stacked list of message-only `Label` rows. The
## bracket-wrapped tag (e.g. `[STOCK]`) drives the row's font_color via
## `_TAG_COLORS` but is stripped from the visible text — the underlying
## `[TAG] message` shape lives only on the signal payload. Player-facing —
## not a debug overlay — so it ships in release builds. Pairs with
## `EventLog`, which emits `event_logged` unconditionally even though its
## ring buffer is debug-only.
##
## Visual contract mirrors `BetaRightPanel` so the two surfaces read as
## a single design family: same `_PANEL_BG`, same 12 px padding, no border.
## Width 260 px, height ~120 px, anchored bottom-left above the carry label
## (which sits at `offset_top = -200` from bottom — we stop at -204).
##
## Owned by the `BetaHUD` autoload (spawned in `BetaHUD._ready`); persists
## across day-controller teardown so it survives day transitions without
## losing in-flight rows.
class_name BetaEventLogPanel
extends CanvasLayer

## Hard cap on rendered rows. A 5th entry queue_free()'s the oldest so the
## panel never spans more than four lines — keeps the bottom-left footprint
## tight and matches the BRAINDUMP "max 3-4 visible lines" guideline.
const MAX_VISIBLE_ENTRIES: int = 4

## Oldest visible row's alpha when the panel is full. Rows interpolate
## linearly between this value (at index 0) and 1.0 (at the last index), so
## each new entry pushes its predecessors toward transparency.
const ALPHA_OLDEST: float = 0.35

## CanvasLayer ordering — sits below ModalDimOverlay (49) so the day-end /
## decision modals dim it, and below ObjectiveRail (40) so the rail's
## active-step chip always wins. Layer 30 matches `BetaRightPanel` — the
## two panels share a tier.
const LAYER_INDEX: int = 30

## Modal-fade contract — mirrors `hud.gd._MODAL_DIM_ALPHA`. When CTX_MODAL
## is on top of the InputFocus stack the panel alpha drops so the modal
## owns the foreground. Calibrated against `ModalDimOverlay.DIM_COLOR.a`
## so the composed visible opacity stays legible (0.65 × 0.6 ≈ 0.39).
const _MODAL_DIM_ALPHA: float = 0.65

const _PANEL_BG: Color = Color(0.08, 0.08, 0.14, 0.88)
const _PANEL_WIDTH: float = 260.0
const _PANEL_HEIGHT: float = 120.0
const _PADDING: int = 12
## Bottom inset chosen so the panel sits flush above `BetaCarryLabel`
## (which lives at `offset_top = -200` on CarryHUD); 4 px clearance keeps
## the carry-state amber strip from kissing the panel edge.
const _BOTTOM_INSET: float = 204.0
const _LEFT_INSET: float = 16.0
const _ENTRY_FONT_SIZE: int = 12
const _ENTRY_MIN_HEIGHT: float = 14.0

## Tag → font color. Keys are bare tag names (no brackets); the bracketed
## form arrives over `event_logged` and is unwrapped before lookup.
const _TAG_COLORS: Dictionary = {
	"STOCK": Color(0.3, 0.75, 0.85, 1.0),       # blue-teal
	"CUSTOMER": Color(0.3, 1.0, 0.5, 1.0),       # green
	"DAY": Color(1.0, 0.78, 0.3, 1.0),           # amber / gold
	"SYSTEM": Color(0.65, 0.65, 0.65, 1.0),      # medium gray
	"OBJECTIVE": Color(0.4, 0.9, 1.0, 1.0),      # cyan
}

## Near-white fallback for unrecognized or missing tags. Picked over pure
## white so the muted desaturated panel chrome still wins visually.
const _DEFAULT_TAG_COLOR: Color = Color(0.95, 0.95, 0.95, 1.0)

var _entry_container: VBoxContainer


func _ready() -> void:
	add_to_group("beta_event_log_panel")
	layer = LAYER_INDEX
	_build_panel()
	# §EH-13 — direct typed connection; `event_logged` is owner-declared on
	# EventBus so a signal-rename fails at parse time instead of silently
	# stranding the panel empty.
	EventBus.event_logged.connect(_on_event_logged)
	InputFocus.context_changed.connect(_on_input_focus_changed)
	EventBus.fp_mode_changed.connect(_on_fp_mode_changed)


## Explicit disconnect on tree exit so a freed panel cannot stay subscribed
## to the autoload `EventBus.event_logged` stream and burn the customer FSM
## hot path with `Label.new()` allocations for every state change.
## Godot 4 auto-disconnects when the receiver is freed, but tests that call
## `node.free()` immediately (GUT's `add_child_autofree`) can race the
## cleanup — the disconnect here closes that gap deterministically.
func _exit_tree() -> void:
	if EventBus.event_logged.is_connected(_on_event_logged):
		EventBus.event_logged.disconnect(_on_event_logged)
	if InputFocus.context_changed.is_connected(_on_input_focus_changed):
		InputFocus.context_changed.disconnect(_on_input_focus_changed)
	if EventBus.fp_mode_changed.is_connected(_on_fp_mode_changed):
		EventBus.fp_mode_changed.disconnect(_on_fp_mode_changed)


func _build_panel() -> void:
	var anchor: Control = Control.new()
	anchor.name = "Anchor"
	anchor.anchor_left = 0.0
	anchor.anchor_top = 1.0
	anchor.anchor_right = 0.0
	anchor.anchor_bottom = 1.0
	anchor.offset_left = _LEFT_INSET
	anchor.offset_top = -(_BOTTOM_INSET + _PANEL_HEIGHT)
	anchor.offset_right = _LEFT_INSET + _PANEL_WIDTH
	anchor.offset_bottom = -_BOTTOM_INSET
	anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	var background: ColorRect = ColorRect.new()
	background.name = "Background"
	background.color = _PANEL_BG
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(background)

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

	_entry_container = VBoxContainer.new()
	_entry_container.name = "Entries"
	_entry_container.add_theme_constant_override("separation", 2)
	# Bottom-anchored so new entries push older rows up — the freshest beat
	# always sits flush against the bottom of the panel where the player's
	# eye lands first.
	_entry_container.alignment = BoxContainer.ALIGNMENT_END
	_entry_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_entry_container)


func _on_event_logged(tag: String, message: String) -> void:
	if _entry_container == null:
		return
	if message.is_empty():
		return
	# Treat "[TAG] message" as the canonical entry shape; splitting on the
	# first "] " strips the bracket prefix for display while leaving the
	# upstream signal payload (the stored format) untouched.
	var raw_entry: String = "%s %s" % [tag, message]
	var parts: PackedStringArray = raw_entry.split("] ", true, 1)
	var display_text: String
	var tag_key: String
	if parts.size() > 1:
		display_text = parts[1]
		tag_key = parts[0].trim_prefix("[")
	else:
		display_text = raw_entry
		tag_key = ""

	var row: Label = Label.new()
	row.text = display_text
	row.add_theme_font_size_override("font_size", _ENTRY_FONT_SIZE)
	row.add_theme_color_override(
		"font_color", _TAG_COLORS.get(tag_key, _DEFAULT_TAG_COLOR)
	)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0.0, _ENTRY_MIN_HEIGHT)
	_entry_container.add_child(row)

	# Synchronous eviction — `queue_free` alone keeps the node parented until
	# end-of-frame, which would skew `get_child_count()` and the alpha math.
	while _entry_container.get_child_count() > MAX_VISIBLE_ENTRIES:
		var oldest: Node = _entry_container.get_child(0)
		_entry_container.remove_child(oldest)
		oldest.queue_free()

	_refresh_alpha()


## Recomputes per-row `modulate.a` so the oldest row sits at `ALPHA_OLDEST`,
## the newest at 1.0, and intermediate rows fall on the linear segment
## between. Runs synchronously after every add/evict so the fade is in
## place before the next frame draws.
func _refresh_alpha() -> void:
	if _entry_container == null:
		return
	var count: int = _entry_container.get_child_count()
	for i: int in range(count):
		var child: Node = _entry_container.get_child(i)
		if not (child is CanvasItem):
			continue
		var alpha: float
		if count <= 1:
			alpha = 1.0
		else:
			alpha = lerp(ALPHA_OLDEST, 1.0, float(i) / float(count - 1))
		var item: CanvasItem = child as CanvasItem
		var mod: Color = item.modulate
		mod.a = alpha
		item.modulate = mod


func _on_input_focus_changed(new_ctx: StringName, _old_ctx: StringName) -> void:
	var target: float = (
		_MODAL_DIM_ALPHA if new_ctx == InputFocus.CTX_MODAL else 1.0
	)
	for child: Node in get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = target


## Hide entirely in FP mode — the FP corner overlays already surface the
## glanceable cues this panel duplicates.
func _on_fp_mode_changed(enabled: bool) -> void:
	visible = not enabled


## Test seam — returns the number of rendered entry rows.
func get_visible_entry_count() -> int:
	if _entry_container == null:
		return 0
	return _entry_container.get_child_count()


## Test seam — returns the visible text of the most-recent row (without the
## stripped `[TAG] ` prefix), or an empty string when the panel has no
## entries.
func get_latest_row_text() -> String:
	if _entry_container == null:
		return ""
	var count: int = _entry_container.get_child_count()
	if count == 0:
		return ""
	var row: Node = _entry_container.get_child(count - 1)
	if row is Label:
		return (row as Label).text
	return ""


## Test seam — returns the font color the panel would apply for `tag`.
## Accepts either the bare key (`"STOCK"`) or the bracketed form
## (`"[STOCK]"`) so call sites can use whichever they have on hand.
func get_tag_color(tag: String) -> Color:
	var key: String = tag.trim_prefix("[").trim_suffix("]")
	return _TAG_COLORS.get(key, _DEFAULT_TAG_COLOR)


## Test seam — returns the resolved `modulate.a` for the row at `index`
## (0 = oldest visible row). Mirrors what `_refresh_alpha` writes without
## forcing tests to dig into CanvasItem state directly.
func get_row_alpha(index: int) -> float:
	if _entry_container == null:
		return 0.0
	if index < 0 or index >= _entry_container.get_child_count():
		return 0.0
	var child: Node = _entry_container.get_child(index)
	if child is CanvasItem:
		return (child as CanvasItem).modulate.a
	return 0.0
