## Tutorial overlay displaying step prompts, highlights, and a skip button.
class_name TutorialOverlay
extends CanvasLayer

const TIP_DISPLAY_DURATION: float = 10.0
const FADE_DURATION: float = 0.3

var tutorial_system: TutorialSystem

@onready var _panel: PanelContainer = $Panel
@onready var _step_label: Label = $Panel/Margin/VBox/StepLabel
@onready var _prompt_label: Label = $Panel/Margin/VBox/PromptLabel
@onready var _skip_button: Button = $Panel/Margin/VBox/SkipButton
@onready var _tip_panel: PanelContainer = $TipPanel
@onready var _tip_label: Label = $TipPanel/TipMargin/TipLabel

var _tip_timer: float = 0.0
var _tip_visible: bool = false


func _ready() -> void:
	_panel.visible = false
	_tip_panel.visible = false
	_skip_button.pressed.connect(_on_skip_pressed)
	EventBus.tutorial_step_changed.connect(
		_on_tutorial_step_changed
	)
	EventBus.tutorial_step_completed.connect(
		_on_tutorial_step_completed
	)
	EventBus.tutorial_completed.connect(_on_tutorial_completed)
	EventBus.tutorial_skipped.connect(_on_tutorial_skipped)
	EventBus.contextual_tip_requested.connect(
		_on_contextual_tip_requested
	)


func _process(delta: float) -> void:
	if _tip_visible:
		_tip_timer -= delta
		if _tip_timer <= 0.0:
			_hide_tip()


func show_step(step_id: String, prompt_text: String) -> void:
	if prompt_text.is_empty():
		_panel.visible = false
		return
	var step_number: int = _get_step_number(step_id)
	var total_steps: int = (
		TutorialSystem.TutorialStep.FINISHED
	)
	_step_label.text = "Step %d of %d" % [
		step_number, total_steps
	]
	_prompt_label.text = prompt_text
	_panel.visible = true
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(
		_panel, "modulate",
		Color.WHITE, FADE_DURATION
	)


func hide_overlay() -> void:
	_panel.visible = false
	_tip_panel.visible = false


func _on_skip_pressed() -> void:
	if tutorial_system:
		tutorial_system.skip_tutorial()


func _on_tutorial_step_changed(step_id: String) -> void:
	if not tutorial_system:
		return
	var text: String = tutorial_system.get_current_step_text()
	show_step(step_id, text)


func _on_tutorial_step_completed(
	_step_id: String
) -> void:
	pass


func _on_tutorial_completed() -> void:
	hide_overlay()


func _on_tutorial_skipped() -> void:
	hide_overlay()


func _on_contextual_tip_requested(
	tip_text: String
) -> void:
	_show_tip(tip_text)


func _show_tip(text: String) -> void:
	_tip_label.text = text
	_tip_panel.visible = true
	_tip_visible = true
	_tip_timer = TIP_DISPLAY_DURATION
	_tip_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(
		_tip_panel, "modulate",
		Color.WHITE, FADE_DURATION
	)


func _hide_tip() -> void:
	_tip_visible = false
	var tween: Tween = create_tween()
	tween.tween_property(
		_tip_panel, "modulate",
		Color(1.0, 1.0, 1.0, 0.0), FADE_DURATION
	)
	tween.tween_callback(_tip_panel.hide)


func _get_step_number(step_id: String) -> int:
	var step_ids: Array = TutorialSystem.STEP_IDS.values()
	var idx: int = step_ids.find(step_id)
	if idx < 0:
		return 1
	return idx + 1
