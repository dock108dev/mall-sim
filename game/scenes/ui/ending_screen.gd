## Full-screen ending overlay shown when all milestones are completed.
class_name EndingScreen
extends CanvasLayer


signal dismissed

const FADE_DURATION: float = 1.5
const TEXT_DELAY: float = 0.8
const BODY_DELAY: float = 1.6
const BUTTON_DELAY: float = 2.4

var _ending_type: String = ""
var _tween: Tween

@onready var _background: ColorRect = $Background
@onready var _title_label: Label = $Content/VBox/TitleLabel
@onready var _subtitle_label: Label = $Content/VBox/SubtitleLabel
@onready var _body_label: Label = $Content/VBox/BodyLabel
@onready var _continue_button: Button = $Content/VBox/ContinueButton


func _ready() -> void:
	visible = false
	_continue_button.pressed.connect(_on_continue_pressed)


## Shows the ending screen with data from the ending config.
func show_ending(ending_data: Dictionary) -> void:
	_ending_type = str(ending_data.get("id", "normal"))
	_title_label.text = str(ending_data.get("title", ""))
	_subtitle_label.text = str(ending_data.get("subtitle", ""))
	_body_label.text = str(ending_data.get("body", ""))
	_apply_mood(ending_data)
	_animate_in()


func get_ending_type() -> String:
	return _ending_type


func _apply_mood(ending_data: Dictionary) -> void:
	var bg_hex: String = str(
		ending_data.get("background_color", "#1a3a5c")
	)
	var accent_hex: String = str(
		ending_data.get("accent_color", "#f5c842")
	)
	var bg_color: Color = Color.from_string(bg_hex, Color.BLACK)
	var accent_color: Color = Color.from_string(
		accent_hex, Color.WHITE
	)

	_background.color = bg_color
	_title_label.add_theme_color_override(
		"font_color", accent_color
	)
	_subtitle_label.add_theme_color_override(
		"font_color", _get_subtitle_color(ending_data)
	)
	_body_label.add_theme_color_override(
		"font_color", Color(0.85, 0.85, 0.85)
	)


func _get_subtitle_color(ending_data: Dictionary) -> Color:
	var mood: String = str(ending_data.get("mood", "celebratory"))
	match mood:
		"unsettling":
			return Color(0.6, 0.5, 0.7)
		"raid":
			return Color(0.9, 0.3, 0.3)
		_:
			return Color(0.9, 0.85, 0.7)


func _animate_in() -> void:
	_title_label.modulate = Color(1, 1, 1, 0)
	_subtitle_label.modulate = Color(1, 1, 1, 0)
	_body_label.modulate = Color(1, 1, 1, 0)
	_continue_button.modulate = Color(1, 1, 1, 0)
	_background.modulate = Color(1, 1, 1, 0)
	visible = true

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(
		_background, "modulate:a", 1.0, FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	_tween.tween_property(
		_title_label, "modulate:a", 1.0, 0.6
	).set_delay(TEXT_DELAY).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)

	_tween.tween_property(
		_subtitle_label, "modulate:a", 1.0, 0.5
	).set_delay(0.3).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)

	_tween.tween_property(
		_body_label, "modulate:a", 1.0, 0.8
	).set_delay(0.3).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)

	_tween.tween_property(
		_continue_button, "modulate:a", 1.0, 0.5
	).set_delay(0.4).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)


func _on_continue_pressed() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(
		_background, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_title_label, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_subtitle_label, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_body_label, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_continue_button, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.chain().tween_callback(
		func() -> void:
			visible = false
			_background.modulate = Color.WHITE
			_title_label.modulate = Color.WHITE
			_subtitle_label.modulate = Color.WHITE
			_body_label.modulate = Color.WHITE
			_continue_button.modulate = Color.WHITE
			EventBus.ending_dismissed.emit()
			dismissed.emit()
	)
