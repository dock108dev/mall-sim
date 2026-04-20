## Displays a single ambient moment card with optional character name, vignette
## text, a dismiss button, and a countdown progress bar.
## Emits dismissed(moment_id) when the card closes for any reason.
class_name MomentCard
extends PanelContainer

## Fired when the card finishes its exit animation; tray uses this to advance
## the queue regardless of whether dismiss was manual or time-based.
signal dismissed(moment_id: StringName)

const _ANIMATE_IN_SECS: float = 0.18
const _ANIMATE_OUT_SECS: float = 0.22
const _MIN_DURATION: float = 0.5
const _SLIDE_OFFSET: float = 24.0

## Visual flavour matched to ambient_moments.json display_type field.
enum DisplayStyle { TOAST, THOUGHT_BUBBLE, LOG_ENTRY, AUDIO_ONLY }

var moment_id: StringName = &""
var display_style: DisplayStyle = DisplayStyle.TOAST

var _time_remaining: float = 0.0
var _duration: float = 0.0
var _ticking: bool = false
var _closing: bool = false
var _paused: bool = false

@onready var _character_name_label: Label = $Margin/VBox/Header/CharacterName
@onready var _spacer: Control = $Margin/VBox/Header/Spacer
@onready var _dismiss_button: Button = $Margin/VBox/Header/DismissButton
@onready var _flavor_label: Label = $Margin/VBox/FlavorText
@onready var _progress: ProgressBar = $Margin/VBox/Progress


func _ready() -> void:
	modulate.a = 0.0
	if _dismiss_button:
		_dismiss_button.pressed.connect(_on_dismiss_pressed)
	EventBus.moment_expired.connect(_on_moment_expired)


## Configures content and starts the countdown. Call after adding to scene tree.
func setup(
	p_moment_id: StringName,
	p_flavor_text: String,
	p_duration_seconds: float,
	p_character_name: String = "",
	p_display_type: String = "toast",
) -> void:
	moment_id = p_moment_id
	_duration = maxf(p_duration_seconds, _MIN_DURATION)
	_time_remaining = _duration
	display_style = _style_for_type(p_display_type)

	_configure_character_name(p_character_name)
	_configure_flavor_text(p_flavor_text)
	_apply_style_colors()

	if _progress:
		_progress.max_value = _duration
		_progress.value = _duration

	_ticking = true
	_animate_in()


func _process(delta: float) -> void:
	if not _ticking or _closing or _paused:
		return
	_time_remaining -= delta
	if _time_remaining < 0.0:
		_time_remaining = 0.0
	if _progress:
		_progress.value = _time_remaining
	if _time_remaining <= 0.0:
		_begin_close()


## Pauses the countdown without hiding the card.
func pause_countdown() -> void:
	_paused = true


## Resumes a paused countdown.
func resume_countdown() -> void:
	_paused = false


## Adds extra seconds to the remaining display time (e.g. for important moments).
func extend_duration(extra_seconds: float) -> void:
	_time_remaining += maxf(extra_seconds, 0.0)
	_duration += maxf(extra_seconds, 0.0)
	if _progress:
		_progress.max_value = _duration


## Returns the moment ID this card is currently showing.
func get_moment_id() -> StringName:
	return moment_id


## Seconds of display time remaining before automatic dismissal.
func get_time_remaining() -> float:
	return _time_remaining


## Total configured display duration in seconds.
func get_duration() -> float:
	return _duration


## True while an entry or exit animation is running.
func is_closing() -> bool:
	return _closing


## True while the countdown is manually paused.
func is_paused() -> bool:
	return _paused


## Human-readable name for the current display style (useful in tests/logging).
func get_display_style_name() -> String:
	match display_style:
		DisplayStyle.THOUGHT_BUBBLE:
			return "thought_bubble"
		DisplayStyle.LOG_ENTRY:
			return "log_entry"
		DisplayStyle.AUDIO_ONLY:
			return "audio_only"
		_:
			return "toast"


# ── private helpers ──────────────────────────────────────────────────────────


func _configure_character_name(name_text: String) -> void:
	if not _character_name_label:
		return
	var has_name: bool = not name_text.is_empty()
	_character_name_label.visible = has_name
	if _spacer:
		_spacer.visible = has_name
	if has_name:
		_character_name_label.text = name_text


func _configure_flavor_text(text: String) -> void:
	if _flavor_label:
		_flavor_label.text = text


func _apply_style_colors() -> void:
	match display_style:
		DisplayStyle.THOUGHT_BUBBLE:
			_set_color(_flavor_label, Color(0.80, 0.90, 1.00))
			_set_color(_character_name_label, Color(0.60, 0.80, 1.00))
		DisplayStyle.LOG_ENTRY:
			_set_color(_flavor_label, Color(0.85, 0.95, 0.75))
			_set_color(_character_name_label, Color(0.70, 0.90, 0.60))
		DisplayStyle.AUDIO_ONLY:
			_set_color(_flavor_label, Color(0.70, 0.70, 0.70))
			if _flavor_label:
				_flavor_label.modulate.a = 0.75
		_:
			_set_color(_flavor_label, Color(0.96, 0.91, 0.83))
			_set_color(_character_name_label, Color(0.85, 0.78, 0.65))


func _set_color(node: Label, color: Color) -> void:
	if node:
		node.add_theme_color_override("font_color", color)


func _style_for_type(display_type: String) -> DisplayStyle:
	match display_type:
		"thought_bubble":
			return DisplayStyle.THOUGHT_BUBBLE
		"log_entry":
			return DisplayStyle.LOG_ENTRY
		"audio_only":
			return DisplayStyle.AUDIO_ONLY
		_:
			return DisplayStyle.TOAST


func _animate_in() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, _ANIMATE_IN_SECS)
	tween.tween_property(self, "position:x", 0.0, _ANIMATE_IN_SECS) \
		.from(_SLIDE_OFFSET)


func _begin_close() -> void:
	if _closing:
		return
	_closing = true
	_ticking = false
	dismissed.emit(moment_id)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, _ANIMATE_OUT_SECS)
	tween.tween_callback(queue_free)


func _on_dismiss_pressed() -> void:
	if _closing:
		return
	_time_remaining = 0.0
	_begin_close()


func _on_moment_expired(expired_id: StringName) -> void:
	if expired_id == moment_id:
		_time_remaining = 0.0
		_begin_close()
