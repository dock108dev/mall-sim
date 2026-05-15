## Displays queued toast notifications from EventBus.toast_requested.
##
## Visual contract: small, dark, semi-transparent cards with a category-tinted
## left border. Toasts are momentary and never compete with modals — when
## CTX_MODAL is on top of the InputFocus stack, new toasts queue silently and
## the active panel hides until the modal closes.
##
## Z-order: the toast is parented to its own CanvasLayer (layer 45 in
## hud.tscn) — above HUD/rail (≤40) and below the modal dim overlay (49) and
## modal panels (≥80). Mouse events pass through the root Control so toasts
## never steal clicks.
class_name ToastNotificationUI
extends Control


## BRAINDUMP "Milestone toasts should be short. They are not for tutorial
## paragraphs." Toasts render in a fixed-width card (`TOAST_WIDTH` 280 px) on
## the `ToastLayer` (layer 45) and autowrap at ~2 lines. Anything past this
## cap pushes the layout off-spec and starts to read as a tutorial paragraph,
## which is precisely the failure mode the BRAINDUMP forbids. Enforced in
## debug builds via `assert` in `_on_toast_requested`; release builds keep
## the message but log a warning so the regression surfaces in QA logs.
const MAX_MESSAGE_CHARS: int = 72

const SLIDE_IN_DURATION: float = 0.15
const FADE_OUT_DURATION: float = 0.4
const DEFAULT_DURATION: float = 3.0
const MAX_QUEUE_SIZE: int = 5
const TOAST_WIDTH: float = 280.0
## Top-center placement clears the TimeLabel (y≈8–36 px) and the right-side
## stats column with safe margin. See
## `.aidlc/research/toast-position-vs-right-panel-coexistence.md` Option B.
const TOAST_OFFSET_TOP: float = 90.0
## Distance the panel drops in from above its final resting Y during the
## slide-in tween. Tuned to match `SLIDE_IN_DURATION` so the motion reads as
## a quick "message drop" rather than a snap.
const TOAST_DROP_IN_DISTANCE: float = 40.0
const TOAST_MIN_HEIGHT: float = 40.0
const TOAST_MAX_HEIGHT: float = 80.0
const PADDING_HORIZONTAL: int = 12
const PADDING_VERTICAL: int = 8
const PANEL_BG_COLOR: Color = Color(0.08, 0.08, 0.08, 0.85)
const PANEL_CORNER_RADIUS: int = 6
const LEFT_BORDER_WIDTH: int = 3
const TEXT_COLOR: Color = Color(0.92, 0.92, 0.92, 1.0)
const TEXT_FONT_SIZE: int = 15

## Left-border tint per category. Designers reach for these via the category
## arg on `EventBus.toast_requested`. `&"sale"` and `&"positive_cash"` are
## aliases the beta day-1 outcome path uses for cash-positive events.
## `&"unlock"` is emitted by `UnlockSystem.grant_unlock` when a milestone
## reward grants a new fixture slot or content category — cyan reads as
## "new capability available" and stays distinct from milestone gold.
const CATEGORY_COLORS: Dictionary = {
	&"system": Color(0.45, 0.45, 0.45),
	&"info": Color(0.45, 0.45, 0.45),
	&"sale": Color(0.30, 0.69, 0.31),
	&"positive_cash": Color(0.30, 0.69, 0.31),
	&"milestone": Color(1.0, 0.84, 0.0),
	&"unlock": Color(0.20, 0.78, 0.85),
	&"reputation_up": Color(0.30, 0.69, 0.31),
	&"reputation_down": Color(0.85, 0.40, 0.20),
	&"staff": Color(1.0, 0.6, 0.2),
	&"random_event": Color(1.0, 0.75, 0.1),
}
const DEFAULT_COLOR: Color = Color(0.45, 0.45, 0.45)

