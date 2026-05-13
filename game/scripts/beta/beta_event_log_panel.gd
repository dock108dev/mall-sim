## Bottom-left on-screen event log surface for the beta Day-1 loop.
##
## Subscribes to `EventBus.event_logged(tag, message)` and renders the
## most-recent entries as a stacked list of `[TAG] message` rows. Tag tokens
## are color-coded per event type; message text uses the same 60% white tier
## as the right stats panel rows. Player-facing — not a debug overlay — so
## it ships in release builds. Pairs with `EventLog`, which emits
## `event_logged` unconditionally even though its ring buffer is debug-only.
##
## Visual contract mirrors `BetaTodayStatsPanel` so the two surfaces read as
## a single design family: same `_PANEL_BG`, same 12 px padding, no border.
## Width 260 px, height ~120 px, anchored bottom-left above the carry label
## (which sits at `offset_top = -200` from bottom — we stop at -204).
##
## Owned by `BetaDayOneController` (spawned in `_ensure_panels`); not an
## autoload.
class_name BetaEventLogPanel
extends CanvasLayer

## Visible entry cap — 6-8 rows fit in the 120 px height at 12 px font.
## When the buffer hits this number the oldest entry fades to
## `_FADE_OUT_ALPHA` over `_FADE_OUT_SECONDS` before its row is removed.
const MAX_VISIBLE_ENTRIES: int = 8

## CanvasLayer ordering — sits below ModalDimOverlay (49) so the day-end /
## decision modals dim it, and below ObjectiveRail (40) so the rail's
## active-step chip always wins. Layer 30 matches `BetaTodayStatsPanel` and
## `BetaTodayChecklist` — the three panels share a tier.
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
## Faded alpha applied to the oldest entry before it scrolls off. The tween
## from 1.0 -> _FADE_OUT_ALPHA -> remove keeps the eviction from popping.
const _FADE_OUT_ALPHA: float = 0.3
const _FADE_OUT_SECONDS: float = 0.35

## Color-coded per tag — message text after the tag always uses
## `_MESSAGE_COLOR` (60% white) regardless of tag.
const _TAG_COLORS: Dictionary = {
	"[STOCK]": Color(1.0, 0.58, 0.3),
	"[CUSTOMER]": Color(0.3, 1.0, 0.5),
	"[OBJECTIVE]": Color(0.4, 0.9, 1.0),
	"[DAY]": Color(1.0, 1.0, 1.0, 1.0),
	"[MODAL]": Color(1.0, 1.0, 1.0, 0.5),
	"[STAT]": Color(1.0, 1.0, 1.0, 0.6),
}
const _MESSAGE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
const _DEFAULT_TAG_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)

var _background: ColorRect
var _entry_container: VBoxContainer
## Stable references to active entry rows in display order (oldest first).
## We append on new events, pop_front when over the cap.
var _entries: Array[RichTextLabel] = []


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
## hot path with `RichTextLabel.new()` allocations for every state change.
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
	var row: RichTextLabel = RichTextLabel.new()
	row.fit_content = true
	row.bbcode_enabled = true
	row.scroll_active = false
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0.0, _ENTRY_MIN_HEIGHT)
	row.add_theme_font_size_override("normal_font_size", _ENTRY_FONT_SIZE)
	# §F-S9 trust contract — `tag` and `message` originate from `EventLog`
	# (a project-internal autoload) which builds them from EventBus payload
	# fields (item_id, state name, etc.). Those fields are content-author /
	# code-controlled, not save / network derived. Future callers piping
	# user-typed or save-derived text into the log must escape `[` -> `[lb]`.
	row.text = _format_row(tag, message)
	_entry_container.add_child(row)
	_entries.append(row)
	if _entries.size() > MAX_VISIBLE_ENTRIES:
		_fade_and_remove_oldest()


## Drops the oldest visible row with a short alpha tween so the eviction
## reads as a fade rather than a snap. The tween's `finished` callback
## queue_frees the row and clears it from `_entries`.
func _fade_and_remove_oldest() -> void:
	if _entries.is_empty():
		return
	var oldest: RichTextLabel = _entries.pop_front()
	if not is_instance_valid(oldest):
		return
	var tween: Tween = create_tween()
	tween.tween_property(oldest, "modulate:a", _FADE_OUT_ALPHA, _FADE_OUT_SECONDS)
	tween.tween_callback(Callable(self, "_free_row").bind(oldest))


func _free_row(row: RichTextLabel) -> void:
	if is_instance_valid(row):
		row.queue_free()


## Builds the BBCode-formatted row. The tag token gets its color from
## `_TAG_COLORS`; the trailing message uses the muted 60% white tier so
## the tag reads as the highlighted glyph.
##
## §F-S15 — `row.bbcode_enabled = true` (set on the RichTextLabel above),
## so any literal `[` in `message` would be parsed as a BBCode tag. The
## current `EventLog._format_message` callers feed integer- and enum-
## derived strings only, but the durable hardening — matching the
## canonical pattern from `checkout_panel._set_reasoning_text` and
## `boot._show_error_panel` — is to escape `[` -> `[lb]` at the sink so
## a future caller piping content-, save-, or user-derived text through
## `EventBus.event_logged` cannot smuggle `[img=res://…]` / `[url=…]` /
## `[font=…]` tags into the rendered row. The color-format tokens added
## *after* escape are intentional BBCode; only the message input is
## escaped. `tag` is *not* escaped because the only accepted values are
## the hardcoded keys of `_TAG_COLORS` (`[STOCK]`, `[CUSTOMER]`, …) —
## escaping it would alter the visible token (it would still render as
## `[STOCK]` since `[lb]` resolves to `[`, but the test contract pins the
## raw row text). The trust contract for `tag` is the autoload-internal
## token allowlist; any future caller passing a tag outside the table
## degrades to `_DEFAULT_TAG_COLOR` and renders the token literally.
func _format_row(tag: String, message: String) -> String:
	var tag_color: Color = _TAG_COLORS.get(tag, _DEFAULT_TAG_COLOR)
	return "[color=#%s]%s[/color] [color=#%s]%s[/color]" % [
		tag_color.to_html(false),
		tag,
		_MESSAGE_COLOR.to_html(false),
		message.replace("[", "[lb]"),
	]


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


## Test seam — returns the number of rendered entry rows (excluding any
## that are mid-fade-out tween).
func get_visible_entry_count() -> int:
	var count: int = 0
	for row: RichTextLabel in _entries:
		if is_instance_valid(row):
			count += 1
	return count


## Test seam — returns the raw BBCode text of the most-recent row, empty
## string when the panel has no entries. Tests use this to verify the tag
## color tokens land on the right tags.
func get_latest_row_text() -> String:
	if _entries.is_empty():
		return ""
	var row: RichTextLabel = _entries[_entries.size() - 1]
	if not is_instance_valid(row):
		return ""
	return row.text


## Test seam — returns the resolved color for `tag` from the lookup table,
## or the default tag color when unmapped. Mirrors what `_format_row` would
## use without forcing tests to scrape BBCode.
func get_tag_color(tag: String) -> Color:
	return _TAG_COLORS.get(tag, _DEFAULT_TAG_COLOR)
