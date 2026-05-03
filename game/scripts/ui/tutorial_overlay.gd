## Non-blocking bottom bar that shows tutorial step prompts during gameplay.
class_name TutorialOverlay
extends CanvasLayer

# Localization marker for static validation: tr("TUTORIAL_WELCOME")

const SLIDE_DURATION: float = 0.3
const SLIDE_OFFSET: float = 100.0

## Game states each tutorial step requires before its prompt may appear.
## Steps absent from this map have no state restriction.
const _STEP_REQUIRED_STATES: Dictionary = {
	"move_to_shelf": GameManager.State.STORE_VIEW,
	"open_inventory": GameManager.State.STORE_VIEW,
	"place_item": GameManager.State.STORE_VIEW,
	"set_price": GameManager.State.STORE_VIEW,
	"wait_for_customer": GameManager.State.STORE_VIEW,
	"close_day": GameManager.State.STORE_VIEW,
}

var tutorial_system: TutorialSystem

var _current_tween: Tween
var _rest_offset_top: float
## Most-recently-received step id; used to re-show after a state transition.
var _pending_step_id: String = ""

@onready var _bottom_bar: PanelContainer = $BottomBar
@onready var _prompt_label: Label = $BottomBar/HBox/PromptLabel
@onready var _skip_button: Button = $BottomBar/HBox/SkipButton


func _ready() -> void:
	_bottom_bar.visible = false
	_rest_offset_top = _bottom_bar.offset_top
	_skip_button.pressed.connect(_on_skip_pressed)
	EventBus.tutorial_step_changed.connect(_on_tutorial_step_changed)
	EventBus.tutorial_completed.connect(_on_tutorial_completed)
	EventBus.tutorial_skipped.connect(_on_tutorial_completed)
	EventBus.tutorial_context_cleared.connect(_on_tutorial_context_cleared)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	InputFocus.context_changed.connect(_on_input_focus_changed)
	if tutorial_system and tutorial_system.tutorial_completed:
		_bottom_bar.visible = false
		set_process(false)
		return
	if GameState.get_flag(&"tutorial_skipped"):
		_bottom_bar.visible = false
		set_process(false)


## Returns false when tutorial UI must not render:
## blocked in MAIN_MENU or DAY_SUMMARY states, when a modal has input focus,
## or when the tutorial_skipped flag is set. All FP tutorial steps render
## inside STORE_VIEW; MALL_OVERVIEW is left permissive here because contextual
## tips can still surface there after the tutorial completes.
## TutorialContextSystem.is_tutorial_rendering_allowed() additionally blocks
## MALL_OVERVIEW for autoload-level context-entry decisions, which is a
## separate concern from overlay rendering.
func _can_show_tutorial() -> bool:
	if GameState.get_flag(&"tutorial_skipped"):
		return false
	var state: GameManager.State = GameManager.current_state
	if state == GameManager.State.MAIN_MENU or state == GameManager.State.DAY_SUMMARY:
		return false
	if InputFocus.current() == InputFocus.CTX_MODAL:
		return false
	return true


func _step_allowed_in_state(step_id: String) -> bool:
	if not _STEP_REQUIRED_STATES.has(step_id):
		return true
	var required: int = int(_STEP_REQUIRED_STATES[step_id])
	return int(GameManager.current_state) == required


func _on_tutorial_step_changed(step_id: String) -> void:
	_pending_step_id = step_id
	if not tutorial_system:
		return
	if not _can_show_tutorial():
		return
	if not _step_allowed_in_state(step_id):
		return
	var prompt_text: String = tutorial_system.get_current_step_text()
	if prompt_text.is_empty():
		return
	_show_step(prompt_text)


func _on_tutorial_completed() -> void:
	_pending_step_id = ""
	_slide_out_and_free()


func _on_skip_pressed() -> void:
	EventBus.skip_tutorial_requested.emit()


func _on_tutorial_context_cleared() -> void:
	if not _bottom_bar.visible:
		return
	_kill_tween()
	_bottom_bar.visible = false


func _on_game_state_changed(_old_state: int, _new_state: int) -> void:
	_reevaluate_visibility()


func _on_input_focus_changed(_new_ctx: StringName, _old_ctx: StringName) -> void:
	_reevaluate_visibility()


## Re-checks whether the pending step can be shown or must be hidden.
## Called on every game_state_changed or InputFocus.context_changed.
func _reevaluate_visibility() -> void:
	if _bottom_bar.visible:
		if not _can_show_tutorial() or not _step_allowed_in_state(_pending_step_id):
			_kill_tween()
			_bottom_bar.visible = false
		return
	if _pending_step_id.is_empty():
		return
	if not _can_show_tutorial():
		return
	if not _step_allowed_in_state(_pending_step_id):
		return
	if tutorial_system == null:
		return
	var prompt: String = tutorial_system.get_current_step_text()
	if not prompt.is_empty():
		_show_step(prompt)


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