var _queue: Array[Dictionary] = []
var _is_showing: bool = false
var _active_panel: PanelContainer
var _tween: Tween
## True iff the most recent context_changed put CTX_MODAL on top of the
## InputFocus stack. While true, no new toast may begin animating; the active
## panel (if any) is hidden and re-queued so the modal owns the screen.
var _modal_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.toast_requested.connect(_on_toast_requested)
	# §EH-15 — `InputFocus` is an autoload (project.godot:51) and owns
	# `context_changed` (input_focus.gd:15). The prior null + has_signal
	# guards would silently disable modal-suppression on a rename, so a
	# toast would slide in over a modal without anyone noticing. Connect
	# unconditionally; any signature drift fails at GDScript parse time.
	InputFocus.context_changed.connect(_on_input_focus_changed)
	_modal_active = (InputFocus.current() == InputFocus.CTX_MODAL)


func _on_toast_requested(
	message: String, category: StringName, duration: float
) -> void:
	if message.is_empty():
		return
	# Debug-build copy-length contract — see `MAX_MESSAGE_CHARS` docstring.
	# Release builds push a `push_warning` instead of asserting so QA still
	# sees the regression in the logs but the player doesn't crash on an
	# accidentally-long content string.
	if message.length() > MAX_MESSAGE_CHARS:
		assert(
			false,
			(
				"Toast message exceeds %d chars (got %d): %s"
				% [MAX_MESSAGE_CHARS, message.length(), message]
			),
		)
		push_warning(
			(
				"ToastNotificationUI: message length %d exceeds %d chars: %s"
				% [message.length(), MAX_MESSAGE_CHARS, message]
			)
		)
	# Deduplicate by message string: discard if this exact text is already the
	# active card or already sitting in the queue. Defense-in-depth against a
	# second emission path (replays, multiple systems formatting the same
	# milestone string) bypassing per-system guards like UnlockSystem._granted.
	if _is_showing and is_instance_valid(_active_panel):
		if String(_active_panel.get_meta("toast_message", "")) == message:
			return
	for queued: Dictionary in _queue:
		if String(queued.get("message", "")) == message:
			return
	var effective_duration: float = duration if duration > 0.0 else DEFAULT_DURATION
	var entry: Dictionary = {
		"message": message,
		"category": category,
		"duration": effective_duration,
	}
	if _is_showing or _modal_active:
		if _queue.size() >= MAX_QUEUE_SIZE:
			_queue.pop_front()
		_queue.append(entry)
		return
	_show_toast(entry)


