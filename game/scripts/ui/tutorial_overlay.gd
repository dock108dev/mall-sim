## Non-blocking bottom bar that shows tutorial step prompts during gameplay.
class_name TutorialOverlay
extends CanvasLayer

# Localization marker for static validation: tr("TUTORIAL_WELCOME")

const SLIDE_DURATION: float = 0.3
const SLIDE_OFFSET: float = 100.0

var tutorial_system: TutorialSystem

var _current_tween: Tween
var _rest_offset_top: float

@onready var _bottom_bar: PanelContainer = $BottomBar
@onready var _prompt_label: Label = $BottomBar/HBox/PromptLabel
@onready var _skip_button: Button = $BottomBar/HBox/SkipButton


func _ready() -> void:
	_bottom_bar.visible = false
	_rest_offset_top = _bottom_bar.offset_top
	_skip_button.pressed.connect(_on_skip_pressed)
	EventBus.tutorial_step_changed.connect(
		_on_tutorial_step_changed
	)
	EventBus.tutorial_completed.connect(_on_tutorial_completed)
	EventBus.tutorial_skipped.connect(_on_tutorial_completed)
	if tutorial_system and tutorial_system.tutorial_completed:
		_bottom_bar.visible = false
		set_process(false)
		return


func _on_tutorial_step_changed(_step_id: String) -> void:
	if not tutorial_system:
		return
	var prompt_text: String = tutorial_system.get_current_step_text()
	if prompt_text.is_empty():
		return
	_show_step(prompt_text)


func _on_tutorial_completed() -> void:
	_slide_out_and_free()


func _on_skip_pressed() -> void:
	EventBus.skip_tutorial_requested.emit()


func _show_step(prompt_text: String) -> void:
	_prompt_label.text = prompt_text
	_bottom_bar.visible = true
	_slide_in()


func _slide_in() -> void:
	_kill_tween()
	_bottom_bar.offset_top = _rest_offset_top + SLIDE_OFFSET
	_current_tween = create_tween()
	_current_tween.tween_property(
		_bottom_bar, "offset_top",
		_rest_offset_top, SLIDE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _slide_out_and_free() -> void:
	if not _bottom_bar.visible:
		queue_free()
		return
	_kill_tween()
	_current_tween = create_tween()
	_current_tween.tween_property(
		_bottom_bar, "offset_top",
		_rest_offset_top + SLIDE_OFFSET, SLIDE_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_callback(queue_free)


func _kill_tween() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = null