func _show_toast(entry: Dictionary) -> void:
	_is_showing = true
	var panel: PanelContainer = _create_toast_panel(entry)
	_active_panel = panel
	add_child(panel)

	var viewport_width: float = get_viewport_rect().size.x
	var target_x: float = (viewport_width - TOAST_WIDTH) / 2.0
	var start_y: float = TOAST_OFFSET_TOP - TOAST_DROP_IN_DISTANCE

	panel.position = Vector2(target_x, start_y)
	panel.modulate.a = 0.0

	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(
		panel, "position:y", TOAST_OFFSET_TOP, SLIDE_IN_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		panel, "modulate:a", 1.0, SLIDE_IN_DURATION
	).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
	_tween.tween_interval(entry.get("duration", DEFAULT_DURATION))
	_tween.tween_property(
		panel, "modulate:a", 0.0, FADE_OUT_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(_on_toast_finished)


## Public dismiss — used by the click-area button on each toast and by the
## scenario where a modal opens while a toast is still showing. The latter
## requeues the message so it can finish playing once the modal closes;
## explicit clicks just drop it.
func dismiss() -> void:
	if not _is_showing or not is_instance_valid(_active_panel):
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(
		_active_panel, "modulate:a", 0.0, FADE_OUT_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(_on_toast_finished)


func _on_toast_finished() -> void:
	if is_instance_valid(_active_panel):
		_active_panel.queue_free()
		_active_panel = null
	_is_showing = false
	if _modal_active:
		return
	if not _queue.is_empty():
		var next: Dictionary = _queue.pop_front()
		_show_toast(next)


## Modal-suppression hook. While CTX_MODAL is on top of InputFocus, new toasts
## queue silently and the active card is dismissed and re-queued so the modal
## owns the screen. On pop, the queue drains in FIFO order.
func _on_input_focus_changed(new_ctx: StringName, _old_ctx: StringName) -> void:
	var modal_now: bool = (new_ctx == InputFocus.CTX_MODAL)
	if modal_now == _modal_active:
		return
	_modal_active = modal_now
	if modal_now:
		_suspend_for_modal()
	else:
		_resume_after_modal()


func _suspend_for_modal() -> void:
	if not _is_showing or not is_instance_valid(_active_panel):
		return
	# Re-queue the active entry at the head so the player still sees it once
	# the modal closes. Drop the visible panel without running its fade so
	# the modal isn't fronted by a fading toast.
	var pending: Dictionary = {
		"message": _active_panel.get_meta("toast_message", "") as String,
		"category": _active_panel.get_meta("toast_category", &"") as StringName,
		"duration": _active_panel.get_meta("toast_duration", DEFAULT_DURATION) as float,
	}
	_kill_tween()
	_active_panel.queue_free()
	_active_panel = null
	_is_showing = false
	# If a duplicate of the interrupted message was already queued during the
	# modal, dropping the re-queue keeps the player from seeing the same card
	# twice once the modal closes.
	var pending_message: String = String(pending.get("message", ""))
	for queued: Dictionary in _queue:
		if String(queued.get("message", "")) == pending_message:
			return
	_queue.push_front(pending)
	if _queue.size() > MAX_QUEUE_SIZE:
		_queue.pop_back()


func _resume_after_modal() -> void:
	if _is_showing or _queue.is_empty():
		return
	var next: Dictionary = _queue.pop_front()
	_show_toast(next)


func _create_toast_panel(entry: Dictionary) -> PanelContainer:
	var category: StringName = entry.get("category", &"")
	var border_color: Color = CATEGORY_COLORS.get(category, DEFAULT_COLOR)

	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(TOAST_WIDTH, TOAST_MIN_HEIGHT)
	panel.size = Vector2(TOAST_WIDTH, TOAST_MIN_HEIGHT)
	panel.clip_contents = true
	# Cap the rendered height at the two-line ceiling. The min-size + autowrap
	# combination already lets a single-line card sit at ~40 px, but we don't
	# want a long string to push the card past the spec's 80 px.
	panel.add_theme_stylebox_override("panel", _make_panel_style(border_color))
	# Stash the source message + category on the panel so `_suspend_for_modal`
	# can re-queue the live card without keeping a parallel struct in sync.
	panel.set_meta("toast_message", entry.get("message", ""))
	panel.set_meta("toast_category", category)
	panel.set_meta("toast_duration", entry.get("duration", DEFAULT_DURATION))

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override(
		"margin_left", PADDING_HORIZONTAL + LEFT_BORDER_WIDTH
	)
	margin.add_theme_constant_override("margin_right", PADDING_HORIZONTAL)
	margin.add_theme_constant_override("margin_top", PADDING_VERTICAL)
	margin.add_theme_constant_override("margin_bottom", PADDING_VERTICAL)
	panel.add_child(margin)

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = entry.get("message", "")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	margin.add_child(label)

	var click_area: Button = Button.new()
	click_area.flat = true
	click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	click_area.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	click_area.pressed.connect(dismiss)
	panel.add_child(click_area)

	return panel


## Builds the rounded-rect dark stylebox with a category-tinted left border.
## Border width and radius are baked into the stylebox so designers cannot
## drift the visual contract by overriding only one corner.
func _make_panel_style(border_color: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = PANEL_BG_COLOR
	sb.border_color = border_color
	sb.border_width_left = LEFT_BORDER_WIDTH
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	sb.corner_radius_top_left = PANEL_CORNER_RADIUS
	sb.corner_radius_top_right = PANEL_CORNER_RADIUS
	sb.corner_radius_bottom_right = PANEL_CORNER_RADIUS
	sb.corner_radius_bottom_left = PANEL_CORNER_RADIUS
	return sb


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


## Test seam — clears state without relying on the tween or the autoload
## InputFocus stack. Pair with `InputFocus._reset_for_tests()` in tests that
## drive context changes through the autoload.
func _reset_for_tests() -> void:
	_kill_tween()
	if is_instance_valid(_active_panel):
		_active_panel.queue_free()
		_active_panel = null
	_queue.clear()
	_is_showing = false
	_modal_active = false
